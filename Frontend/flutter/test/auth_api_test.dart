import 'dart:convert';

import 'package:face_payment/services/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const validChallenge = <String, dynamic>{
  'challenge_id': 'challenge-123',
  'expires_in': 300,
  'retry_after': 30,
  'delivery': 'development_test',
};

const validSession = <String, dynamic>{
  'access_token': 'opaque-server-session',
  'token_type': 'Bearer',
  'expires_in': 3600,
  'user': {'id': 'user-123', 'phone': '+917349083847'},
};

TypeMatcher<AuthFailure> authFailure(String code) =>
    isA<AuthFailure>().having((failure) => failure.code, 'code', code);

HttpAuthService serviceForResponse(http.Response response) => HttpAuthService(
  baseUrl: 'http://localhost:8080',
  client: MockClient((_) async => response),
);

void main() {
  test('uses the Render API when no endpoint override is supplied', () {
    expect(
      HttpAuthService.configuredBaseUrl,
      HttpAuthService.deployedBaseUrl,
    );
    expect(
      HttpAuthService.deployedBaseUrl,
      'https://facepay-rtyr.onrender.com',
    );
  });

  test(
    'request OTP sends a phone number to the backend and reads challenge metadata',
    () async {
      final service = HttpAuthService(
        baseUrl: 'http://localhost:8080',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'http://localhost:8080/auth/request-otp',
          );
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {'phone': '+917349083847'});
          return http.Response(jsonEncode(validChallenge), 200);
        }),
      );
      addTearDown(service.dispose);
      final challenge = await service.requestOtp('+917349083847');
      expect(challenge.id, 'challenge-123');
      expect(challenge.expiresIn, 300);
      expect(challenge.retryAfter, 30);
      expect(challenge.developmentTest, isTrue);
    },
  );

  test(
    'verify sends the exact six-character OTP and accepts only the backend session',
    () async {
      final service = HttpAuthService(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://api.example.test/auth/verify-otp',
          );
          expect(jsonDecode(request.body), {
            'challenge_id': 'challenge-123',
            'otp': '000000',
          });
          return http.Response(jsonEncode(validSession), 200);
        }),
      );
      addTearDown(service.dispose);
      final session = await service.verifyOtp('challenge-123', '000000');
      expect(session.accessToken, 'opaque-server-session');
      expect(session.userId, 'user-123');
      expect(session.phone, '+917349083847');
      expect(session.expiresIn, 3600);
    },
  );

  test('logout uses the existing session bearer token', () async {
    final service = HttpAuthService(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/logout');
        expect(
          request.headers['authorization'],
          'Bearer opaque-server-session',
        );
        expect(jsonDecode(request.body), isEmpty);
        return http.Response('', 204);
      }),
    );
    addTearDown(service.dispose);
    await service.logout('opaque-server-session');
  });

  test(
    'an invalid OTP returns the backend error instead of a session',
    () async {
      final service = serviceForResponse(
        http.Response(
          jsonEncode({
            'error': {
              'code': 'invalid_otp',
              'message': 'The code is incorrect.',
            },
          }),
          400,
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.verifyOtp('challenge-123', '123456'),
        throwsA(
          authFailure('invalid_otp').having(
            (failure) => failure.message,
            'message',
            'The code is incorrect.',
          ),
        ),
      );
    },
  );

  test('rate-limit responses retain the server retry delay', () async {
    final service = serviceForResponse(
      http.Response(
        jsonEncode({
          'error': {
            'code': 'rate_limited',
            'message': 'Please wait before trying again.',
            'retry_after': 23,
          },
        }),
        429,
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.requestOtp('+917349083847'),
      throwsA(
        isA<AuthFailure>()
            .having((failure) => failure.code, 'code', 'rate_limited')
            .having((failure) => failure.retryAfter, 'retryAfter', 23),
      ),
    );
  });

  test('connection failures return a usable authentication error', () async {
    final service = HttpAuthService(
      baseUrl: 'http://localhost:8080',
      client: MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.requestOtp('+917349083847'),
      throwsA(authFailure('connection')),
    );
    await expectLater(
      service.verifyOtp('challenge-123', '000000'),
      throwsA(authFailure('connection')),
    );
  });

  for (final malformed in <String>['not JSON', '[]', 'null', '"success"']) {
    test(
      'malformed JSON shape $malformed cannot become a challenge or session',
      () async {
        final service = serviceForResponse(http.Response(malformed, 200));
        addTearDown(service.dispose);
        await expectLater(
          service.requestOtp('+917349083847'),
          throwsA(authFailure('invalid_response')),
        );
        await expectLater(
          service.verifyOtp('challenge-123', '000000'),
          throwsA(authFailure('invalid_response')),
        );
      },
    );
  }

  final malformedChallenges = <String, Map<String, dynamic>>{
    'missing challenge': {},
    'empty challenge ID': {...validChallenge, 'challenge_id': ''},
    'nonstring challenge ID': {...validChallenge, 'challenge_id': 123},
    'missing expiry': {...validChallenge}..remove('expires_in'),
    'zero expiry': {...validChallenge, 'expires_in': 0},
    'negative expiry': {...validChallenge, 'expires_in': -1},
    'nonnumeric expiry': {...validChallenge, 'expires_in': '300'},
    'negative retry delay': {...validChallenge, 'retry_after': -1},
    'missing retry delay': {...validChallenge}..remove('retry_after'),
  };
  for (final entry in malformedChallenges.entries) {
    test('rejects challenge response with ${entry.key}', () async {
      final service = serviceForResponse(
        http.Response(jsonEncode(entry.value), 200),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.requestOtp('+917349083847'),
        throwsA(authFailure('invalid_response')),
      );
    });
  }

  final malformedSessions = <String, Map<String, dynamic>>{
    'missing session': {},
    'empty token': {...validSession, 'access_token': ''},
    'wrong token type': {...validSession, 'access_token': true},
    'zero expiry': {...validSession, 'expires_in': 0},
    'negative expiry': {...validSession, 'expires_in': -1},
    'missing user': {...validSession}..remove('user'),
    'wrong user type': {...validSession, 'user': []},
    'missing user ID': {
      ...validSession,
      'user': {'phone': '+917349083847'},
    },
    'empty user ID': {
      ...validSession,
      'user': {'id': '', 'phone': '+917349083847'},
    },
    'empty phone': {
      ...validSession,
      'user': {'id': 'user-123', 'phone': ''},
    },
    'missing phone': {
      ...validSession,
      'user': {'id': 'user-123'},
    },
  };
  for (final entry in malformedSessions.entries) {
    test('rejects session response with ${entry.key}', () async {
      final service = serviceForResponse(
        http.Response(jsonEncode(entry.value), 200),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.verifyOtp('challenge-123', '000000'),
        throwsA(authFailure('invalid_response')),
      );
    });
  }

  test('an empty HTTP success response cannot authenticate', () async {
    final service = serviceForResponse(http.Response('', 204));
    addTearDown(service.dispose);
    await expectLater(
      service.requestOtp('+917349083847'),
      throwsA(authFailure('invalid_response')),
    );
    await expectLater(
      service.verifyOtp('challenge-123', '000000'),
      throwsA(authFailure('invalid_response')),
    );
  });
}
