/// An interaction check only: two open -> closed -> open cycles. This is not
/// identity verification or replay-resistant liveness/payment authorization.
class BlinkChallenge {
  BlinkChallenge({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  int count = 0;
  int? _trackingId;
  DateTime? _lastSample;
  DateTime? _closedAt;
  bool _armed = false;

  bool get complete => count == 2;

  void reset() {
    count = 0;
    _trackingId = null;
    _lastSample = null;
    _closedAt = null;
    _armed = false;
  }

  bool add({
    required int faceCount,
    int? trackingId,
    double? leftOpen,
    double? rightOpen,
    double? yaw,
    double? roll,
  }) {
    final now = _now();
    if (faceCount != 1 ||
        trackingId == null ||
        leftOpen == null ||
        rightOpen == null ||
        !leftOpen.isFinite ||
        !rightOpen.isFinite ||
        yaw == null ||
        roll == null ||
        !yaw.isFinite ||
        !roll.isFinite ||
        yaw.abs() > 18 ||
        roll.abs() > 18) {
      reset();
      return false;
    }
    if (trackingId != _trackingId ||
        (_lastSample != null &&
            now.difference(_lastSample!) > const Duration(milliseconds: 750))) {
      reset();
    }
    _trackingId = trackingId;
    _lastSample = now;
    if (complete) return true;
    final open = leftOpen >= .75 && rightOpen >= .75;
    final closed = leftOpen <= .25 && rightOpen <= .25;
    if (_closedAt != null &&
        now.difference(_closedAt!) > const Duration(milliseconds: 1500)) {
      // Holding the eyes shut is not a completed blink.
      _closedAt = null;
      _armed = false;
    }
    if (open) {
      if (_closedAt != null &&
          now.difference(_closedAt!) >= const Duration(milliseconds: 60)) {
        count++;
      }
      _closedAt = null;
      _armed = true;
    } else if (closed && _armed) {
      _closedAt = now;
      _armed = false;
    }
    return complete;
  }
}
