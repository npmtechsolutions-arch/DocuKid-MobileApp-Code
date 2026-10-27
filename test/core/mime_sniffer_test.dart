import 'dart:typed_data';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List b(List<int> v) => Uint8List.fromList(v);

void main() {
  test('JPEG', () => expect(sniffBytes(b([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])), SniffedType.jpeg));
  test('PNG', () => expect(sniffBytes(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0])), SniffedType.png));
  test('WebP', () {
    expect(sniffBytes(b([...'RIFF'.codeUnits, 1, 2, 3, 4, ...'WEBP'.codeUnits, ...'VP8 '.codeUnits])), SniffedType.webp);
  });
  test('RIFF that is not WebP is unknown', () {
    expect(sniffBytes(b([...'RIFF'.codeUnits, 1, 2, 3, 4, ...'WAVE'.codeUnits])), SniffedType.unknown);
  });
  for (final brand in ['heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1']) {
    test('HEIC brand $brand', () {
      expect(sniffBytes(b([0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits, 0, 0, 0, 0])), SniffedType.heic);
    });
  }
  test('ftyp with a video brand is unknown', () {
    expect(sniffBytes(b([0, 0, 0, 24, ...'ftyp'.codeUnits, ...'mp42'.codeUnits])), SniffedType.unknown);
  });
  test('GIF', () => expect(sniffBytes(b('GIF89a'.codeUnits)), SniffedType.gif));
  test('PDF at start', () => expect(sniffBytes(b('%PDF-1.7\n'.codeUnits)), SniffedType.pdf));
  test('PDF after junk within 1024 bytes', () {
    expect(sniffBytes(b([...List.filled(500, 0x20), ...'%PDF-1.4'.codeUnits])), SniffedType.pdf);
  });
  test('PDF marker beyond 1024 bytes is ignored', () {
    expect(sniffBytes(b([...List.filled(1100, 0x20), ...'%PDF-1.4'.codeUnits])), SniffedType.unknown);
  });
  test('extension is ignored: PNG bytes stay PNG', () {
    // A ".jpg" that is really PNG is decided by its bytes alone.
    expect(sniffBytes(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), SniffedType.png);
  });
  test('empty and tiny inputs', () {
    expect(sniffBytes(b([])), SniffedType.unknown);
    expect(sniffBytes(b([0xFF])), SniffedType.unknown);
  });
  test('supported image set', () {
    expect(SniffedType.jpeg.isSupportedImage, isTrue);
    expect(SniffedType.heic.isSupportedImage, isTrue);
    expect(SniffedType.gif.isSupportedImage, isFalse);
    expect(SniffedType.pdf.isSupportedImage, isFalse);
  });
}
