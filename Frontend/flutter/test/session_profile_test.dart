import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_payment/main.dart';
import 'package:face_payment/screens/app_shell.dart';
import 'package:face_payment/screens/auth_screen.dart';
import 'package:face_payment/screens/profile_screen.dart';
import 'package:face_payment/services/auth_api.dart';
import 'frontend_test.dart' as helpers;

class RestoringAuth extends helpers.FakeAuthService {
  AuthFailure? failure;
  int restores = 0;
  @override
  Future<AuthSession> getCurrentUser(String token) async {
    restores++;
    if (failure != null) throw failure!;
    return helpers.testSession;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('saved session restores without OTP and logout removes it', (
    tester,
  ) async {
    final store = helpers.MemorySessionStore()..token = 'saved-token';
    final auth = RestoringAuth();
    await tester.pumpWidget(
      FacePaymentApp(authService: auth, sessionStore: store),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(auth.restores, 1);
    expect(auth.requestedPhones, isEmpty);
    await helpers.tapVisible(tester, find.text('Profile'));
    await helpers.tapVisible(tester, find.text('Sign out'));
    expect(store.token, isNull);
    expect(find.byType(AuthScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'temporary restore failure retains token and retry opens dashboard',
    (tester) async {
      final store = helpers.MemorySessionStore()..token = 'saved-token';
      final auth = RestoringAuth()
        ..failure = const AuthFailure('Offline', code: 'connection');
      await tester.pumpWidget(
        FacePaymentApp(authService: auth, sessionStore: store),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(store.token, 'saved-token');
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.text('The server is taking a little longer'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
      expect(find.text('Sign in with another account'), findsNothing);
      expect(auth.restores, 5);
      auth.failure = null;
      await helpers.tapVisible(tester, find.text('Try again'));
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'non-transient restore failure can discard only the saved login',
    (tester) async {
      final store = helpers.MemorySessionStore()..token = 'saved-token';
      final auth = RestoringAuth()
        ..failure = const AuthFailure(
          'Unexpected response',
          code: 'invalid_response',
        );
      await tester.pumpWidget(
        FacePaymentApp(authService: auth, sessionStore: store),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await helpers.tapVisible(
        tester,
        find.text('Sign in with another account'),
      );
      expect(store.token, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('revoked session is cleared and asks for OTP', (tester) async {
    final store = helpers.MemorySessionStore()..token = 'revoked-token';
    final auth = RestoringAuth()
      ..failure = const AuthFailure('Revoked', statusCode: 401);
    await tester.pumpWidget(
      FacePaymentApp(authService: auth, sessionStore: store),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(store.token, isNull);
    expect(find.byType(AuthScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'profile shows save success only after server confirmation and keeps mobile read-only',
    (tester) async {
      helpers.sizeScreen(tester, const Size(390, 844));
      var fail = true;
      await tester.pumpWidget(
        helpers.host(
          ProfileScreen(
            profile: helpers.testProfile,
            onSignOut: () {},
            onSaveProfile: (name, email) async {
              if (fail) throw const AuthFailure('Database unavailable');
              return ProfileData(
                id: 'user-123',
                mobileNo: '+917349083847',
                name: name,
                email: email,
              );
            },
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('profile-mobile')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Test Member',
      );
      await helpers.tapVisible(tester, find.text('Save changes'));
      expect(find.text('Database unavailable'), findsOneWidget);
      expect(find.text('Profile saved.'), findsNothing);
      fail = false;
      await helpers.tapVisible(tester, find.text('Save changes'));
      expect(find.text('Profile saved.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
