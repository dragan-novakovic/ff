// Basic smoke test for the app.
//
// The full app cannot be pumped here because it requires a live Firebase
// connection. This test simply ensures the test harness compiles and the
// Flutter test framework is reachable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke: trivial widget pumps', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('OK'))),
    );
    expect(find.text('OK'), findsOneWidget);
  });
}
