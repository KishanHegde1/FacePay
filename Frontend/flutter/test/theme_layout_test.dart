import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_payment/data/app_state.dart';
import 'package:face_payment/screens/app_shell.dart';
import 'package:face_payment/screens/auth_screen.dart';
import 'package:face_payment/screens/profile_screen.dart';
import 'package:face_payment/screens/wallet_screen.dart';
import 'package:face_payment/screens/activity_screen.dart';
import 'package:face_payment/screens/payment_screen.dart';
import 'package:face_payment/screens/receive_screen.dart';
import 'package:face_payment/screens/bank_link_screen.dart';
import 'package:face_payment/screens/balance_screen.dart';
import 'package:face_payment/screens/settings_screen.dart';
import 'package:face_payment/screens/scan_screen.dart';
import 'package:face_payment/services/app_settings.dart';
import 'package:face_payment/ui/design.dart';
import 'frontend_test.dart' as helpers;
import 'settings_photo_test.dart' as photos;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in width == 320 ? [1.0, 1.8] : [1.0]) {
        testWidgets(
          '${dark ? 'dark' : 'light'} screens width $width text scale $scale',
          (tester) async {
            helpers.sizeScreen(tester, Size(width, width >= 1000 ? 900 : 844));
            final state = AppState();
            final settings = AppSettings();
            addTearDown(state.dispose);
            addTearDown(settings.dispose);
            final pages = <String, Widget>{
              'login': AuthScreen(
                authService: helpers.FakeAuthService(),
                onAuthenticated: (_) {},
              ),
              'dashboard': AppShell(state: state, onSignOut: () {}),
              'wallet': WalletScreen(state: state),
              'activity': ActivityScreen(state: state),
              'profile': ProfileScreen(
                profile: helpers.testProfile,
                photoRepository: photos.FakePhotos(),
                onSignOut: () {},
              ),
              'payment': PaymentScreen(state: state),
              'receive': ReceiveScreen(state: state),
              'banks': BankLinkScreen(state: state),
              'balance': BalanceScreen(state: state),
              'settings': SettingsScreen(settings: settings),
              'scan': ScanScreen(
                state: state,
                session: helpers.LayoutScannerSession(),
              ),
            };
            for (final entry in pages.entries) {
              final capture = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: RepaintBoundary(
                    key: capture,
                    child: Scaffold(body: entry.value),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: entry.key);
              if (const bool.fromEnvironment('SAVE_PREVIEWS') &&
                  width == 390 &&
                  [
                    'login',
                    'dashboard',
                    'profile',
                    'settings',
                  ].contains(entry.key)) {
                final boundary =
                    capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                await tester.runAsync(() async {
                  final image = await boundary.toImage(pixelRatio: 1);
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final file = File(
                    'build/review/${dark ? 'dark' : 'light'}-${entry.key}.png',
                  );
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(data!.buffer.asUint8List());
                  image.dispose();
                });
              }
              await tester.pumpWidget(const SizedBox());
            }
          },
        );
      }
    }
  }
}
