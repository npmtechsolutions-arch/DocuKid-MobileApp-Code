import 'dart:math' as math;
import 'dart:ui';

import 'text_recognizer.dart';

/// A rectangle in PDF points, origin bottom-left (y up), so [top] > [bottom].
/// Kept apart from [Rect] (y down) to avoid mixing the two spaces.
class PdfBox {
  const PdfBox({required this.left, required this.bottom, required this.right, required this.top});

  final double left, bottom, right, top;

  double get width => right - left;
  double get height => top - bottom;

  @override
  String toString() => 'PdfBox($left, $bottom, $right, $top)';
}

/// RELEASE_V1_3 §4.5: [box] in the pixels of an image (W×H, origin top-left)
/// that is drawn into [page] → the same area in PDF points.
PdfBox toPdfBox(Rect box, {required int imageWidth, required int imageHeight, required PdfBox page}) {
  final sx = page.width / imageWidth, sy = page.height / imageHeight;
  return PdfBox(
    left: page.left + box.left * sx,
    bottom: page.bottom + (imageHeight - box.bottom) * sy,
    right: page.left + box.right * sx,
    top: page.bottom + (imageHeight - box.top) * sy,
  );
}

/// One point, mapped like [toPdfBox].
Offset toPdfPoint(Offset p, {required int imageWidth, required int imageHeight, required PdfBox page}) => Offset(
      page.left + p.dx * page.width / imageWidth,
      page.bottom + (imageHeight - p.dy) * page.height / imageHeight,
    );

/// The angle of a line's top edge (corner 0 → corner 1) in image space, in
/// radians; 0 when the corners are unknown.
double imageAngle(List<Offset> corners) {
  if (corners.length < 2) return 0;
  final d = corners[1] - corners[0];
  return math.atan2(d.dy, d.dx);
}

/// In PDF space the angle turns the other way (y is flipped).
double pdfAngle(double imageAngle) => -imageAngle;

/// Lines tilted more than 2° are placed with a rotated text matrix (§4.5).
bool isSkewed(double angle) => angle.abs() > 2 * math.pi / 180;

/// Reading order (§4.5) for `.txt`, Copy all and the text layer: rows top to
/// bottom, where a line joins a row when it overlaps any line of the row
/// vertically by more than half the smaller height; left to right within a
/// row. (Column detection is P2.)
List<OcrLine> readingOrder(List<OcrLine> lines) {
  final byTop = [...lines]..sort((a, b) => a.box.top.compareTo(b.box.top));
  final rows = <List<OcrLine>>[];
  for (final l in byTop) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && row.any((m) => _sameRow(m.box, l.box))) {
      row.add(l);
    } else {
      rows.add([l]);
    }
  }
  return [
    for (final row in rows) ...(row..sort((a, b) => a.box.left.compareTo(b.box.left))),
  ];
}

bool _sameRow(Rect a, Rect b) {
  final overlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
  return overlap > 0.5 * math.min(a.height, b.height);
}

/// [page] with its lines in reading order.
OcrPage sortedPage(OcrPage page) =>
    OcrPage(imageWidth: page.imageWidth, imageHeight: page.imageHeight, lines: readingOrder(page.lines));
