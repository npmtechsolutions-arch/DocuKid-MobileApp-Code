import 'package:docukit_native/docukit_native.dart';

/// Free space, background task and output protection (ARCHITECTURE §6.4).
abstract interface class DeviceServices {
  Future<int> freeBytes();
  Future<int> beginBackgroundTask(String name);
  Future<void> endBackgroundTask(int token);
  Future<void> protectOutput(String path);
}

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
}
