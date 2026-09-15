import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:face_payment/services/scan_detection.dart';
import 'package:face_payment/services/scanner_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

const _backCamera = CameraDescription(
  name: 'test-back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

/// Exercises the real CameraController and scanner session without hardware.
class _NativeCamera extends CameraPlatform {
  _NativeCamera() {
    frames = StreamController<CameraImageData>.broadcast(
      sync: true,
      onListen: () => streamStarts++,
      onCancel: () => streamStops++,
    );
  }

  late final StreamController<CameraImageData> frames;
  List<CameraDescription> cameras = [_backCamera];
  PlatformException? initializationError;
  int availableCalls = 0;
  int creates = 0;
  int streamStarts = 0;
  int streamStops = 0;
  final List<int> disposals = [];
  ImageFormatGroup? requestedFormat;
  bool? audioEnabled;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    availableCalls++;
    return cameras;
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    audioEnabled = enableAudio;
    return ++creates;
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream<DeviceOrientationChangedEvent>.empty();

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      // CameraController listens with .first; an empty, closed stream would
      // itself report an unrelated "No element" error during initialization.
      Stream<CameraErrorEvent>.multi((_) {});

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    requestedFormat = imageFormatGroup;
    if (initializationError case final error?) throw error;
  }

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => frames.stream;

  @override
  Future<void> dispose(int cameraId) async => disposals.add(cameraId);
}

class _NativeVision {
  static const qrChannel = MethodChannel('google_mlkit_barcode_scanning');
  static const faceChannel = MethodChannel('google_mlkit_face_detector');
  static const imageLabelChannel = MethodChannel('google_mlkit_image_labeler');

  final List<MethodCall> qrCalls = [];
  final List<MethodCall> faceCalls = [];
  final List<String> qrCloses = [];
  final List<String> faceCloses = [];
  final List<MethodCall> imageLabelCalls = [];
  final List<String> imageLabelCloses = [];
  List<Map<String, Object?>> qrResults = [];
  List<Map<String, Object?>> faceResults = [];
  List<Map<String, Object?>> imageLabelResults = [];
  Completer<List<Map<String, Object?>>>? pendingQr;

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(qrChannel, (call) async {
      final arguments = call.arguments as Map;
      if (call.method == 'vision#closeBarcodeScanner') {
        qrCloses.add(arguments['id'] as String);
        return null;
      }
      expect(call.method, 'vision#startBarcodeScanner');
      qrCalls.add(call);
      return pendingQr == null ? qrResults : await pendingQr!.future;
    });
    messenger.setMockMethodCallHandler(faceChannel, (call) async {
      final arguments = call.arguments as Map;
      if (call.method == 'vision#closeFaceDetector') {
        faceCloses.add(arguments['id'] as String);
        return null;
      }
      expect(call.method, 'vision#startFaceDetector');
      faceCalls.add(call);
      return faceResults;
    });
    messenger.setMockMethodCallHandler(imageLabelChannel, (call) async {
      final arguments = call.arguments as Map;
      if (call.method == 'vision#closeImageLabelDetector') {
        imageLabelCloses.add(arguments['id'] as String);
        return null;
      }
      expect(call.method, 'vision#startImageLabelDetector');
      imageLabelCalls.add(call);
      return imageLabelResults;
    });
  }

  void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(qrChannel, null);
    messenger.setMockMethodCallHandler(faceChannel, null);
    messenger.setMockMethodCallHandler(imageLabelChannel, null);
  }
}

CameraImageData _frameData({
  ImageFormatGroup format = ImageFormatGroup.nv21,
  int planes = 1,
}) {
  final bgra = format == ImageFormatGroup.bgra8888;
  return CameraImageData(
    format: CameraImageFormat(format, raw: bgra ? 1111970369 : 17),
    width: 4,
    height: 2,
    planes: List.generate(
      planes,
      (_) => CameraImagePlane(
        bytes: Uint8List.fromList(List.generate(bgra ? 32 : 12, (i) => i)),
        bytesPerRow: bgra ? 16 : 4,
        bytesPerPixel: bgra ? 4 : 1,
      ),
    ),
  );
}

Map<String, Object?> _face({double open = .95}) => {
  'rect': {'left': 0.0, 'top': 0.0, 'right': 4.0, 'bottom': 2.0},
  'trackingId': 7,
  'headEulerAngleY': 0.0,
  'headEulerAngleZ': 0.0,
  'leftEyeOpenProbability': open,
  'rightEyeOpenProbability': open,
  'landmarks': <String, Object?>{},
  'contours': <String, Object?>{},
};

Map<String, Object?> _qr(String value) => {
  'type': 7,
  'format': 256,
  'rawValue': value,
  'displayValue': value,
  'rect': {'left': 0.0, 'top': 0.0, 'right': 4.0, 'bottom': 2.0},
  'points': <Object?>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CameraPlatform originalCamera;
  late _NativeCamera camera;
  late _NativeVision vision;
  late MlKitScannerSession session;
  late DateTime now;

  setUp(() {
    originalCamera = CameraPlatform.instance;
    camera = _NativeCamera();
    CameraPlatform.instance = camera;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    now = DateTime(2026);
    vision = _NativeVision()..install();
    session = MlKitScannerSession(now: () => now);
  });

  tearDown(() async {
    // Drain native teardown before restoring the global platform/channel mocks.
    if (vision.pendingQr case final pending? when !pending.isCompleted) {
      pending.complete([]);
    }
    await session.stop();
    session.dispose();
    await session.stop();
    await camera.frames.close();
    vision.uninstall();
    CameraPlatform.instance = originalCamera;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> drain() => Future<void>.delayed(Duration.zero);

  Future<void> frame({int afterMs = 300}) async {
    now = now.add(Duration(milliseconds: afterMs));
    camera.frames.add(_frameData());
    await drain();
  }

  test(
    'one camera feeds the same image to QR and initial face detection',
    () async {
      await session.start().timeout(const Duration(seconds: 5));
      expect(session.status, ScannerStatus.scanning);
      await frame(afterMs: 1000);

      expect(camera.creates, 1);
      expect(camera.streamStarts, 1);
      expect(camera.audioEnabled, isFalse);
      expect(camera.requestedFormat, ImageFormatGroup.nv21);
      expect(vision.qrCalls, hasLength(1));
      expect(vision.faceCalls, hasLength(1));
      final qrArguments = vision.qrCalls.single.arguments as Map;
      final faceArguments = vision.faceCalls.single.arguments as Map;
      expect(qrArguments['formats'], [256]);
      expect(faceArguments['imageData'], equals(qrArguments['imageData']));
      expect(
        (faceArguments['options'] as Map)['enableClassification'],
        isFalse,
      );
      expect(session.detection, isNull);
    },
  );

  test(
    'stable face enables classification then requires two full blinks',
    () async {
      var faceEvents = 0;
      session.addListener(() {
        if (session.status == ScannerStatus.detected &&
            session.detection?.kind == ScanDetectionKind.face) {
          faceEvents++;
        }
      });
      vision.faceResults = [_face()];
      await session.start().timeout(const Duration(seconds: 5));
      await frame(afterMs: 1000);
      await frame();
      expect(session.checkingBlinks, isFalse);
      await frame();
      expect(session.checkingBlinks, isTrue);
      expect(session.blinkCount, 0);
      expect(vision.faceCalls, hasLength(3));
      expect(vision.faceCloses, hasLength(1));
      for (final call in vision.faceCalls) {
        expect(
          ((call.arguments as Map)['options'] as Map)['enableClassification'],
          isFalse,
        );
      }

      await frame(afterMs: 100); // Establish open eyes.
      expect(vision.imageLabelCalls, hasLength(1));
      expect(
        ((vision.faceCalls.last.arguments as Map)['options']
            as Map)['enableClassification'],
        isTrue,
      );
      vision.faceResults = [_face(open: .1)];
      await frame(afterMs: 100);
      await frame(afterMs: 100);
      expect(session.blinkCount, 0); // Closed eyes alone are not a blink.
      vision.faceResults = [_face()];
      await frame(afterMs: 100);
      expect(session.blinkCount, 1);
      expect(faceEvents, 0);
      vision.faceResults = [_face(open: .1)];
      await frame(afterMs: 100);
      expect(faceEvents, 0);
      vision.faceResults = [_face()];
      await frame(afterMs: 100);
      expect(session.blinkCount, 2);
      expect(session.status, ScannerStatus.detected);
      expect(faceEvents, 1);
      final faceCallsAtCompletion = vision.faceCalls.length;
      await frame(afterMs: 1000);
      expect(faceEvents, 1);
      expect(vision.faceCalls, hasLength(faceCallsAtCompletion));
      expect(
        vision.qrCalls,
        hasLength(3),
      ); // QR pauses during the blink challenge.
      expect(camera.creates, 1);
    },
  );

  test('stops the blink check when a phone or display is detected', () async {
    vision.faceResults = [_face()];
    vision.imageLabelResults = [
      {'text': 'Mobile phone', 'confidence': .96, 'index': 0},
    ];
    await session.start().timeout(const Duration(seconds: 5));
    await frame(afterMs: 1000);
    await frame();
    await frame();
    expect(session.checkingBlinks, isTrue);
    await frame(afterMs: 1000);
    expect(session.status, ScannerStatus.error);
    expect(session.message, contains('phone, tablet, or display'));
  });

  test(
    'pending inference is single flight and stop suppresses late QR',
    () async {
      final pending = Completer<List<Map<String, Object?>>>();
      vision.pendingQr = pending;
      var resultEvents = 0;
      session.addListener(() {
        if (session.status == ScannerStatus.detected) resultEvents++;
      });
      await session.start().timeout(const Duration(seconds: 5));
      await frame(afterMs: 1000);
      await frame(afterMs: 1000);
      expect(vision.qrCalls, hasLength(1));
      expect(vision.faceCalls, isEmpty);

      var stopped = false;
      final stopping = session.stop().then((_) => stopped = true);
      await drain();
      expect(camera.streamStops, 1);
      expect(stopped, isFalse);
      expect(camera.disposals, isEmpty);
      pending.complete([_qr('upi://pay?pa=unverified@bank')]);
      await drain();
      await stopping;
      expect(stopped, isTrue);
      expect(session.status, ScannerStatus.idle);
      expect(session.detection, isNull);
      expect(resultEvents, 0);
      expect(vision.faceCalls, isEmpty);
      expect(camera.disposals, [1]);
      expect(vision.qrCloses, hasLength(1));
      expect(vision.faceCloses, hasLength(1));
      await session.stop();
      expect(camera.disposals, [1]);
      expect(vision.qrCloses, hasLength(1));
      expect(vision.faceCloses, hasLength(1));
    },
  );

  test('QR result locks further frames and skips face work', () async {
    vision.qrResults = [_qr('unverified-code')];
    var resultEvents = 0;
    session.addListener(() {
      if (session.status == ScannerStatus.detected) resultEvents++;
    });
    await session.start().timeout(const Duration(seconds: 5));
    await frame(afterMs: 1000);
    expect(session.detection?.kind, ScanDetectionKind.qr);
    expect(session.detection?.rawValue, 'unverified-code');
    await frame(afterMs: 1000);
    expect(resultEvents, 1);
    expect(vision.qrCalls, hasLength(1));
    expect(vision.faceCalls, isEmpty);
  });

  test(
    'permission denial releases camera and leaves a retryable error',
    () async {
      camera.initializationError = PlatformException(
        code: 'CameraAccessDenied',
      );
      await session.start().timeout(const Duration(seconds: 5));
      expect(session.status, ScannerStatus.error);
      expect(session.message, contains('permission was denied'));
      expect(camera.disposals, [1]);
      expect(camera.streamStarts, 0);
      expect(vision.qrCalls, isEmpty);
      expect(vision.faceCalls, isEmpty);

      camera.initializationError = null;
      await session.start().timeout(const Duration(seconds: 5));
      expect(session.status, ScannerStatus.scanning);
      expect(camera.creates, 2);
      expect(camera.streamStarts, 1);
    },
  );

  test('no camera reports an error before allocation or inference', () async {
    camera.cameras = [];
    await session.start().timeout(const Duration(seconds: 5));
    expect(session.status, ScannerStatus.error);
    expect(session.message, contains('No camera'));
    expect(camera.creates, 0);
    expect(vision.qrCalls, isEmpty);
    expect(vision.faceCalls, isEmpty);
  });

  test(
    'desktop is unsupported without touching native camera or MLKit',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await session.start().timeout(const Duration(seconds: 5));
      expect(session.status, ScannerStatus.unsupported);
      expect(camera.availableCalls, 0);
      expect(camera.creates, 0);
      expect(vision.qrCalls, isEmpty);
      expect(vision.faceCalls, isEmpty);
    },
  );

  test('NV21 applies sensor and device rotation for front and back lenses', () {
    final image = CameraImage.fromPlatformInterface(_frameData());
    const front = CameraDescription(
      name: 'test-front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );
    final expectedBack = [90, 0, 270, 180];
    final expectedFront = [270, 0, 90, 180];
    const orientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
    ];
    for (var i = 0; i < orientations.length; i++) {
      final backInput = scannerInputImage(
        image,
        _backCamera,
        orientations[i],
        TargetPlatform.android,
      );
      final frontInput = scannerInputImage(
        image,
        front,
        orientations[i],
        TargetPlatform.android,
      );
      expect(backInput.metadata!.rotation.rawValue, expectedBack[i]);
      expect(frontInput.metadata!.rotation.rawValue, expectedFront[i]);
      expect(backInput.metadata!.format, InputImageFormat.nv21);
      expect(backInput.bytes, same(image.planes.single.bytes));
      expect(backInput.metadata!.size.width, 4);
      expect(backInput.metadata!.size.height, 2);
    }
  });

  test('BGRA preserves iOS bytes, row stride and sensor orientation', () {
    final image = CameraImage.fromPlatformInterface(
      _frameData(format: ImageFormatGroup.bgra8888),
    );
    final input = scannerInputImage(
      image,
      _backCamera,
      DeviceOrientation.landscapeRight,
      TargetPlatform.iOS,
    );
    expect(input.bytes, same(image.planes.single.bytes));
    expect(input.metadata!.format, InputImageFormat.bgra8888);
    expect(input.metadata!.bytesPerRow, 16);
    expect(input.metadata!.rotation, InputImageRotation.rotation90deg);
  });

  test(
    'wrong camera format and multiple planes fail before native inference',
    () {
      for (final data in [
        _frameData(format: ImageFormatGroup.yuv420),
        _frameData(planes: 3),
        _frameData(format: ImageFormatGroup.bgra8888),
      ]) {
        expect(
          () => scannerInputImage(
            CameraImage.fromPlatformInterface(data),
            _backCamera,
            DeviceOrientation.portraitUp,
            TargetPlatform.android,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
