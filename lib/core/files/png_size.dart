import 'dart:io';
import 'dart:typed_data';

/// (width, height) from a PNG's IHDR, without decoding it; null if it isn't one.
(int, int)? pngSize(String path) {
  try {
    final raf = File(path).openSync();
    try {
      final b = raf.readSync(24);
      if (b.length < 24 || b[1] != 0x50 || b[2] != 0x4E || b[3] != 0x47) return null;
      final d = ByteData.sublistView(b);
      return (d.getUint32(16), d.getUint32(20));
    } finally {
      raf.closeSync();
    }
  } on FileSystemException {
    return null;
  }
}
