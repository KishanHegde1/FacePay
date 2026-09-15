import 'dart:async';

import 'package:face_payment/data/app_state.dart';
import 'package:face_payment/screens/app_shell.dart';
import 'package:face_payment/screens/balance_screen.dart';
import 'package:face_payment/services/bank_balance_service.dart';
import 'package:face_payment/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'frontend_test.dart' as helpers;

class PendingBalanceService extends UnconnectedBankBalanceService {
  Completer<BankBalanceResult> pending = Completer();
  int calls = 0;
  @override
  Future<BankBalanceResult> fetchBalance(BalanceAccount account) {
    calls++;
    return pending.future;
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
  });
  Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Balance action is reachable at width $width', (tester) async {
      helpers.sizeScreen(tester, Size(width, 844));
      final state = AppState();
      addTearDown(state.dispose);
      await tester.pumpWidget(host(AppShell(state: state, onSignOut: () {})));
      await helpers.tapVisible(
        tester,
        find.byKey(const ValueKey('action-balance')),
      );
      expect(find.byType(BalanceScreen), findsOneWidget);
      expect(find.text('No bank account selected'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      expect(find.textContaining('₹'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'selected local bank shows unavailable after repeated requests without financial data',
    (tester) async {
      final state = AppState()
        ..linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
      addTearDown(state.dispose);
      await tester.pumpWidget(host(BalanceScreen(state: state)));
      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.text('•••• 4821'), findsOneWidget);
      expect(find.textContaining('Local bank preview only'), findsOneWidget);
      await helpers.tapVisible(tester, find.text('Fetch Balance'));
      expect(
        find.byKey(const ValueKey('balance-unavailable-result')),
        findsOneWidget,
      );
      await helpers.tapVisible(tester, find.text('Refresh Balance'));
      expect(find.byKey(const ValueKey('provider-balance')), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(state.balance, 0);
      expect(state.transactions, isEmpty);
    },
  );

  testWidgets(
    'pending fetch is locked and an unlinked account discards its result',
    (tester) async {
      final state = AppState()
        ..linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
      final service = PendingBalanceService();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        host(BalanceScreen(state: state, service: service)),
      );
      await tester.tap(find.text('Fetch Balance'));
      await tester.pump();
      expect(service.calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      state.unlinkDemoBank();
      await tester.pump();
      service.pending.complete(
        BankBalanceAvailable(
          minorUnits: 123456,
          currency: 'INR',
          fractionDigits: 2,
          fetchedAt: DateTime(2026),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No bank account selected'), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-balance')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'provider failure can retry and connected provider result renders without persistence',
    (tester) async {
      final state = AppState()
        ..linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
      final service = PendingBalanceService();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        host(BalanceScreen(state: state, service: service)),
      );
      await tester.tap(find.text('Fetch Balance'));
      await tester.pump();
      service.pending.completeError(StateError('provider down'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not fetch your bank balance. Please try again.'),
        findsOneWidget,
      );
      service.pending = Completer();
      await tester.tap(find.text('Fetch Balance'));
      await tester.pump();
      service.pending.complete(
        BankBalanceAvailable(
          minorUnits: 123456,
          currency: 'INR',
          fractionDigits: 2,
          fetchedAt: DateTime(2026),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('INR 1234.56'), findsOneWidget);
      expect(state.balance, 0);
      expect(state.transactions, isEmpty);
    },
  );
}
