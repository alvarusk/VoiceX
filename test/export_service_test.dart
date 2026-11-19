import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/export/export_service_io.dart';
import 'package:voicex/export/export_service_web.dart' as web;
import 'package:voicex/import/ass_parser.dart';
import 'package:voicex/settings/settings_service.dart';
import 'package:voicex/review/review_service.dart';
import 'package:voicex/review/source_review.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late File base;
  late AppDatabase db;
  const header =
      '[Events]\n'
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n';
  String event(int second, String text, {String name = ''}) =>
      'Dialogue: 0,0:00:0$second.00,0:00:0$second.90,Default,$name,0,0,0,,$text';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('voicex_export_test');
    base = File('${dir.path}/base.ass');
    await base.writeAsString(
      '$header${event(1, 'Bonjour')}\n'
      '${event(2, 'CARTEL', name: 'CARTEL')}\n${event(3, 'Au revoir')}\n',
    );
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await SettingsService.instance.setProjectExportMetadata(
      'p',
      directory: dir.path,
      fileName: 'result.ass',
    );
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            projectId: 'p',
            title: 'French',
            createdAtMs: 1,
            updatedAtMs: 1,
            baseAssPath: base.path,
          ),
        );
    final dialogues = AssParser.parseAssLines(
      await base.readAsLines(),
    ).dialogues.where((d) => !AssParser.isCartel(d)).toList();
    for (var i = 0; i < dialogues.length; i++) {
      final d = dialogues[i];
      await db
          .into(db.subtitleLines)
          .insert(
            SubtitleLinesCompanion.insert(
              lineId: '$i',
              projectId: 'p',
              dialogueIndex: i,
              eventsRowIndex: d.eventsRowIndex,
              startMs: d.startMs,
              endMs: d.endMs,
              style: Value(d.style),
              name: Value(d.name),
              effect: Value(d.effect),
              dialoguePrefix: d.dialoguePrefix,
              originalText: d.text,
              selectedText: Value(['Hola editado', 'Adiós editado'][i]),
              reviewed: const Value(true),
              updatedAtMs: 1,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'exports straight quotes on desktop and web without editing stored text',
    () async {
      const selected = 'Dijo: «Hola», «adiós».';
      await (db.update(db.subtitleLines)..where((t) => t.lineId.equals('0')))
          .write(const SubtitleLinesCompanion(selectedText: Value(selected)));
      final original = await base.readAsString();
      await base.writeAsString(
        '$original\nComment: 0,0:00:00.00,0:00:00.00,Default,,0,0,0,,«Nota original»',
      );
      final desktop = await ExportService(db).exportCleanAssXFile('p');
      final desktopText = await desktop.readAsString();
      expect(desktopText, contains('Dijo: "Hola", "adiós".'));
      expect(desktopText, contains(',,"Nota original"'));
      final browser = await web.ExportService(db).exportCleanAssXFile('p');
      expect(await browser.readAsString(), contains('Dijo: "Hola", "adiós".'));
      final line = await (db.select(
        db.subtitleLines,
      )..where((t) => t.lineId.equals('0'))).getSingle();
      expect(line.selectedText, selected);
      expect(await base.readAsString(), contains('«Nota original»'));
    },
  );

  test(
    'source review exports straight quotes in source text and notes',
    () async {
      await (db.update(
        db.subtitleLines,
      )).write(const SubtitleLinesCompanion(selectedText: Value(null)));
      await ReviewService(db).setReviewNote('0', 'comprobar «actor»');
      final desktop = await ExportService(db).exportCleanAssXFile('p');
      final browser = await web.ExportService(db).exportCleanAssXFile('p');
      for (final output in [desktop, browser]) {
        expect(
          await output.readAsString(),
          contains('Bonjour(comprobar "actor")'),
        );
      }
    },
  );

  test(
    'does not reuse absolute row indices as relative indices on signs',
    () async {
      final output = await ExportService(db).exportCleanAssXFile('p');
      final text = await output.readAsString();
      expect(text, contains(event(1, 'Hola editado')));
      expect(text, contains(event(2, 'CARTEL', name: 'CARTEL')));
      expect(text, contains(event(3, 'Adiós editado')));
      expect('Hola editado'.allMatches(text).length, 1);
    },
  );

  test('source review exports Japanese, flags and independent notes', () async {
    final originals = [r'{\i1}着歯！{romaji}{gloss}', 'たのむであります。'];
    await base.writeAsString(
      '$header${event(1, originals[0], name: 'Tamama')}\n'
      '${event(2, r'{tag}CARTEL', name: 'CARTEL')}\n'
      '${event(3, originals[1], name: 'Keroro')}\n',
    );
    for (var i = 0; i < 2; i++) {
      final actor = ['Tamama', 'Keroro'][i];
      final prefix = event(i == 0 ? 1 : 3, '', name: actor);
      await (db.update(
        db.subtitleLines,
      )..where((t) => t.lineId.equals('$i'))).write(
        SubtitleLinesCompanion(
          originalText: Value(originals[i]),
          name: Value(actor),
          dialoguePrefix: Value(prefix),
          selectedText: const Value(null),
          reviewed: const Value(false),
        ),
      );
    }
    final service = ReviewService(db);
    await service.toggleDoubt('0', true);
    await service.setReviewNote('0', 'actor distinto');
    await service.setReviewNote('1', 'comprobar texto');
    expect(await watchSourceReview(db, 'p').first, isTrue);
    final output = await ExportService(db).exportCleanAssXFile('p');
    final text = await output.readAsString();
    expect(
      text,
      contains(
        event(
          1,
          '着歯！(actor distinto)',
          name: 'Tamama',
        ).replaceFirst('Dialogue:', 'Comment:'),
      ),
    );
    expect(
      text,
      contains(event(3, 'たのむであります。(comprobar texto)', name: 'Keroro')),
    );
    expect(text, contains(event(2, 'CARTEL', name: 'CARTEL')));
    expect(text, isNot(contains('{')));
    expect(text, isNot(contains('Gen_Italics')));
    final line = await (db.select(
      db.subtitleLines,
    )..where((t) => t.lineId.equals('0'))).getSingle();
    expect(line.selectedText, isNull);
    expect(line.reviewed, isFalse);
    expect(line.originalText, originals[0]);
    await service.toggleDoubt('0', false);
    final unflagged = await ExportService(db).exportCleanAssXFile('p');
    expect(
      await unflagged.readAsString(),
      contains(event(1, '着歯！(actor distinto)', name: 'Tamama')),
    );
  });

  test(
    'source review blocks unmatched lines even without selections',
    () async {
      await (db.update(
        db.subtitleLines,
      )).write(const SubtitleLinesCompanion(selectedText: Value(null)));
      await base.writeAsString('$header${event(1, 'Changed')}');
      await expectLater(
        ExportService(db).exportCleanAssXFile('p'),
        throwsA(isA<ExportBlockedException>()),
      );
      expect(await File('${dir.path}/result.ass').exists(), isFalse);
    },
  );

  test('matches edits after header and comment rows shift', () async {
    final original = await base.readAsString();
    await base.writeAsString(
      '[Script Info]\nTitle: Changed header\n$original'.replaceFirst(
        event(1, 'Bonjour'),
        'Comment: 0,0:00:00.00,0:00:00.00,Default,,0,0,0,,Note\n${event(1, 'Bonjour')}',
      ),
    );
    final output = await ExportService(db).exportCleanAssXFile('p');
    final text = await output.readAsString();
    expect(text, contains(event(1, 'Hola editado')));
    expect(text, contains(event(3, 'Adiós editado')));
    expect(text, contains(',,Note'));
  });

  test(
    'blocks changed base instead of exporting unrelated unedited text',
    () async {
      await base.writeAsString(
        '$header${event(1, 'Different')}\n${event(3, 'Au revoir')}',
      );
      await expectLater(
        ExportService(db).exportCleanAssXFile('p'),
        throwsA(isA<ExportBlockedException>()),
      );
      expect(await File('${dir.path}/result.ass').exists(), isFalse);
    },
  );

  test(
    'keeps the internal base intact when output name equals base name',
    () async {
      final original = await base.readAsString();
      await SettingsService.instance.setProjectExportMetadata(
        'p',
        directory: dir.path,
        fileName: 'base.ass',
      );
      // A non-generic source name exercises the normal filename-preserving path.
      final namedBase = await base.rename('${dir.path}/french.ass');
      await (db.update(db.projects)..where((p) => p.projectId.equals('p')))
          .write(ProjectsCompanion(baseAssPath: Value(namedBase.path)));
      await SettingsService.instance.setProjectExportMetadata(
        'p',
        directory: dir.path,
        fileName: 'french.ass',
      );
      final output = await ExportService(db).exportCleanAssXFile('p');
      expect(output.path, isNot(namedBase.path));
      expect(await namedBase.readAsString(), original);
      await ExportService(db).exportCleanAssXFile('p');
    },
  );
}
