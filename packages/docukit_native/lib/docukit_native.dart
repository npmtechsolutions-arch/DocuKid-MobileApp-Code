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

/// Result of [DocukitNative.saveManyToFolder].
sealed class NativeSaveManyResult {
  const NativeSaveManyResult();
}

final class NativeSavedMany extends NativeSaveManyResult {
  const NativeSavedMany({required this.saved, required this.failed, this.folderName});
  final int saved, failed;

  /// Display name of the picked folder (Android; iOS when the system says).
  final String? folderName;
}

final class NativeSaveManyCancelled extends NativeSaveManyResult {
  const NativeSaveManyCancelled();
}

final class NativeSaveManyFailed extends NativeSaveManyResult {
  const NativeSaveManyFailed(this.code);
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

  /// Writes several files into one folder the user picks.
  /// Android: `ACTION_OPEN_DOCUMENT_TREE` (one-time, no persisted permission)
  /// + `DocumentsContract.createDocument` and a stream copy per file (ADR-060).
  /// iOS: `UIDocumentPickerViewController(forExporting:asCopy:)` with all URLs.
  /// Names must already be safe and unique.
  Future<NativeSaveManyResult> saveManyToFolder(List<({String path, String name, String mime})> items) async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('saveManyToFolder', {
        'items': [
          for (final i in items) {'path': i.path, 'name': i.name, 'mime': i.mime},
        ],
      });
      switch (res?['status']) {
        case 'saved':
          return NativeSavedMany(
            saved: (res?['savedCount'] as int?) ?? 0,
            failed: (res?['failedCount'] as int?) ?? 0,
            folderName: res?['folderName'] as String?,
          );
        case 'cancelled':
          return const NativeSaveManyCancelled();
        default:
          return NativeSaveManyFailed((res?['code'] as String?) ?? 'unknown');
      }
    } on PlatformException catch (e) {
      return NativeSaveManyFailed(e.code);
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
