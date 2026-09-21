import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'blink_challenge.dart';
import 'scan_detection.dart';
import 'presentation_guard.dart';

enum ScannerStatus { idle, starting, scanning, detected, error, unsupported }

abstract class ScannerSession extends ChangeNotifier {
  ScannerStatus get status;
  String get message;
  bool get checkingBlinks;
  int get blinkCount;
  ScanDetection? get detection;
  Widget buildPreview();
  Future<void> start();
  Future<void> stop();
  Future<void> switchCamera();
}

/// Owns exactly one camera. Frames are transient and never uploaded or saved.
class MlKitScannerSession extends ScannerSession {
  MlKitScannerSession({
    DateTime Function()? now,
    this.requireFaceLiveness = true,
  }) : _gate = ScanDetectionGate(now: now),
       _blinks = BlinkChallenge(now: now);

  final bool requireFaceLiveness;

  CameraController? _camera;
  BarcodeScanner? _qr;
  FaceDetector? _faces;
  ImageLabeler? _imageLabeler;
  final ScanDetectionGate _gate;
  final BlinkChallenge _blinks;
  Future<void> _operations = Future<void>.value();
  Future<void>? _frame;
  Timer? _blinkDeadline;
  DateTime? _lastPresentationCheck;
  int _generation = 0;
  bool _disposed = false;
  CameraLensDirection _lens = CameraLensDirection.back;

  @override
  ScannerStatus status = ScannerStatus.idle;
  @override
  String message = 'Point your camera at a QR code or one FacePay user.';
  @override
  bool checkingBlinks = false;
  @override
  int get blinkCount => _blinks.count;
  @override
  ScanDetection? detection;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // Serialize camera acquisition/release, including fast background/resume and
  // permission-dialog transitions. Generation changes discard stale results.
  Future<void> _enqueue(Future<void> Function() operation) {
    _operations = _operations.then((_) => operation());
    return _operations;
  }

  @override
  Future<void> start() {
    if (_disposed) return Future<void>.value();
    final generation = ++_generation;
    return _enqueue(() async {
      await _release();
      if (!_current(generation)) return;
      detection = null;
      checkingBlinks = false;
      _lastPresentationCheck = null;
      _blinks.reset();
      _gate.reset();
      if (!_supported) {
        status = ScannerStatus.unsupported;
        message =
            'Live QR and face scanning is available in the Android and iOS app.';
        _notify();
        return;
      }
      status = ScannerStatus.starting;
      message = 'Opening camera…';
      _notify();
      try {
        final cameras = await availableCameras();
        if (!_current(generation)) return;
        if (cameras.isEmpty) {
          throw CameraException('NoCamera', 'No camera available.');
        }
        final description =
            cameras
                .where((camera) => camera.lensDirection == _lens)
                .firstOrNull ??
            cameras.first;
        final camera = CameraController(
          description,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
        _camera = camera;
        await camera.initialize();
        if (!_current(generation)) {
          await _release();
          return;
        }
        _qr = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
        _faces = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            enableTracking: true,
            minFaceSize: .15,
          ),
        );
        camera.addListener(_cameraChanged);
        status = ScannerStatus.scanning;
        message = 'Point your camera at a QR code or one FacePay user.';
        await camera.startImageStream((image) {
          if (!_current(generation) ||
              status != ScannerStatus.scanning ||
              !_gate.beginFrame(
                interval: Duration(milliseconds: checkingBlinks ? 80 : 300),
              )) {
            return;
          }
          _frame = _process(image, generation);
        });
        if (!_current(generation)) {
          await _release();
          return;
        }
        _notify();
      } catch (error) {
        await _release();
        if (!_current(generation)) return;
        status = ScannerStatus.error;
        message = cameraErrorMessage(error);
        _notify();
      }
    });
  }

  void _cameraChanged() {
    if (_camera?.value.hasError == true && status == ScannerStatus.scanning) {
      _fail(
        'The camera stopped unexpectedly. Close other camera apps, then try again.',
      );
    }
  }

  void _fail(String reason) {
    if (_disposed) return;
    ++_generation;
    status = ScannerStatus.error;
    message = reason;
    _notify();
    unawaited(_enqueue(_release));
  }

  Future<void> _process(CameraImage image, int generation) async {
    try {
      final input = scannerInputImage(
        image,
        _camera!.description,
        _camera!.value.deviceOrientation,
        defaultTargetPlatform,
      );
      if (!checkingBlinks) {
        final codes = await _qr!.processImage(input);
        if (!_current(generation)) return;
        final found = _gate.qr(codes.map((code) => code.rawValue));
        if (found != null) {
          _detected(found);
          return;
        }
      }
      final faces = await _faces!.processImage(input);
      if (!_current(generation)) return;
      if (checkingBlinks) {
        // This deliberately runs only during the short blink challenge and no
        // more than once per 900ms. It reuses the same transient camera frame.
        if (_shouldCheckForDeviceScreen()) {
          final labels = await _imageLabeler!.processImage(input);
          if (!_current(generation)) return;
          if (containsPossibleDeviceOrScreen(
            labels.map((label) => label.label),
          )) {
            _fail(
              'A phone, tablet, or display may be in view. Scan the person directly, not a screen.',
            );
            return;
          }
        }
        final face = faces.length == 1 ? faces.single : null;
        final completed = _blinks.add(
          faceCount: faces.length,
          trackingId: face?.trackingId,
          leftOpen: face?.leftEyeOpenProbability,
          rightOpen: face?.rightEyeOpenProbability,
          yaw: face?.headEulerAngleY,
          roll: face?.headEulerAngleZ,
        );
        message = faces.length > 1
            ? 'Keep only one face in view. Blink count has restarted.'
            : face == null
            ? 'Face lost. Look at the camera to restart.'
            : 'Look straight at the camera. Blink twice; remove phones, tablets, or displays from view.';
        if (completed) {
          _detected(const ScanDetection.face());
          return;
        }
        _notify();
      } else {
        final found = _gate.face(
          count: faces.length,
          trackingId: faces.length == 1 ? faces.single.trackingId : null,
        );
        if (found != null) {
          if (!requireFaceLiveness) {
            // Recipient discovery needs a stable single face, but the explicit
            // two-blink challenge belongs to the main Scan and enrollment
            // flows. Check the same transient frame for a possible screen
            // before returning the unverified face detection.
            _imageLabeler = ImageLabeler(
              options: ImageLabelerOptions(confidenceThreshold: .86),
            );
            final labels = await _imageLabeler!.processImage(input);
            if (!_current(generation)) return;
            if (containsPossibleDeviceOrScreen(
              labels.map((label) => label.label),
            )) {
              _fail(
                'A phone, tablet, or display may be in view. Scan the person directly, not a screen.',
              );
              return;
            }
            _detected(found);
            return;
          }
          // Classification is enabled only after initial face detection. This
          // is an interaction challenge, never face recognition/matching.
          await _faces!.close();
          if (!_current(generation)) return;
          _faces = FaceDetector(
            options: FaceDetectorOptions(
              performanceMode: FaceDetectorMode.fast,
              enableClassification: true,
              enableLandmarks: true,
              enableTracking: true,
              minFaceSize: .15,
            ),
          );
          checkingBlinks = true;
          _imageLabeler = ImageLabeler(
            options: ImageLabelerOptions(confidenceThreshold: .86),
          );
          _lastPresentationCheck = null;
          _blinks.reset();
          _gate.reset(debounce: false);
          message = 'Face detected. Look at the camera and blink twice.';
          _blinkDeadline = Timer(const Duration(seconds: 20), () {
            if (_current(generation) && status == ScannerStatus.scanning) {
              _fail(
                'The blink check timed out. Try again in good light with your face straight toward the camera.',
              );
            }
          });
        } else {
          message = faces.length > 1
              ? 'Keep only one face in view, or scan a QR code.'
              : 'Point your camera at a QR code or one FacePay user.';
        }
        _notify();
      }
    } catch (_) {
      if (_current(generation)) {
        _fail(
          'Could not process the camera image. Please try again on a supported device.',
        );
      }
    } finally {
      _gate.endFrame();
    }
  }

  bool _shouldCheckForDeviceScreen() {
    final now = DateTime.now();
    final last = _lastPresentationCheck;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 900)) {
      return false;
    }
    _lastPresentationCheck = now;
    return true;
  }

  void _detected(ScanDetection value) {
    _blinkDeadline?.cancel();
    detection = value;
    status = ScannerStatus.detected;
    _notify();
  }

  @override
  Future<void> stop() {
    ++_generation;
    _blinkDeadline?.cancel();
    if (status != ScannerStatus.detected &&
        status != ScannerStatus.error &&
        status != ScannerStatus.unsupported) {
      status = ScannerStatus.idle;
      _notify();
    }
    return _enqueue(_release);
  }

  Future<void> _release() async {
    _blinkDeadline?.cancel();
    final camera = _camera;
    _camera = null;
    camera?.removeListener(_cameraChanged);
    if (camera != null) {
      try {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
      } catch (_) {
        /* Already interrupted by the OS. */
      }
    }
    await _frame;
    _frame = null;
    if (camera != null) {
      try {
        await camera.dispose();
      } catch (_) {
        /* The native camera may already be closed. */
      }
    }
    final qr = _qr;
    final faces = _faces;
    final imageLabeler = _imageLabeler;
    _qr = null;
    _faces = null;
    _imageLabeler = null;
    try {
      await qr?.close();
    } catch (_) {
      /* Best-effort native cleanup. */
    }
    try {
      await faces?.close();
    } catch (_) {
      /* Best-effort native cleanup. */
    }
    try {
      await imageLabeler?.close();
    } catch (_) {
      /* Best-effort native cleanup. */
    }
  }

  @override
  Future<void> switchCamera() {
    _lens = _camera?.description.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    return start();
  }

  @override
  Widget buildPreview() {
    final camera = _camera;
    return camera != null && camera.value.isInitialized
        ? CameraPreview(camera)
        : const Center(
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white54,
              size: 76,
            ),
          );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _blinkDeadline?.cancel();
    unawaited(_enqueue(_release));
    super.dispose();
  }
}

String cameraErrorMessage(Object error) {
  if (error is CameraException) {
    return switch (error.code) {
      'CameraAccessDenied' =>
        'Camera permission was denied. Allow camera access in your device settings, then try again.',
      'CameraAccessDeniedWithoutPrompt' =>
        'Camera access is disabled. Enable it for FacePay in Settings, then return and try again.',
      'CameraAccessRestricted' =>
        'Camera access is restricted on this device. Check device restrictions before trying again.',
      'NoCamera' => 'No camera was found on this device.',
      _ =>
        'Could not open the camera. Close other camera apps, then try again.',
    };
  }
  return 'Could not start the scanner. Please try again on an Android or iOS device.';
}

InputImage scannerInputImage(
  CameraImage image,
  CameraDescription camera,
  DeviceOrientation orientation,
  TargetPlatform platform,
) {
  final android = platform == TargetPlatform.android;
  final expected = android ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;
  if (image.planes.length != 1 || image.format.group != expected) {
    throw const FormatException('Unsupported camera image layout');
  }
  final degrees = switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  final rotation = android
      ? (camera.sensorOrientation +
                (camera.lensDirection == CameraLensDirection.front
                    ? degrees
                    : -degrees) +
                360) %
            360
      : camera.sensorOrientation;
  final plane = image.planes.single;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(rotation)!,
      format: android ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}
