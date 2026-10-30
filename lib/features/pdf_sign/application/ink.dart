import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

/// The draw pad's inks (FR-SIG-02).
enum InkColour {
  black(Color(0xFF111111)),
  blue(Color(0xFF1A3FB0));

  const InkColour(this.color);
  final Color color;
}

/// Pen widths in logical pixels.
enum InkThickness {
  thin(2),
  medium(3.5),
  thick(5.5);

  const InkThickness(this.width);
  final double width;
}

/// One finger-down → finger-up, in the pad's logical pixels.
class InkStroke {
  const InkStroke(this.points);
  final List<Offset> points;
}

/// Midpoint quadratic Béziers through the touch points (RELEASE_V1_4 §4.7):
/// each point is a control point and the curve passes through the midpoints,
/// so corners are rounded and fast strokes stay smooth. One point is a dot.
Path smoothStrokePath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) return path..lineTo(pts.first.dx + 0.01, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = (pts[i] + pts[i + 1]) / 2;
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  return path..lineTo(pts.last.dx, pts.last.dy);
}

Paint inkPaint(InkColour colour, double width) => Paint()
  ..color = colour.color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// All ink, widened by half the pen; null when nothing is drawn.
Rect? inkBounds(List<InkStroke> strokes, double width) {
  Rect? r;
  for (final s in strokes) {
    for (final pt in s.points) {
      final b = Rect.fromCircle(center: pt, radius: width / 2);
      r = r == null ? b : r.expandToInclude(b);
    }
  }
  return r;
}

class InkImage {
  const InkImage(this.pngPath, this.widthPx, this.heightPx);
  final String pngPath;
  final int widthPx, heightPx;
}

/// The strokes at [scale]× on a transparent canvas, cropped to the ink +
/// [pad] px, as a PNG at [outPath] (§4.7).
Future<InkImage> exportInkPng(
  List<InkStroke> strokes, {
  required InkColour colour,
  required InkThickness thickness,
  required String outPath,
  double scale = 3,
  int pad = 8,
}) async {
  final bounds = inkBounds(strokes, thickness.width);
  if (bounds == null) throw StateError('no ink');
  final w = (bounds.width * scale).ceil() + 2 * pad, h = (bounds.height * scale).ceil() + 2 * pad;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)
    ..translate(pad.toDouble(), pad.toDouble())
    ..scale(scale)
    ..translate(-bounds.left, -bounds.top);
  final paint = inkPaint(colour, thickness.width);
  for (final s in strokes) {
    canvas.drawPath(smoothStrokePath(s.points), paint);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(math.max(1, w), math.max(1, h));
  try {
    final data = await image.toByteData(format: ImageByteFormat.png);
    await File(outPath).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
    picture.dispose();
  }
  return InkImage(outPath, w, h);
}
