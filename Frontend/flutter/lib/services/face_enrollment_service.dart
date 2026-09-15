import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api.dart';
import 'session_store.dart';

/// The API stores only a device-bound enrollment record. A real face-template
/// provider can later send an encrypted, opaque template to the same profile;
/// raw images and ML Kit landmarks are deliberately never sent to the API.
class FaceEnrollmentService {
  FaceEnrollmentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Uri get _base => Uri.parse(HttpAuthService.configuredBaseUrl);

  Future<bool> enrolled(String accessToken) async {
    final json = await _request('GET', '/face-enrollment', accessToken);
    return json['enrolled'] == true;
  }

  Future<void> register(String accessToken) async {
    final deviceId = await SecureSessionStore().readOrCreateDeviceId();
    await _request(
      'POST',
      '/face-enrollment',
      accessToken,
      body: {'device_id': deviceId, 'liveness_method': 'two_blink_v1'},
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    String accessToken, {
    Map<String, String>? body,
  }) async {
    try {
      final request = http.Request(method, _base.resolve(path))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Face setup could not be saved. Please try again.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['error'] is Map) {
            message = (decoded['error'] as Map)['message'] as String? ?? message;
          }
        } on FormatException {
          // Keep the safe local message.
        }
        throw AuthFailure(message, statusCode: response.statusCode);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthFailure('Face setup could not be saved. Please try again.');
      }
      return decoded;
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw const AuthFailure('Face setup timed out. Please try again.');
    } on http.ClientException {
      throw const AuthFailure('Cannot reach the FacePay service. Check your connection and try again.');
    } on FormatException {
      throw const AuthFailure('Face setup could not be saved. Please try again.');
    }
  }

  void dispose() => _client.close();
}
