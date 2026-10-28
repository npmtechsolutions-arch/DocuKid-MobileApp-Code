import '../errors/app_error.dart';
import '../files/mime_sniffer.dart';
import '../files/picked_file.dart';

/// Limits (FEATURE_SPECS §6).
abstract final class Limits {
  static const imageMaxBytes = 100 * 1024 * 1024;
  static const imageMaxPixels = 200000000;
  static const pdfMaxBytes = 500 * 1024 * 1024;
  static const mergeMaxFiles = 20;
  static const mergeMaxPages = 2000;
  static const organizerMaxPages = 2000;
  static const imagesPerPdf = 100;
  static const largeFileBytes = 50 * 1024 * 1024;
  static const freeSpaceMargin = 50 * 1024 * 1024;

  /// FR-BAT-04: files per share sheet; more → offer one ZIP.
  static const maxShareFiles = 50;

  /// R16: below this, an empty or failed pick is reported as low storage
  /// (the picker couldn't copy the file) instead of being treated as a cancel.
  static const pickMinFreeBytes = 300 * 1024 * 1024;
  static const targetMinBytes = 5 * 1024;
}

/// Pre-copy size gate (FR-FILE-09): "oversize → a clear message before copying".
AppErrorCode? sizeGate({required bool pdf, required int sizeBytes}) {
  final limit = pdf ? Limits.pdfMaxBytes : Limits.imageMaxBytes;
  return sizeBytes > limit ? AppErrorCode.fileTooLarge : null;
}

/// FEATURE_SPECS §2.2 validateImage (header already inspected).
ValidationStatus validateImageFile({required SniffedType type, required int sizeBytes, ImageMeta? meta, AppErrorCode? inspectError}) {
  if (sizeBytes > Limits.imageMaxBytes) return const ValidationStatus.invalid(AppErrorCode.fileTooLarge);
  if (!type.isSupportedImage) return const ValidationStatus.invalid(AppErrorCode.unsupportedFormat);
  if (inspectError != null || meta == null) return ValidationStatus.invalid(inspectError ?? AppErrorCode.corruptFile);
  if (meta.pixels > Limits.imageMaxPixels) return const ValidationStatus.invalid(AppErrorCode.fileTooLarge);
  final warnings = <WarningCode>{
    if (meta.hasAlpha) WarningCode.hasAlpha,
    if (meta.animated) WarningCode.animated,
    if (sizeBytes > Limits.largeFileBytes) WarningCode.largeFile,
  };
  return warnings.isEmpty ? const ValidationStatus.ok() : ValidationStatus.warning(warnings);
}

/// FEATURE_SPECS §2.2 validatePdf.
ValidationStatus validatePdfFile({required SniffedType type, required int sizeBytes, PdfMeta? meta, AppErrorCode? inspectError}) {
  if (sizeBytes > Limits.pdfMaxBytes) return const ValidationStatus.invalid(AppErrorCode.fileTooLarge);
  if (type != SniffedType.pdf) return const ValidationStatus.invalid(AppErrorCode.unsupportedFormat);
  if (inspectError != null) return ValidationStatus.invalid(inspectError);
  if (meta == null || meta.pageCount == 0) return const ValidationStatus.invalid(AppErrorCode.corruptFile);
  return sizeBytes > Limits.largeFileBytes
      ? const ValidationStatus.warning({WarningCode.largeFile})
      : const ValidationStatus.ok();
}

/// FEATURE_SPECS §2.3 storage estimate multipliers.
int estimateBytes(String tool, int totalInputBytes) {
  final m = switch (tool) {
    'imageCompress' || 'imageResize' => 1.5,
    'imageToPdf' => 1.2,
    'pdfMerge' || 'pdfOrganize' => 2.1,
    'pdfCompress' => 2.5,
    _ => 2.5,
  };
  return (totalInputBytes * m).ceil();
}

bool hasEnoughSpace({required int freeBytes, required int requiredBytes}) =>
    freeBytes >= requiredBytes + Limits.freeSpaceMargin;
