import '../errors/app_error.dart';
import 'mime_sniffer.dart';

/// Header facts about an image, in display (oriented) pixels.
class ImageMeta {
  const ImageMeta({
    required this.format,
    required this.width,
    required this.height,
    this.orientation = 1,
    this.hasAlpha = false,
    this.hasGps,
    this.animated = false,
  });

  final SniffedType format;
  final int width, height;
  final int orientation;
  final bool hasAlpha;
  final bool? hasGps;
  final bool animated;

  int get pixels => width * height;

  Map<String, Object?> toJson() => {
        'f': format.name,
        'w': width,
        'h': height,
        'o': orientation,
        'a': hasAlpha,
        'g': hasGps,
        'an': animated,
      };

  static ImageMeta fromJson(Map<String, dynamic> j) => ImageMeta(
        format: SniffedType.values.byName(j['f'] as String),
        width: j['w'] as int,
        height: j['h'] as int,
        orientation: j['o'] as int? ?? 1,
        hasAlpha: j['a'] as bool? ?? false,
        hasGps: j['g'] as bool?,
        animated: j['an'] as bool? ?? false,
      );
}

/// Facts about a PDF (pt sizes are post-/Rotate).
class PdfMeta {
  const PdfMeta({required this.pageCount, this.isEncrypted = false, this.pageSizes = const [], this.producer});
  final int pageCount;
  final bool isEncrypted;
  final List<(double, double)> pageSizes;
  final String? producer;

  Map<String, Object?> toJson() => {'p': pageCount, 'e': isEncrypted};
  static PdfMeta fromJson(Map<String, dynamic> j) =>
      PdfMeta(pageCount: j['p'] as int, isEncrypted: j['e'] as bool? ?? false);
}

enum ValidationLevel { ok, warning, invalid }

enum WarningCode { hasAlpha, animated, largeFile }

class ValidationStatus {
  const ValidationStatus.ok()
      : level = ValidationLevel.ok,
        error = null,
        warnings = const {};
  const ValidationStatus.warning(this.warnings)
      : level = ValidationLevel.warning,
        error = null;
  const ValidationStatus.invalid(AppErrorCode this.error)
      : level = ValidationLevel.invalid,
        warnings = const {};

  final ValidationLevel level;
  final AppErrorCode? error;
  final Set<WarningCode> warnings;

  bool get isValid => level != ValidationLevel.invalid;
}

/// Always a COPY inside a job's in/ dir (ADR-007). [displayName] is for the UI
/// and history only — never logged.
class PickedFile {
  const PickedFile({
    required this.path,
    required this.displayName,
    required this.type,
    required this.sizeBytes,
    this.image,
    this.pdf,
    this.status = const ValidationStatus.ok(),
  });

  final String path;
  final String displayName;
  final SniffedType type;
  final int sizeBytes;
  final ImageMeta? image;
  final PdfMeta? pdf;
  final ValidationStatus status;

  String get mime => type.mime;
  bool get isImage => type.isSupportedImage;
  bool get isPdf => type == SniffedType.pdf;

  /// Same name + size, for the "Added twice" hint.
  String get dedupeKey => '$displayName|$sizeBytes';

  Map<String, Object?> toJson() => {
        'path': path,
        'name': displayName,
        'type': type.name,
        'size': sizeBytes,
        if (image != null) 'img': image!.toJson(),
        if (pdf != null) 'pdf': pdf!.toJson(),
      };

  static PickedFile fromJson(Map<String, dynamic> j) => PickedFile(
        path: j['path'] as String,
        displayName: j['name'] as String,
        type: SniffedType.values.byName(j['type'] as String),
        sizeBytes: j['size'] as int,
        image: j['img'] == null ? null : ImageMeta.fromJson((j['img'] as Map).cast<String, dynamic>()),
        pdf: j['pdf'] == null ? null : PdfMeta.fromJson((j['pdf'] as Map).cast<String, dynamic>()),
      );
}
