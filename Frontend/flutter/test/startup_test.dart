import 'dart:async';

import 'package:face_payment/main.dart';
import 'package:face_payment/screens/app_shell.dart';
import 'package:face_payment/screens/auth_screen.dart';
import 'package:face_payment/screens/splash_screen.dart';
import 'package:face_payment/services/auth_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'frontend_test.dart' as helpers;

class StartupAuth extends helpers.FakeAuthService {
  int restores = 0;
  int disposals = 0;

  @override
  Future<AuthSession> getCurrentUser(String token) async {
    restores++;
    return helpers.testSession;
  }

  @override
  void dispose() => disposals++;
}

class StartupStore extends helpers.MemorySessionStore {
  int reads = 0;

  @override
  Future<String?> readToken() async {
    reads++;
    return token;
  }
}

void main() {
  testWidgets('logo lasts two seconds, then splash completes once at five', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onComplete: () => completions++)),
    );
    expect(find.byKey(const ValueKey('startup-logo')), findsOneWidget);
    expect(find.text('A familiar face. A simpler way to pay.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byKey(const ValueKey('startup-logo')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('startup-splash')), findsOneWidget);
    expect(find.text('A familiar face. A simpler way to pay.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposing either startup stage cancels completion', (
    tester,
  ) async {
    for (final elapsed in [1, 3]) {
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onComplete: () => completions++)),
      );
      await tester.pump(Duration(seconds: elapsed));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(completions, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('initialization runs behind branding and gates authentication', (
    tester,
  ) async {
    final initialization = Completer<void>();
    final auth = StartupAuth();
    final store = StartupStore()..token = 'saved-token';
    await tester.pumpWidget(
      FacePaymentApp(
        authService: auth,
        sessionStore: store,
        initializeServices: () => initialization.future,
      ),
    );
    expect(find.byKey(const ValueKey('startup-logo')), findsOneWidget);
    expect(store.reads, 0);
    expect(auth.restores, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(AppShell), findsNothing);
    initialization.complete();
    await tester.pumpAndSettle();
    expect(auth.restores, 1);
    expect(find.byType(AppShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(auth.disposals, 1);
  });

  testWidgets(
    'initialization failure retains login and supports a safe retry',
    (tester) async {
      final auth = StartupAuth();
      final store = StartupStore()..token = 'saved-token';
      var attempts = 0;
      await tester.pumpWidget(
        FacePaymentApp(
          authService: auth,
          sessionStore: store,
          initializeServices: () async {
            if (++attempts == 1) {
              throw StateError('Firebase initialization failed');
            }
          },
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('We could not start phone sign-in'), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.text('Sign in with another account'), findsNothing);
      expect(store.token, 'saved-token');
      expect(store.reads, 0);
      expect(auth.restores, 0);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(auth.restores, 1);
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('finishing initialization after disposal does not restore', (
    tester,
  ) async {
    final initialization = Completer<void>();
    final auth = StartupAuth();
    final store = StartupStore()..token = 'saved-token';
    await tester.pumpWidget(
      FacePaymentApp(
        authService: auth,
        sessionStore: store,
        initializeServices: () => initialization.future,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    initialization.complete();
    await tester.pump(const Duration(seconds: 6));
    expect(auth.disposals, 1);
    expect(store.reads, 0);
    expect(auth.restores, 0);
    expect(tester.takeException(), isNull);
  });
}
