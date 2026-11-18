import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/review/review_page.dart';
import 'package:voicex/review/review_service.dart';
import 'package:voicex/settings/settings_service.dart';
import 'package:voicex/sync/cloud_sync_service.dart';
import 'package:voicex/sync/sync_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    db = AppDatabase(NativeDatabase.memory());
    for (final id in ['one', 'two']) {
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              projectId: id,
              title: id,
              createdAtMs: 10,
              updatedAtMs: 10,
              baseAssPath: '',
            ),
          );
      await db
          .into(db.subtitleLines)
          .insert(
            SubtitleLinesCompanion.insert(
              lineId: id,
              projectId: id,
              dialogueIndex: 0,
              eventsRowIndex: 0,
              startMs: 0,
              endMs: 1000,
              dialoguePrefix: 'Dialogue:',
              originalText: 'Original $id',
              candFinal: const Value('Final candidate'),
              candGpt: const Value('Initial candidate'),
              updatedAtMs: 10,
            ),
          );
    }
  });

  tearDown(() async => db.close());

  test('a new edit invalidates a previously clean cloud indicator', () async {
    final cloud = CloudSyncService(db);
    await SyncPrefs().setLastSynced('one', 20);
    expect(await cloud.isProjectDirty('one'), isFalse);
    await ReviewService(db).setVoiceText('one', 'Cambio pendiente');
    expect(await cloud.isProjectDirty('one'), isTrue);
    expect(await cloud.isProjectDirty('two'), isTrue);
  });

  testWidgets('review settles and displays edits with two loaded projects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPage(db: db, projectId: 'one'),
      ),
    );
    // Let the real SQLite queries complete between frames.
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('Initial candidate'), findsOneWidget);
    expect(find.text('FINAL'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Final candidate')).dy,
      lessThan(tester.getTopLeft(find.text('Initial candidate')).dy),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);

    final edit = ReviewService(
      db,
    ).setCandidateText(lineId: 'one', source: 'gpt', text: 'Edited candidate');
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await edit;
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('Edited candidate'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });

  testWidgets('JAP-only review saves a note without selecting a translation', (
    tester,
  ) async {
    await (db.update(db.subtitleLines)..where((t) => t.projectId.equals('one')))
        .write(const SubtitleLinesCompanion(
          candFinal: Value(null), candGpt: Value(null),
          originalText: Value(r'{\i1}着歯！{romaji}'),
        ));
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: ReviewPage(db: db, projectId: 'one'),
    ));
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('着歯！'), findsOneWidget);
    final note = find.byKey(const ValueKey('review-note-one'));
    expect(note, findsOneWidget);
    await tester.enterText(note, 'actor distinto');
    await tester.tap(find.byTooltip('Mark doubt'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    final line = await tester.runAsync(() =>
      (db.select(db.subtitleLines)..where((t) => t.lineId.equals('one'))).getSingle());
    expect(line!.reviewNote, 'actor distinto');
    expect(line.doubt, isTrue);
    expect(line.selectedText, isNull);
    expect(line.reviewed, isFalse);
    expect(find.text('actor distinto'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
