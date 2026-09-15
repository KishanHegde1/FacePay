import 'package:face_payment/data/app_state.dart';
import 'package:face_payment/screens/wallet_screen.dart';
import 'package:face_payment/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
  });

  testWidgets('wallet starts empty without funding controls or card data', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: WalletScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.balance, 0);
    expect(state.transactions, isEmpty);
    expect(find.text('Your wallet is ready for setup'), findsOneWidget);
    expect(find.text('Payments are not active yet'), findsOneWidget);
    expect(find.text('Add demo money'), findsNothing);
    expect(find.text('••••   ••••   ••••   2048'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet setup fits a compact phone viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: WalletScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse bank directory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
