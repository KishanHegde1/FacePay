import 'package:face_payment/services/blink_challenge.dart';
import 'package:face_payment/services/scan_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late ScanDetectionGate gate;
  late BlinkChallenge blinks;

  setUp(() {
    now = DateTime(2026);
    gate = ScanDetectionGate(now: () => now);
    blinks = BlinkChallenge(now: () => now);
  });

  void advance([int milliseconds = 100]) =>
      now = now.add(Duration(milliseconds: milliseconds));
  bool eyes(
    double? left,
    double? right, {
    int count = 1,
    int? id = 1,
    double yaw = 0,
  }) {
    advance();
    return blinks.add(
      faceCount: count,
      trackingId: id,
      leftOpen: left,
      rightOpen: right,
      yaw: yaw,
      roll: 0,
    );
  }

  void blink() {
    eyes(.95, .95);
    eyes(.1, .1);
    eyes(.95, .95);
  }

  test('frames are single flight and throttled', () {
    expect(gate.beginFrame(), isTrue);
    advance(500);
    expect(gate.beginFrame(), isFalse);
    gate.endFrame();
    expect(gate.beginFrame(), isTrue);
    gate.endFrame();
    advance(100);
    expect(gate.beginFrame(), isFalse);
    advance(200);
    expect(gate.beginFrame(), isTrue);
  });

  test(
    'QR detection locks out repeated codes and faces until explicit reset',
    () {
      expect(gate.qr([null, ' ']), isNull);
      expect(gate.qr(['upi://pay?pa=test@bank'])?.kind, ScanDetectionKind.qr);
      advance(30000);
      expect(gate.qr(['another-code']), isNull);
      expect(gate.face(count: 1, trackingId: 1), isNull);
      gate.reset();
      expect(gate.beginFrame(), isFalse);
      advance(1000);
      expect(gate.beginFrame(), isTrue);
    },
  );

  test(
    'stable single-face detection rejects multiple faces, gaps and track changes',
    () {
      expect(gate.face(count: 1, trackingId: 1), isNull);
      advance(300);
      expect(gate.face(count: 2), isNull);
      expect(gate.face(count: 1, trackingId: 1), isNull);
      advance(300);
      expect(gate.face(count: 1, trackingId: 2), isNull);
      advance(1100);
      expect(gate.face(count: 1, trackingId: 2), isNull);
      advance(300);
      expect(gate.face(count: 1, trackingId: 2), isNull);
      advance(300);
      expect(gate.face(count: 1, trackingId: 2)?.kind, ScanDetectionKind.face);
      expect(gate.qr(['code']), isNull);
    },
  );

  test('exactly two complete blinks are required, reopening after each', () {
    eyes(.1, .1);
    eyes(.95, .95);
    expect(blinks.count, 0);
    blink();
    expect(blinks.count, 1);
    expect(blinks.complete, isFalse);
    eyes(.1, .1);
    eyes(.1, .1);
    expect(blinks.complete, isFalse);
    eyes(.95, .95);
    expect(blinks.count, 2);
    expect(blinks.complete, isTrue);
    blink();
    expect(blinks.count, 2);
  });

  test('winking, ambiguous eyes and holding eyes closed do not pass', () {
    eyes(.95, .95);
    eyes(.1, .95);
    eyes(.95, .95);
    eyes(.5, .5);
    eyes(.95, .95);
    expect(blinks.count, 0);
    eyes(.1, .1);
    for (var i = 0; i < 20; i++) {
      eyes(.1, .1);
    }
    eyes(.95, .95);
    expect(blinks.count, 0);
  });

  test(
    'face loss, multiple faces, missing classification, pose or identity changes reset blinks',
    () {
      blink();
      eyes(null, null);
      expect(blinks.count, 0);
      blink();
      eyes(.95, .95, count: 2);
      expect(blinks.count, 0);
      blink();
      eyes(.95, .95, id: 2);
      expect(blinks.count, 0);
      blink();
      eyes(.95, .95, count: 0);
      expect(blinks.count, 0);
      blink();
      eyes(.95, .95, yaw: 30);
      expect(blinks.count, 0);
      blink();
      advance(800);
      eyes(.95, .95);
      expect(blinks.count, 0);
      blink();
      eyes(.95, .95, id: null);
      expect(blinks.count, 0);
    },
  );
}
