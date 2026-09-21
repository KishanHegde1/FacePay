import 'package:face_payment/services/device_lock_service.dart';
import 'package:face_payment/ui/design.dart';
import 'package:face_payment/ui/device_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDeviceLockService implements DeviceLockService {
  bool unlocked = false;
  int requests = 0;

  @override
  Future<bool> authenticate() async {
    requests++;
    return unlocked;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> hasEnrolledBiometrics() async => true;
}

void main() {
  testWidgets('enabled app lock hides account until device authentication', (
    tester,
  ) async {
    final service = FakeDeviceLockService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DeviceLockGate(
          active: true,
          enabled: true,
          service: service,
          onUseAnotherAccount: () async {},
          child: const Scaffold(body: Text('Private account screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.requests, 1);
    expect(find.text('FacePay is locked'), findsOneWidget);
    expect(find.text('Private account screen'), findsNothing);

    service.unlocked = true;
    await tester.ensureVisible(find.text('Unlock FacePay'));
    await tester.tap(find.text('Unlock FacePay'));
    await tester.pumpAndSettle();
    expect(service.requests, 2);
    expect(find.text('Private account screen'), findsOneWidget);
    expect(find.text('FacePay is locked'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out app never requests device authentication', (
    tester,
  ) async {
    final service = FakeDeviceLockService();
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceLockGate(
          active: false,
          enabled: true,
          service: service,
          onUseAnotherAccount: () async {},
          child: const Scaffold(body: Text('Sign in')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.requests, 0);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
