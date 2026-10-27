import 'dart:io';
import 'dart:typed_data';

/// Formats DocuKit recognises from magic bytes (FEATURE_SPECS §2.1).
enum SniffedType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp'),
  heic('image/heic', 'heic'),
  gif('image/gif', 'gif'),
  pdf('application/pdf', 'pdf'),
  unknown('application/octet-stream', 'bin');

  const SniffedType(this.mime, this.ext);
  final String mime;
  final String ext;

  bool get isSupportedImage => this == jpeg || this == png || this == webp || this == heic;

  static SniffedType fromMime(String mime) =>
      values.firstWhere((t) => t.mime == mime, orElse: () => unknown);
}

const _heicBrands = {'heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1'};

/// Decides the type from the header only; the extension is ignored.
SniffedType sniffBytes(Uint8List b) {
  bool at(int offset, List<int> sig) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return SniffedType.jpeg;
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return SniffedType.png;
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) && at(8, const [0x57, 0x45, 0x42, 0x50])) {
    return SniffedType.webp;
  }
  if (at(4, const [0x66, 0x74, 0x79, 0x70]) && b.length >= 12) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (_heicBrands.contains(brand)) return SniffedType.heic;
  }
  if (at(0, const [0x47, 0x49, 0x46, 0x38])) return SniffedType.gif;
  // %PDF- anywhere in the first 1024 bytes.
  final limit = b.length < 1024 ? b.length : 1024;
  for (var i = 0; i + 5 <= limit; i++) {
    if (b[i] == 0x25 && b[i + 1] == 0x50 && b[i + 2] == 0x44 && b[i + 3] == 0x46 && b[i + 4] == 0x2D) {
      return SniffedType.pdf;
    }
  }
  return SniffedType.unknown;
}

Future<Uint8List> readHead(String path, [int length = 1024]) async {
  final raf = await File(path).open();
  try {
    return await raf.read(length);
  } finally {
    await raf.close();
  }
}

Future<SniffedType> sniffFile(String path) async => sniffBytes(await readHead(path));
