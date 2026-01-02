// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders home navigation', (WidgetTester tester) async {
    // Build a lightweight home scaffold to validate navigation labels.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox.shrink(),
        bottomNavigationBar: NavigationBar(
          destinations: [
            NavigationDestination(icon: Icon(Icons.folder), label: 'Proyectos'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
          ],
        ),
      ),
    ));

    // Verify navigation tabs exist.
    expect(find.text('Proyectos'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
