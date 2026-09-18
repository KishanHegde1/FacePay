import 'dart:async';

import 'package:face_payment/main.dart';
import 'package:face_payment/screens/app_shell.dart';
import 'package:face_payment/screens/auth_screen.dart';
import 'package:face_payment/screens/splash_screen.dart';
import 'package:face_payment/services/auth_api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class ConnectionAuth extends StartupAuth {
  final failures = <AuthFailure>[];
  Completer<AuthSession>? pending;
  @override
  Future<AuthSession> getCurrentUser(String token) async {
    restores++;
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return pending?.future ?? helpers.testSession;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'slow server shows connecting message until session is verified',
    (tester) async {
      final auth = ConnectionAuth()..pending = Completer<AuthSession>();
      final store = StartupStore()..token = 'saved-token';
      await tester.pumpWidget(
        FacePaymentApp(authService: auth, sessionStore: store),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Connecting to the server'), findsOneWidget);
      expect(find.textContaining('Please wait a moment'), findsOneWidget);
      expect(find.text('We could not restore your account'), findsNothing);
      expect(find.byType(AppShell), findsNothing);
      expect(store.token, 'saved-token');
      auth.pending!.complete(helpers.testSession);
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('temporary timeout and gateway failures recover automatically', (
    tester,
  ) async {
    final auth = ConnectionAuth()
      ..failures.addAll([
        const AuthFailure('Timed out', code: 'timeout'),
        const AuthFailure('Gateway unavailable', statusCode: 503),
      ]);
    final store = StartupStore()..token = 'saved-token';
    await tester.pumpWidget(
      FacePaymentApp(authService: auth, sessionStore: store),
    );
    await tester.pump();
    expect(auth.restores, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(auth.restores, 2);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(auth.restores, 3);
    expect(find.byType(AppShell), findsOneWidget);
    expect(store.token, 'saved-token');
    expect(find.text('We could not restore your account'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'retries are bounded, friendly delayed state retains login and retries safely',
    (tester) async {
      final auth = ConnectionAuth()
        ..failures.addAll(
          List.filled(5, const AuthFailure('Offline', code: 'connection')),
        );
      final store = StartupStore()..token = 'saved-token';
      await tester.pumpWidget(
        FacePaymentApp(authService: auth, sessionStore: store),
      );
      await tester.pump();
      for (final seconds in [2, 4, 6, 8]) {
        await tester.pump(Duration(seconds: seconds));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(auth.restores, 5);
      expect(find.text('The server is taking a little longer'), findsOneWidget);
      expect(find.text('We could not restore your account'), findsNothing);
      expect(find.text('Sign in with another account'), findsNothing);
      expect(store.token, 'saved-token');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(auth.restores, 6);
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'rejected session clears token immediately without connection retries',
    (tester) async {
      final auth = ConnectionAuth()
        ..failures.add(const AuthFailure('Expired', statusCode: 401));
      final store = StartupStore()..token = 'saved-token';
      await tester.pumpWidget(
        FacePaymentApp(authService: auth, sessionStore: store),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(auth.restores, 1);
      expect(store.token, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('invalid server response is not retried as a sleeping server', (
    tester,
  ) async {
    final auth = ConnectionAuth()
      ..failures.add(
        const AuthFailure('Unexpected response', code: 'invalid_response'),
      );
    final store = StartupStore()..token = 'saved-token';
    await tester.pumpWidget(
      FacePaymentApp(authService: auth, sessionStore: store),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(auth.restores, 1);
    expect(find.text('Unexpected response'), findsOneWidget);
    expect(store.token, 'saved-token');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disposing during retry cancels timer and makes no further requests',
    (tester) async {
      final auth = ConnectionAuth()
        ..failures.add(const AuthFailure('Timed out', code: 'timeout'));
      final store = StartupStore()..token = 'saved-token';
      await tester.pumpWidget(
        FacePaymentApp(authService: auth, sessionStore: store),
      );
      await tester.pump();
      expect(auth.restores, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(auth.restores, 1);
      expect(auth.disposals, 1);
      expect(store.token, 'saved-token');
      expect(tester.takeException(), isNull);
    },
  );

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
