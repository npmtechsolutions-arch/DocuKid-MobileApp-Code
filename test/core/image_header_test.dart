import 'dart:typed_data';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/image/image_header.dart';
import 'package:docukit/core/image/jpeg_exif_patch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List jpegWithOrientation(int w, int h, int orientation, {bool gps = false}) {
  final im = img.Image(width: w, height: h);
  im.exif.imageIfd.orientation = orientation;
  if (gps) {
    im.exif.gpsIfd[0x0002] = img.IfdValueRational(35, 1); // GPSLatitude
  }
  return img.encodeJpg(im);
}

void main() {
  group('JPEG', () {
    test('dimensions and orientation 1', () {
      final h = parseImageHeader(jpegWithOrientation(40, 30, 1));
      expect(h.type, SniffedType.jpeg);
      expect((h.width, h.height), (40, 30));
      expect(h.orientation, 1);
      expect((h.displayWidth, h.displayHeight), (40, 30));
    });

    for (var o = 1; o <= 8; o++) {
      test('EXIF orientation $o swaps axes only for 5–8', () {
        final h = parseImageHeader(jpegWithOrientation(40, 30, o));
        expect(h.orientation, o);
        final swapped = o >= 5;
        expect((h.displayWidth, h.displayHeight), swapped ? (30, 40) : (40, 30));
      });
    }

    test('GPS IFD detected', () {
      expect(parseImageHeader(jpegWithOrientation(8, 8, 1, gps: true)).hasGps, isTrue);
      expect(parseImageHeader(jpegWithOrientation(8, 8, 1)).hasGps, isFalse);
    });

    test('truncated JPEG throws', () {
      final full = jpegWithOrientation(40, 30, 1);
      expect(() => parseImageHeader(Uint8List.sublistView(full, 0, 20)), throwsA(isA<ImageHeaderException>()));
    });

    test('orientation reset patch sets the tag to 1', () {
      final bytes = jpegWithOrientation(40, 30, 6);
      expect(resetJpegOrientation(bytes), isTrue);
      expect(parseImageHeader(bytes).orientation, 1);
    });
  });

  group('PNG', () {
    test('opaque RGB', () {
      final h = parseImageHeader(img.encodePng(img.Image(width: 7, height: 5)));
      expect((h.width, h.height, h.hasAlpha), (7, 5, false));
    });
    test('RGBA has alpha', () {
      final h = parseImageHeader(img.encodePng(img.Image(width: 7, height: 5, numChannels: 4)));
      expect(h.hasAlpha, isTrue);
    });
    test('1×1 edge case', () {
      final h = parseImageHeader(img.encodePng(img.Image(width: 1, height: 1)));
      expect((h.width, h.height), (1, 1));
    });
  });

  group('WebP', () {
    Uint8List riff(String chunk, List<int> payload) =>
        Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, ...chunk.codeUnits, ...payload]);

    test('VP8X with alpha and animation flags', () {
      // flags at 20, then 3 reserved bytes, width-1 (24-bit LE) at 24, height-1 at 27.
      final payload = [0, 0, 0, 0, 0x12, 0, 0, 0, 99, 0, 0, 49, 0, 0, 0, 0];
      final h = parseImageHeader(riff('VP8X', payload));
      expect((h.width, h.height), (100, 50));
      expect(h.hasAlpha, isTrue);
      expect(h.animated, isTrue);
    });

    test('VP8L lossless size', () {
      // w-1 = 9 (14 bits), h-1 = 19 (14 bits), alpha bit set.
      const w1 = 9, h1 = 19;
      const bits = w1 | (h1 << 14) | (1 << 28);
      final payload = [0, 0, 0, 0, 0x2F, bits & 0xFF, (bits >> 8) & 0xFF, (bits >> 16) & 0xFF, (bits >> 24) & 0xFF, 0, 0, 0, 0, 0];
      final h = parseImageHeader(riff('VP8L', payload));
      expect((h.width, h.height), (10, 20));
      expect(h.hasAlpha, isTrue);
    });
  });

  group('HEIC', () {
    Uint8List box(String type, List<int> body) {
      final size = 8 + body.length;
      return Uint8List.fromList([(size >> 24) & 0xFF, (size >> 16) & 0xFF, (size >> 8) & 0xFF, size & 0xFF, ...type.codeUnits, ...body]);
    }

    List<int> be32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

    test('largest ispe wins and irot maps to an orientation', () {
      final ispeThumb = box('ispe', [0, 0, 0, 0, ...be32(320), ...be32(240)]);
      final ispeMain = box('ispe', [0, 0, 0, 0, ...be32(4032), ...be32(3024)]);
      final irot = box('irot', [3]);
      final ipco = box('ipco', [...ispeThumb, ...ispeMain, ...irot]);
      final iprp = box('iprp', ipco);
      final meta = box('meta', [0, 0, 0, 0, ...iprp]);
      final ftyp = box('ftyp', [...'heic'.codeUnits, 0, 0, 0, 0, ...'mif1'.codeUnits]);
      final h = parseImageHeader(Uint8List.fromList([...ftyp, ...meta]));
      expect(h.type, SniffedType.heic);
      expect((h.width, h.height), (4032, 3024));
      expect(h.orientation, 6);
      expect((h.displayWidth, h.displayHeight), (3024, 4032));
    });
  });

  test('unsupported data throws', () {
    expect(() => parseImageHeader(Uint8List.fromList('GIF89a....'.codeUnits)), throwsA(isA<ImageHeaderException>()));
  });
}
