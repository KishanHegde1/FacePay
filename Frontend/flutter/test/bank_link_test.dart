import 'dart:io';
import 'dart:ui' as ui;

import 'package:face_payment/data/app_state.dart';
import 'package:face_payment/screens/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'frontend_test.dart' as helpers;

void main() {
  test('demo bank connection is only held in local app state', () {
    final state = AppState();
    addTearDown(state.dispose);

    expect(state.linkedBank, isNull);
    state.linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
    expect(state.linkedBank?.name, 'HDFC Bank');
    expect(state.linkedBank?.lastFour, '4821');

    state.unlinkDemoBank();
    expect(state.linkedBank, isNull);
  });

  testWidgets('dashboard can search, link, show, and unlink a demo bank', (
    tester,
  ) async {
    helpers.sizeScreen(tester, const Size(390, 844));
    final state = AppState();
    final capture = GlobalKey();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      helpers.host(
        AppShell(state: state, onSignOut: () {}),
        captureKey: capture,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await helpers.tapVisible(
      tester,
      find.byKey(const ValueKey('bank-link-cta')),
    );
    expect(find.text('Choose your bank'), findsOneWidget);
    expect(find.text('Demo only'), findsOneWidget);
    expect(find.byKey(const ValueKey('bank-search')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const ValueKey('bank-search')), 'hdfc');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bank-option-hdfc')), findsOneWidget);
    expect(find.byKey(const ValueKey('bank-option-sbi')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bank-option-hdfc')));
    await tester.pumpAndSettle();
    await helpers.tapVisible(
      tester,
      find.byKey(const ValueKey('bank-continue')),
    );
    expect(find.text('Review your demo account'), findsOneWidget);
    expect(find.text('Savings account · •••• 4821'), findsOneWidget);
    expect(find.text('OTP'), findsNothing);
    expect(tester.takeException(), isNull);

    await helpers.tapVisible(
      tester,
      find.byKey(const ValueKey('bank-link-confirm')),
    );
    expect(state.linkedBank?.name, 'HDFC Bank');
    expect(find.byKey(const ValueKey('bank-linked-card')), findsOneWidget);
    expect(find.text('Demo connection active'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await helpers.tapVisible(tester, find.text('Back to dashboard'));
    expect(find.byKey(const ValueKey('bank-dashboard-card')), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await helpers.tapVisible(tester, find.byKey(const ValueKey('action-wallet')));
    expect(find.text('Demo account · •••• 4821'), findsOneWidget);
    if (const bool.fromEnvironment('SAVE_PREVIEWS')) {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/previews/bank-linked-wallet-390.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);

    await helpers.tapVisible(
      tester,
      find.byKey(const ValueKey('wallet-bank-link')),
    );
    await helpers.tapVisible(tester, find.byKey(const ValueKey('bank-unlink')));
    await helpers.tapVisible(
      tester,
      find.byKey(const ValueKey('bank-unlink-confirm')),
    );
    expect(state.linkedBank, isNull);
    expect(find.text('Choose your bank'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
