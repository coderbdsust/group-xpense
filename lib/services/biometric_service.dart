import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      print('Biometric check error: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Get biometrics error: $e');
      return <BiometricType>[];
    }
  }

  static Future<bool> authenticate({
    String reason = 'Please authenticate to access Group Xpense',
  }) async {
    try {
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) {
        print('Biometric not available');
        return false;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Pattern fallback
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );

      print('Authentication result: $didAuthenticate');
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Authentication error: ${e.code} - ${e.message}');

      // Handle specific error codes
      if (e.code == 'NotAvailable' ||
          e.code == 'NotEnrolled' ||
          e.code == 'PasscodeNotSet') {
        return false;
      }

      // User cancelled
      if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return false;
      }

      return false;
    } catch (e) {
      print('Unexpected error during authentication: $e');
      return false;
    }
  }

  static String getBiometricTypeString(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (types.contains(BiometricType.weak)) {
      return 'Biometric';
    } else {
      return 'Device Authentication';
    }
  }
}
