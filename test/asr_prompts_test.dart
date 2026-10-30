import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/import/ass_parser.dart';
import 'package:voicex/review/review_service.dart';

const header = [
  '[Events]',
  'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
];

String dialogue(int second, String text, {String name = ''}) =>
    'Dialogue: 0,0:00:${second.toString().padLeft(2, '0')}.00,'
    '0:00:${(second + 1).toString().padLeft(2, '0')}.00,'
    'Default,$name,0,0,0,,$text';

void main() {
  late AppDatabase db;
  late Directory directory;
  late File asr;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('voicex_asr_test_');
    // Use the cloud filename too: identifying ASR must not depend on `_asr`.
    asr = File('${directory.path}/asr.ass');
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            projectId: 'project',
            title: 'ASR alignment',
            createdAtMs: 1,
            updatedAtMs: 1,
            baseAssPath: asr.path,
          ),
        );
    await db
        .into(db.projectFiles)
        .insert(
          ProjectFilesCompanion.insert(
            fileId: 'asr',
            projectId: 'project',
            engine: 'asr',
            assPath: asr.path,
            importedAtMs: 1,
          ),
        );
  });

  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<List<String>> load(List<String> base, List<String> annotations) async {
    final parsed = AssParser.parseAssLines([...header, ...base]);
    for (var i = 0; i < parsed.dialogues.length; i++) {
      final d = parsed.dialogues[i];
      await db
          .into(db.subtitleLines)
          .insert(
            SubtitleLinesCompanion.insert(
              lineId: 'line-$i',
              projectId: 'project',
              dialogueIndex: i,
              eventsRowIndex: d.eventsRowIndex,
              startMs: d.startMs,
              endMs: d.endMs,
              style: Value(d.style),
              name: Value(d.name),
              effect: Value(d.effect),
              dialoguePrefix: d.dialoguePrefix,
              originalText: d.text,
              updatedAtMs: 1,
            ),
          );
    }
    await asr.writeAsString([...header, ...annotations].join('\n'));
    return ReviewService(db).loadAsrPrompts('project');
  }

  test(
    'a missing ASR entry leaves a hole without shifting later prompts',
    () async {
      expect(
        await load(
          [dialogue(1, 'One'), dialogue(2, 'Two'), dialogue(3, 'Three')],
          [
            dialogue(1, 'One{one}{Prompt one}'),
            dialogue(3, 'Three{three}{Prompt three}'),
          ],
        ),
        ['Prompt one', '', 'Prompt three'],
      );
    },
  );

  test('extra and reordered entries do not shift prompts', () async {
    expect(
      await load(
        [dialogue(1, 'One'), dialogue(3, 'Three')],
        [
          dialogue(3, 'Three{three}{Prompt three}'),
          dialogue(2, 'Extra{extra}{Wrong prompt}'),
          dialogue(1, 'One{one}{Prompt one}'),
        ],
      ),
      ['Prompt one', 'Prompt three'],
    );
  });

  test('equal entry counts do not imply matching indices', () async {
    expect(
      await load(
        [dialogue(1, 'One'), dialogue(2, 'Two'), dialogue(3, 'Three')],
        [
          dialogue(0, 'Extra{extra}{Wrong prompt}'),
          dialogue(1, 'One{one}{Prompt one}'),
          dialogue(3, 'Three{three}{Prompt three}'),
        ],
      ),
      ['Prompt one', '', 'Prompt three'],
    );
  });

  test('simultaneous entries match by text even when reordered', () async {
    expect(
      await load(
        [dialogue(1, 'One'), dialogue(1, 'Two')],
        [
          dialogue(1, 'Two{two}{Prompt two}'),
          dialogue(1, 'One{one}{Prompt one}'),
        ],
      ),
      ['Prompt one', 'Prompt two'],
    );
  });

  test(
    'speaker disambiguates simultaneous entries with changed text',
    () async {
      expect(
        await load(
          [
            dialogue(1, 'Base one', name: 'A'),
            dialogue(1, 'Base two', name: 'B'),
          ],
          [
            dialogue(1, 'ASR two{two}{Prompt two}', name: 'B'),
            dialogue(1, 'ASR one{one}{Prompt one}', name: 'A'),
          ],
        ),
        ['Prompt one', 'Prompt two'],
      );
    },
  );

  test(
    'missing simultaneous entry does not steal its neighbor prompt',
    () async {
      expect(
        await load(
          [dialogue(1, 'One'), dialogue(1, 'Two')],
          [dialogue(1, 'Two{two}{Prompt two}')],
        ),
        ['', 'Prompt two'],
      );
    },
  );

  test('ambiguous simultaneous entry stays unassigned', () async {
    expect(
      await load(
        [dialogue(1, 'One'), dialogue(1, 'Two')],
        [dialogue(1, 'Different{different}{Ambiguous}')],
      ),
      ['', ''],
    );
  });

  test(
    'formatting and empty romanization preserve prompt slots and breaks',
    () async {
      expect(
        await load(
          [dialogue(1, 'One'), dialogue(2, 'Two'), dialogue(3, 'Three')],
          [
            dialogue(1, r'{\an8}One{one}{First\NSecond\nThird}{\i0}'),
            dialogue(2, 'Two{}{Prompt two}'),
            dialogue(3, r'{\i1}Three{three}{\i0}'),
          ],
        ),
        ['First\nSecond\nThird', 'Prompt two', ''],
      );
    },
  );

  test('CARTEL entries cannot affect prompt alignment', () async {
    expect(
      await load(
        [dialogue(1, 'One'), dialogue(2, 'Two')],
        [
          dialogue(1, 'Sign{sign}{Wrong prompt}', name: 'CARTEL'),
          dialogue(1, 'One{one}{Prompt one}'),
          dialogue(2, 'Two{two}{Prompt two}'),
        ],
      ),
      ['Prompt one', 'Prompt two'],
    );
  });

  test(
    'base file fallback also aligns prompts with stored subtitles',
    () async {
      await db.delete(db.projectFiles).go();
      expect(
        await load(
          [dialogue(2, 'Two')],
          [
            dialogue(1, 'One{one}{Wrong prompt}'),
            dialogue(2, 'Two{two}{Prompt two}'),
          ],
        ),
        ['Prompt two'],
      );
    },
  );
}
