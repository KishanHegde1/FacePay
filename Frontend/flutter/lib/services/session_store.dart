import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

abstract class SessionStore {
  Future<String?> readToken();
  Future<void> saveToken(String token);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  static const _key = 'facepay.session';
  static const deviceKey = 'facepay.device-id';
  static const _installation = 'facepay.installation';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> _prepare() async {
    final preferences = await SharedPreferences.getInstance();
    // Keychain can survive uninstall; the app-local marker cannot.
    if (preferences.getBool(_installation) != true) {
      await _storage.delete(key: _key);
      if (!await preferences.setBool(_installation, true)) {
        throw StateError('Could not initialize session storage.');
      }
    }
  }

  @override
  Future<String?> readToken() async {
    await _prepare();
    return _storage.read(key: _key);
  }

  @override
  Future<void> saveToken(String token) async {
    await _prepare();
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);

  /// A random per-installation identifier kept in platform-secure storage.
  /// It identifies an app installation, not a person or a hardware serial.
  Future<String> readOrCreateDeviceId() async {
    await _prepare();
    final existing = await _storage.read(key: deviceKey);
    if (existing != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final value = List<String>.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: deviceKey, value: value);
    return value;
  }
}
