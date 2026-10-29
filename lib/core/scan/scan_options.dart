import '../files/file_naming.dart';
import '../ocr/text_recognizer.dart';
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
    this.ocrScript = OcrScript.latin,
    this.rotations = const [],
  });

  final ScanOutputFormat format;
  final ScanPageSize pageSize;
  final ScanQuality quality;

  /// User-edited name without extension (D3); null = `Scan_<stamp>`.
  final String? baseName;

  /// "Make searchable (recognise text)" (FR-OCR-13): PDF output only.
  final bool makeSearchable;

  /// The text language when [makeSearchable] is on.
  final OcrScript ocrScript;

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
    bool? makeSearchable,
    OcrScript? ocrScript,
    List<int>? rotations,
  }) =>
      ScanOptions(
        format: format ?? this.format,
        pageSize: pageSize ?? this.pageSize,
        quality: quality ?? this.quality,
        baseName: baseName == null ? this.baseName : baseName(),
        makeSearchable: makeSearchable ?? this.makeSearchable,
        ocrScript: ocrScript ?? this.ocrScript,
        rotations: rotations ?? this.rotations,
      );

  /// The scan really becomes searchable: the switch is on and the output is PDF.
  bool get searchable => makeSearchable && format == ScanOutputFormat.pdf;

  /// History `optionsJson` (§5): no page or file names, never text; the
  /// OCR choice only when it's on (1.2 rows read the same).
  @override
  Map<String, Object?> toJson() => {
        'format': format.name,
        'pageSize': pageSize.name,
        'quality': quality.name,
        if (makeSearchable) ...{'searchable': true, 'script': ocrScript.name},
      };

  static ScanOptions fromJson(Map<String, dynamic> j, ScanOptions d) => ScanOptions(
        format: enumByName(ScanOutputFormat.values, j['format'], d.format),
        pageSize: enumByName(ScanPageSize.values, j['pageSize'], d.pageSize),
        quality: enumByName(ScanQuality.values, j['quality'], d.quality),
        makeSearchable: j['searchable'] as bool? ?? d.makeSearchable,
        ocrScript: enumByName(OcrScript.values, j['script'], d.ocrScript),
      );
}
