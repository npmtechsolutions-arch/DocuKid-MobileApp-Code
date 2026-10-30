// T11.5 — §4.4 placement maths (RELEASE_V1_4 §8.1), written before the
// implementation: 4 page rotations × a crop box offset from the media box ×
// stamp rotations {0, 30, 90}; the four image corners land within ±0.01 pt.
// PDFium itself checks the same placements in pdf_stamper_host_test.dart.
import 'dart:math' as math;
import 'dart:ui';

import 'package:docukit/core/pdf/stamp_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Crop box inset 36 pt in an A4-ish 612×792 media box (W 540, H 720).
  const crop = PageGeometry(cx0: 36, cy0: 36, cx1: 576, cy1: 756, rotation: 0);
  PageGeometry rotated(int r) =>
      PageGeometry(cx0: crop.cx0, cy0: crop.cy0, cx1: crop.cx1, cy1: crop.cy1, rotation: r);

  group('toUser: hand-checked visual (10, 10) on each rotation', () {
    // rot 90 (clockwise): the crop's bottom-left becomes the visual top-left, and so on.
    for (final (rot, ux, uy) in [(0, 46.0, 746.0), (90, 46.0, 46.0), (180, 566.0, 46.0), (270, 566.0, 746.0)]) {
      test('$rot°', () {
        final (x, y) = rotated(rot).toUser(10, 10);
        expect(x, closeTo(ux, 0.01));
        expect(y, closeTo(uy, 0.01));
      });
    }
  });

  test('visual size swaps for 90/270; normalises an inverted crop box and odd /Rotate values', () {
    expect(rotated(0).visualSize, const Size(540, 720));
    expect(rotated(90).visualSize, const Size(720, 540));
    expect(rotated(270).visualSize, const Size(720, 540));
    final g = PageGeometry.normalised(x0: 576, y0: 756, x1: 36, y1: 36, rotation: -90);
    expect((g.cx0, g.cy0, g.cx1, g.cy1, g.rotation), (36.0, 36.0, 576.0, 756.0, 270));
    expect(PageGeometry.normalised(x0: 0, y0: 0, x1: 10, y1: 10, rotation: 450).rotation, 90);
  });

  group('placementMatrix: image corners on the visual stamp corners (±0.01 pt)', () {
    // Where image corner (u, v) — v = 1 is the image's top — should appear in
    // visual space: the stamp's own rotation turns it clockwise about its centre.
    Offset visualCorner(Rect r, double deg, double u, double v) {
      final t = deg * math.pi / 180, x = (u - 0.5) * r.width, y = (0.5 - v) * r.height;
      return r.center + Offset(x * math.cos(t) - y * math.sin(t), x * math.sin(t) + y * math.cos(t));
    }

    const rect = Rect.fromLTWH(10, 10, 100, 50);
    for (final rot in [0, 90, 180, 270]) {
      for (final deg in [0.0, 30.0, 90.0]) {
        test('page $rot°, stamp $deg°', () {
          final g = rotated(rot);
          final m = placementMatrix(g, rect, deg);
          for (final (u, v) in [(0.0, 0.0), (0.0, 1.0), (1.0, 0.0), (1.0, 1.0)]) {
            final want = visualCorner(rect, deg, u, v);
            final (ex, ey) = g.toUser(want.dx, want.dy);
            final (x, y) = m.apply(u, v);
            expect(x, closeTo(ex, 0.01), reason: 'corner ($u, $v) x');
            expect(y, closeTo(ey, 0.01), reason: 'corner ($u, $v) y');
          }
        });
      }
    }

    test('page 0°, stamp 0°: the exact §4.4 numbers for a 100×50 stamp at (10, 10)', () {
      final m = placementMatrix(crop, rect, 0);
      expect(m.apply(0, 1), (46.0, 746.0)); // image top-left → visual (10, 10)
      expect(m.apply(1, 0), (146.0, 696.0)); // image bottom-right → visual (110, 60)
    });
  });

  test('Affine: composition order (this · o applies o first) and the PDF [a b c d e f] layout', () {
    final m = Affine.translate(5, 7) * Affine.scale(2, 3);
    expect(m.apply(1, 1), (7.0, 10.0));
    expect((m.a, m.b, m.c, m.d, m.e, m.f), (2.0, 0.0, 0.0, 3.0, 5.0, 7.0));
    final r = Affine.rotate(90).apply(1, 0);
    expect(r.$1, closeTo(0, 1e-9));
    expect(r.$2, closeTo(1, 1e-9), reason: 'counter-clockwise in y-up user space');
  });
}
