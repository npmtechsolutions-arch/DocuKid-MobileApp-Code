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
  const NativeSavedMany({required this.saved, required this.failed, this.failedIndexes = const [], this.folderName});
  final int saved, failed;

  /// Which items failed (Android); empty when the OS doesn't say (iOS).
  final List<int> failedIndexes;

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

/// Files that arrived from a share or "Open with" (FR-SHR), already copied
/// into a temporary folder by the native side.
class IncomingBatch {
  const IncomingBatch({required this.dir, required this.files, this.truncated = false, this.failed = 0});
  final String dir;
  final List<({String path, String name})> files;

  /// More files were sent than are ever kept.
  final bool truncated;

  /// Files that couldn't be read.
  final int failed;

  static IncomingBatch fromMap(Map<Object?, Object?> m) => IncomingBatch(
        dir: m['dir'] as String? ?? '',
        files: [
          for (final f in (m['files'] as List? ?? const []).cast<Map<Object?, Object?>>())
            (path: f['path'] as String, name: f['name'] as String),
        ],
        truncated: m['truncated'] == true,
        failed: (m['failed'] as int?) ?? 0,
      );
}

/// Whether the system document scanner can open now (RELEASE_V1_2 §4.2).
enum NativeScanAvailability { ready, needsDownload, noPlayServices, unsupported, cameraDenied }

/// Outcome of [DocukitNative.prepareScanner] (the one-time module download).
enum NativeScanPrepare { ready, offline, failed }

/// Result of [DocukitNative.scanDocument].
sealed class NativeScanResult {
  const NativeScanResult();

  static NativeScanResult fromMap(Map<Object?, Object?>? m) => switch (m?['status']) {
        'completed' => NativeScanCompleted(
            ((m?['pagePaths'] as List?) ?? const []).cast<String>(),
            truncated: m?['truncated'] == true,
          ),
        'cancelled' => const NativeScanCancelled(),
        _ => NativeScanFailed((m?['errorCode'] as String?) ?? 'unknown'),
      };
}

final class NativeScanCompleted extends NativeScanResult {
  const NativeScanCompleted(this.pagePaths, {this.truncated = false});

  /// JPEGs already inside the destination folder, in scan order.
  final List<String> pagePaths;

  /// More pages were scanned than the limit; only the first were kept (iOS).
  final bool truncated;
}

final class NativeScanCancelled extends NativeScanResult {
  const NativeScanCancelled();
}

final class NativeScanFailed extends NativeScanResult {
  const NativeScanFailed(this.code);

  /// moduleUnavailable | offline | noPlayServices | unsupported | cameraDenied | storage | unknown
  final String code;
}

/// A scan whose result arrived after Android had killed the app (FR-SCN-20).
class RestoredScan {
  const RestoredScan({required this.destDir, required this.result});
  final String destDir;
  final NativeScanResult result;
}

class DocukitNative {
  DocukitNative({MethodChannel? channel, EventChannel? incoming})
      : _channel = channel ?? const MethodChannel('docukit/native'),
        _incoming = incoming ?? const EventChannel('docukit/incoming');

  final MethodChannel _channel;
  final EventChannel _incoming;

  /// Batches that arrived before anyone listened (cold start). Each call
  /// returns them once.
  Future<List<IncomingBatch>> getIncomingFiles() async {
    try {
      final list = await _channel.invokeListMethod<Object?>('getIncomingFiles') ?? const [];
      return [for (final m in list.cast<Map<Object?, Object?>>()) IncomingBatch.fromMap(m)];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Batches that arrive while DocuKit runs (warm start).
  Stream<IncomingBatch> get incomingFiles =>
      _incoming.receiveBroadcastStream().map((e) => IncomingBatch.fromMap(e as Map<Object?, Object?>));

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
            failedIndexes: ((res?['failedIndexes'] as List?) ?? const []).cast<int>(),
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

  /// Android: Google Play services present, then whether the ML Kit scanner
  /// module is installed. iOS: VisionKit support and camera permission.
  Future<NativeScanAvailability> scanAvailability() async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('scanAvailability');
      return NativeScanAvailability.values.asNameMap()[res?['status']] ?? NativeScanAvailability.unsupported;
    } on PlatformException {
      return NativeScanAvailability.unsupported;
    } on MissingPluginException {
      return NativeScanAvailability.unsupported;
    }
  }

  /// Android: asks Play services to download the scanner module and waits
  /// until it is installed or fails. The caller applies its own time limit
  /// (FR-SCN-07). iOS: always ready (VisionKit is part of the OS).
  Future<NativeScanPrepare> prepareScanner() async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('prepareScanner');
      return NativeScanPrepare.values.asNameMap()[res?['status']] ?? NativeScanPrepare.failed;
    } on PlatformException {
      return NativeScanPrepare.failed;
    } on MissingPluginException {
      return NativeScanPrepare.failed;
    }
  }

  /// Opens the system document scanner and copies each page as a JPEG into
  /// [destDir] (`page_###.jpg`, numbered after the pages already there).
  /// Android: ML Kit full mode (ADR-041). iOS: VisionKit.
  Future<NativeScanResult> scanDocument({
    required int maxPages,
    required String destDir,
    bool allowGalleryImport = true,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('scanDocument', {
        'maxPages': maxPages,
        'destDir': destDir,
        'allowGalleryImport': allowGalleryImport,
      });
      return NativeScanResult.fromMap(res);
    } on PlatformException catch (e) {
      return NativeScanFailed(e.code);
    } on MissingPluginException {
      return const NativeScanFailed('unsupported');
    }
  }

  /// A scan result Android delivered after restarting the app (FR-SCN-20).
  /// Each call returns it once.
  Future<RestoredScan?> takeRestoredScan() async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('takeRestoredScan');
      if (res == null) return null;
      return RestoredScan(
        destDir: res['destDir'] as String? ?? '',
        result: NativeScanResult.fromMap(res['result'] as Map<Object?, Object?>?),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Debug builds only: makes [scanAvailability] and [scanDocument] act as if
  /// [status] were true (e.g. `noPlayServices`), or back to normal with null.
  /// Ignored by release builds.
  Future<void> debugSetScanOverride(String? status) async {
    try {
      await _channel.invokeMethod<void>('debugSetScanOverride', {'status': status});
    } on PlatformException {
      // Release build: ignored.
    } on MissingPluginException {
      // No plugin: nothing to override.
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
