import 'dart:convert';

import 'package:face_payment/services/auth_api.dart';
import 'package:face_payment/services/hdfc_bank_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('lists masked linked accounts through the FacePay backend', () async {
    late http.Request request;
    final service = HdfcBankService(
      baseUrl: 'https://api.example.test',
      client: MockClient((captured) async {
        request = captured;
        return http.Response(
          jsonEncode({
            'accounts': [
              {
                'id': 'a' * 64,
                'bank_name': 'HDFC Bank',
                'bank_code': 'HDFC',
                'masked_account_number': 'XXXX4821',
                'account_type': 'Savings',
                'account_holder_name': 'FacePay User',
                'verification_status': 'verified',
                'provider': 'hdfc_sandbox',
              },
            ],
          }),
          200,
        );
      }),
    );

    final accounts = await service.listLinkedAccounts('session-token');

    expect(request.method, 'GET');
    expect(request.url.path, '/api/bank/accounts');
    expect(request.headers['authorization'], 'Bearer session-token');
    expect(accounts, hasLength(1));
    expect(accounts.single.maskedAccountNumber, 'XXXX4821');
    service.dispose();
  });

  test('does not send malformed account identifiers to the backend', () async {
    var called = false;
    final service = HdfcBankService(
      baseUrl: 'https://api.example.test',
      client: MockClient((_) async {
        called = true;
        return http.Response('', 204);
      }),
    );

    await expectLater(
      () => service.unlinkAccount('session-token', 'not-an-account-id'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.code,
          'code',
          'bank_account_not_found',
        ),
      ),
    );
    expect(called, isFalse);
    service.dispose();
  });

  test('surfaces the backend safe error instead of HDFC details', () async {
    final service = HdfcBankService(
      baseUrl: 'https://api.example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'hdfc_sandbox_setup_required',
              'message': 'Bank verification is not available yet.',
            },
          }),
          503,
        ),
      ),
    );

    await expectLater(
      () => service.listLinkedAccounts('session-token'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.code,
          'code',
          'hdfc_sandbox_setup_required',
        ),
      ),
    );
    service.dispose();
  });
}
