import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/operation/multi_output.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';

/// Convert Image options (RELEASE_V1_1 §2.3). Never resizes (FR-CNV-07).
class ConvertOptions extends ToolOptions {
  const ConvertOptions({this.format = ImageFormat.jpeg, this.quality = 90, this.stripMetadata = true});

  final ImageFormat format;

  /// JPG / WebP / HEIC only; PNG is lossless (FR-CNV-03).
  final int quality;
  final bool stripMetadata;

  bool get hasQuality => format != ImageFormat.png;

  ConvertOptions copyWith({ImageFormat? format, int? quality, bool? stripMetadata}) => ConvertOptions(
        format: format ?? this.format,
        quality: quality ?? this.quality,
        stripMetadata: stripMetadata ?? this.stripMetadata,
      );

  @override
  Map<String, Object?> toJson() => {'format': format.name, 'quality': quality, 'strip': stripMetadata};

  static ConvertOptions fromJson(Map<String, dynamic> j, ConvertOptions d) => ConvertOptions(
        format: enumByName(ImageFormat.values, j['format'], d.format),
        quality: (j['quality'] as int?)?.clamp(10, 100) ?? d.quality,
        stripMetadata: j['strip'] as bool? ?? d.stripMetadata,
      );
}

/// FR-CNV-02: the output formats this device can encode (HEIC: iOS only).
List<ImageFormat> convertFormats(ImageEngine engine) => [for (final f in ImageFormat.values) if (engine.canEncode(f)) f];

/// FR-CNV-04: a transparent input going to a format without alpha.
bool alphaWillBeLost(List<PickedFile> files, ImageFormat to) =>
    !to.supportsAlpha && files.any((f) => f.status.isValid && f.image?.hasAlpha == true);

/// FR-CNV-06: how many valid inputs are already in [to] (they're re-saved).
int sameFormatCount(List<PickedFile> files, ImageFormat to) =>
    files.where((f) => f.status.isValid && f.type == to.sniffed).length;

/// One image → the same picture in another format, same size, inside [dir].
/// Name: the original base name with the new extension (IMG_1234.heic →
/// IMG_1234.jpg). The single tool and every batch item run this (ADR-036).
Future<RawOutput> convertOneImage(ImageEngine engine, PickedFile input, ConvertOptions o, {required Directory dir}) async {
  final meta = input.image!;
  final out = p.join(dir.path, 'out.${o.format.ext}');
  await engine.transform(
    input.path,
    out,
    // No target size: the engine keeps the oriented size; alpha → JPG is
    // composited onto white by the engine.
    ImageTransform(format: o.format, quality: o.quality, stripMetadata: o.stripMetadata),
    meta: meta,
  );
  return RawOutput(
    path: out,
    suggestedName: withExtension(safeBaseName(input.displayName), o.format.ext),
    mime: o.format.mime,
    flags: {'format': o.format.name, 'quality': o.quality, 'w': meta.width, 'h': meta.height},
  );
}

/// Re-opens the output: right format and exactly the input's size (FR-CNV-07).
Future<OutputMeta> validateConverted(RawOutput out) async {
  final format = ImageFormat.values.byName(out.flags['format'] as String);
  final w = out.flags['w'] as int, h = out.flags['h'] as int;
  await validateImageOutput(out.path, format, width: w, height: h);
  return OutputMeta(bytes: await File(out.path).length(), width: w, height: h, flags: out.flags);
}

/// One image (S11 result).
class ConvertImageOperation implements ToolOperation<ConvertOptions> {
  ConvertImageOperation(this._engine);
  final ImageEngine _engine;

  @override
  ToolId get tool => ToolId.imageConvert;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ConvertOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    if (!_engine.canEncode(o.format)) throw const AppError(AppErrorCode.unsupportedFormat);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ConvertOptions o) => _estimate(inputs);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, ConvertOptions o) async {
    ctx.report(const Indeterminate('stepConverting'));
    return convertOneImage(_engine, inputs.single, o, dir: ctx.workDir);
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ConvertOptions o) => validateConverted(out);
}

/// 2–50 images (S22 result). Invalid images fail alone (FR-BAT-05).
class BatchConvertOperation implements MultiToolOperation<ConvertOptions> {
  BatchConvertOperation(this._engine);
  final ImageEngine _engine;

  @override
  ToolId get tool => ToolId.imageConvert;
  @override
  String get itemStepKey => 'stepConverting';
  @override
  ProgressUnit get itemUnit => ProgressUnit.images;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ConvertOptions o) async {
    if (inputs.isEmpty) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    if (inputs.length > Limits.batchMaxImages) throw const AppError(AppErrorCode.tooManyFiles, count: Limits.batchMaxImages);
    if (!inputs.any((f) => f.status.isValid)) {
      final first = inputs.first;
      throw AppError(first.status.error ?? AppErrorCode.unsupportedFormat, fileDisplayName: first.displayName);
    }
    if (!_engine.canEncode(o.format)) throw const AppError(AppErrorCode.unsupportedFormat);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ConvertOptions o) => _estimate(inputs);

  @override
  int itemCount(List<PickedFile> inputs, ConvertOptions o) => inputs.length;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, ConvertOptions o) async {
    final input = inputs[i];
    if (!input.status.isValid) {
      throw AppError(input.status.error ?? AppErrorCode.unsupportedFormat, fileDisplayName: input.displayName);
    }
    final dir = Directory(p.join(ctx.workDir.path, 'item_$i'));
    await dir.create();
    return convertOneImage(_engine, input, o, dir: dir);
  }

  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, ConvertOptions o) => validateConverted(out);

  @override
  Future<void> close() async {}
}

/// PNG of a photo can be several times the JPEG: budget 4 B/px per image.
int _estimate(List<PickedFile> inputs) {
  var total = 0;
  for (final f in inputs.where((f) => f.status.isValid)) {
    final px = (f.image?.width ?? 0) * (f.image?.height ?? 0) * 4;
    final base = estimateBytes(ToolId.imageConvert.name, f.sizeBytes);
    total += base > px ? base : px;
  }
  return total;
}
