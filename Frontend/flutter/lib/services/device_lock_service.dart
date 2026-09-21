import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class DeviceLockService {
  Future<bool> hasEnrolledBiometrics();
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
  Future<bool> hasEnrolledBiometrics() async {
    if (!_supportedPlatform) return false;
    try {
      if (!await _authentication.isDeviceSupported()) return false;
      if (!await _authentication.canCheckBiometrics) return false;
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    if (!await hasEnrolledBiometrics()) return false;
    try {
      return await _authentication.authenticate(
        localizedReason: 'Unlock FacePay with your device biometrics',
        biometricOnly: true,
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
