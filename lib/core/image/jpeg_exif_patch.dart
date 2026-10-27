import 'dart:typed_data';

/// Rewrites the EXIF orientation tag (0x0112) of a JPEG to 1 in place.
///
/// Needed because flutter_image_compress on Android copies the original
/// orientation tag even though it has already rotated the pixels, which makes
/// viewers rotate the image twice (spike T2.0 finding, DECISIONS ADR-019).
/// Returns true if a tag was changed.
bool resetJpegOrientation(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return false;
  var o = 2;
  while (o + 4 <= b.length && b[o] == 0xFF) {
    final marker = b[o + 1];
    if (marker == 0xDA || marker == 0xD9) return false;
    final len = (b[o + 2] << 8) | b[o + 3];
    final start = o + 4;
    final end = o + 2 + len;
    if (end > b.length) return false;
    if (marker == 0xE1 && len >= 14 && b[start] == 0x45 && b[start + 1] == 0x78 && b[start + 2] == 0x69 && b[start + 3] == 0x66) {
      final t = start + 6;
      final little = b[t] == 0x49;
      int u16(int p) => little ? b[p] | (b[p + 1] << 8) : (b[p] << 8) | b[p + 1];
      int u32(int p) => little
          ? b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24)
          : (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
      final ifd = t + u32(t + 4);
      if (ifd + 2 > end) return false;
      final count = u16(ifd);
      for (var i = 0; i < count; i++) {
        final e = ifd + 2 + i * 12;
        if (e + 12 > end) return false;
        if (u16(e) == 0x0112) {
          if (little) {
            b[e + 8] = 1;
            b[e + 9] = 0;
          } else {
            b[e + 8] = 0;
            b[e + 9] = 1;
          }
          return true;
        }
      }
      return false;
    }
    o = end;
  }
  return false;
}
