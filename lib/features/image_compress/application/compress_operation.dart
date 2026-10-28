import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/target_size_search.dart';
import '../../../core/operation/multi_output.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';

enum CompressMode { quality, targetSize }

class CompressOptions extends ToolOptions {
  const CompressOptions({
    this.mode = CompressMode.quality,
    this.quality = 80,
    this.targetBytes = 100 * 1024,
    this.format = OutputFormatChoice.same,
    this.maxLongEdge,
    this.stripMetadata = true,
  });

  final CompressMode mode;
  final int quality;
  final int targetBytes;
  final OutputFormatChoice format;
  final int? maxLongEdge;
  final bool stripMetadata;

  CompressOptions copyWith({
    CompressMode? mode,
    int? quality,
    int? targetBytes,
    OutputFormatChoice? format,
    int? Function()? maxLongEdge,
    bool? stripMetadata,
  }) =>
      CompressOptions(
        mode: mode ?? this.mode,
        quality: quality ?? this.quality,
        targetBytes: targetBytes ?? this.targetBytes,
        format: format ?? this.format,
        maxLongEdge: maxLongEdge == null ? this.maxLongEdge : maxLongEdge(),
        stripMetadata: stripMetadata ?? this.stripMetadata,
      );

  @override
  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'quality': quality,
        'targetBytes': targetBytes,
        'format': format.name,
        'maxLongEdge': maxLongEdge,
        'strip': stripMetadata,
      };

  static CompressOptions fromJson(Map<String, dynamic> j, CompressOptions d) => CompressOptions(
        mode: enumByName(CompressMode.values, j['mode'], d.mode),
        quality: (j['quality'] as int?)?.clamp(10, 100) ?? d.quality,
        targetBytes: (j['targetBytes'] as int?) ?? d.targetBytes,
        format: enumByName(OutputFormatChoice.values, j['format'], d.format),
        maxLongEdge: j['maxLongEdge'] as int?,
        stripMetadata: j['strip'] as bool? ?? d.stripMetadata,
      );
}

/// Resolves the actual output format (ADR-014 + target-size → JPEG).
ImageFormat compressFormatFor(CompressOptions o, PickedFile input, ImageEngine engine) {
  var f = resolveOutputFormat(o.format, input.type, heicSupported: engine.canEncode(ImageFormat.heic));
  if (o.mode == CompressMode.targetSize && (f == ImageFormat.png || f == ImageFormat.heic)) f = ImageFormat.jpeg;
  return f;
}

class CompressImageOperation implements ToolOperation<CompressOptions> {
  CompressImageOperation(this._engine, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final ImageEngine _engine;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.imageCompress;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, CompressOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    if (o.mode == CompressMode.targetSize && o.targetBytes < Limits.targetMinBytes) {
      throw const AppError(AppErrorCode.invalidInput);
    }
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, CompressOptions o) =>
      estimateBytes(tool.name, inputs.fold(0, (s, f) => s + f.sizeBytes));

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, CompressOptions o) async {
    ctx.report(const Indeterminate('stepCompressing'));
    return compressOneImage(_engine, inputs.single, o, dir: ctx.workDir, cancel: ctx.cancel, now: _now());
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, CompressOptions o) => validateCompressed(out);
}

/// One image → one compressed copy inside [dir] (which it may clear of its own
/// attempts). The single tool and every batch item run this same step
/// (ADR-036); the engine calls are unchanged, so the ADR-034 mirror fix in the
/// engine still applies (C-2).
Future<RawOutput> compressOneImage(
  ImageEngine engine,
  PickedFile input,
  CompressOptions o, {
  required Directory dir,
  required CancelToken cancel,
  required DateTime now,
}) async {
  final meta = input.image!;
  final format = compressFormatFor(o, input, engine);
  final name = defaultOutputName(NamingTool.imageCompress, firstInputName: input.displayName, now: now, ext: format.ext);

  if (o.mode == CompressMode.quality) {
    final out = p.join(dir.path, 'out.${format.ext}');
    await engine.transform(
      input.path,
      out,
      ImageTransform(format: format, quality: o.quality, maxLongEdge: o.maxLongEdge, stripMetadata: o.stripMetadata),
      meta: meta,
    );
    return RawOutput(path: out, suggestedName: name, mime: format.mime, flags: {'format': format.name, 'quality': o.quality});
  }

  final baseLong = math.min(o.maxLongEdge ?? 1 << 30, math.max(meta.width, meta.height));
  final result = await searchTargetSize(
    targetBytes: o.targetBytes,
    checkCancelled: cancel.throwIfCancelled,
    encode: (q, scale, attempt) async {
      final out = p.join(dir.path, 'try_$attempt.${format.ext}');
      final r = await engine.transform(
        input.path,
        out,
        ImageTransform(
          format: format,
          quality: q,
          maxLongEdge: math.max(1, (baseLong * scale).round()),
          stripMetadata: o.stripMetadata,
        ),
        meta: meta,
      );
      return EncodeAttempt(quality: q, scale: scale, bytes: r.bytes, path: out);
    },
  );
  // Keep only the chosen attempt.
  await for (final e in dir.list()) {
    if (e is File && e.path != result.best.path) await e.delete();
  }
  return RawOutput(
    path: result.best.path,
    suggestedName: name,
    mime: format.mime,
    flags: {
      'format': format.name,
      'quality': result.best.quality,
      'targetBytes': o.targetBytes,
      'targetMissed': result.targetMissed,
    },
  );
}

/// Re-opens a compressed image (ARCHITECTURE §5.4).
Future<OutputMeta> validateCompressed(RawOutput out) async {
  final format = ImageFormat.values.byName(out.flags['format'] as String);
  final h = await validateImageOutput(out.path, format);
  return OutputMeta(
    bytes: await File(out.path).length(),
    width: h.displayWidth,
    height: h.displayHeight,
    flags: out.flags,
  );
}

/// Batch Compress (RELEASE_V1_1 §2.2): 1–50 images, one set of options, one
/// output per image. Invalid images become failed items (they never stop the
/// batch, FR-BAT-05); target size is searched per image (FR-BAT-13).
class BatchCompressOperation implements MultiToolOperation<CompressOptions> {
  BatchCompressOperation(this._engine, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final ImageEngine _engine;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.imageCompress;
  @override
  String get itemStepKey => 'stepCompressing';
  @override
  ProgressUnit get itemUnit => ProgressUnit.images;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, CompressOptions o) async {
    if (inputs.isEmpty) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    if (inputs.length > Limits.batchMaxImages) throw const AppError(AppErrorCode.tooManyFiles, count: Limits.batchMaxImages);
    if (!inputs.any((f) => f.status.isValid)) {
      final first = inputs.first;
      throw AppError(first.status.error ?? AppErrorCode.unsupportedFormat, fileDisplayName: first.displayName);
    }
    if (o.mode == CompressMode.targetSize && o.targetBytes < Limits.targetMinBytes) {
      throw const AppError(AppErrorCode.invalidInput);
    }
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, CompressOptions o) =>
      estimateBytes(tool.name, inputs.where((f) => f.status.isValid).fold(0, (s, f) => s + f.sizeBytes));

  @override
  int itemCount(List<PickedFile> inputs, CompressOptions o) => inputs.length;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, CompressOptions o) async {
    final input = inputs[i];
    if (!input.status.isValid) {
      throw AppError(input.status.error ?? AppErrorCode.unsupportedFormat, fileDisplayName: input.displayName);
    }
    // Each item has its own folder: the step names its files out.* / try_*.
    final dir = Directory(p.join(ctx.workDir.path, 'item_$i'));
    await dir.create();
    return compressOneImage(_engine, input, o, dir: dir, cancel: ctx.cancel, now: _now());
  }

  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, CompressOptions o) => validateCompressed(out);

  @override
  Future<void> close() async {}
}
