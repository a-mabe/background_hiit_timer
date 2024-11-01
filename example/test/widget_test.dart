// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Timer smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait until the text "Get ready" is found.
    await tester.pumpAndSettle();
    expect(find.text('Get ready'), findsOneWidget);

    // Move forward 11 seconds.
    await tester.pump(const Duration(seconds: 11));

    await tester.pumpAndSettle();
    expect(find.text('Warmup'), findsOneWidget);

    // Move forward 22 seconds.
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);

    // Tap the restart icon.
    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pump();

    // Wait at most 10 seconds for "Get ready" to be on screen.
    await tester.pumpAndSettle(const Duration(seconds: 10));
    // expect(find.text('Get ready'), findsOneWidget);

    // Tap the button with the text "Stop".
    await tester.tap(find.text('Stop'));
    await tester.pump();

    // Verify that the initial text is "Get ready".
    // expect(find.text('Get ready'), findsOneWidget);
    // expect(find.text('Warmup'), findsNothing);

    // // Wait for 11 seconds.
    // await tester.pump(const Duration(seconds: 11));

    // // Verify that the text has changed to "Warmup".
    // expect(find.text('Get ready'), findsNothing);
    // expect(find.text('Warmup'), findsOneWidget);
  });
}
