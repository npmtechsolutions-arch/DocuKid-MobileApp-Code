import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_stamper.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';
import 'placement.dart';

/// History keeps counts only — never paths (RELEASE_V1_4 §5.3).
class SignOptions extends ToolOptions {
  SignOptions(this.placements);
  final List<Placement> placements;

  @override
  Map<String, Object?> toJson() =>
      {'placements': placements.length, 'pages': placements.map((p) => p.pageIndex).toSet().length};
}

/// Whether [box] (visual points) on [page] of [path] has ink.
typedef StampCheck = Future<bool> Function(String path, int page, ui.Rect box, ui.Size pageSize);

/// S33/S35 · Sign PDF (RELEASE_V1_4 §4.8, FR-SIG-09, 12): the placements as
/// stamps on a new file (ADR-048).
class SignPdfOperation implements ToolOperation<SignOptions> {
  SignPdfOperation(this._stamper, {required this.validatePages, required this.stampVisible, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;
  final PdfStamper _stamper;
  final Future<int> Function(String path, int expectedPages) validatePages;
  final StampCheck stampVisible;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.pdfSign;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, SignOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    final pages = f.pdf?.pageCount ?? 0;
    if (o.placements.isEmpty || o.placements.any((p) => p.pageIndex < 0 || p.pageIndex >= pages)) {
      throw const AppError(AppErrorCode.invalidInput);
    }
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, SignOptions o) => estimateBytes(tool.name, inputs.single.sizeBytes);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, SignOptions o) async {
    final input = inputs.single;
    final out = p.join(ctx.workDir.path, 'signed.pdf');
    await _stamper.apply(
      input.path,
      [
        for (final pl in o.placements)
          Stamp(pageIndex: pl.pageIndex, pngPath: pl.pngPath, visualRect: pl.rect, rotationDegrees: pl.rotation),
      ],
      out,
      ctx,
    );
    return RawOutput(
      path: out,
      suggestedName: defaultOutputName(NamingTool.pdfSign, firstInputName: input.displayName, now: _now()),
      mime: 'application/pdf',
      flags: {'stamped': o.placements.map((p) => p.pageIndex).toSet().length},
    );
  }

  /// Opens with the same page count; the first stamped page, rendered at
  /// 72 dpi, isn't blank inside its first stamp's box (§4.8).
  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, SignOptions o) async {
    const invalid = AppError(AppErrorCode.outputValidationFailed);
    final input = inputs.single;
    final pages = await validatePages(out.path, input.pdf!.pageCount);
    if (pages != input.pdf!.pageCount) throw invalid;
    final first = o.placements.reduce((a, b) => b.pageIndex < a.pageIndex ? b : a);
    final sizes = input.pdf!.pageSizes;
    final size = first.pageIndex < sizes.length ? ui.Size(sizes[first.pageIndex].$1, sizes[first.pageIndex].$2) : ui.Size.zero;
    if (!await stampVisible(out.path, first.pageIndex, rotatedBounds(first.rect, first.rotation), size)) throw invalid;
    return OutputMeta(bytes: await File(out.path).length(), pages: pages, flags: out.flags);
  }
}

/// The axis-aligned box of [r] turned [degrees] clockwise about its centre.
ui.Rect rotatedBounds(ui.Rect r, double degrees) {
  final t = degrees * math.pi / 180, c = math.cos(t).abs(), s = math.sin(t).abs();
  return ui.Rect.fromCenter(center: r.center, width: r.width * c + r.height * s, height: r.width * s + r.height * c);
}

/// §4.8: non-background pixels > 0.5% of the box, at 72 dpi.
Future<bool> stampHasInk(PdfEngine engine, String path, int page, ui.Rect box, ui.Size pageSize) async {
  try {
    final width = pageSize.width > 0 ? pageSize.width.round() : 612;
    final im = await engine.renderPage(path, page, targetWidthPx: width);
    if (im == null) return false;
    try {
      final data = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return false;
      final k = pageSize.width > 0 ? im.width / pageSize.width : 1.0;
      final x0 = math.max(0, (box.left * k).floor()), y0 = math.max(0, (box.top * k).floor());
      final x1 = math.min(im.width, (box.right * k).ceil()), y1 = math.min(im.height, (box.bottom * k).ceil());
      if (x1 <= x0 || y1 <= y0) return false;
      var ink = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * im.width + x) * 4;
          if (data.getUint8(i) < 235 || data.getUint8(i + 1) < 235 || data.getUint8(i + 2) < 235) ink++;
        }
      }
      return ink > (x1 - x0) * (y1 - y0) * 0.005;
    } finally {
      im.dispose();
    }
  } finally {
    await engine.close(path);
  }
}

final signOperationProvider = Provider<SignPdfOperation>((ref) {
  final pdf = ref.watch(pdfEngineProvider);
  return SignPdfOperation(
    ref.watch(pdfStamperProvider),
    validatePages: (path, expected) => validatePdfOutput(pdf, path, expectedPages: expected),
    stampVisible: (path, page, box, size) => stampHasInk(pdf, path, page, box, size),
    clock: ref.watch(clockProvider),
  );
});
