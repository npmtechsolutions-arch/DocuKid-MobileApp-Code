// R7 / mirrored EXIF orientations on Android (written before the fix).
// flutter_image_compress on Android rotates by ExifInterface.rotationDegrees
// (plus our extra rotation) but never applies the flip. This models exactly
// that and checks that mirrorAfterNativeRotation() restores the image a
// correct EXIF viewer shows, for every orientation × every extra rotation.
import 'package:docukit/core/image/resize_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/fixtures/orientation.dart';

/// androidx ExifInterface.getRotationDegrees().
int androidRotationDegrees(int o) => switch (o) {
      3 || 4 => 180,
      5 || 8 => 270,
      6 || 7 => 90,
      _ => 0,
    };

void main() {
  const w = 60, h = 80;

  String corners(img.Image im) {
    bool red(int x, int y) {
      final p = im.getPixel(x, y);
      return p.r > 150 && p.g < 100 && p.b < 100;
    }

    final (cx, cy) = (im.width ~/ 8, im.height ~/ 8);
    return [
      red(cx, cy),
      red(im.width - 1 - cx, cy),
      red(cx, im.height - 1 - cy),
      red(im.width - 1 - cx, im.height - 1 - cy),
    ].map((b) => b ? 'X' : '.').join();
  }

  for (var o = 1; o <= 8; o++) {
    for (final extra in const [0, 90, 180, 270]) {
      test('orientation $o + extra rotation $extra°', () {
        // Ground truth: what an EXIF-correct viewer shows, then our rotation.
        final shown = img.decodeJpg(orientationFixture(o, width: w, height: h))!; // applies EXIF itself
        final expected = extra == 0 ? shown : img.copyRotate(shown, angle: extra);
        expect(corners(expected).indexOf('X'), isNonNegative);

        // Android native step: rotation only.
        final total = (androidRotationDegrees(o) + extra) % 360;
        final stored = orientationStoredImage(o, width: w, height: h);
        var out = total == 0 ? stored : img.copyRotate(stored, angle: total);
        switch (mirrorAfterNativeRotation(o, extra)) {
          case MirrorAxis.horizontal:
            out = img.flipHorizontal(out);
          case MirrorAxis.vertical:
            out = img.flipVertical(out);
          case null:
            break;
        }
        expect((out.width, out.height), (expected.width, expected.height));
        expect(corners(out), corners(expected));
      });
    }
  }
}
