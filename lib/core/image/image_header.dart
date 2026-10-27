import 'dart:io';
import 'dart:typed_data';

import '../files/mime_sniffer.dart';

/// Header-only image facts, read without decoding pixels.
///
/// Width/height are the *stored* (sensor) dimensions; use [displayWidth] /
/// [displayHeight] for the oriented size (FEATURE_SPECS §3.1).
class ImageHeader {
  const ImageHeader({
    required this.type,
    required this.width,
    required this.height,
    this.orientation = 1,
    this.hasAlpha = false,
    this.hasGps,
    this.animated = false,
  });

  final SniffedType type;
  final int width;
  final int height;

  /// EXIF orientation 1–8 (HEIC `irot` is mapped onto the same scale).
  final int orientation;
  final bool hasAlpha;

  /// null = unknown for this format.
  final bool? hasGps;
  final bool animated;

  bool get swapsAxes => orientation >= 5 && orientation <= 8;
  int get displayWidth => swapsAxes ? height : width;
  int get displayHeight => swapsAxes ? width : height;
}

class ImageHeaderException implements Exception {
  const ImageHeaderException(this.reason);
  final String reason;
}

/// Reads at most [maxBytes] from the start of the file and parses it.
Future<ImageHeader> readImageHeader(String path, {int maxBytes = 1 << 20}) async {
  final raf = await File(path).open();
  try {
    final len = await raf.length();
    final bytes = await raf.read(len < maxBytes ? len : maxBytes);
    return parseImageHeader(bytes);
  } finally {
    await raf.close();
  }
}

ImageHeader parseImageHeader(Uint8List b) {
  final type = sniffBytes(b);
  switch (type) {
    case SniffedType.jpeg:
      return _jpeg(b);
    case SniffedType.png:
      return _png(b);
    case SniffedType.webp:
      return _webp(b);
    case SniffedType.heic:
      return _heic(b);
    default:
      throw const ImageHeaderException('unsupported');
  }
}

int _be16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];
int _be32(Uint8List b, int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
int _le16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
int _le24(Uint8List b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);

void _need(Uint8List b, int end) {
  if (end > b.length) throw const ImageHeaderException('truncated');
}

// ---------------------------------------------------------------- JPEG

ImageHeader _jpeg(Uint8List b) {
  var o = 2;
  var orientation = 1;
  bool? hasGps = false;
  while (o + 4 <= b.length) {
    if (b[o] != 0xFF) {
      o++;
      continue;
    }
    final marker = b[o + 1];
    if (marker == 0xFF) {
      o++;
      continue;
    }
    if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
      o += 2;
      continue;
    }
    if (marker == 0xD9 || marker == 0xDA) break; // EOI / start of scan before SOF
    final segLen = _be16(b, o + 2);
    final segStart = o + 4;
    final segEnd = o + 2 + segLen;
    if (marker == 0xE1 && segEnd <= b.length && segLen >= 8) {
      if (b[segStart] == 0x45 && b[segStart + 1] == 0x78 && b[segStart + 2] == 0x69 && b[segStart + 3] == 0x66) {
        final exif = _parseExif(b, segStart + 6, segEnd);
        orientation = exif.$1;
        hasGps = exif.$2;
      }
    }
    final isSof = (marker >= 0xC0 && marker <= 0xCF) && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
    if (isSof) {
      _need(b, segStart + 5);
      final h = _be16(b, segStart + 1);
      final w = _be16(b, segStart + 3);
      if (w == 0 || h == 0) throw const ImageHeaderException('zero');
      return ImageHeader(type: SniffedType.jpeg, width: w, height: h, orientation: orientation, hasGps: hasGps);
    }
    o = segEnd;
  }
  throw const ImageHeaderException('no_sof');
}

/// Returns (orientation, hasGps) from a TIFF block in [b] between [start] and [end].
(int, bool) _parseExif(Uint8List b, int start, int end) {
  if (start + 8 > end) return (1, false);
  final little = b[start] == 0x49 && b[start + 1] == 0x49;
  int u16(int o) => little ? _le16(b, o) : _be16(b, o);
  int u32(int o) => little ? (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) : _be32(b, o);
  final ifd = start + u32(start + 4);
  if (ifd + 2 > end) return (1, false);
  final count = u16(ifd);
  var orientation = 1;
  var gps = false;
  for (var i = 0; i < count; i++) {
    final e = ifd + 2 + i * 12;
    if (e + 12 > end) break;
    final tag = u16(e);
    if (tag == 0x0112) {
      final v = u16(e + 8);
      if (v >= 1 && v <= 8) orientation = v;
    } else if (tag == 0x8825) {
      final gpsIfd = start + u32(e + 8);
      if (gpsIfd + 2 <= end && u16(gpsIfd) > 0) gps = true;
    }
  }
  return (orientation, gps);
}

// ---------------------------------------------------------------- PNG

ImageHeader _png(Uint8List b) {
  _need(b, 33);
  final w = _be32(b, 16);
  final h = _be32(b, 20);
  final colorType = b[25];
  var alpha = colorType == 4 || colorType == 6;
  // Look for tRNS before IDAT.
  var o = 8;
  while (!alpha && o + 8 <= b.length) {
    final len = _be32(b, o);
    final name = String.fromCharCodes(b.sublist(o + 4, o + 8));
    if (name == 'tRNS') alpha = true;
    if (name == 'IDAT' || name == 'IEND') break;
    o += 12 + len;
  }
  if (w == 0 || h == 0) throw const ImageHeaderException('zero');
  return ImageHeader(type: SniffedType.png, width: w, height: h, hasAlpha: alpha, hasGps: false);
}

// ---------------------------------------------------------------- WebP

ImageHeader _webp(Uint8List b) {
  _need(b, 30);
  final chunk = String.fromCharCodes(b.sublist(12, 16));
  switch (chunk) {
    case 'VP8 ':
      final w = _le16(b, 26) & 0x3FFF;
      final h = _le16(b, 28) & 0x3FFF;
      return ImageHeader(type: SniffedType.webp, width: w, height: h, hasGps: false);
    case 'VP8L':
      final b0 = b[21], b1 = b[22], b2 = b[23], b3 = b[24];
      final w = 1 + (b0 | ((b1 & 0x3F) << 8));
      final h = 1 + ((b1 >> 6) | (b2 << 2) | ((b3 & 0x0F) << 10));
      final alpha = ((b3 >> 4) & 1) == 1;
      return ImageHeader(type: SniffedType.webp, width: w, height: h, hasAlpha: alpha, hasGps: false);
    case 'VP8X':
      final flags = b[20];
      final w = 1 + _le24(b, 24);
      final h = 1 + _le24(b, 27);
      return ImageHeader(
        type: SniffedType.webp,
        width: w,
        height: h,
        hasAlpha: (flags & 0x10) != 0,
        animated: (flags & 0x02) != 0,
        hasGps: (flags & 0x08) != 0 ? null : false,
      );
  }
  throw const ImageHeaderException('webp_chunk');
}

// ---------------------------------------------------------------- HEIC

ImageHeader _heic(Uint8List b) {
  var bestW = 0, bestH = 0;
  int? irot;

  void walk(int start, int end, int depth) {
    var o = start;
    while (o + 8 <= end) {
      var size = _be32(b, o);
      final name = String.fromCharCodes(b.sublist(o + 4, o + 8));
      var header = 8;
      if (size == 1) {
        if (o + 16 > end) return;
        size = (_be32(b, o + 8) << 32) | _be32(b, o + 12);
        header = 16;
      } else if (size == 0) {
        size = end - o;
      }
      if (size < header || o + size > end) {
        if (name != 'mdat') return;
        size = end - o;
      }
      final body = o + header;
      switch (name) {
        case 'meta':
          walk(body + 4, o + size, depth + 1); // full box: skip version/flags
        case 'iprp':
        case 'ipco':
          walk(body, o + size, depth + 1);
        case 'ispe':
          if (body + 12 <= o + size) {
            final w = _be32(b, body + 4), h = _be32(b, body + 8);
            if (w * h > bestW * bestH) {
              bestW = w;
              bestH = h;
            }
          }
        case 'irot':
          if (body < o + size) irot ??= b[body] & 0x3;
      }
      if (name == 'mdat') return;
      o += size;
    }
  }

  walk(0, b.length, 0);
  if (bestW == 0 || bestH == 0) throw const ImageHeaderException('heic_no_ispe');
  // irot is anticlockwise quarter turns; map to the EXIF orientation that
  // displays the same way.
  final orientation = switch (irot) { 1 => 8, 2 => 3, 3 => 6, _ => 1 };
  return ImageHeader(type: SniffedType.heic, width: bestW, height: bestH, orientation: orientation);
}
