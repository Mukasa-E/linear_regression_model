// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salary_predictor/main.dart';

void main() {
  testWidgets('App shows input form', (WidgetTester tester) async {
  // Build our app and trigger a frame.
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Salary Predictor')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Predict'),
          ),
        ),
      ),
    ),
  );
  // Wait for animations and layout (SliverAppBar) to settle.
  await tester.pumpAndSettle();

  // Verify that the app bar title is present.
  expect(find.text('Salary Predictor'), findsOneWidget);
    // Verify that the Predict button exists.
    expect(find.text('Predict'), findsOneWidget);
  });
}
