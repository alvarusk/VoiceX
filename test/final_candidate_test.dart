import 'dart:io';

import 'package:cross_file/cross_file.dart';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/import/import_service.dart';
import 'package:voicex/review/review_service.dart';
import 'package:voicex/settings/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FINAL suffix takes precedence over model names', () {
    for (final name in ['episode_final.ass', 'episode_gpt_FINAL.ASS']) {
      expect(inferEngineFromName(name), Engine.finalAss);
    }
    expect(engineToStr(Engine.finalAss), 'final');
    expect(inferEngineFromName('episode_gpt.ass'), Engine.gpt);
    expect(inferEngineFromName('episode_final_draft.ass'), isNull);
    expect(inferEngineFromName('final.ass'), isNull);
  });

  test(
    'version 5 database upgrades without losing existing candidates',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE subtitle_lines (line_id TEXT PRIMARY KEY, cand_gpt TEXT)',
            );
            raw.execute(
              "INSERT INTO subtitle_lines VALUES ('line', 'Existing GPT')",
            );
            raw.execute('PRAGMA user_version = 5');
          },
        ),
      );
      addTearDown(db.close);
      final row = await db
          .customSelect('SELECT * FROM subtitle_lines')
          .getSingle();
      expect(row.read<String>('cand_gpt'), 'Existing GPT');
      expect(row.data['cand_final'], isNull);
      expect(row.data.containsKey('cand_final'), isTrue);
      await db.customStatement(
        "UPDATE subtitle_lines SET cand_final = 'New FINAL'",
      );
      expect(
        (await db
                .customSelect('SELECT cand_final FROM subtitle_lines')
                .getSingle())
            .read<String>('cand_final'),
        'New FINAL',
      );
    },
  );

  test(
    'FINAL imports, can be edited and selected, and has its own metrics',
    () async {
      final dir = await Directory.systemTemp.createTemp('voicex_final_test');
      addTearDown(() => dir.delete(recursive: true));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            ),
      );
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const header =
          '[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n';
      String dialogue(String text) =>
          'Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,$text\n';
      Future<PlatformFile> ass(String name, String text) async {
        final file = File('${dir.path}/$name');
        await file.writeAsString('$header${dialogue(text)}');
        return _LocalAssFile(file);
      }

      final projectId = await ImportService(db).importProject(
        title: 'FINAL import',
        baseAss: await ass('base.ass', 'Original'),
        engineAssFiles: {
          Engine.finalAss: await ass(
            'episode_final.ass',
            r'¡¿Final...?!\N¿¡translation…!? ¡Hola!',
          ),
          Engine.gpt: await ass('episode_gpt.ass', '¡¿GPT...?!'),
        },
      );
      final line = await db.select(db.subtitleLines).getSingle();
      expect(line.candFinal, '¿Final.?\n¿translation.? Hola.');
      expect(line.candGpt, '¡¿GPT...?!');
      expect(line.originalText, 'Original');
      final files = await db.select(db.projectFiles).get();
      expect(files.map((f) => f.engine), contains('final'));
      final review = ReviewService(db);
      await review.setCandidateText(
        lineId: line.lineId,
        source: 'final',
        text: 'Edited FINAL',
      );
      await review.chooseCandidate(
        projectId: projectId,
        lineId: line.lineId,
        source: 'final',
        text: 'Edited FINAL',
        method: 'tap',
      );
      final updated = await db.select(db.subtitleLines).getSingle();
      expect(updated.candFinal, 'Edited FINAL');
      expect(updated.selectedSource, 'final');
      expect(updated.selectedText, 'Edited FINAL');
      final metrics = await review
          .watchMetrics(projectId)
          .firstWhere(
            (m) =>
                m.bySource['final'] == 1 && m.historicalBySource['final'] == 1,
          )
          .timeout(const Duration(seconds: 5));
      expect(metrics.reviewed, 1);
      expect(metrics.bySource['other'] ?? 0, 0);

      // Unequal dialogue counts take the time-matching import path.
      final timedBase = File('${dir.path}/timed_base.ass');
      await timedBase.writeAsString(
        '$header${dialogue('Original')}'
        '${dialogue('Other').replaceAll('0:00:01', '0:00:03').replaceAll('0:00:02', '0:00:04')}',
      );
      final timedId = await ImportService(db).importProject(
        title: 'Timed FINAL import',
        baseAss: _LocalAssFile(timedBase),
        engineAssFiles: {
          Engine.finalAss: await ass('timed_final.ass', '¿¡Final...!? ¡Hola!'),
        },
      );
      final timedLines = await (db.select(
        db.subtitleLines,
      )..where((t) => t.projectId.equals(timedId))).get();
      expect(timedLines.first.candFinal, '¿Final.? Hola.');
      expect(timedLines.last.candFinal, isNull);
    },
  );
}

final class _LocalAssFile extends PlatformFile {
  _LocalAssFile(this.file);
  final File file;
  @override
  String get name => file.uri.pathSegments.last;
  @override
  Uri get uri => file.uri;
  @override
  XFile get xFile => XFile(file.path);
  @override
  Future<int> length() => file.length();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}
