import 'package:docukit_native/docukit_native.dart';

import 'system_flow.dart';

/// Free space, background task, output protection and the app's Settings
/// page (ARCHITECTURE §6.4).
abstract interface class DeviceServices {
  Future<int> freeBytes();
  Future<int> beginBackgroundTask(String name);
  Future<void> endBackgroundTask(int token);
  Future<void> protectOutput(String path);

  /// DocuKit's page in the system Settings (camera permission, FR-SCN-08).
  Future<void> openAppSettings();

  /// 1.5 indexing (FR-LIB-16). Level -1 = unknown.
  Future<({int level, bool charging})> battery();
}

/// FR-LIB-16: below 20 % and not charging, background work waits. An unknown
/// level (simulator, error) never blocks.
bool batteryLow(({int level, bool charging}) b) => !b.charging && b.level >= 0 && b.level < 20;

class NativeDeviceServices implements DeviceServices {
  NativeDeviceServices(this._native);
  final DocukitNative _native;

  @override
  Future<int> freeBytes() async {
    try {
      return await _native.freeBytes();
    } catch (_) {
      // Unknown free space must not block work.
      return 1 << 62;
    }
  }

  @override
  Future<int> beginBackgroundTask(String name) => _native.beginBackgroundTask(name);

  @override
  Future<void> endBackgroundTask(int token) => _native.endBackgroundTask(token);

  @override
  Future<void> protectOutput(String path) => _native.protectOutput(path);

  @override
  Future<void> openAppSettings() => SystemFlow.run(_native.openAppSettings);

  @override
  Future<({int level, bool charging})> battery() async {
    try {
      return await _native.batteryState();
    } catch (_) {
      return (level: -1, charging: false);
    }
  }
}
