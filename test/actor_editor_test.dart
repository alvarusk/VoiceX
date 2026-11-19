import 'dart:async';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/review/actor_editor.dart';
import 'package:voicex/review/review_service.dart';

void main() {
  test(
    'actor suggestions are unique, project scoped and reflect edits',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      for (final (id, project, actor) in [
        ('a', 'p', 'Natsumi'),
        ('b', 'p', 'Keroro'),
        ('c', 'p', 'Natsumi'),
        ('d', 'other', 'Other project'),
      ]) {
        await db
            .into(db.subtitleLines)
            .insert(
              SubtitleLinesCompanion.insert(
                lineId: id,
                projectId: project,
                dialogueIndex: 0,
                eventsRowIndex: 0,
                startMs: 0,
                endMs: 1000,
                name: Value(actor),
                dialoguePrefix:
                    'Comment: 0,0:00:00.00,0:00:01.00,Default,$actor,0,0,0,,',
                originalText: 'Original',
                updatedAtMs: 1,
                doubt: const Value(true),
              ),
            );
      }
      final service = ReviewService(db);
      expect(await service.watchActorNames('p').first, ['Keroro', 'Natsumi']);
      await service.setActorName('a', '  New   actor  ');
      expect(await service.watchActorNames('p').first, [
        'Keroro',
        'Natsumi',
        'New actor',
      ]);
      final line = await (db.select(
        db.subtitleLines,
      )..where((t) => t.lineId.equals('a'))).getSingle();
      expect(line.name, 'New actor');
      expect(line.dialoguePrefix, startsWith('Comment:'));
      expect(line.dialoguePrefix, contains(',New actor,'));
      expect(line.selectedText, isNull);
      await Future.wait([
        service.toggleDoubt('a', false),
        service.setActorName('a', 'Keroro'),
      ]);
      final updated = await (db.select(
        db.subtitleLines,
      )..where((t) => t.lineId.equals('a'))).getSingle();
      expect(updated.name, 'Keroro');
      expect(updated.doubt, isFalse);
      expect(updated.dialoguePrefix, startsWith('Dialogue:'));
      expect(updated.dialoguePrefix, contains(',Keroro,'));
    },
  );

  testWidgets(
    'actor dropdown allows selecting and typing without a save button',
    (tester) async {
      final saved = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActorEditor(
              initialValue: 'Natsumi',
              actors: const ['Keroro', 'Natsumi'],
              onSave: (value) async {
                saved.add(value);
              },
            ),
          ),
        ),
      );
      expect(find.byTooltip('Save actor'), findsNothing);
      await tester.tap(find.byTooltip('Choose actor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keroro').last);
      await tester.pumpAndSettle();
      expect(saved.last, 'Keroro');
      await tester.enterText(find.byType(TextField), 'Original actor');
      await tester.pump();
      expect(saved.last, 'Original actor');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(saved.last, '');
    },
  );

  testWidgets('actor writes stay ordered and finish after leaving the line', (
    tester,
  ) async {
    final firstSave = Completer<void>();
    final saved = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActorEditor(
            initialValue: 'Natsumi',
            actors: const [],
            onSave: (value) async {
              if (saved.isEmpty) {
                saved.add(value);
                await firstSave.future;
              } else {
                saved.add(value);
              }
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'N');
    await tester.enterText(find.byType(TextField), 'New actor');
    await tester.pump();
    expect(saved, ['N']);
    await tester.pumpWidget(const SizedBox.shrink());
    firstSave.complete();
    await tester.pump();
    expect(saved, ['N', 'New actor']);
    expect(tester.takeException(), isNull);
  });
}
