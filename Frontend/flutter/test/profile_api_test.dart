import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:face_payment/services/auth_api.dart';

void main() {
  test('OTP accepts durable sessions with null expiry', () async {
    final service = HttpAuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'access_token': 'token',
            'token_type': 'Bearer',
            'expires_in': null,
            'user': {
              'id': 'id',
              'phone': '+917349083847',
              'name': null,
              'email': null,
            },
          }),
          200,
        ),
      ),
    );
    addTearDown(service.dispose);
    final session = await service.verifyOtp('challenge', '000000');
    expect(session.expiresIn, isNull);
    expect(session.name, isEmpty);
  });
  test(
    'profile saves through bearer token without client identity or phone fields',
    () async {
      final service = HttpAuthService(
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/profile');
          expect(request.headers['authorization'], 'Bearer saved-token');
          expect(jsonDecode(request.body), {
            'name': 'Test Member',
            'email': null,
          });
          return http.Response(
            jsonEncode({
              'profile': {
                'id': 'id',
                'mobile_no': '+917349083847',
                'name': 'Test Member',
                'email': null,
              },
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final profile = await service.saveProfile(
        'saved-token',
        ' Test Member ',
        ' ',
      );
      expect(profile.name, 'Test Member');
      expect(profile.email, isEmpty);
    },
  );
  test('plain unauthorized response invalidates session', () async {
    final service = HttpAuthService(
      client: MockClient((_) async => http.Response('Unauthorized', 401)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.getCurrentUser('token'),
      throwsA(
        isA<AuthFailure>().having((e) => e.sessionRejected, 'rejected', isTrue),
      ),
    );
  });
}
