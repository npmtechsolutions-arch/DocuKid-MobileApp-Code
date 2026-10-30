import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_stamper.dart';
import '../../../core/pdf/stamp_check.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';
import 'watermark_layout.dart';

/// One watermark run. [pngPath] is the text rendered to an image, or the
/// picked logo as PNG; [pages] are 0-based; [pageSizes] are visual sizes.
class WatermarkOptions extends ToolOptions {
  WatermarkOptions({
    required this.pngPath,
    required this.aspect,
    required this.image,
    required this.position,
    required this.sizePct,
    required this.opacityPct,
    required this.rotation,
    required this.pageMode,
    required this.pages,
    required this.pageSizes,
  });
  final String pngPath;
  final double aspect;
  final bool image;
  final WatermarkPosition position;
  final int sizePct, opacityPct;
  final double rotation;
  final PageMode pageMode;
  final List<int> pages;
  final List<ui.Size> pageSizes;

  /// The style only: never the text or the image's path (RELEASE_V1_4 §5.3).
  @override
  Map<String, Object?> toJson() => {
        'kind': image ? 'image' : 'text',
        'position': position.name,
        'size': sizePct,
        'opacity': opacityPct,
        'rotation': rotation,
        'pages': pageMode.name,
      };

  List<Stamp> stamps() => [
        for (final i in pages)
          for (final s in watermarkLayout(pageSizes[i], aspect, position: position, sizePct: sizePct, rotation: rotation))
            Stamp(pageIndex: i, pngPath: pngPath, visualRect: s.rect, rotationDegrees: s.rotation, opacity: opacityPct / 100),
      ];
}

/// FR-WMK-10: the last text watermark's look, in settings. Text only.
class WatermarkTextStyle {
  const WatermarkTextStyle({
    required this.text,
    required this.colour,
    required this.bold,
    required this.position,
    required this.sizePct,
    required this.opacityPct,
    required this.rotation,
  });
  final String text;
  final int colour;
  final bool bold;
  final WatermarkPosition position;
  final int sizePct, opacityPct;
  final double rotation;

  String toJson() => jsonEncode({
        'text': text,
        'colour': colour,
        'bold': bold,
        'position': position.name,
        'size': sizePct,
        'opacity': opacityPct,
        'rotation': rotation,
      });

  static WatermarkTextStyle? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return WatermarkTextStyle(
        text: String.fromCharCodes((j['text'] as String).runes.take(maxWatermarkChars)),
        colour: j['colour'] as int,
        bold: j['bold'] as bool,
        position: WatermarkPosition.values.firstWhere((v) => v.name == j['position'], orElse: () => WatermarkPosition.diagonal),
        sizePct: (j['size'] as num).toInt().clamp(minSizePct, maxSizePct),
        opacityPct: (j['opacity'] as num).toInt().clamp(minOpacityPct, maxOpacityPct),
        rotation: (j['rotation'] as num).toDouble().clamp(-90, 90),
      );
    } catch (_) {
      return null;
    }
  }
}

/// S36 · Watermark PDF (RELEASE_V1_4 §4.8, FR-WMK-09): on top of the pages,
/// one shared image per run (ADR-048).
class WatermarkPdfOperation implements ToolOperation<WatermarkOptions> {
  WatermarkPdfOperation(this._stamper, {required this.validatePages, required this.stampVisible, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;
  final PdfStamper _stamper;
  final Future<int> Function(String path, int expectedPages) validatePages;
  final Future<bool> Function(String path, int page, ui.Rect box, ui.Size pageSize) stampVisible;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.pdfWatermark;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, WatermarkOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    final n = f.pdf?.pageCount ?? 0;
    if (o.pages.isEmpty ||
        o.pages.any((i) => i < 0 || i >= n || i >= o.pageSizes.length) ||
        o.opacityPct < minOpacityPct ||
        o.opacityPct > maxOpacityPct) {
      throw const AppError(AppErrorCode.invalidInput);
    }
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, WatermarkOptions o) => estimateBytes(tool.name, inputs.single.sizeBytes);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, WatermarkOptions o) async {
    final input = inputs.single;
    final out = p.join(ctx.workDir.path, 'watermarked.pdf');
    await _stamper.apply(input.path, o.stamps(), out, ctx);
    return RawOutput(
      path: out,
      suggestedName: defaultOutputName(NamingTool.pdfWatermark, firstInputName: input.displayName, now: _now()),
      mime: 'application/pdf',
      flags: {'stamped': o.pages.length},
    );
  }

  /// Same pages; the first selected page shows the first stamp (§4.8).
  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, WatermarkOptions o) async {
    const invalid = AppError(AppErrorCode.outputValidationFailed);
    final n = inputs.single.pdf!.pageCount;
    final pages = await validatePages(out.path, n);
    if (pages != n) throw invalid;
    final first = o.pages.reduce((a, b) => a < b ? a : b);
    final s = o.stamps().firstWhere((s) => s.pageIndex == first);
    if (!await stampVisible(out.path, first, rotatedBounds(s.visualRect, s.rotationDegrees), o.pageSizes[first])) throw invalid;
    return OutputMeta(bytes: await File(out.path).length(), pages: pages, flags: out.flags);
  }
}

final watermarkOperationProvider = Provider<WatermarkPdfOperation>((ref) {
  final pdf = ref.watch(pdfEngineProvider);
  return WatermarkPdfOperation(
    ref.watch(pdfStamperProvider),
    validatePages: (path, expected) => validatePdfOutput(pdf, path, expectedPages: expected),
    // A light colour at 10% is barely off white (T11.8 decision).
    stampVisible: (path, page, box, size) => stampHasInk(pdf, path, page, box, size, threshold: 252),
    clock: ref.watch(clockProvider),
  );
});
