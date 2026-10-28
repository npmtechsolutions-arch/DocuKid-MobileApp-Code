import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../files/paths.dart';
import 'image_options.dart';

/// One rendered page: raw BGRA, top-down, [width] × [height].
class PagePixels {
  const PagePixels(this.bgra, this.width, this.height);
  final Uint8List bgra;
  final int width, height;
}

/// Turns rendered page pixels into a JPG/PNG file (PDF to Images, §4.7).
abstract interface class PageImageEncoder {
  /// Writes [out] at exactly the pixel size of [px]. [keepAlpha] (PNG only)
  /// keeps a transparent page background.
  Future<void> encode(PagePixels px, String out, {required ImageFormat format, required int quality, required bool keepAlpha});
}

/// ADR-060: wrap the BGRA in a 32-bit BMP (BITMAPV4, BI_BITFIELDS, top-down)
/// and let the native codec encode it — about 4× faster than the `image`
/// package. The header is written first and then the pixels, so no second
/// full-size buffer is built in memory.
Future<void> writeBgraBmp(PagePixels px, String path) async {
  const header = 14 + 108;
  final h = ByteData(header);
  h.setUint8(0, 0x42); // 'B'
  h.setUint8(1, 0x4D); // 'M'
  h.setUint32(2, header + px.bgra.length, Endian.little);
  h.setUint32(10, header, Endian.little);
  h.setUint32(14, 108, Endian.little); // BITMAPV4HEADER
  h.setInt32(18, px.width, Endian.little);
  h.setInt32(22, -px.height, Endian.little); // top-down
  h.setUint16(26, 1, Endian.little);
  h.setUint16(28, 32, Endian.little);
  h.setUint32(30, 3, Endian.little); // BI_BITFIELDS
  h.setUint32(34, px.bgra.length, Endian.little);
  h.setUint32(54, 0x00FF0000, Endian.little); // R
  h.setUint32(58, 0x0000FF00, Endian.little); // G
  h.setUint32(62, 0x000000FF, Endian.little); // B
  h.setUint32(66, 0xFF000000, Endian.little); // A
  h.setUint32(70, 0x73524742, Endian.little); // 'sRGB'
  final f = await File(path).open(mode: FileMode.write);
  try {
    await f.writeFrom(h.buffer.asUint8List());
    await f.writeFrom(px.bgra);
  } finally {
    await f.close();
  }
}

/// Native encode through the BMP wrapper; the `image` package in an isolate
/// when the native codec refuses the BMP, and for transparent PNGs (the BMP
/// path's alpha handling wasn't checked in the T8.0 spike).
class NativePageImageEncoder implements PageImageEncoder {
  const NativePageImageEncoder();

  @override
  Future<void> encode(PagePixels px, String out, {required ImageFormat format, required int quality, required bool keepAlpha}) async {
    final png = format == ImageFormat.png;
    final alpha = png && keepAlpha;
    if (!alpha) {
      final bmp = '$out.bmp';
      try {
        await writeBgraBmp(px, bmp);
        final bytes = await FlutterImageCompress.compressWithFile(
          bmp,
          format: png ? CompressFormat.png : CompressFormat.jpeg,
          quality: quality,
          minWidth: px.width,
          minHeight: px.height,
          keepExif: false,
        );
        if (bytes != null && bytes.isNotEmpty) {
          await File(out).writeAsBytes(bytes, flush: true);
          return;
        }
      } catch (_) {
        // Fall through to the Dart encoder.
      } finally {
        await deleteQuietly(File(bmp));
      }
    }
    final bgra = px.bgra, w = px.width, h = px.height;
    final bytes = await Isolate.run(() => _encodeDart(bgra, w, h, png: png, quality: quality, alpha: alpha));
    await File(out).writeAsBytes(bytes, flush: true);
  }
}

Uint8List _encodeDart(Uint8List bgra, int w, int h, {required bool png, required int quality, required bool alpha}) {
  final im = img.Image.fromBytes(width: w, height: h, bytes: bgra.buffer, numChannels: 4, order: img.ChannelOrder.bgra);
  final out = alpha ? im : im.convert(numChannels: 3);
  return png ? img.encodePng(out, level: 6) : img.encodeJpg(out, quality: quality);
}
