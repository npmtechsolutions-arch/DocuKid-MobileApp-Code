/// Error codes (ARCHITECTURE §9). Stored in history by `name`.
enum AppErrorCode {
  unsupportedFormat,
  invalidInput,
  encryptedDocument,
  corruptFile,
  fileTooLarge,
  tooManyFiles,
  notEnoughFiles,
  insufficientStorage,
  permissionLost,
  processingFailed,
  outOfMemory,
  cancelled,
  outputValidationFailed,
  saveFailed,
  interrupted,
  // 1.3: a text-recognition script this build can't run (RELEASE_V1_3 §4.11).
  ocrModelUnavailable;

  static AppErrorCode? tryParse(String? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// A user-explainable failure. [fileDisplayName] is for the UI only and is
/// never logged.
class AppError implements Exception {
  const AppError(
    this.code, {
    this.fileDisplayName,
    this.limitBytes,
    this.count,
    this.neededBytes,
    this.script,
  });

  final AppErrorCode code;
  final String? fileDisplayName;

  /// For [AppErrorCode.fileTooLarge].
  final int? limitBytes;

  /// For tooManyFiles (max) / notEnoughFiles (min).
  final int? count;

  /// For [AppErrorCode.insufficientStorage].
  final int? neededBytes;

  /// For [AppErrorCode.ocrModelUnavailable]: the `OcrScript` name.
  final String? script;

  @override
  String toString() => 'AppError(${code.name})';
}

/// Thrown by [CancelToken.throwIfCancelled].
class CancelledException implements Exception {
  const CancelledException();
}
