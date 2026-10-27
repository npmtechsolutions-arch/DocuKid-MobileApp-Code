import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../errors/app_error.dart';
import '../files/mime_sniffer.dart';
import '../files/picked_file.dart';
import 'image_engine.dart';
import 'image_header.dart';
import 'image_options.dart';
import 'jpeg_exif_patch.dart';
import 'resize_math.dart';

/// Native coarse step (flutter_image_compress) + exact Dart step in an
/// isolate (FEATURE_SPECS §3.4).
///
/// Plugin semantics verified in the pinned 2.5.1 sources (DECISIONS ADR-019):
/// scale = max(1, min(w/minW, h/minH)), truncated, never upscales; min dims are
/// compared in EXIF-oriented space, *before* the extra `rotate`.
class NativeImageEngine implements ImageEngine {
  const NativeImageEngine();

  @override
  bool canEncode(ImageFormat format) => switch (format) {
        ImageFormat.heic => Platform.isIOS,
        _ => true,
      };

  @override
  Future<ImageMeta> inspect(String path) async {
    final type = await sniffFile(path);
    if (!type.isSupportedImage) throw const AppError(AppErrorCode.unsupportedFormat);
    try {
      final h = await readImageHeader(path);
      return ImageMeta(
        format: h.type,
        width: h.displayWidth,
        height: h.displayHeight,
        orientation: h.orientation,
        hasAlpha: h.hasAlpha,
        hasGps: h.hasGps,
        animated: h.animated,
      );
    } on ImageHeaderException {
      if (type != SniffedType.heic) throw const AppError(AppErrorCode.corruptFile);
      // Some HEIC layouts keep `meta` after `mdat`; let the platform codec read the header.
      return _inspectWithPlatformCodec(path, type);
    } on FileSystemException {
      throw const AppError(AppErrorCode.permissionLost);
    }
  }

  Future<ImageMeta> _inspectWithPlatformCodec(String path, SniffedType type) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      final d = await ui.ImageDescriptor.encoded(buffer);
      final meta = ImageMeta(format: type, width: d.width, height: d.height);
      d.dispose();
      buffer.dispose();
      return meta;
    } catch (_) {
      throw const AppError(AppErrorCode.corruptFile);
    }
  }

  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    final m = meta ?? await inspect(inPath);
    final rot = ((t.extraRotation % 360) + 360) % 360;
    final quarter = rot == 90 || rot == 270;
    final rw = quarter ? m.height : m.width;
    final rh = quarter ? m.width : m.height;

    late int tw, th;
    if (t.targetWidth != null && t.targetHeight != null) {
      tw = t.targetWidth!;
      th = t.targetHeight!;
    } else if (t.maxLongEdge != null && math.max(rw, rh) > t.maxLongEdge!) {
      final s = t.maxLongEdge! / math.max(rw, rh);
      tw = math.max(1, roundHalfUp(rw * s));
      th = math.max(1, roundHalfUp(rh * s));
    } else {
      tw = rw;
      th = rh;
    }

    final format = canEncode(t.format) ? t.format : ImageFormat.jpeg;
    final composite = m.hasAlpha && !format.supportsAlpha;
    final shapeChange = ratioDiffers(tw, th, rw, rh) && t.fit != FitMode.stretch;
    final keepAlpha = m.hasAlpha && format.supportsAlpha;
    final dir = p.dirname(outPath);
    final stem = p.basenameWithoutExtension(outPath);

    // Step A — native decode + orientation + coarse downscale.
    final directCandidate = !composite && !shapeChange && !(t.fit == FitMode.stretch && ratioDiffers(tw, th, rw, rh));
    final stepAFormat = directCandidate ? format : (keepAlpha || composite ? ImageFormat.png : ImageFormat.jpeg);
    final stepAPath = directCandidate ? outPath : p.join(dir, '${stem}_a.${stepAFormat.ext}');
    final keepExif = !t.stripMetadata && directCandidate && format == ImageFormat.jpeg;
    // Min dims in post-EXIF, pre-extra-rotation space.
    final minW = quarter ? th : tw;
    final minH = quarter ? tw : th;
    await _nativeEncode(
      inPath,
      stepAPath,
      minWidth: minW,
      minHeight: minH,
      quality: directCandidate ? t.quality : 98,
      rotate: rot,
      format: stepAFormat,
      keepExif: keepExif,
    );

    var header = await _header(stepAPath);
    if (directCandidate && header.width == tw && header.height == th) {
      if (keepExif) await _resetOrientation(outPath);
      return EncodedImage(path: outPath, bytes: await File(outPath).length(), width: tw, height: th, format: format);
    }

    // Step B — exact size / fit / alpha composite in an isolate on the
    // already-downsampled image.
    final job = _ExactJob(
      inPath: stepAPath,
      outPath: format == ImageFormat.jpeg || format == ImageFormat.png
          ? outPath
          : p.join(dir, '${stem}_b.png'),
      width: tw,
      height: th,
      fit: t.fit,
      pad: t.pad,
      composite: composite,
      encodeJpeg: format == ImageFormat.jpeg,
      quality: t.quality,
    );
    try {
      await Isolate.run(() => _exactResize(job));
    } on OutOfMemoryError {
      throw const AppError(AppErrorCode.outOfMemory);
    } catch (e) {
      if (e is AppError) rethrow;
      throw const AppError(AppErrorCode.processingFailed);
    }
    if (stepAPath != outPath) await _delete(stepAPath);

    // Step C — WebP/HEIC can only be encoded natively.
    if (job.outPath != outPath) {
      await _nativeEncode(job.outPath, outPath,
          minWidth: tw, minHeight: th, quality: t.quality, rotate: 0, format: format, keepExif: false, autoRotate: false);
      await _delete(job.outPath);
    }
    header = await _header(outPath);
    return EncodedImage(
      path: outPath,
      bytes: await File(outPath).length(),
      width: header.width,
      height: header.height,
      format: format,
    );
  }

  Future<void> _nativeEncode(
    String inPath,
    String outPath, {
    required int minWidth,
    required int minHeight,
    required int quality,
    required int rotate,
    required ImageFormat format,
    required bool keepExif,
    bool autoRotate = true,
  }) async {
    XFile? res;
    try {
      res = await FlutterImageCompress.compressAndGetFile(
        inPath,
        outPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality.clamp(1, 100),
        rotate: rotate,
        autoCorrectionAngle: autoRotate,
        format: switch (format) {
          ImageFormat.jpeg => CompressFormat.jpeg,
          ImageFormat.png => CompressFormat.png,
          ImageFormat.webp => CompressFormat.webp,
          ImageFormat.heic => CompressFormat.heic,
        },
        keepExif: keepExif,
      );
    } on UnsupportedError {
      throw const AppError(AppErrorCode.unsupportedFormat);
    } catch (_) {
      throw const AppError(AppErrorCode.processingFailed);
    }
    if (res == null || !await File(outPath).exists() || await File(outPath).length() == 0) {
      throw const AppError(AppErrorCode.processingFailed);
    }
  }

  Future<ImageHeader> _header(String path) async {
    try {
      return await readImageHeader(path);
    } on ImageHeaderException {
      throw const AppError(AppErrorCode.outputValidationFailed);
    }
  }

  Future<void> _resetOrientation(String path) async {
    final f = File(path);
    final bytes = await f.readAsBytes();
    if (resetJpegOrientation(bytes)) await f.writeAsBytes(bytes, flush: true);
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Work dir is deleted by the JobRunner anyway.
    }
  }
}

class _ExactJob {
  const _ExactJob({
    required this.inPath,
    required this.outPath,
    required this.width,
    required this.height,
    required this.fit,
    required this.pad,
    required this.composite,
    required this.encodeJpeg,
    required this.quality,
  });
  final String inPath, outPath;
  final int width, height;
  final FitMode fit;
  final PadColor pad;
  final bool composite, encodeJpeg;
  final int quality;
}

/// Runs inside [Isolate.run].
void _exactResize(_ExactJob j) {
  var src = img.decodeImage(File(j.inPath).readAsBytesSync());
  if (src == null) throw const AppError(AppErrorCode.corruptFile);
  if (src.hasPalette) src = src.convert(numChannels: 4);
  final rect = fitRect(j.fit, j.width, j.height, src.width, src.height);
  final scaled = (src.width == rect.width && src.height == rect.height)
      ? src
      : img.copyResize(src, width: rect.width, height: rect.height, interpolation: img.Interpolation.cubic);

  img.Image out;
  switch (j.fit) {
    case FitMode.stretch:
      out = scaled;
    case FitMode.cover:
      out = img.copyCrop(scaled, x: -rect.left, y: -rect.top, width: j.width, height: j.height);
    case FitMode.contain:
      final transparent = j.pad == PadColor.transparent && !j.composite && !j.encodeJpeg;
      out = img.Image(width: j.width, height: j.height, numChannels: transparent || scaled.numChannels == 4 ? 4 : 3);
      img.fill(out, color: switch (j.pad) {
        PadColor.black => img.ColorRgba8(0, 0, 0, 255),
        PadColor.transparent when transparent => img.ColorRgba8(0, 0, 0, 0),
        _ => img.ColorRgba8(255, 255, 255, 255),
      });
      img.compositeImage(out, scaled, dstX: rect.left, dstY: rect.top);
  }
  if ((j.composite || j.encodeJpeg) && out.numChannels == 4) {
    // Alpha → JPEG: composite onto white (FR-IMG-05).
    final white = img.Image(width: out.width, height: out.height, numChannels: 3);
    img.fill(white, color: img.ColorRgba8(255, 255, 255, 255));
    img.compositeImage(white, out);
    out = white;
  }
  final bytes = j.encodeJpeg ? img.encodeJpg(out, quality: j.quality) : img.encodePng(out, level: 6);
  File(j.outPath).writeAsBytesSync(bytes, flush: true);
}
