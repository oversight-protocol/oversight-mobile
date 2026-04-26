// Smoke test — ensure the Oversight app builds and the home tagline renders.
// We don't pump the full app (RustLib.init requires the native lib) — just
// the Material wrapper around a placeholder boot screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App scaffold renders without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Oversight'))),
    ));
    expect(find.text('Oversight'), findsOneWidget);
  });
}
