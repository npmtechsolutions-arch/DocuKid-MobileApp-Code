import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/resize_math.dart';
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
      );
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
    final meta = input.image!;
    final (w, h) = o.dimsFor(meta.width, meta.height)!;
    final format = resolveOutputFormat(o.format, input.type, heicSupported: _engine.canEncode(ImageFormat.heic));
    ctx.report(const Indeterminate('stepResizing'));
    final out = p.join(ctx.workDir.path, 'out.${format.ext}');
    await _engine.transform(
      input.path,
      out,
      ImageTransform(
        format: format,
        quality: o.quality,
        targetWidth: w,
        targetHeight: h,
        fit: ratioDiffers(w, h, meta.width, meta.height) ? o.fit : FitMode.stretch,
        pad: o.pad,
        stripMetadata: o.stripMetadata,
      ),
      meta: meta,
    );
    return RawOutput(
      path: out,
      suggestedName: defaultOutputName(NamingTool.imageResize,
          firstInputName: input.displayName, now: _now(), ext: format.ext, width: w, height: h),
      mime: format.mime,
      flags: {'format': format.name, 'quality': o.quality, 'w': w, 'h': h},
    );
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ResizeOptions o) async {
    final format = ImageFormat.values.byName(out.flags['format'] as String);
    final w = out.flags['w'] as int, h = out.flags['h'] as int;
    await validateImageOutput(out.path, format, width: w, height: h);
    return OutputMeta(bytes: await File(out.path).length(), width: w, height: h, flags: out.flags);
  }
}
