import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api.dart';

/// The only account fields a Flutter client needs after a server-side link.
/// Provider-issued account references and customer references remain server-side.
class LinkedBankAccount {
  const LinkedBankAccount({
    required this.id,
    required this.bankName,
    required this.bankCode,
    required this.maskedAccountNumber,
    required this.accountType,
    required this.accountHolderName,
    required this.verificationStatus,
    required this.provider,
  });

  final String id;
  final String bankName;
  final String bankCode;
  final String maskedAccountNumber;
  final String? accountType;
  final String? accountHolderName;
  final String verificationStatus;
  final String provider;

  factory LinkedBankAccount.fromJson(Map<String, dynamic> value) {
    const requiredFields = {
      'id',
      'bank_name',
      'bank_code',
      'masked_account_number',
      'verification_status',
      'provider',
    };
    if (requiredFields.any((key) => value[key] is! String) ||
        value['account_type'] != null && value['account_type'] is! String ||
        value['account_holder_name'] != null &&
            value['account_holder_name'] is! String) {
      throw const AuthFailure(
        'The bank service returned an unexpected response. Please try again.',
        code: 'invalid_response',
      );
    }
    return LinkedBankAccount(
      id: value['id'] as String,
      bankName: value['bank_name'] as String,
      bankCode: value['bank_code'] as String,
      maskedAccountNumber: value['masked_account_number'] as String,
      accountType: value['account_type'] as String?,
      accountHolderName: value['account_holder_name'] as String?,
      verificationStatus: value['verification_status'] as String,
      provider: value['provider'] as String,
    );
  }
}

/// Future providers can implement this same interface without changing UI.
abstract interface class BankLinkRepository {
  Future<List<LinkedBankAccount>> listLinkedAccounts(String accessToken);
  Future<void> unlinkAccount(String accessToken, String accountId);
  void dispose();
}

/// Calls FacePay's Rust API only. It never contacts HDFC directly and it has no
/// client ID, secret, OTP schema, or bank account-verification implementation.
class HdfcBankService implements BankLinkRepository {
  HdfcBankService({String? baseUrl, http.Client? client})
    : _client = client ?? http.Client(),
      _base = Uri.parse(baseUrl ?? HttpAuthService.configuredBaseUrl);

  final http.Client _client;
  final Uri _base;

  Future<http.Response> _request(
    String method,
    String path,
    String accessToken,
  ) async {
    try {
      final request = http.Request(method, _base.resolve(path));
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failureFrom(response);
      }
      return response;
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw const AuthFailure(
        'The bank service took too long. Please try again.',
        code: 'timeout',
      );
    } on http.ClientException {
      throw const AuthFailure(
        'Cannot reach the bank service. Check your connection and try again.',
        code: 'connection',
      );
    }
  }

  AuthFailure _failureFrom(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic> && value['error'] is Map) {
        final error = value['error'] as Map;
        final message = error['message'];
        final code = error['code'];
        if (message is String && code is String) {
          return AuthFailure(
            message,
            code: code,
            statusCode: response.statusCode,
            retryAfter: (error['retry_after'] as num?)?.toInt(),
          );
        }
      }
    } on FormatException {
      // Use a safe local error below.
    }
    return AuthFailure(
      'The bank service could not complete that request. Please try again.',
      code: response.statusCode == 401 ? 'unauthorized' : 'server_error',
      statusCode: response.statusCode,
    );
  }

  @override
  Future<List<LinkedBankAccount>> listLinkedAccounts(
    String accessToken,
  ) async {
    final response = await _request('GET', '/api/bank/accounts', accessToken);
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic> || value['accounts'] is! List) {
        throw const FormatException();
      }
      return (value['accounts'] as List)
          .map((account) {
            if (account is! Map<String, dynamic>) throw const FormatException();
            return LinkedBankAccount.fromJson(account);
          })
          .toList(growable: false);
    } on AuthFailure {
      rethrow;
    } on FormatException {
      throw const AuthFailure(
        'The bank service returned an unexpected response. Please try again.',
        code: 'invalid_response',
      );
    }
  }

  @override
  Future<void> unlinkAccount(String accessToken, String accountId) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(accountId)) {
      throw const AuthFailure(
        'This bank account is no longer available.',
        code: 'bank_account_not_found',
      );
    }
    await _request('DELETE', '/api/bank/accounts/$accountId', accessToken);
  }

  @override
  void dispose() => _client.close();
}
