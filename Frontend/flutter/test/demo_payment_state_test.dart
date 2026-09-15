import 'package:face_payment/data/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo payments require the chosen local bank label', () {
    final state = AppState();
    addTearDown(state.dispose);

    expect(
      () => state.recordDemoPayment(recipient: 'Test', amount: 10),
      throwsStateError,
    );
    expect(state.transactions, isEmpty);
    expect(state.balance, 0);
  });

  test('demo payment stays local and leaves the real balance untouched', () {
    final state = AppState()..linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
    addTearDown(state.dispose);

    state.recordDemoPayment(recipient: 'Test recipient', amount: 125.5);

    expect(state.linkedBank?.name, 'HDFC Bank');
    expect(state.balance, 0);
    expect(state.transactions, hasLength(1));
    expect(state.transactions.single.isDemo, isTrue);
    expect(state.transactions.single.category, 'Demo payment');
    expect(state.transactions.single.subtitle, contains('HDFC Bank'));
  });

  test('demo payment rejects missing recipient and non-positive amount', () {
    final state = AppState()..linkDemoBank(name: 'HDFC Bank', monogram: 'HDFC');
    addTearDown(state.dispose);

    expect(
      () => state.recordDemoPayment(recipient: ' ', amount: 1),
      throwsArgumentError,
    );
    expect(
      () => state.recordDemoPayment(recipient: 'Test', amount: 0),
      throwsArgumentError,
    );
    expect(state.transactions, isEmpty);
  });
}
