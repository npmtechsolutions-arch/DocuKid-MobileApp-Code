import 'dart:io';

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/image_to_pdf_builder.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';

class ImageToPdfOptions extends ToolOptions {
  const ImageToPdfOptions({
    this.size = PdfPageSize.a4,
    this.orientation = PdfOrientation.auto,
    this.fit = PdfFit.fit,
    this.margin = PdfMargin.small,
    this.quality = PdfImageQuality.high,
    this.outputName,
    this.rotations = const [],
  });

  final PdfPageSize size;
  final PdfOrientation orientation;
  final PdfFit fit;
  final PdfMargin margin;
  final PdfImageQuality quality;

  /// User-edited name (D3); null = the default `Images_<stamp>.pdf`.
  final String? outputName;

  /// Per-input extra quarter turns, in input order (not persisted in history).
  final List<int> rotations;

  ImageToPdfOptions copyWith({
    PdfPageSize? size,
    PdfOrientation? orientation,
    PdfFit? fit,
    PdfMargin? margin,
    PdfImageQuality? quality,
    String? Function()? outputName,
    List<int>? rotations,
  }) =>
      ImageToPdfOptions(
        size: size ?? this.size,
        orientation: orientation ?? this.orientation,
        fit: fit ?? this.fit,
        margin: margin ?? this.margin,
        quality: quality ?? this.quality,
        outputName: outputName == null ? this.outputName : outputName(),
        rotations: rotations ?? this.rotations,
      );

  @override
  Map<String, Object?> toJson() => {
        'size': size.name,
        'orientation': orientation.name,
        'fit': fit.name,
        'margin': margin.name,
        'quality': quality.name,
      };

  static ImageToPdfOptions fromJson(Map<String, dynamic> j, ImageToPdfOptions d) => ImageToPdfOptions(
        size: enumByName(PdfPageSize.values, j['size'], d.size),
        orientation: enumByName(PdfOrientation.values, j['orientation'], d.orientation),
        fit: enumByName(PdfFit.values, j['fit'], d.fit),
        margin: enumByName(PdfMargin.values, j['margin'], d.margin),
        quality: enumByName(PdfImageQuality.values, j['quality'], d.quality),
      );
}

class ImageToPdfOperation implements ToolOperation<ImageToPdfOptions> {
  ImageToPdfOperation(this._images, this._pdf, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final ImageEngine _images;
  final PdfEngine _pdf;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.imageToPdf;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ImageToPdfOptions o) async {
    if (inputs.isEmpty) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    if (inputs.length > Limits.imagesPerPdf) throw const AppError(AppErrorCode.tooManyFiles, count: Limits.imagesPerPdf);
    for (final f in inputs) {
      if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    }
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ImageToPdfOptions o) =>
      estimateBytes(tool.name, inputs.fold(0, (s, f) => s + f.sizeBytes));

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, ImageToPdfOptions o) async {
    final items = [
      for (var i = 0; i < inputs.length; i++) ImageToPdfItem(inputs[i], i < o.rotations.length ? o.rotations[i] : 0),
    ];
    final path = await ImageToPdfBuilder(_images, _pdf).build(
      items,
      ImageToPdfSettings(size: o.size, orientation: o.orientation, fit: o.fit, margin: o.margin, quality: o.quality),
      ctx,
    );
    return RawOutput(
      path: path,
      suggestedName: o.outputName ?? defaultOutputName(NamingTool.imageToPdf, now: _now()),
      mime: 'application/pdf',
      flags: {'expectedPages': inputs.length},
    );
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ImageToPdfOptions o) async {
    final pages = await validatePdfOutput(_pdf, out.path, expectedPages: inputs.length);
    return OutputMeta(bytes: await File(out.path).length(), pages: pages, flags: {'quality': o.quality.name});
  }
}
