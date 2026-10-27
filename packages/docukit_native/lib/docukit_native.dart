/// DocuKit's small native bridge (ARCHITECTURE §6.4, ADR-006).
///
/// Every method takes file paths, never bytes, so large files are streamed by
/// the OS side instead of being copied across the platform channel.
library;

import 'package:flutter/services.dart';

/// Result of [DocukitNative.saveAs].
sealed class NativeSaveResult {
  const NativeSaveResult();
}

final class NativeSaved extends NativeSaveResult {
  const NativeSaved(this.displayName);

  /// The name the system finally used (it may add " (1)"), when known.
  final String? displayName;
}

final class NativeSaveCancelled extends NativeSaveResult {
  const NativeSaveCancelled();
}

final class NativeSaveFailed extends NativeSaveResult {
  const NativeSaveFailed(this.code);
  final String code;
}

class DocukitNative {
  DocukitNative({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('docukit/native');

  final MethodChannel _channel;

  /// Android: `ACTION_CREATE_DOCUMENT` + a stream copy.
  /// iOS: `UIDocumentPickerViewController(forExporting:asCopy:)`.
  Future<NativeSaveResult> saveAs(
    String path, {
    required String suggestedName,
    required String mime,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('saveAs', {
        'path': path,
        'name': suggestedName,
        'mime': mime,
      });
      switch (res?['status']) {
        case 'saved':
          return NativeSaved(res?['name'] as String?);
        case 'cancelled':
          return const NativeSaveCancelled();
        default:
          return NativeSaveFailed((res?['code'] as String?) ?? 'unknown');
      }
    } on PlatformException catch (e) {
      return NativeSaveFailed(e.code);
    }
  }

  /// Opens the file in another app. Returns false when no app can open it.
  /// [origin] anchors the iPad popover (global logical coordinates).
  Future<bool> openWith(String path, {required String mime, Rect? origin}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openWith', {
        'path': path,
        'mime': mime,
        if (origin != null) 'origin': _rect(origin),
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Free bytes on the volume that holds the app's files.
  Future<int> freeBytes() async {
    final v = await _channel.invokeMethod<int>('freeBytes');
    return v ?? 0;
  }

  /// iOS: `UIApplication.beginBackgroundTask`. Android: no-op (ADR-009).
  Future<int> beginBackgroundTask(String name) async {
    try {
      return await _channel.invokeMethod<int>('beginBackgroundTask', {'name': name}) ?? -1;
    } on PlatformException {
      return -1;
    }
  }

  Future<void> endBackgroundTask(int token) async {
    if (token < 0) return;
    try {
      await _channel.invokeMethod<void>('endBackgroundTask', {'token': token});
    } on PlatformException {
      // Ending an already-expired task is harmless.
    }
  }

  /// iOS: excludes [path] from iCloud backup and applies
  /// `completeUntilFirstUserAuthentication` file protection. Android: no-op.
  Future<void> protectOutput(String path) async {
    try {
      await _channel.invokeMethod<void>('protectOutput', {'path': path});
    } on PlatformException {
      // Best effort; never blocks a job.
    }
  }

  static Map<String, double> _rect(Rect r) =>
      {'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height};
}
