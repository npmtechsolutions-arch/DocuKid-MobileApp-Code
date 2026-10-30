import 'dart:math' as math;
import 'dart:ui' as ui;

import 'pdf_engine.dart';

/// The axis-aligned box of [r] turned [degrees] clockwise about its centre.
ui.Rect rotatedBounds(ui.Rect r, double degrees) {
  final t = degrees * math.pi / 180, c = math.cos(t).abs(), s = math.sin(t).abs();
  return ui.Rect.fromCenter(center: r.center, width: r.width * c + r.height * s, height: r.width * s + r.height * c);
}

/// §4.8: non-background pixels > 0.5% of the box, at 72 dpi. A pixel counts
/// when a channel is below [threshold]: 235 for signatures; watermarks pass a
/// higher one, since a light colour at 10% is barely off white.
Future<bool> stampHasInk(PdfEngine engine, String path, int page, ui.Rect box, ui.Size pageSize, {int threshold = 235}) async {
  try {
    final width = pageSize.width > 0 ? pageSize.width.round() : 612;
    final im = await engine.renderPage(path, page, targetWidthPx: width);
    if (im == null) return false;
    try {
      final data = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return false;
      final k = pageSize.width > 0 ? im.width / pageSize.width : 1.0;
      final x0 = math.max(0, (box.left * k).floor()), y0 = math.max(0, (box.top * k).floor());
      final x1 = math.min(im.width, (box.right * k).ceil()), y1 = math.min(im.height, (box.bottom * k).ceil());
      if (x1 <= x0 || y1 <= y0) return false;
      var ink = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * im.width + x) * 4;
          if (data.getUint8(i) < threshold || data.getUint8(i + 1) < threshold || data.getUint8(i + 2) < threshold) ink++;
        }
      }
      return ink > (x1 - x0) * (y1 - y0) * 0.005;
    } finally {
      im.dispose();
    }
  } finally {
    await engine.close(path);
  }
}
