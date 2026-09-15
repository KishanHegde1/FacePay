import 'package:face_payment/services/presentation_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flags explicit phone, tablet, and display labels', () {
    expect(containsPossibleDeviceOrScreen(['Person', 'Mobile phone']), isTrue);
    expect(containsPossibleDeviceOrScreen(['tablet']), isTrue);
    expect(containsPossibleDeviceOrScreen(['DISPLAY']), isTrue);
  });

  test('does not flag an ordinary face scene', () {
    expect(
      containsPossibleDeviceOrScreen(['person', 'face', 'indoor']),
      isFalse,
    );
  });
}
