import 'package:face_payment/data/app_state.dart';
import 'package:face_payment/screens/scan_screen.dart';
import 'package:face_payment/screens/scan_result_screen.dart';
import 'package:face_payment/services/scan_detection.dart';
import 'package:face_payment/services/scanner_session.dart';
import 'package:face_payment/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'frontend_test.dart' as helpers;

class TestScannerSession extends ScannerSession {
  @override
  ScannerStatus status = ScannerStatus.idle;
  @override
  String message = 'Point at a QR code or face';
  @override
  bool checkingBlinks = false;
  @override
  int blinkCount = 0;
  @override
  ScanDetection? detection;
  int starts = 0, stops = 0;
  bool closed = false;
  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);
  @override
  Future<void> start() async {
    starts++;
    status = ScannerStatus.scanning;
    detection = null;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> switchCamera() => start();
  void found(ScanDetection value) {
    status = ScannerStatus.detected;
    detection = value;
    notifyListeners();
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
  });
  late AppState state;
  late TestScannerSession session;
  setUp(() {
    state = AppState();
    session = TestScannerSession();
  });
  tearDown(() => state.dispose());
  Widget host() => MaterialApp(
    theme: AppTheme.light,
    home: ScanScreen(state: state, session: session),
  );

  testWidgets(
    'QR route stops camera and suppresses duplicate navigation; back stays paused',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      session.found(const ScanDetection.qr('upi://pay?pa=test@bank'));
      session.found(const ScanDetection.qr('upi://pay?pa=test@bank'));
      await tester.pumpAndSettle();
      expect(session.stops, 1);
      expect(find.byType(ScanResultScreen), findsOneWidget);
      expect(find.text('Scanned content · unverified'), findsOneWidget);
      expect(state.transactions, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(session.starts, 1);
      await helpers.tapVisible(tester, find.text('Scan again'));
      expect(session.starts, 2);
      await tester.pumpWidget(const SizedBox());
      expect(session.closed, isTrue);
    },
  );

  testWidgets(
    'blink progress and completion never claim identity or create a payment',
    (tester) async {
      await tester.pumpWidget(host());
      session.checkingBlinks = true;
      session.blinkCount = 1;
      session.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Blink twice'), findsOneWidget);
      expect(find.text('1 / 2 blinks'), findsOneWidget);
      session.found(const ScanDetection.face());
      await tester.pumpAndSettle();
      expect(find.text('Two blinks detected'), findsOneWidget);
      expect(find.text('Face liveness check complete.'), findsOneWidget);
      expect(
        find.textContaining('No face image or ML Kit landmark data is saved.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('face-template provider is still required'),
        findsOneWidget,
      );
      expect(state.faceRegistered, isFalse);
      expect(state.transactions, isEmpty);
      expect(state.balance, 0);
    },
  );

  testWidgets(
    'background releases camera and resume restarts only the scanner route',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(session.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(session.starts, 2);
      session.found(const ScanDetection.qr('untrusted-code'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(session.starts, 2);
      expect(find.byType(ScanResultScreen), findsOneWidget);
    },
  );

  testWidgets('permission errors offer retry and fit a narrow viewport', (
    tester,
  ) async {
    helpers.sizeScreen(tester, const Size(320, 700));
    await tester.pumpWidget(host());
    session.status = ScannerStatus.error;
    session.message =
        'Camera permission was denied. Enable camera access in Settings.';
    session.notifyListeners();
    await tester.pumpAndSettle();
    await helpers.tapVisible(tester, find.text('Try again'));
    expect(session.starts, 2);
    expect(tester.takeException(), isNull);
  });
}
