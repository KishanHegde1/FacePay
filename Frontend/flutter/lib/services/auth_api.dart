import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.expiresIn,
    required this.retryAfter,
    required this.developmentTest,
  });
  final String id;
  final int expiresIn, retryAfter;
  final bool developmentTest;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.phone,
    required this.expiresIn,
    this.name = '',
    this.email = '',
  });
  final String accessToken, userId, phone, name, email;
  final int? expiresIn;
}

class ProfileData {
  const ProfileData({
    required this.id,
    required this.mobileNo,
    required this.name,
    required this.email,
  });
  final String id, mobileNo, name, email;
}

class AuthFailure implements Exception {
  const AuthFailure(
    this.message, {
    this.code = 'unknown',
    this.retryAfter,
    this.statusCode,
  });
  final String message, code;
  final int? retryAfter, statusCode;
  bool get sessionRejected =>
      statusCode == 401 ||
      const {
        'unauthorized',
        'invalid_session',
        'session_expired',
        'expired_session',
      }.contains(code);
  @override
  String toString() => message;
}

abstract class AuthService {
  Future<OtpChallenge> requestOtp(String phone);
  Future<AuthSession> verifyOtp(String challengeId, String otp);
  Future<AuthSession> getCurrentUser(String accessToken);
  Future<ProfileData> getProfile(String accessToken);
  Future<ProfileData> saveProfile(
    String accessToken,
    String name,
    String email,
  );
  Future<void> logout(String accessToken);
  void dispose();
}

class HttpAuthService implements AuthService {
  HttpAuthService({String? baseUrl, http.Client? client})
    : _client = client ?? http.Client(),
      _base = Uri.parse(baseUrl ?? configuredBaseUrl);

  /// The hosted API is the safe default for release builds. Developers can
  /// still point a local build at their own API with `--dart-define`.
  static const deployedBaseUrl = 'https://facepay-rtyr.onrender.com';

  static String get configuredBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    return configured.isNotEmpty ? configured : deployedBaseUrl;
  }

  final http.Client _client;
  final Uri _base;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final request = http.Request(method, _base.resolve(path));
      request.headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 204) return {};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Map<String, dynamic>? error;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> &&
              decoded['error'] is Map<String, dynamic>) {
            error = decoded['error'] as Map<String, dynamic>;
          }
        } on FormatException {
          /* Use the HTTP status when an error has no JSON body. */
        }
        throw AuthFailure(
          error?['message'] as String? ??
              'Something went wrong. Please try again.',
          code:
              error?['code'] as String? ??
              (response.statusCode == 401 ? 'unauthorized' : 'server_error'),
          retryAfter: (error?['retry_after'] as num?)?.toInt(),
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw const AuthFailure(
        'The connection took too long. Please try again.',
        code: 'timeout',
      );
    } on http.ClientException {
      throw const AuthFailure(
        'Cannot reach the login service. Check your connection and that the backend is running.',
        code: 'connection',
      );
    } on FormatException {
      throw const AuthFailure(
        'The login service returned an unexpected response. Please try again.',
        code: 'invalid_response',
      );
    } on TypeError {
      throw const AuthFailure(
        'The login service returned an unexpected response. Please try again.',
        code: 'invalid_response',
      );
    }
  }

  @override
  Future<OtpChallenge> requestOtp(String phone) async {
    final json = await _request(
      'POST',
      '/auth/request-otp',
      body: {'phone': phone},
    );
    if (json['challenge_id'] is! String ||
        (json['challenge_id'] as String).trim().isEmpty ||
        json['expires_in'] is! int ||
        (json['expires_in'] as int) <= 0 ||
        json['retry_after'] is! int ||
        (json['retry_after'] as int) < 0) {
      throw const AuthFailure(
        'The login service could not start verification. Please try again.',
        code: 'invalid_response',
      );
    }
    return OtpChallenge(
      id: json['challenge_id'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
      retryAfter: (json['retry_after'] as num).toInt(),
      developmentTest: json['delivery'] == 'development_test',
    );
  }

  @override
  Future<AuthSession> verifyOtp(String challengeId, String otp) async {
    final json = await _request(
      'POST',
      '/auth/verify-otp',
      body: {'challenge_id': challengeId, 'otp': otp},
    );
    return _sessionFromJson(json);
  }

  Future<AuthSession> verifyFirebaseIdToken(String idToken) async {
    final json = await _request(
      'POST',
      '/auth/firebase',
      body: {'id_token': idToken},
    );
    return _sessionFromJson(json);
  }

  AuthSession _sessionFromJson(Map<String, dynamic> json) {
    if (json['access_token'] is! String ||
        (json['access_token'] as String).trim().isEmpty ||
        json['token_type'] != 'Bearer' ||
        !json.containsKey('expires_in') ||
        (json['expires_in'] != null &&
            (json['expires_in'] is! int || (json['expires_in'] as int) <= 0))) {
      throw const AuthFailure(
        'Verification could not be completed. Please request a new code.',
        code: 'invalid_response',
      );
    }
    return _parseSession(
      json['user'],
      json['access_token'] as String,
      json['expires_in'] as int?,
    );
  }

  AuthSession _parseSession(dynamic user, String token, int? expiresIn) {
    final profile = _parseProfile(user, phoneKey: 'phone');
    return AuthSession(
      accessToken: token,
      userId: profile.id,
      phone: profile.mobileNo,
      name: profile.name,
      email: profile.email,
      expiresIn: expiresIn,
    );
  }

  ProfileData _parseProfile(dynamic value, {String phoneKey = 'mobile_no'}) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        (value['id'] as String).trim().isEmpty ||
        value[phoneKey] is! String ||
        !RegExp(r'^\+91[6-9][0-9]{9}$').hasMatch(value[phoneKey] as String) ||
        (value['name'] != null && value['name'] is! String) ||
        (value['email'] != null && value['email'] is! String)) {
      throw const AuthFailure(
        'Your account details could not be loaded. Please try again.',
        code: 'invalid_response',
      );
    }
    return ProfileData(
      id: value['id'] as String,
      mobileNo: value[phoneKey] as String,
      name: value['name'] as String? ?? '',
      email: value['email'] as String? ?? '',
    );
  }

  @override
  Future<AuthSession> getCurrentUser(String accessToken) async {
    final json = await _request('GET', '/auth/me', token: accessToken);
    return _parseSession(json['user'], accessToken, null);
  }

  @override
  Future<ProfileData> getProfile(String accessToken) async {
    final json = await _request('GET', '/profile', token: accessToken);
    return _parseProfile(json['profile']);
  }

  @override
  Future<ProfileData> saveProfile(
    String accessToken,
    String name,
    String email,
  ) async {
    final json = await _request(
      'PATCH',
      '/profile',
      token: accessToken,
      body: {
        'name': name.trim(),
        'email': email.trim().isEmpty ? null : email.trim(),
      },
    );
    return _parseProfile(json['profile']);
  }

  @override
  Future<void> logout(String accessToken) async {
    await _request('POST', '/auth/logout', body: {}, token: accessToken);
  }

  @override
  void dispose() => _client.close();
}

/// Uses Firebase only to prove control of the phone number. The Firebase ID
/// token is then exchanged for FacePay's existing opaque backend session.
class FirebasePhoneAuthService implements AuthService {
  FirebasePhoneAuthService({FirebaseAuth? firebaseAuth, HttpAuthService? api})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _api = api ?? HttpAuthService();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final FirebaseAuth _firebaseAuth;
  final HttpAuthService _api;

  @override
  Future<OtpChallenge> requestOtp(String phone) {
    if (!isSupported) {
      return Future.error(
        const AuthFailure(
          'Phone verification is available on the FacePay Android app.',
          code: 'unsupported_platform',
        ),
      );
    }
    final result = Completer<OtpChallenge>();
    unawaited(
      _firebaseAuth
          .verifyPhoneNumber(
            phoneNumber: phone,
            timeout: const Duration(seconds: 60),
            // Android may detect an incoming code automatically. We leave the
            // account unsigned-in here so the app always exchanges a verified
            // Firebase ID token with the FacePay backend in one place.
            verificationCompleted: (_) {},
            verificationFailed: (error) {
              if (!result.isCompleted) result.completeError(_failure(error));
            },
            codeSent: (verificationId, _) {
              if (!result.isCompleted) {
                result.complete(
                  OtpChallenge(
                    id: verificationId,
                    expiresIn: 300,
                    retryAfter: 30,
                    developmentTest: false,
                  ),
                );
              }
            },
            codeAutoRetrievalTimeout: (_) {},
          )
          .catchError((Object error) {
            if (!result.isCompleted) {
              result.completeError(
                error is FirebaseAuthException
                    ? _failure(error)
                    : const AuthFailure(
                        'We could not start phone verification. Please try again.',
                        code: 'verification_unavailable',
                      ),
              );
            }
          }),
    );
    return result.future.timeout(
      const Duration(seconds: 75),
      onTimeout: () => throw const AuthFailure(
        'We could not send a verification code. Please try again.',
        code: 'verification_timeout',
      ),
    );
  }

  AuthFailure _failure(FirebaseAuthException error) {
    final code = switch (error.code) {
      'invalid-phone-number' => 'invalid_phone',
      'too-many-requests' || 'quota-exceeded' => 'rate_limited',
      'session-expired' => 'challenge_expired',
      'operation-not-allowed' => 'phone_provider_disabled',
      'app-not-authorized' ||
      'invalid-app-credential' ||
      'missing-client-identifier' => 'app_not_authorized',
      'captcha-check-failed' => 'app_verification_failed',
      'network-request-failed' => 'network_unavailable',
      _ => 'verification_failed',
    };
    final message = switch (code) {
      'invalid_phone' => 'Enter a valid mobile number.',
      'rate_limited' => 'Too many attempts. Please wait and try again.',
      'challenge_expired' => 'This code has expired. Request a new one.',
      'phone_provider_disabled' =>
        'Enable Phone sign-in in Firebase Authentication, then try again.',
      'app_not_authorized' =>
        'Firebase does not recognize this Android app. Add its SHA fingerprints and rebuild.',
      'app_verification_failed' =>
        'Firebase could not verify this app. Check its SHA fingerprints and Google Play services.',
      'network_unavailable' =>
        'Check the phone internet connection and try again.',
      _ => 'We could not verify this number. Please try again.',
    };
    final debugDetail = kDebugMode ? ' [Firebase: ${error.code}]' : '';
    return AuthFailure('$message$debugDetail', code: code);
  }

  @override
  Future<AuthSession> verifyOtp(String challengeId, String otp) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: challengeId,
        smsCode: otp,
      );
      final signedIn = await _firebaseAuth.signInWithCredential(credential);
      final token = await signedIn.user?.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const AuthFailure(
          'We could not confirm your phone verification. Please try again.',
          code: 'firebase_token_missing',
        );
      }
      return _api.verifyFirebaseIdToken(token);
    } on FirebaseAuthException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<AuthSession> getCurrentUser(String accessToken) =>
      _api.getCurrentUser(accessToken);

  @override
  Future<ProfileData> getProfile(String accessToken) =>
      _api.getProfile(accessToken);

  @override
  Future<ProfileData> saveProfile(
    String accessToken,
    String name,
    String email,
  ) => _api.saveProfile(accessToken, name, email);

  @override
  Future<void> logout(String accessToken) async {
    try {
      await _api.logout(accessToken);
    } finally {
      await _firebaseAuth.signOut();
    }
  }

  @override
  void dispose() => _api.dispose();
}
