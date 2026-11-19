import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicex/review/source_review_flags.dart';

void main() {
  testWidgets('review flags toggle independently and serialize rapid taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = <String>[];
    final firstSave = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceReviewFlags(
            note: '',
            onChanged: (note) async {
              saved.add(note);
              if (saved.length == 1) await firstSave.future;
            },
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FilledButton).first).height, 64);
    await tester.tap(find.text('Actor'));
    await tester.pump();
    expect(find.text('(Revisar actor)'), findsOneWidget);
    await tester.tap(find.text('Text'));
    await tester.pump();
    expect(find.text('(Revisar actor y texto)'), findsOneWidget);
    await tester.tap(find.text('Actor'));
    await tester.pump();
    expect(find.text('(Revisar texto)'), findsOneWidget);
    await tester.tap(find.text('Text'));
    await tester.pump();
    expect(find.textContaining('(Revisar'), findsNothing);
    firstSave.complete();
    await tester.pump();
    expect(saved, [
      'Revisar actor',
      'Revisar actor y texto',
      'Revisar texto',
      '',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening a line restores flags and preserves existing notes', (
    tester,
  ) async {
    final saved = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceReviewFlags(
            note: 'Nota anterior\nRevisar texto',
            onChanged: (note) async => saved.add(note),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Actor'));
    await tester.pump();
    expect(saved.last, 'Nota anterior\nRevisar actor y texto');
    await tester.tap(find.text('Text'));
    await tester.pump();
    expect(saved.last, 'Nota anterior\nRevisar actor');
    await tester.tap(find.text('Actor'));
    await tester.pump();
    expect(saved.last, 'Nota anterior');
  });
}
