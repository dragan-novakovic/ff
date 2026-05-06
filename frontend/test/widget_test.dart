// Basic smoke test for the app.
//
// The full app is not pumped here because it expects backend services to be
// available. This test simply ensures the test harness compiles and the Flutter
// test framework is reachable.

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
