import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/export/export_service_io.dart';
import 'package:voicex/import/ass_parser.dart';
import 'package:voicex/settings/settings_service.dart';

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
