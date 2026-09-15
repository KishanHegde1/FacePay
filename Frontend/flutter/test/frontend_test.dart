import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:face_payment/main.dart';
import 'package:face_payment/data/app_state.dart';
import 'package:face_payment/screens/app_shell.dart';
import 'package:face_payment/screens/auth_screen.dart';
import 'package:face_payment/screens/wallet_screen.dart';
import 'package:face_payment/screens/activity_screen.dart';
import 'package:face_payment/screens/profile_screen.dart';
import 'package:face_payment/screens/payment_screen.dart';
import 'package:face_payment/screens/receive_screen.dart';
import 'package:face_payment/screens/scan_screen.dart';
import 'package:face_payment/screens/bank_link_screen.dart';
import 'package:face_payment/services/auth_api.dart';
import 'package:face_payment/services/session_store.dart';
import 'package:face_payment/services/scanner_session.dart';
import 'package:face_payment/services/scan_detection.dart';
import 'package:face_payment/ui/design.dart';

const testSession = AuthSession(
  accessToken: 'server-session-token',
  userId: 'user-123',
  phone: '+917349083847',
  expiresIn: 3600,
);

const testProfile = ProfileData(
  id: 'user-123',
  mobileNo: '+917349083847',
  name: '',
  email: '',
);

/// Layout tests never acquire a native camera; scanner lifecycle and results
/// are covered by the dedicated scanner tests.
class LayoutScannerSession extends ScannerSession {
  @override
  ScannerStatus get status => ScannerStatus.scanning;
  @override
  String get message => 'Point your camera at a QR code or one FacePay user.';
  @override
  bool get checkingBlinks => false;
  @override
  int get blinkCount => 0;
  @override
  ScanDetection? get detection => null;
  @override
  Widget buildPreview() => const Center(
    child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white54, size: 76),
  );
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> switchCamera() async {}
}

class PaymentScannerSession extends LayoutScannerSession {
  @override
  ScannerStatus status = ScannerStatus.scanning;
  @override
  ScanDetection? detection;

  void complete(ScanDetection value) {
    detection = value;
    status = ScannerStatus.detected;
    notifyListeners();
  }
}

class MemorySessionStore implements SessionStore {
  String? token;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class FakeAuthService implements AuthService {
  @override
  Future<AuthSession> getCurrentUser(String token) async => testSession;
  @override
  Future<ProfileData> getProfile(String token) async => testProfile;
  @override
  Future<ProfileData> saveProfile(
    String token,
    String name,
    String email,
  ) async => ProfileData(
    id: testProfile.id,
    mobileNo: testProfile.mobileNo,
    name: name,
    email: email,
  );
  final requestedPhones = <String>[];
  final verificationRequests = <({String challengeId, String otp})>[];
  final loggedOutTokens = <String>[];
  Future<OtpChallenge> Function(String phone)? onRequest;
  Future<AuthSession> Function(String challengeId, String otp)? onVerify;

  @override
  Future<OtpChallenge> requestOtp(String phone) async {
    requestedPhones.add(phone);
    if (onRequest != null) return onRequest!(phone);
    return OtpChallenge(
      id: 'challenge-${requestedPhones.length}',
      expiresIn: 300,
      retryAfter: 0,
      developmentTest: true,
    );
  }

  @override
  Future<AuthSession> verifyOtp(String challengeId, String otp) async {
    verificationRequests.add((challengeId: challengeId, otp: otp));
    if (onVerify != null) return onVerify!(challengeId, otp);
    return testSession;
  }

  @override
  Future<void> logout(String accessToken) async {
    loggedOutTokens.add(accessToken);
  }

  @override
  void dispose() {}
}

void sizeScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget host(Widget screen, {GlobalKey? captureKey}) => RepaintBoundary(
  key: captureKey,
  child: MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home:
        screen is AppShell ||
            screen is AuthScreen ||
            screen is PaymentScreen ||
            screen is ReceiveScreen ||
            screen is ScanScreen ||
            screen is BankLinkScreen
        ? screen
        : Scaffold(body: screen),
  ),
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  final screens = <String, Widget Function(AppState)>{
    'login': (state) =>
        AuthScreen(authService: FakeAuthService(), onAuthenticated: (_) {}),
    'dashboard': (state) => AppShell(state: state, onSignOut: () {}),
    'wallet': (state) => WalletScreen(state: state),
    'activity': (state) => ActivityScreen(state: state),
    'profile': (state) => ProfileScreen(profile: testProfile, onSignOut: () {}),
    'payment': (state) => PaymentScreen(state: state),
    'receive': (state) => ReceiveScreen(state: state),
    'scan': (state) =>
        ScanScreen(state: state, session: LayoutScannerSession()),
    'bank-link': (state) => BankLinkScreen(state: state),
  };
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 600),
    const Size(1440, 1000),
  ]) {
    for (final screen in screens.entries) {
      testWidgets(
        '${screen.key} has no layout errors at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          sizeScreen(tester, size);
          final state = AppState();
          addTearDown(state.dispose);
          final capture = GlobalKey();
          await tester.pumpWidget(
            host(screen.value(state), captureKey: capture),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('SAVE_PREVIEWS') &&
              (size.width == 390 || size.width == 1440)) {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1.5);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final output = File(
                'build/previews/${screen.key}-${size.width.toInt()}.png',
              );
              await output.parent.create(recursive: true);
              await output.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 600),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'OTP has no layout errors at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        sizeScreen(tester, size);
        final capture = GlobalKey();
        await tester.pumpWidget(
          host(
            AuthScreen(authService: FakeAuthService(), onAuthenticated: (_) {}),
            captureKey: capture,
          ),
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-phone')),
          '7349083847',
        );
        await tapVisible(tester, find.text('Continue'));
        expect(find.byKey(const ValueKey('auth-otp')), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('SAVE_PREVIEWS') &&
            (size.width == 390 || size.width == 1440)) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = File('build/previews/otp-${size.width.toInt()}.png');
            await output.parent.create(recursive: true);
            await output.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'phone validation prevents requests and sends a canonical Indian number',
    (tester) async {
      sizeScreen(tester, const Size(390, 844));
      final service = FakeAuthService();
      await tester.pumpWidget(
        host(
          AuthScreen(
            authService: service,
            onAuthenticated: (_) =>
                fail('A phone number alone must not sign in'),
          ),
        ),
      );
      await tapVisible(tester, find.text('Continue'));
      expect(service.requestedPhones, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('auth-phone')), '12345');
      await tapVisible(tester, find.text('Continue'));
      expect(service.requestedPhones, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '7349083847',
      );
      await tapVisible(tester, find.text('Continue'));
      expect(service.requestedPhones, ['+917349083847']);
      expect(find.byKey(const ValueKey('auth-otp')), findsOneWidget);
      expect(find.text('Explore demo'), findsNothing);
      expect(find.byKey(const ValueKey('auth-password')), findsNothing);
      expect(find.byKey(const ValueKey('auth-email')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'dashboard waits for server verification and preserves leading-zero OTP',
    (tester) async {
      sizeScreen(tester, const Size(390, 844));
      final pending = Completer<AuthSession>();
      final service = FakeAuthService()..onVerify = (_, _) => pending.future;
      await tester.pumpWidget(
        FacePaymentApp(
          authService: service,
          sessionStore: MemorySessionStore(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '7349083847',
      );
      await tapVisible(tester, find.text('Continue'));
      expect(find.byType(AppShell), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '000000');
      await tester.ensureVisible(find.text('Verify & continue'));
      await tester.tap(find.text('Verify & continue'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.verificationRequests, [
        (challengeId: 'challenge-1', otp: '000000'),
      ]);
      expect(find.byType(AppShell), findsNothing);
      pending.complete(testSession);
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      await tapVisible(tester, find.text('Profile'));
      await tapVisible(tester, find.text('Sign out'));
      expect(service.loggedOutTokens, ['server-session-token']);
      expect(find.byKey(const ValueKey('auth-phone')), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'invalid and incomplete OTP keep the dashboard closed and allow retry',
    (tester) async {
      sizeScreen(tester, const Size(390, 844));
      final service = FakeAuthService()
        ..onVerify = (_, _) async => throw const AuthFailure(
          'That code is incorrect. Try again.',
          code: 'invalid_otp',
        );
      AuthSession? result;
      await tester.pumpWidget(
        host(
          AuthScreen(
            authService: service,
            onAuthenticated: (value) => result = value,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '7349083847',
      );
      await tapVisible(tester, find.text('Continue'));
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '000');
      await tapVisible(tester, find.text('Verify & continue'));
      expect(service.verificationRequests, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '123456');
      await tapVisible(tester, find.text('Verify & continue'));
      expect(find.text('That code is incorrect. Try again.'), findsOneWidget);
      expect(result, isNull);
      expect(find.byKey(const ValueKey('auth-otp')), findsOneWidget);
      service.onVerify = null;
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '000000');
      await tapVisible(tester, find.text('Verify & continue'));
      expect(result, same(testSession));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'request and verify connection failures show an error and permit retry',
    (tester) async {
      sizeScreen(tester, const Size(390, 844));
      final service = FakeAuthService()
        ..onRequest = (_) async => throw const AuthFailure(
          'Login service is offline.',
          code: 'connection',
        );
      AuthSession? result;
      await tester.pumpWidget(
        host(
          AuthScreen(
            authService: service,
            onAuthenticated: (value) => result = value,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '7349083847',
      );
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('Login service is offline.'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-otp')), findsNothing);
      expect(result, isNull);
      service.onRequest = null;
      service.onVerify = (_, _) async => throw const AuthFailure(
        'Verification connection lost.',
        code: 'connection',
      );
      await tapVisible(tester, find.text('Continue'));
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '000000');
      await tapVisible(tester, find.text('Verify & continue'));
      expect(find.text('Verification connection lost.'), findsOneWidget);
      expect(result, isNull);
      service.onVerify = null;
      await tapVisible(tester, find.text('Verify & continue'));
      expect(result, same(testSession));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'initial request rate limit disables retry until the server delay ends',
    (tester) async {
      sizeScreen(tester, const Size(390, 844));
      final service = FakeAuthService()
        ..onRequest = (_) async => throw const AuthFailure(
          'Please wait',
          code: 'rate_limited',
          retryAfter: 30,
        );
      await tester.pumpWidget(
        host(
          AuthScreen(
            authService: service,
            onAuthenticated: (_) =>
                fail('A rate-limited request must not sign in'),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '7349083847',
      );
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('Please wait'), findsOneWidget);
      final retryButton = find.widgetWithText(
        FilledButton,
        'Try again in 0:30',
      );
      expect(retryButton, findsOneWidget);
      expect(tester.widget<FilledButton>(retryButton).onPressed, isNull);
      await tester.tap(retryButton);
      await tester.pump();
      expect(service.requestedPhones, ['+917349083847']);
      expect(find.byKey(const ValueKey('auth-otp')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resend uses a fresh challenge and changing number restarts verification',
    (tester) async {
      sizeScreen(tester, const Size(390, 844));
      final service = FakeAuthService()
        ..onVerify = (_, _) async =>
            throw const AuthFailure('Code rejected.', code: 'invalid_otp');
      await tester.pumpWidget(
        host(
          AuthScreen(
            authService: service,
            onAuthenticated: (_) => fail('Must not sign in'),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '7349083847',
      );
      await tapVisible(tester, find.text('Continue'));
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '111111');
      await tapVisible(tester, find.text('Resend code'));
      expect(service.requestedPhones, ['+917349083847', '+917349083847']);
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '000000');
      await tapVisible(tester, find.text('Verify & continue'));
      expect(service.verificationRequests.single.challengeId, 'challenge-2');
      await tapVisible(tester, find.text('Change number'));
      expect(find.byKey(const ValueKey('auth-otp')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '9876543210',
      );
      await tapVisible(tester, find.text('Continue'));
      expect(service.requestedPhones.last, '+919876543210');
      await tester.enterText(find.byKey(const ValueKey('auth-otp')), '000000');
      await tapVisible(tester, find.text('Verify & continue'));
      expect(service.verificationRequests.last.challengeId, 'challenge-3');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('demo payment requires face check and explicit demo approval', (
    tester,
  ) async {
    sizeScreen(tester, const Size(390, 844));
    final state = AppState();
    addTearDown(state.dispose);
    state.linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
    state.setFaceRegistered(true);
    final scanner = PaymentScannerSession();
    await tester.pumpWidget(
      host(PaymentScreen(state: state, scannerSessionFactory: () => scanner)),
    );
    await tester.pumpAndSettle();

    expect(find.text('DEMO MODE · NO MONEY MOVES'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('demo-payment-recipient')),
      'My test recipient',
    );
    await tester.enterText(
      find.byKey(const ValueKey('demo-payment-amount')),
      '500',
    );
    await tapVisible(tester, find.text('Review & approve'));
    expect(find.textContaining('No money moves'), findsWidgets);
    expect(state.transactions, isEmpty);
    await tapVisible(tester, find.text('Continue to face check'));
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(state.transactions, isEmpty);
    scanner.complete(const ScanDetection.face());
    scanner.complete(const ScanDetection.face());
    await tester.pumpAndSettle();
    expect(find.text('Two blinks detected'), findsOneWidget);
    expect(
      find.textContaining('not a real transfer or bank authorization'),
      findsOneWidget,
    );
    expect(state.transactions, isEmpty);
    await tapVisible(tester, find.text('Approve demo payment'));
    expect(find.text('Demo payment recorded'), findsWidgets);
    expect(state.balance, 0);
    expect(state.transactions, hasLength(1));
    expect(state.transactions.single.title, 'My test recipient');
    expect(state.transactions.single.amount, 500);
    expect(state.transactions.single.isDemo, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo payment requires enrollment before opening approval', (
    tester,
  ) async {
    sizeScreen(tester, const Size(390, 844));
    final state = AppState();
    addTearDown(state.dispose);
    state.linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
    await tester.pumpWidget(host(PaymentScreen(state: state)));
    await tapVisible(tester, find.text('Register FacePay first'));
    expect(
      find.text('Open Home and choose Register Face first.'),
      findsOneWidget,
    );
    expect(find.byType(ScanScreen), findsNothing);
    expect(state.transactions, isEmpty);
    expect(state.balance, 0);
  });

  testWidgets('QR detection cannot approve a pending demo payment', (
    tester,
  ) async {
    sizeScreen(tester, const Size(390, 844));
    final state = AppState();
    addTearDown(state.dispose);
    state.linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
    state.setFaceRegistered(true);
    final scanner = PaymentScannerSession();
    await tester.pumpWidget(
      host(PaymentScreen(state: state, scannerSessionFactory: () => scanner)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('demo-payment-recipient')),
      'My test recipient',
    );
    await tester.enterText(
      find.byKey(const ValueKey('demo-payment-amount')),
      '500',
    );
    await tapVisible(tester, find.text('Review & approve'));
    await tapVisible(tester, find.text('Continue to face check'));
    scanner.complete(const ScanDetection.qr('unverified-recipient'));
    await tester.pumpAndSettle();
    expect(find.text('Scanned content · unverified'), findsOneWidget);
    expect(find.text('Approve demo payment'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.transactions, isEmpty);
    expect(state.balance, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard starts with no payment users, balance, or activity', (
    tester,
  ) async {
    sizeScreen(tester, const Size(390, 844));
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(host(AppShell(state: state, onSignOut: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Hello, there.'), findsOneWidget);
    expect(find.text('Ready for setup'), findsOneWidget);
    expect(find.text('Aarav'), findsNothing);
    expect(find.text('₹24,850.00'), findsNothing);
    expect(
      find.text(
        'No demo activity yet. Verified transactions will appear here after payment services are connected.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet opens the empty payment setup instead of a funding flow', (
    tester,
  ) async {
    sizeScreen(tester, const Size(390, 844));
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(host(AppShell(state: state, onSignOut: () {})));
    await tapVisible(tester, find.byKey(const ValueKey('action-wallet')));

    expect(find.text('Payments are not active yet'), findsOneWidget);
    expect(find.text('Add demo money'), findsNothing);
    expect(
      find.text(
        'No card, balance, or real bank connection is stored in this wallet. Demo payment activity stays only while the app is open.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('a new app state contains no seeded financial data', () {
    final state = AppState();
    addTearDown(state.dispose);

    expect(state.displayName, isEmpty);
    expect(state.email, isEmpty);
    expect(state.balance, 0);
    expect(state.transactions, isEmpty);
  });
}
