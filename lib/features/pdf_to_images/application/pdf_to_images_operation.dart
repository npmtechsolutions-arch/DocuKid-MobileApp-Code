import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/page_image_encoder.dart';
import '../../../core/operation/multi_output.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/page_ranges.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';

/// PDF to Images options (RELEASE_V1_1 §2.5).
class PdfToImagesOptions extends ToolOptions {
  const PdfToImagesOptions({
    this.allPages = true,
    this.ranges = '',
    this.format = ImageFormat.jpeg,
    this.quality = 90,
    this.dpi = 150,
    this.keepTransparent = false,
  });

  final bool allPages;

  /// "Choose pages" text, §4.6 grammar (union of parts, document order).
  final String ranges;

  /// JPG (default) or PNG (FR-P2I-03).
  final ImageFormat format;
  final int quality;

  /// 72 / 150 / 300 (FR-P2I-04).
  final int dpi;

  /// PNG only (FR-P2I-07).
  final bool keepTransparent;

  bool get transparent => format == ImageFormat.png && keepTransparent;

  PdfToImagesOptions copyWith({bool? allPages, String? ranges, ImageFormat? format, int? quality, int? dpi, bool? keepTransparent}) =>
      PdfToImagesOptions(
        allPages: allPages ?? this.allPages,
        ranges: ranges ?? this.ranges,
        format: format ?? this.format,
        quality: quality ?? this.quality,
        dpi: dpi ?? this.dpi,
        keepTransparent: keepTransparent ?? this.keepTransparent,
      );

  @override
  Map<String, Object?> toJson() => {
        'all': allPages,
        'ranges': ranges,
        'format': format.name,
        'quality': quality,
        'dpi': dpi,
        'alpha': keepTransparent,
      };

  static PdfToImagesOptions fromJson(Map<String, dynamic> j, PdfToImagesOptions d) => PdfToImagesOptions(
        allPages: j['all'] as bool? ?? d.allPages,
        ranges: j['ranges'] as String? ?? d.ranges,
        format: enumByName(ImageFormat.values, j['format'], d.format) == ImageFormat.png ? ImageFormat.png : ImageFormat.jpeg,
        quality: (j['quality'] as int?)?.clamp(10, 100) ?? d.quality,
        dpi: const [72, 150, 300].contains(j['dpi']) ? j['dpi'] as int : d.dpi,
        keepTransparent: j['alpha'] as bool? ?? d.keepTransparent,
      );
}

/// FR-P2I-04: no page renders above this (memory, FR-P2I-05).
const maxPagePixels = 40000000;

/// Page size in pt → pixels at [dpi] (pt × dpi / 72), scaled down to
/// [maxPagePixels] keeping the ratio. Returns (width, height, capped).
(int, int, bool) pagePixelSize(double widthPt, double heightPt, int dpi) {
  var w = widthPt * dpi / 72, h = heightPt * dpi / 72;
  final capped = w * h > maxPagePixels;
  if (capped) {
    final s = math.sqrt(maxPagePixels / (w * h));
    w *= s;
    h *= s;
  }
  int px(double v) => math.max(1, capped ? v.floor() : v.round());
  return (px(w), px(h), capped);
}

/// The pages to export (1-based, document order), or the range error.
({List<int>? pages, PageRangeError? error}) selectedPages(PdfToImagesOptions o, int pageCount,
    {Set<String> endWords = const {'end'}}) {
  if (o.allPages) return (pages: [for (var i = 1; i <= pageCount; i++) i], error: null);
  final r = parsePageRanges(o.ranges, pageCount, endWords: endWords);
  return r.error != null ? (pages: null, error: r.error) : (pages: pageUnion(r.parts!), error: null);
}

/// FR-P2I-06: `<base>_page007.jpg`, padded to the page-count digits (min 2).
String pageImageName(String inputName, int page, int pageCount, ImageFormat format) {
  final width = math.max(2, '$pageCount'.length);
  return withExtension('${safeBaseName(inputName)}_page${'$page'.padLeft(width, '0')}', format.ext);
}

/// PDF to Images: one image per chosen page (S22). One page is rendered,
/// encoded and released at a time; the source stays open across pages.
class PdfToImagesOperation implements MultiToolOperation<PdfToImagesOptions> {
  PdfToImagesOperation(this._engine, this._encoder, {this.endWords = const {'end'}});
  final PdfEngine _engine;
  final PageImageEncoder _encoder;
  final Set<String> endWords;
  PdfPageExtractor? _src;

  @override
  ToolId get tool => ToolId.pdfToImages;
  @override
  String get itemStepKey => 'stepSavingPages';
  @override
  ProgressUnit get itemUnit => ProgressUnit.pages;

  List<int> _pages(List<PickedFile> inputs, PdfToImagesOptions o) =>
      selectedPages(o, inputs.single.pdf?.pageCount ?? 0, endWords: endWords).pages ?? const [];

  (int, int, bool) _size(PickedFile f, int page, PdfToImagesOptions o) {
    final (w, h) = f.pdf!.pageSizes[page - 1];
    return pagePixelSize(w, h, o.dpi);
  }

  @override
  Future<void> validateInputs(List<PickedFile> inputs, PdfToImagesOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    // FR-P2I-01: encrypted / corrupt as everywhere else.
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    final meta = f.pdf;
    if (meta == null || meta.pageSizes.length != meta.pageCount) throw const AppError(AppErrorCode.corruptFile);
    if (_pages(inputs, o).isEmpty) throw const AppError(AppErrorCode.invalidInput);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, PdfToImagesOptions o) {
    // JPG ≈ 1 B/px at most; PNG of a rendered page can reach ~3 B/px.
    final perPx = o.format == ImageFormat.png ? 3 : 1;
    return _pages(inputs, o).fold(0, (s, pg) {
      final (w, h, _) = _size(inputs.single, pg, o);
      return s + w * h * perPx;
    });
  }

  @override
  int itemCount(List<PickedFile> inputs, PdfToImagesOptions o) => _pages(inputs, o).length;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, PdfToImagesOptions o) async {
    final input = inputs.single;
    final page = _pages(inputs, o)[i];
    final (w, h, capped) = _size(input, page, o);
    final src = _src ??= await _engine.openExtractor(input.path);
    final out = p.join(ctx.workDir.path, 'page_$page.${o.format.ext}');
    final px = await src.renderPage(page - 1, width: w, height: h, transparent: o.transparent);
    await _encoder.encode(px, out, format: o.format, quality: o.quality, keepAlpha: o.transparent);
    return RawOutput(
      path: out,
      suggestedName: pageImageName(input.displayName, page, input.pdf!.pageCount, o.format),
      mime: o.format.mime,
      flags: {'format': o.format.name, 'w': w, 'h': h, 'page': page, if (capped) 'capped': true},
    );
  }

  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, PdfToImagesOptions o) async {
    final format = ImageFormat.values.byName(out.flags['format'] as String);
    final w = out.flags['w'] as int, h = out.flags['h'] as int;
    await validateImageOutput(out.path, format, width: w, height: h);
    return OutputMeta(bytes: await File(out.path).length(), width: w, height: h, flags: out.flags);
  }

  @override
  Future<void> close() async {
    final src = _src;
    _src = null;
    await src?.close();
  }
}
