import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:face_payment/services/profile_photo_service.dart';

Uint8List get photo => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class TestPicker extends ImagePicker {
  XFile? file;
  PlatformException? failure;
  LostDataResponse recovered = LostDataResponse();
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (failure != null) throw failure!;
    return file;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => recovered;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('photos persist per account and removing one preserves another', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final picker = TestPicker()
        ..file = XFile.fromData(photo, name: 'photo.png');
      final service = ProfilePhotoService(picker: picker);
      await service.choose('account-a', ImageSource.gallery);
      expect(await service.read('account-b'), isNull);
      await service.choose('account-b', ImageSource.camera);
      await service.remove('account-a');
      expect(await service.read('account-a'), isNull);
      expect(await service.read('account-b'), isNotNull);
      expect(
        await ProfilePhotoService(picker: TestPicker()).read('account-b'),
        isNotNull,
      );
    });
  });
  testWidgets('picker cancellation preserves the stored photo', (tester) async {
    await tester.runAsync(() async {
      final picker = TestPicker()..file = XFile.fromData(photo);
      final service = ProfilePhotoService(picker: picker);
      final original = await service.choose('account', ImageSource.gallery);
      picker.file = null;
      expect(await service.choose('account', ImageSource.camera), isNull);
      expect(await service.read('account'), orderedEquals(original!));
    });
  });
  for (final oversized in [false, true]) {
    testWidgets(
      'rejects ${oversized ? 'oversized' : 'invalid'} photo without replacing stored data',
      (tester) async {
        await tester.runAsync(() async {
          final picker = TestPicker()..file = XFile.fromData(photo);
          final service = ProfilePhotoService(picker: picker);
          final original = await service.choose('account', ImageSource.gallery);
          picker.file = XFile.fromData(
            oversized
                ? Uint8List(ProfilePhotoService.maxBytes + 1)
                : Uint8List.fromList([1, 2, 3]),
          );
          await expectLater(
            service.choose('account', ImageSource.gallery),
            throwsA(isA<ProfilePhotoFailure>()),
          );
          expect(await service.read('account'), orderedEquals(original!));
        });
      },
    );
  }
  for (final sameOwner in [true, false]) {
    testWidgets(
      'lost Android photo recovery ${sameOwner ? 'restores owner' : 'cannot cross accounts'}',
      (tester) async {
        await tester.runAsync(() async {
          FlutterSecureStorage.setMockInitialValues({
            'facepay.photo.pending-owner': 'account-a',
          });
          final picker = TestPicker()
            ..recovered = LostDataResponse(
              files: [XFile.fromData(photo)],
              type: RetrieveType.image,
            );
          final service = ProfilePhotoService(picker: picker);
          final recovered = await service.read(
            sameOwner ? 'account-a' : 'account-b',
          );
          expect(recovered, sameOwner ? isNotNull : isNull);
          expect(
            await const FlutterSecureStorage().read(
              key: 'facepay.photo.pending-owner',
            ),
            isNull,
          );
        });
      },
    );
  }
  testWidgets(
    'permission denial returns actionable error and clears pending owner',
    (tester) async {
      final picker = TestPicker()
        ..failure = PlatformException(code: 'camera_access_denied');
      final service = ProfilePhotoService(picker: picker);
      await expectLater(
        service.choose('account', ImageSource.camera),
        throwsA(
          isA<ProfilePhotoFailure>().having(
            (e) => e.message,
            'message',
            contains('phone settings'),
          ),
        ),
      );
      expect(
        await const FlutterSecureStorage().read(
          key: 'facepay.photo.pending-owner',
        ),
        isNull,
      );
    },
  );
}
