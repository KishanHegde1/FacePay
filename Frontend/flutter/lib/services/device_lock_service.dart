import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class DeviceLockService {
  Future<bool> isDeviceAuthenticationAvailable();
  Future<bool> authenticate();
  Future<void> cancel();
}

class LocalDeviceLockService implements DeviceLockService {
  LocalDeviceLockService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isDeviceAuthenticationAvailable() async {
    if (!_supportedPlatform) return false;
    try {
      return await _authentication.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    if (!await isDeviceAuthenticationAvailable()) return false;
    try {
      return await _authentication.authenticate(
        localizedReason: 'Unlock FacePay',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _authentication.stopAuthentication();
    } catch (_) {
      // The platform may have already closed its authentication prompt.
    }
  }
}
