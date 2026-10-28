import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/operation/multi_output.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/image_to_pdf_builder.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/providers.dart';
import '../../../core/scan/scan_options.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';
import 'scan_controller.dart';

/// The Images to PDF settings for a scan (RELEASE_V1_2 §4.4): no margins
/// (scans are already cropped), fit, the page's own orientation; Fit to scan
/// is the scan's own size at 200 dpi.
ImageToPdfSettings scanPdfSettings(ScanOptions o) => ImageToPdfSettings(
      size: switch (o.pageSize) {
        ScanPageSize.a4 => PdfPageSize.a4,
        ScanPageSize.letter => PdfPageSize.letter,
        ScanPageSize.fitToScan => PdfPageSize.image,
      },
      orientation: PdfOrientation.auto,
      fit: PdfFit.fit,
      margin: PdfMargin.none,
      quality: _quality(o),
      imageDpi: 200,
      savingStepKey: 'stepSavingScan',
    );

PdfImageQuality _quality(ScanOptions o) => o.quality == ScanQuality.high ? PdfImageQuality.high : PdfImageQuality.compact;

/// 1–50 pages, each one decodes (§4.4).
void _validatePages(List<PickedFile> inputs) {
  if (inputs.isEmpty) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
  if (inputs.length > ScanController.maxPages) {
    throw const AppError(AppErrorCode.tooManyFiles, count: ScanController.maxPages);
  }
  for (final f in inputs) {
    if (!f.status.isValid || f.image == null) {
      throw AppError(f.status.error ?? AppErrorCode.corruptFile, fileDisplayName: f.displayName);
    }
  }
}

int _estimate(List<PickedFile> inputs) =>
    estimateBytes(ToolId.scanDocument.name, inputs.fold(0, (s, f) => s + f.sizeBytes));

int _rotation(ScanOptions o, int i) => i < o.rotations.length ? o.rotations[i] : 0;

/// Save as PDF (S11 result). `makeSearchable` is a 1.3 hook and ignored here.
class ScanPdfOperation implements ToolOperation<ScanOptions> {
  ScanPdfOperation(this._images, this._pdf, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final ImageEngine _images;
  final PdfEngine _pdf;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.scanDocument;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ScanOptions o) async => _validatePages(inputs);

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ScanOptions o) => _estimate(inputs);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, ScanOptions o) async {
    final items = [for (var i = 0; i < inputs.length; i++) ImageToPdfItem(inputs[i], _rotation(o, i))];
    final path = await ImageToPdfBuilder(_images, _pdf).build(items, scanPdfSettings(o), ctx);
    return RawOutput(
      path: path,
      suggestedName: '${o.baseName ?? defaultScanBaseName(_now())}.pdf',
      mime: 'application/pdf',
      flags: {'expectedPages': inputs.length},
    );
  }

  /// FR-SCN-17: page count == pages, first page renders.
  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ScanOptions o) async {
    final pages = await validatePdfOutput(_pdf, out.path, expectedPages: inputs.length);
    return OutputMeta(bytes: await File(out.path).length(), pages: pages, flags: {'quality': o.quality.name});
  }
}

/// Save as JPG images: one file per page (S22 result, ZIP offered — 1.1).
class ScanJpgOperation implements MultiToolOperation<ScanOptions> {
  ScanJpgOperation(this._images, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final ImageEngine _images;
  final DateTime Function() _now;

  /// Fixed when the job starts, so every page shares one name.
  String? _base;

  @override
  ToolId get tool => ToolId.scanDocument;
  @override
  String get itemStepKey => 'stepSavingScan';
  @override
  ProgressUnit get itemUnit => ProgressUnit.images;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ScanOptions o) async => _validatePages(inputs);

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ScanOptions o) => _estimate(inputs);

  @override
  int itemCount(List<PickedFile> inputs, ScanOptions o) => inputs.length;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, ScanOptions o) async {
    final page = inputs[i];
    final meta = page.image;
    if (!page.status.isValid || meta == null) {
      throw AppError(page.status.error ?? AppErrorCode.corruptFile, fileDisplayName: page.displayName);
    }
    final q = _quality(o);
    // FR-SCN-15: the dpi cap at A4's long edge; never enlarges.
    final cap = (PdfPageSize.a4.heightPt / 72 * q.dpiCap).round();
    final dir = Directory(p.join(ctx.workDir.path, 'item_$i'));
    await dir.create();
    final encoded = await _images.transform(
      page.path,
      p.join(dir.path, 'page.jpg'),
      ImageTransform(
        format: ImageFormat.jpeg,
        quality: q.jpegQuality,
        maxLongEdge: math.min(cap, math.max(meta.width, meta.height)),
        extraRotation: _rotation(o, i) * 90,
        stripMetadata: true,
      ),
      meta: meta,
    );
    final base = _base ??= o.baseName ?? defaultScanBaseName(_now());
    return RawOutput(
      path: encoded.path,
      suggestedName: scanJpgName(base, i),
      mime: ImageFormat.jpeg.mime,
      flags: {'w': encoded.width, 'h': encoded.height, 'quality': q.jpegQuality},
    );
  }

  /// FR-SCN-17: each file decodes at the size written.
  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, ScanOptions o) async {
    final w = out.flags['w'] as int, h = out.flags['h'] as int;
    await validateImageOutput(out.path, ImageFormat.jpeg, width: w, height: h);
    return OutputMeta(bytes: await File(out.path).length(), width: w, height: h, flags: out.flags);
  }

  @override
  Future<void> close() async {}
}

final scanPdfOperationProvider = Provider<ScanPdfOperation>((ref) => ScanPdfOperation(
      ref.watch(imageEngineProvider),
      ref.watch(pdfEngineProvider),
      clock: ref.watch(clockProvider),
    ));

/// A new instance per job: it keeps the job's base name.
ScanJpgOperation newScanJpgOperation(WidgetRef ref) =>
    ScanJpgOperation(ref.read(imageEngineProvider), clock: ref.read(clockProvider));
