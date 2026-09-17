import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoFailure implements Exception {
  const ProfilePhotoFailure(this.message);
  final String message;
}

abstract interface class ProfilePhotoRepository {
  Future<Uint8List?> read(String profileId);
  Future<Uint8List?> choose(String profileId, ImageSource source);
  Future<void> remove(String profileId);
}

/// Photos stay in encrypted device storage, scoped to the signed-in profile.
/// A profile picture is presentation data and never a biometric template.
class ProfilePhotoService implements ProfilePhotoRepository {
  ProfilePhotoService({ImagePicker? picker, FlutterSecureStorage? storage})
    : _picker = picker ?? ImagePicker(),
      _storage = storage ?? const FlutterSecureStorage();
  final ImagePicker _picker;
  final FlutterSecureStorage _storage;
  static const _pendingOwner = 'facepay.photo.pending-owner';
  static const maxBytes = 512 * 1024;
  String _key(String id) =>
      'facepay.photo.${base64Url.encode(utf8.encode(id))}';

  Future<Uint8List> _validated(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const ProfilePhotoFailure('Choose a smaller photo (up to 512 KB).');
    }
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          if (image.width > 2048 || image.height > 2048) {
            throw const ProfilePhotoFailure(
              'Choose a smaller photo and try again.',
            );
          }
          // Re-encode the image to remove metadata before storing.
          final encoded = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (encoded == null || encoded.lengthInBytes > maxBytes) {
            throw const ProfilePhotoFailure(
              'Choose a simpler or smaller photo and try again.',
            );
          }
          return encoded.buffer.asUint8List(
            encoded.offsetInBytes,
            encoded.lengthInBytes,
          );
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } on ProfilePhotoFailure {
      rethrow;
    } catch (_) {
      throw const ProfilePhotoFailure(
        'This photo could not be opened. Choose another image.',
      );
    }
  }

  Future<Uint8List> _save(String id, XFile file) async {
    if (await file.length() > maxBytes) {
      throw const ProfilePhotoFailure('Choose a smaller photo (up to 512 KB).');
    }
    final bytes = await _validated(await file.readAsBytes());
    await _storage.write(key: _key(id), value: base64Encode(bytes));
    return bytes;
  }

  @override
  Future<Uint8List?> read(String profileId) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final recovered = await _picker.retrieveLostData();
        final owner = await _storage.read(key: _pendingOwner);
        await _storage.delete(key: _pendingOwner);
        if (owner == profileId && recovered.files?.isNotEmpty == true) {
          return await _save(profileId, recovered.files!.first);
        }
      }
      final value = await _storage.read(key: _key(profileId));
      if (value == null) return null;
      return await _validated(base64Decode(value));
    } on ProfilePhotoFailure {
      rethrow;
    } catch (_) {
      throw const ProfilePhotoFailure(
        'Your saved photo could not be loaded. Try again.',
      );
    }
  }

  @override
  Future<Uint8List?> choose(String profileId, ImageSource source) async {
    try {
      await _storage.write(key: _pendingOwner, value: profileId);
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 384,
        maxHeight: 384,
        imageQuality: 75,
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return null;
      return await _save(profileId, file);
    } on PlatformException catch (error) {
      if (error.code.contains('denied') || error.code.contains('restricted')) {
        throw const ProfilePhotoFailure(
          'Allow camera or photo access in your phone settings, then try again.',
        );
      }
      throw const ProfilePhotoFailure(
        'The camera or gallery could not open. Please try again.',
      );
    } on ProfilePhotoFailure {
      rethrow;
    } catch (_) {
      throw const ProfilePhotoFailure(
        'Your photo could not be saved. Please try again.',
      );
    } finally {
      try {
        await _storage.delete(key: _pendingOwner);
      } catch (_) {
        // A cleanup error must not replace cancellation or the original error.
      }
    }
  }

  @override
  Future<void> remove(String profileId) async {
    try {
      await _storage.delete(key: _key(profileId));
    } catch (_) {
      throw const ProfilePhotoFailure(
        'Your photo could not be removed. Please try again.',
      );
    }
  }
}
