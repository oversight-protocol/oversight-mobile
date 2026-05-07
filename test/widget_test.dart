// Smoke test — ensure the Oversight app builds and the home tagline renders.
// We don't pump the full app (RustLib.init requires the native lib) — just
// the Material wrapper around a placeholder boot screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oversight/main.dart';
import 'package:oversight/src/rust/api/verify.dart';

void main() {
  testWidgets('App scaffold renders without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Oversight'))),
    ));
    expect(find.text('Oversight'), findsOneWidget);
  });

  testWidgets('Result page can copy a verification receipt',
      (WidgetTester tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(MaterialApp(
      home: ResultPage(
        filename: 'sample.oversight',
        result: _verifiedResult(),
      ),
    ));

    await tester.tap(find.byTooltip('Copy receipt'));
    await tester.pump();

    expect(find.text('Receipt copied'), findsOneWidget);
    expect(
      calls.any((call) =>
          call.method == 'Clipboard.setData' &&
          (call.arguments as Map)['text']
              .toString()
              .contains('Oversight verification receipt')),
      isTrue,
    );
  });
}

VerifyResult _verifiedResult() {
  return VerifyResult(
    status: VerifyStatus.ok,
    bundleSizeBytes: BigInt.from(256),
    signatureValid: true,
    failures: const [],
    manifest: ManifestSummary(
      fileId: 'file-123',
      issuerId: 'issuer-1',
      issuerPubkeyShort: '01234567...89abcdef',
      originalFilename: 'sample.txt',
      contentType: 'text/plain',
      contentHashShort: 'abcdef01...23456789',
      sizeBytes: BigInt.from(42),
      issuedAtUnix: 1767225600,
      suite: 'OSGT-CLASSIC-v1',
      watermarkCount: BigInt.zero,
      hasRecipient: true,
    ),
  );
}
