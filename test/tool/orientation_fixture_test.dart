// The R7 fixtures themselves: once EXIF orientation is applied (by the image
// package, independently of DocuKit), each shows 900×1200 with the marker
// top-left.
import 'package:docukit/core/image/image_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/fixtures/orientation.dart';

void main() {
  for (var o = 1; o <= 8; o++) {
    test('orientation $o: displayed 900×1200, marker top-left', () {
      final bytes = orientationFixture(o);
      expect(parseImageHeader(bytes).orientation, o, reason: 'tag written');
      // decodeJpg applies the EXIF orientation itself (an implementation
      // independent of DocuKit's native engine).
      final shown = img.decodeJpg(bytes)!;
      expect((shown.width, shown.height), (900, 1200));
      bool red(int x, int y) {
        final p = shown.getPixel(x, y);
        return p.r > 150 && p.g < 100 && p.b < 100;
      }
      expect(red(60, 60), isTrue);
      expect(red(840, 60), isFalse);
      expect(red(60, 1140), isFalse);
      expect(red(840, 1140), isFalse);
    });
  }
}
