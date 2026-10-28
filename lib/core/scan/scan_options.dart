import '../files/file_naming.dart';
import '../operation/tool_operation.dart';
import '../pdf/pdf_options.dart';

enum ScanOutputFormat { pdf, jpg }

/// `fitToScan`: each page takes the scan's own aspect at 200 dpi (FR-SCN-14).
enum ScanPageSize { a4, letter, fitToScan }

/// High: JPEG q85, ≤ 200 dpi at page size; Compact: q65, ≤ 150 dpi (FR-SCN-15).
enum ScanQuality { high, compact }

/// S29 review options that drive the scan job (RELEASE_V1_2 §4.2).
class ScanOptions extends ToolOptions {
  const ScanOptions({
    this.format = ScanOutputFormat.pdf,
    this.pageSize = ScanPageSize.a4,
    this.quality = ScanQuality.high,
    this.baseName,
    this.makeSearchable = false,
    this.rotations = const [],
  });

  final ScanOutputFormat format;
  final ScanPageSize pageSize;
  final ScanQuality quality;

  /// User-edited name without extension (D3); null = `Scan_<stamp>`.
  final String? baseName;

  /// 1.3 hook (OCR); always false in 1.2 (ADR-043).
  final bool makeSearchable;

  /// Per-page extra quarter turns, in page order (not kept in history).
  final List<int> rotations;

  /// The name shown on S29: the PDF, or the first JPG.
  String displayName(DateTime now) {
    final base = baseName ?? defaultScanBaseName(now);
    return format == ScanOutputFormat.pdf ? '$base.pdf' : scanJpgName(base, 0);
  }

  ScanOptions copyWith({
    ScanOutputFormat? format,
    ScanPageSize? pageSize,
    ScanQuality? quality,
    String? Function()? baseName,
    List<int>? rotations,
  }) =>
      ScanOptions(
        format: format ?? this.format,
        pageSize: pageSize ?? this.pageSize,
        quality: quality ?? this.quality,
        baseName: baseName == null ? this.baseName : baseName(),
        makeSearchable: makeSearchable,
        rotations: rotations ?? this.rotations,
      );

  /// History `optionsJson` (§5): no page or file names.
  @override
  Map<String, Object?> toJson() => {'format': format.name, 'pageSize': pageSize.name, 'quality': quality.name};

  static ScanOptions fromJson(Map<String, dynamic> j, ScanOptions d) => ScanOptions(
        format: enumByName(ScanOutputFormat.values, j['format'], d.format),
        pageSize: enumByName(ScanPageSize.values, j['pageSize'], d.pageSize),
        quality: enumByName(ScanQuality.values, j['quality'], d.quality),
      );
}
