import 'package:local_auth/local_auth.dart';

import '../platform/system_flow.dart';

/// How an unlock attempt ended (FR-LCK-06/07).
enum AuthOutcome { success, failed, cancelled, noCredential, error }

/// The device's own biometrics / PIN / pattern / passcode (ADR-056: DocuKit
/// stores no PIN of its own). Behind an interface so tests use a fake.
abstract interface class DeviceAuth {
  /// The phone has a screen lock (biometrics or a device credential).
  Future<bool> available();

  Future<AuthOutcome> authenticate(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<AuthOutcome> authenticate(String reason) => SystemFlow.run(() async {
        try {
          // Biometrics with the device PIN / pattern / passcode as fallback.
          // No automatic re-prompt when the app comes back (FR-LCK-06: no
          // retry loop) — with it, Back on Android's PIN screen re-opened it.
          final ok = await _auth.authenticate(localizedReason: reason, biometricOnly: false);
          return ok ? AuthOutcome.success : AuthOutcome.failed;
        } on LocalAuthException catch (e) {
          return switch (e.code) {
            LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled => AuthOutcome.cancelled,
            LocalAuthExceptionCode.noCredentialsSet => AuthOutcome.noCredential,
            _ => AuthOutcome.error,
          };
        } on Exception {
          return AuthOutcome.error;
        }
      });
}
