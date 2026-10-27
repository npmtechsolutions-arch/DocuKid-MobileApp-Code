/// Resize maths (FEATURE_SPECS §3.2). Rounding is half-up so it's the same
/// on every platform.
library;

const maxSide = 12000;
const maxOutputPixels = 100000000;

int roundHalfUp(double x) => (x + 0.5).floor();

int lockedHeightFor(int w, int origW, int origH) {
  final v = roundHalfUp(w * origH / origW);
  return v < 1 ? 1 : v;
}

int lockedWidthFor(int h, int origW, int origH) {
  final v = roundHalfUp(h * origW / origH);
  return v < 1 ? 1 : v;
}

(int, int) percentDims(int p, int origW, int origH) {
  int f(int o) {
    final v = roundHalfUp(o * p / 100);
    return v < 1 ? 1 : v;
  }

  return (f(origW), f(origH));
}

enum DimsError { range, megapixels }

DimsError? validateDims(int? w, int? h) {
  if (w == null || h == null) return DimsError.range;
  if (w < 1 || w > maxSide || h < 1 || h > maxSide) return DimsError.range;
  if (w * h > maxOutputPixels) return DimsError.megapixels;
  return null;
}

DimsError? validateSide(int? v) => (v == null || v < 1 || v > maxSide) ? DimsError.range : null;

bool ratioDiffers(int w, int h, int origW, int origH) => (w / h - origW / origH).abs() > 0.01;

bool isUpscale(int w, int h, int origW, int origH) => w > origW || h > origH;

/// Fit modes (FEATURE_SPECS §3.3): the drawn image rect inside a w×h canvas.
enum FitMode { stretch, contain, cover }

class FitRect {
  const FitRect(this.left, this.top, this.width, this.height);
  final int left, top, width, height;

  @override
  bool operator ==(Object other) =>
      other is FitRect && other.left == left && other.top == top && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'FitRect($left,$top,$width,$height)';
}

/// Where the source image lands on the canvas (it may overflow for cover).
FitRect fitRect(FitMode mode, int w, int h, int origW, int origH) {
  switch (mode) {
    case FitMode.stretch:
      return FitRect(0, 0, w, h);
    case FitMode.contain:
      final s = (w / origW) < (h / origH) ? w / origW : h / origH;
      final dw = roundHalfUp(origW * s).clamp(1, w), dh = roundHalfUp(origH * s).clamp(1, h);
      return FitRect((w - dw) ~/ 2, (h - dh) ~/ 2, dw, dh);
    case FitMode.cover:
      final s = (w / origW) > (h / origH) ? w / origW : h / origH;
      final dw = roundHalfUp(origW * s), dh = roundHalfUp(origH * s);
      return FitRect((w - dw) ~/ 2, (h - dh) ~/ 2, dw, dh);
  }
}

/// Built-in presets (FR-RES-06).
enum BuiltInPreset {
  passport(413, 531),
  signature(140, 60),
  square(1080, 1080),
  story(1080, 1920),
  hd(1280, 720),
  fullHd(1920, 1080);

  const BuiltInPreset(this.width, this.height);
  final int width, height;
}

enum MirrorAxis { horizontal, vertical }

/// The flip still needed after a native rotate-only EXIF correction.
///
/// On Android, flutter_image_compress rotates by ExifInterface.rotationDegrees
/// (+ [extraRotation]) but drops the mirror of orientations 2, 4, 5 and 7.
/// EXIF means "flip horizontally, then rotate"; a horizontal flip done before
/// a rotation of R° equals, after it, a horizontal flip when R is 0/180° and a
/// vertical flip when R is 90/270°. Null when nothing is mirrored.
MirrorAxis? mirrorAfterNativeRotation(int orientation, int extraRotation) {
  final exifRotation = switch (orientation) {
    2 => 0,
    4 => 180,
    5 => 270,
    7 => 90,
    _ => null,
  };
  if (exifRotation == null) return null;
  return (exifRotation + extraRotation) % 180 == 0 ? MirrorAxis.horizontal : MirrorAxis.vertical;
}
