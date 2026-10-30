import 'dart:math' as math;
import 'dart:ui';

/// A 2-D affine map in PDF's `[a b c d e f]` layout:
/// x' = a·x + c·y + e, y' = b·x + d·y + f.
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  final double a, b, c, d, e, f;

  static Affine scale(double sx, double sy) => Affine(sx, 0, 0, sy, 0, 0);
  static Affine translate(double tx, double ty) => Affine(1, 0, 0, 1, tx, ty);

  /// Counter-clockwise in a y-up space.
  static Affine rotate(double degrees) {
    final r = degrees * math.pi / 180, cs = math.cos(r), sn = math.sin(r);
    return Affine(cs, sn, -sn, cs, 0, 0);
  }

  /// this · o (o is applied first).
  Affine operator *(Affine o) => Affine(
        a * o.a + c * o.b,
        b * o.a + d * o.b,
        a * o.c + c * o.d,
        b * o.c + d * o.d,
        a * o.e + c * o.f + e,
        b * o.e + d * o.f + f,
      );

  (double, double) apply(double x, double y) => (a * x + c * y + e, b * x + d * y + f);
}

/// A page as the editor sees it (RELEASE_V1_4 §4.4): the crop box in user
/// space and the page's `/Rotate`, clockwise.
class PageGeometry {
  const PageGeometry({required this.cx0, required this.cy0, required this.cx1, required this.cy1, required this.rotation});

  /// Any corner order, any `/Rotate` (a multiple of 90, possibly negative).
  factory PageGeometry.normalised(
          {required double x0, required double y0, required double x1, required double y1, required int rotation}) =>
      PageGeometry(
        cx0: math.min(x0, x1),
        cy0: math.min(y0, y1),
        cx1: math.max(x0, x1),
        cy1: math.max(y0, y1),
        rotation: ((rotation ~/ 90) % 4 + 4) % 4 * 90,
      );

  final double cx0, cy0, cx1, cy1;

  /// 0, 90, 180 or 270.
  final int rotation;

  double get width => cx1 - cx0;
  double get height => cy1 - cy0;

  /// The page as displayed, in points.
  Size get visualSize => rotation == 90 || rotation == 270 ? Size(height, width) : Size(width, height);

  /// A visual point (origin top-left, y down) in user space.
  (double, double) toUser(double vx, double vy) => switch (rotation) {
        0 => (cx0 + vx, cy1 - vy),
        90 => (cx0 + vy, cy0 + vx),
        180 => (cx1 - vx, cy0 + vy),
        _ => (cx1 - vy, cy1 - vx),
      };
}

/// The matrix that draws an image (PDF's unit square, upright) into
/// [visualRect] on the page, turned [rotationDegrees] clockwise about its
/// centre, upright for the reader: T(centre) · R(page) · R(−stamp) · S · T(−½).
Affine placementMatrix(PageGeometry g, Rect visualRect, double rotationDegrees) {
  final s = Affine.scale(visualRect.width, visualRect.height) * Affine.translate(-0.5, -0.5);
  final r = Affine.rotate(-rotationDegrees);
  final page = Affine.rotate(g.rotation.toDouble());
  final (ux, uy) = g.toUser(visualRect.center.dx, visualRect.center.dy);
  return Affine.translate(ux, uy) * page * r * s;
}
