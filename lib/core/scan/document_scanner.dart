import 'package:docukit_native/docukit_native.dart';

/// The system document scanner (RELEASE_V1_2 §4.2, ADR-041): ML Kit on
/// Android, VisionKit on iOS. Pages come back as JPEGs already inside the
/// job's in/ folder. Tests use `FakeDocumentScanner`.
abstract interface class DocumentScanner {
  Future<ScannerAvailability> availability();

  /// Android: downloads the scanner module once (FR-SCN-07). The caller
  /// limits the wait.
  Future<ScanPrepareResult> prepare();

  Future<ScanOutcome> scan({required int maxPages, required String destDir, bool allowGalleryImport = true});

  /// A scan Android delivered after it had killed the app (FR-SCN-20), once.
  Future<RestoredScanResult?> takeRestored();
}

enum ScannerAvailability { ready, needsDownload, noPlayServices, unsupported, cameraDenied }

enum ScanPrepareResult { ready, offline, failed }

enum ScanErrorCode { moduleUnavailable, offline, noPlayServices, unsupported, cameraDenied, storage, unknown }

sealed class ScanOutcome {
  const ScanOutcome();
}

final class ScanCompleted extends ScanOutcome {
  const ScanCompleted(this.pagePaths, {this.truncated = false});

  /// JPEGs inside destDir, in scan order.
  final List<String> pagePaths;

  /// More pages were scanned than allowed; only the first were kept (iOS).
  final bool truncated;
}

final class ScanCancelled extends ScanOutcome {
  const ScanCancelled();
}

final class ScanFailed extends ScanOutcome {
  const ScanFailed(this.code);
  final ScanErrorCode code;
}

typedef RestoredScanResult = ({String destDir, ScanOutcome outcome});

class NativeDocumentScanner implements DocumentScanner {
  NativeDocumentScanner(this._native);
  final DocukitNative _native;

  @override
  Future<ScannerAvailability> availability() async =>
      ScannerAvailability.values.byName((await _native.scanAvailability()).name);

  @override
  Future<ScanPrepareResult> prepare() async => ScanPrepareResult.values.byName((await _native.prepareScanner()).name);

  @override
  Future<ScanOutcome> scan({required int maxPages, required String destDir, bool allowGalleryImport = true}) async =>
      _outcome(await _native.scanDocument(maxPages: maxPages, destDir: destDir, allowGalleryImport: allowGalleryImport));

  @override
  Future<RestoredScanResult?> takeRestored() async {
    final r = await _native.takeRestoredScan();
    return r == null ? null : (destDir: r.destDir, outcome: _outcome(r.result));
  }

  static ScanOutcome _outcome(NativeScanResult r) => switch (r) {
        NativeScanCompleted(:final pagePaths, :final truncated) => ScanCompleted(pagePaths, truncated: truncated),
        NativeScanCancelled() => const ScanCancelled(),
        NativeScanFailed(:final code) =>
          ScanFailed(ScanErrorCode.values.asNameMap()[code] ?? ScanErrorCode.unknown),
      };
}
