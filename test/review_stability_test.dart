import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/review/review_page.dart';
import 'package:voicex/review/review_service.dart';
import 'package:voicex/import/ass_parser.dart';
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

  testWidgets('desktop grid keeps five candidates and voice visible', (
    tester,
  ) async {
    await (db.update(
      db.subtitleLines,
    )..where((t) => t.projectId.equals('one'))).write(
      const SubtitleLinesCompanion(
        name: Value('Natsumi'),
        sourceText: Value(
          '僕も仲間に入れって言うんでしょ！{boku mo nakama ni irete tte iun desho!}',
        ),
        candFinal: Value('Ibas a pedirles que te dejaran ir.'),
        candGpt: Value('Ibas a pedirles que te dejaran ir con ellos.'),
        candClaude: Value('Ibas a pedir que te dejaran unirte, ¿a que sí?'),
        candGemini: Value('Ibas a decir que te dejaran ir con ellos, ¿verdad?'),
        candDeepseek: Value(
          'Seguro que dices que te deje apuntarme a mí también.',
        ),
        candVoice: Value('Ibas a pedirles que te dejaran ir con ellos.'),
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final captureKey = GlobalKey();
    const previewFont = String.fromEnvironment('REVIEW_FONT');
    const previewJapanese = String.fromEnvironment('REVIEW_JAPANESE_FONT');
    const previewIcons = String.fromEnvironment('REVIEW_ICONS');
    for (final (family, path) in [
      ('ReviewUI', previewFont),
      ('ReviewJapanese', previewJapanese),
      ('MaterialIcons', previewIcons),
    ]) {
      if (path.isNotEmpty) {
        await tester.runAsync(() async {
          final loader = FontLoader(family)
            ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
          await loader.load();
        });
      }
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: previewFont.isEmpty ? null : 'ReviewUI',
            fontFamilyFallback: previewJapanese.isEmpty
                ? null
                : ['ReviewJapanese'],
          ),
          home: ReviewPage(db: db, projectId: 'one'),
        ),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (final label in [
      'FINAL',
      'GPT',
      'Claude',
      'Gemini',
      'DeepSeek',
      'My voice',
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('desktop-review-grid')), findsOneWidget);
    for (final (left, right) in [
      ('FINAL', 'GPT'),
      ('Claude', 'Gemini'),
      ('DeepSeek', 'My voice'),
    ]) {
      expect(
        tester.getTopLeft(find.text(left)).dy,
        closeTo(tester.getTopLeft(find.text(right)).dy, 8),
      );
      expect(
        tester.getTopLeft(find.text(left)).dx,
        lessThan(tester.getTopLeft(find.text(right)).dx),
      );
    }
    expect(
      tester.getTopLeft(find.text('FINAL')).dy,
      lessThan(tester.getTopLeft(find.text('Claude')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Claude')).dy,
      lessThan(tester.getTopLeft(find.text('DeepSeek')).dy),
    );
    if (const bool.fromEnvironment('CAPTURE_REVIEW')) {
      await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/review_grid_desktop.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    tester.view.physicalSize = const Size(1366, 768);
    await tester.pumpAndSettle();
    for (final label in [
      'FINAL',
      'GPT',
      'Claude',
      'Gemini',
      'DeepSeek',
      'My voice',
    ]) {
      expect(
        find.text(label).hitTestable(),
        findsOneWidget,
        reason: 'Laptop: $label must stay visible',
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'JAP-only review saves a note without selecting a translation',
    (tester) async {
      final parsed = AssParser.parseAssLines([
        '[Events]',
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
        r'Dialogue: 0,0:07:54.42,0:07:56.93,Gen_Main,Fuyuki,0,0,0,,こんな古いのも売ってんだ……。\N{konna furui no mo uttenda......}',
      ]).dialogues.single;
      await (db.update(
        db.subtitleLines,
      )..where((t) => t.projectId.equals('one'))).write(
        SubtitleLinesCompanion(
          candFinal: const Value(null),
          candGpt: const Value(null),
          originalText: Value(parsed.text),
          sourceText: Value(parsed.sourceText),
        ),
      );
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPage(db: db, projectId: 'one'),
        ),
      );
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        find.text('こんな古いのも売ってんだ……。\nkonna furui no mo uttenda......'),
        findsOneWidget,
      );
      final note = find.byKey(const ValueKey('review-note-one'));
      expect(note, findsOneWidget);
      await tester.enterText(note, 'actor distinto');
      await tester.tap(find.byTooltip('Mark doubt'));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      final line = await tester.runAsync(
        () => (db.select(
          db.subtitleLines,
        )..where((t) => t.lineId.equals('one'))).getSingle(),
      );
      expect(line!.reviewNote, 'actor distinto');
      expect(line.doubt, isTrue);
      expect(line.selectedText, isNull);
      expect(line.reviewed, isFalse);
      expect(line.originalText, parsed.text);
      expect(find.text('actor distinto'), findsOneWidget);

      // Formatting overrides must not be mistaken for the romanization.
      await tester.runAsync(
        () =>
            (db.update(
              db.subtitleLines,
            )..where((t) => t.lineId.equals('one'))).write(
              const SubtitleLinesCompanion(
                originalText: Value(r'{\i1}着歯！{romaji}'),
                sourceText: Value(null),
              ),
            ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.text('着歯！\nromaji'), findsOneWidget);

      // Plain _ja-jp files still display only the Japanese source.
      await tester.runAsync(
        () =>
            (db.update(
              db.subtitleLines,
            )..where((t) => t.lineId.equals('one'))).write(
              const SubtitleLinesCompanion(
                originalText: Value('こんな古いのも売ってんだ……。'),
                sourceText: Value('こんな古いのも売ってんだ……。'),
              ),
            ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.text('こんな古いのも売ってんだ……。'), findsOneWidget);
      expect(find.text('actor distinto'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await db.close();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
