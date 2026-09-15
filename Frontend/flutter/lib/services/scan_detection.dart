enum ScanDetectionKind { qr, face }

class ScanDetection {
  const ScanDetection.qr(this.rawValue) : kind = ScanDetectionKind.qr;
  const ScanDetection.face() : kind = ScanDetectionKind.face, rawValue = null;

  final ScanDetectionKind kind;
  final String? rawValue;
}

/// A single-flight gate, a frame throttle, and a route lock. A result stays
/// locked until the user explicitly chooses to scan again.
class ScanDetectionGate {
  ScanDetectionGate({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastFrame;
  DateTime? _lastFace;
  DateTime? _resumeAfter;
  int? _faceId;
  int _faceFrames = 0;
  bool _busy = false;
  bool _locked = false;

  bool beginFrame({Duration interval = const Duration(milliseconds: 300)}) {
    final now = _now();
    if (_busy ||
        _locked ||
        (_resumeAfter != null && now.isBefore(_resumeAfter!)) ||
        (_lastFrame != null && now.difference(_lastFrame!) < interval)) {
      return false;
    }
    _busy = true;
    _lastFrame = now;
    return true;
  }

  void endFrame() => _busy = false;

  ScanDetection? qr(Iterable<String?> values) {
    if (_locked) return null;
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        _locked = true;
        return ScanDetection.qr(value);
      }
    }
    return null;
  }

  ScanDetection? face({required int count, int? trackingId}) {
    if (_locked) return null;
    final now = _now();
    if (count != 1) {
      _faceFrames = 0;
      _lastFace = null;
      _faceId = null;
      return null;
    }
    if (_lastFace == null ||
        now.difference(_lastFace!) > const Duration(seconds: 1) ||
        trackingId != _faceId) {
      _faceFrames = 0;
    }
    _lastFace = now;
    _faceId = trackingId;
    _faceFrames++;
    if (_faceFrames < 3) return null;
    _locked = true;
    return const ScanDetection.face();
  }

  void reset({bool debounce = true}) {
    _locked = false;
    _busy = false;
    _lastFrame = null;
    _lastFace = null;
    _faceId = null;
    _faceFrames = 0;
    _resumeAfter = debounce ? _now().add(const Duration(seconds: 1)) : null;
  }
}
