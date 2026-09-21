import 'package:face_payment/services/device_lock_service.dart';
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
  Future<bool> isDeviceAuthenticationAvailable() async => true;
}

void main() {
  testWidgets('enabled app lock keeps account hidden behind a blank screen', (
    tester,
  ) async {
    final service = FakeDeviceLockService();
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceLockGate(
          active: true,
          enabled: true,
          service: service,
          child: const Scaffold(body: Text('Private account screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.requests, 1);
    expect(
      find.byKey(const ValueKey('device-lock-blank-screen')),
      findsOneWidget,
    );
    expect(find.text('Private account screen'), findsNothing);
    expect(find.byType(Text), findsNothing);

    service.unlocked = true;
    await tester.tap(find.byKey(const ValueKey('device-lock-blank-screen')));
    await tester.pumpAndSettle();
    expect(service.requests, 2);
    expect(find.text('Private account screen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-lock-blank-screen')),
      findsNothing,
    );
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
          child: const Scaffold(body: Text('Sign in')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.requests, 0);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('enabling app lock in settings does not lock immediately', (
    tester,
  ) async {
    final service = FakeDeviceLockService();
    var enabled = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return DeviceLockGate(
              active: true,
              enabled: enabled,
              service: service,
              child: const Scaffold(body: Text('Private account screen')),
            );
          },
        ),
      ),
    );
    update(() => enabled = true);
    await tester.pumpAndSettle();
    expect(service.requests, 0);
    expect(find.text('Private account screen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-lock-blank-screen')),
      findsNothing,
    );
  });
}
