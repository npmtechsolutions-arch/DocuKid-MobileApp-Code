// EXIF orientation fixtures (TESTING.md IMG-03..10).
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The marker's colour (top-left quarter of the image, as displayed).
final markerColor = img.ColorRgb8(220, 30, 30);

/// A JPEG tagged with EXIF [orientation] (1–8) whose *displayed* image is
/// [width]×[height] with a red marker in the top-left corner. The stored
/// pixels are the displayed image run through the inverse of the orientation
/// transform, so a viewer that honours EXIF shows the marker top-left.
Uint8List orientationFixture(int orientation, {int width = 900, int height = 1200}) {
  final stored = orientationStoredImage(orientation, width: width, height: height)
    ..exif.imageIfd.orientation = orientation;
  return img.encodeJpg(stored, quality: 90);
}

/// The stored (pre-EXIF) pixels of [orientationFixture], untagged.
img.Image orientationStoredImage(int orientation, {int width = 900, int height = 1200}) {
  final shown = img.Image(width: width, height: height);
  img.fill(shown, color: img.ColorRgb8(40, 90, 200));
  img.fillRect(shown, x1: 0, y1: 0, x2: width ~/ 4, y2: height ~/ 4, color: markerColor);

  // Orientations 5–8 store the image with width and height swapped.
  final swap = orientation >= 5;
  final sw = swap ? height : width, sh = swap ? width : height;
  final stored = img.Image(width: sw, height: sh);
  for (var sy = 0; sy < sh; sy++) {
    for (var sx = 0; sx < sw; sx++) {
      // Where stored pixel (sx, sy) appears once the orientation is applied.
      final (dx, dy) = switch (orientation) {
        2 => (sw - 1 - sx, sy), // mirror horizontal
        3 => (sw - 1 - sx, sh - 1 - sy), // rotate 180
        4 => (sx, sh - 1 - sy), // mirror vertical
        5 => (sy, sx), // transpose
        6 => (sh - 1 - sy, sx), // rotate 90 CW
        7 => (sh - 1 - sy, sw - 1 - sx), // transverse
        8 => (sy, sw - 1 - sx), // rotate 90 CCW
        _ => (sx, sy),
      };
      stored.setPixel(sx, sy, shown.getPixel(dx, dy));
    }
  }
  return stored;
}
