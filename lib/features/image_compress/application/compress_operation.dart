import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/target_size_search.dart';
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
    final input = inputs.single;
    final meta = input.image!;
    final format = compressFormatFor(o, input, _engine);
    final name = defaultOutputName(NamingTool.imageCompress, firstInputName: input.displayName, now: _now(), ext: format.ext);
    ctx.report(const Indeterminate('stepCompressing'));

    if (o.mode == CompressMode.quality) {
      final out = p.join(ctx.workDir.path, 'out.${format.ext}');
      await _engine.transform(
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
      checkCancelled: ctx.cancel.throwIfCancelled,
      encode: (q, scale, attempt) async {
        final out = p.join(ctx.workDir.path, 'try_$attempt.${format.ext}');
        final r = await _engine.transform(
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
    await for (final e in ctx.workDir.list()) {
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

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, CompressOptions o) async {
    final format = ImageFormat.values.byName(out.flags['format'] as String);
    final h = await validateImageOutput(out.path, format);
    return OutputMeta(
      bytes: await File(out.path).length(),
      width: h.displayWidth,
      height: h.displayHeight,
      flags: out.flags,
    );
  }
}
