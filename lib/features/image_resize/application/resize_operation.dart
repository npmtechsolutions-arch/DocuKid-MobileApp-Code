import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/resize_math.dart';
import '../../../core/operation/multi_output.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';

enum ResizeMode { pixels, percent, preset }

class ResizeOptions extends ToolOptions {
  const ResizeOptions({
    this.mode = ResizeMode.pixels,
    this.width,
    this.height,
    this.lockRatio = true,
    this.percent = 50,
    this.preset,
    this.presetWidth,
    this.presetHeight,
    this.fit = FitMode.stretch,
    this.pad = PadColor.white,
    this.format = OutputFormatChoice.same,
    this.quality = 90,
    this.stripMetadata = true,
    this.fitInside = true,
  });

  final ResizeMode mode;
  final int? width, height;
  final bool lockRatio;
  final int percent;

  /// Built-in preset name, or `custom:<name>`.
  final String? preset;
  final int? presetWidth, presetHeight;
  final FitMode fit;
  final PadColor pad;
  final OutputFormatChoice format;
  final int quality;
  final bool stripMetadata;

  /// Batch + Pixels: fit each image inside width×height keeping its ratio
  /// (FR-BAT-12, shrink only — ADR-062). Off → the exact box with [fit].
  final bool fitInside;

  ResizeOptions copyWith({
    ResizeMode? mode,
    int? Function()? width,
    int? Function()? height,
    bool? lockRatio,
    int? percent,
    String? Function()? preset,
    int? presetWidth,
    int? presetHeight,
    FitMode? fit,
    PadColor? pad,
    OutputFormatChoice? format,
    int? quality,
    bool? stripMetadata,
    bool? fitInside,
  }) =>
      ResizeOptions(
        mode: mode ?? this.mode,
        width: width == null ? this.width : width(),
        height: height == null ? this.height : height(),
        lockRatio: lockRatio ?? this.lockRatio,
        percent: percent ?? this.percent,
        preset: preset == null ? this.preset : preset(),
        presetWidth: presetWidth ?? this.presetWidth,
        presetHeight: presetHeight ?? this.presetHeight,
        fit: fit ?? this.fit,
        pad: pad ?? this.pad,
        format: format ?? this.format,
        quality: quality ?? this.quality,
        stripMetadata: stripMetadata ?? this.stripMetadata,
        fitInside: fitInside ?? this.fitInside,
      );

  /// Final (w, h) for an oriented original, or null if not set yet.
  (int, int)? dimsFor(int origW, int origH) => switch (mode) {
        ResizeMode.pixels => (width == null || height == null) ? null : (width!, height!),
        ResizeMode.percent => percentDims(percent, origW, origH),
        ResizeMode.preset => (presetWidth == null || presetHeight == null) ? null : (presetWidth!, presetHeight!),
      };

  @override
  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'w': width,
        'h': height,
        'lock': lockRatio,
        'pct': percent,
        'preset': preset,
        'pw': presetWidth,
        'ph': presetHeight,
        'fit': fit.name,
        'pad': pad.name,
        'format': format.name,
        'quality': quality,
        'strip': stripMetadata,
        'inside': fitInside,
      };

  static ResizeOptions fromJson(Map<String, dynamic> j, ResizeOptions d) => ResizeOptions(
        mode: enumByName(ResizeMode.values, j['mode'], d.mode),
        width: j['w'] as int?,
        height: j['h'] as int?,
        lockRatio: j['lock'] as bool? ?? d.lockRatio,
        percent: (j['pct'] as int?)?.clamp(1, 400) ?? d.percent,
        preset: j['preset'] as String?,
        presetWidth: j['pw'] as int?,
        presetHeight: j['ph'] as int?,
        fit: enumByName(FitMode.values, j['fit'], d.fit),
        pad: enumByName(PadColor.values, j['pad'], d.pad),
        format: enumByName(OutputFormatChoice.values, j['format'], d.format),
        quality: (j['quality'] as int?)?.clamp(10, 100) ?? d.quality,
        stripMetadata: j['strip'] as bool? ?? d.stripMetadata,
        fitInside: j['inside'] as bool? ?? d.fitInside,
      );

  /// Size and fit for one image of a batch (FR-BAT-12); null when unset.
  (int, int, FitMode)? batchTargetFor(int origW, int origH) {
    if (mode == ResizeMode.pixels && fitInside) {
      if (width == null || height == null) return null;
      final (w, h) = fitInsideDims(width!, height!, origW, origH);
      return (w, h, FitMode.stretch);
    }
    final d = dimsFor(origW, origH);
    return d == null ? null : (d.$1, d.$2, fit);
  }
}

class ResizeImageOperation implements ToolOperation<ResizeOptions> {
  ResizeImageOperation(this._engine, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final ImageEngine _engine;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.imageResize;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ResizeOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    final d = o.dimsFor(f.image!.width, f.image!.height);
    if (d == null || validateDims(d.$1, d.$2) != null) throw const AppError(AppErrorCode.invalidInput);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ResizeOptions o) {
    final f = inputs.single;
    final d = o.dimsFor(f.image!.width, f.image!.height)!;
    // Upscaled output can be much larger than the input: budget 4 B/px too.
    final pixels = d.$1 * d.$2 * 4;
    final base = estimateBytes(tool.name, f.sizeBytes);
    return base > pixels ? base : pixels;
  }

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, ResizeOptions o) async {
    final input = inputs.single;
    final (w, h) = o.dimsFor(input.image!.width, input.image!.height)!;
    ctx.report(const Indeterminate('stepResizing'));
    return resizeOneImage(_engine, input, o, w: w, h: h, fit: o.fit, dir: ctx.workDir, now: _now());
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ResizeOptions o) => validateResized(out);
}

/// One image → one resized copy of exactly [w]×[h] inside [dir]. The single
/// tool and every batch item run this same step (ADR-036); the engine call is
/// unchanged, so the ADR-034 mirror fix still applies (C-2).
Future<RawOutput> resizeOneImage(
  ImageEngine engine,
  PickedFile input,
  ResizeOptions o, {
  required int w,
  required int h,
  required FitMode fit,
  required Directory dir,
  required DateTime now,
}) async {
  final meta = input.image!;
  final format = resolveOutputFormat(o.format, input.type, heicSupported: engine.canEncode(ImageFormat.heic));
  final out = p.join(dir.path, 'out.${format.ext}');
  await engine.transform(
    input.path,
    out,
    ImageTransform(
      format: format,
      quality: o.quality,
      targetWidth: w,
      targetHeight: h,
      fit: ratioDiffers(w, h, meta.width, meta.height) ? fit : FitMode.stretch,
      pad: o.pad,
      stripMetadata: o.stripMetadata,
    ),
    meta: meta,
  );
  return RawOutput(
    path: out,
    suggestedName: defaultOutputName(NamingTool.imageResize,
        firstInputName: input.displayName, now: now, ext: format.ext, width: w, height: h),
    mime: format.mime,
    flags: {'format': format.name, 'quality': o.quality, 'w': w, 'h': h},
  );
}

/// Re-opens a resized image and checks its exact size (ARCHITECTURE §5.4).
Future<OutputMeta> validateResized(RawOutput out) async {
  final format = ImageFormat.values.byName(out.flags['format'] as String);
  final w = out.flags['w'] as int, h = out.flags['h'] as int;
  await validateImageOutput(out.path, format, width: w, height: h);
  return OutputMeta(bytes: await File(out.path).length(), width: w, height: h, flags: out.flags);
}

/// Batch Resize (RELEASE_V1_1 §2.2): 1–50 images, one set of options. Pixels
/// default to Fit inside (FR-BAT-12); presets keep their exact size with the
/// chosen fit; percent is per image. An image that can't be done fails alone.
class BatchResizeOperation implements MultiToolOperation<ResizeOptions> {
  BatchResizeOperation(this._engine, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final ImageEngine _engine;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.imageResize;
  @override
  String get itemStepKey => 'stepResizing';
  @override
  ProgressUnit get itemUnit => ProgressUnit.images;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ResizeOptions o) async {
    if (inputs.isEmpty) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    if (inputs.length > Limits.batchMaxImages) throw const AppError(AppErrorCode.tooManyFiles, count: Limits.batchMaxImages);
    if (!inputs.any((f) => f.status.isValid)) {
      final first = inputs.first;
      throw AppError(first.status.error ?? AppErrorCode.unsupportedFormat, fileDisplayName: first.displayName);
    }
    // The box (pixels) or the preset must be set and in range; percent is checked per image.
    final box = switch (o.mode) {
      ResizeMode.pixels => (o.width, o.height),
      ResizeMode.preset => (o.presetWidth, o.presetHeight),
      ResizeMode.percent => (1, 1),
    };
    if (validateDims(box.$1, box.$2) != null) throw const AppError(AppErrorCode.invalidInput);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ResizeOptions o) {
    var total = 0;
    for (final f in inputs.where((f) => f.status.isValid)) {
      final t = o.batchTargetFor(f.image!.width, f.image!.height);
      final pixels = t == null ? 0 : t.$1 * t.$2 * 4;
      final base = estimateBytes(tool.name, f.sizeBytes);
      total += base > pixels ? base : pixels;
    }
    return total;
  }

  @override
  int itemCount(List<PickedFile> inputs, ResizeOptions o) => inputs.length;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, ResizeOptions o) async {
    final input = inputs[i];
    if (!input.status.isValid) {
      throw AppError(input.status.error ?? AppErrorCode.unsupportedFormat, fileDisplayName: input.displayName);
    }
    final t = o.batchTargetFor(input.image!.width, input.image!.height);
    if (t == null || validateDims(t.$1, t.$2) != null) {
      throw AppError(AppErrorCode.invalidInput, fileDisplayName: input.displayName);
    }
    final dir = Directory(p.join(ctx.workDir.path, 'item_$i'));
    await dir.create();
    return resizeOneImage(_engine, input, o, w: t.$1, h: t.$2, fit: t.$3, dir: dir, now: _now());
  }

  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, ResizeOptions o) => validateResized(out);
}
