import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// "Background cleanup" slider default (FR-SIG-04).
const defaultCleanup = 55;
const _softness = 24.0;
const _maxEdge = 2000;

/// RELEASE_V1_4 §4.7: luminance L → alpha = clamp((threshold − L) / 24, 0, 1),
/// threshold = cleanup% of white; ink keeps its colour darkened 20% (blue
/// stays blue); cropped to pixels with alpha > 10. Null if nothing is left.
img.Image? removeSignatureBackground(img.Image src, {required int cleanup}) {
  var im = src;
  if (math.max(im.width, im.height) > _maxEdge) {
    im = im.width >= im.height ? img.copyResize(im, width: _maxEdge) : img.copyResize(im, height: _maxEdge);
  }
  im = im.convert(format: img.Format.uint8, numChannels: 3);
  final threshold = 255 * cleanup.clamp(0, 100) / 100;
  final out = img.Image(width: im.width, height: im.height, numChannels: 4);
  int? x0, y0, x1, y1;
  for (final px in im) {
    final r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
    final l = 0.299 * r + 0.587 * g + 0.114 * b;
    final a = (((threshold - l) / _softness).clamp(0.0, 1.0) * 255).round();
    if (a == 0) continue;
    out.setPixelRgba(px.x, px.y, (r * 0.8).round(), (g * 0.8).round(), (b * 0.8).round(), a);
    if (a > 10) {
      x0 = x0 == null ? px.x : math.min(x0, px.x);
      y0 = y0 == null ? px.y : math.min(y0, px.y);
      x1 = x1 == null ? px.x : math.max(x1, px.x);
      y1 = y1 == null ? px.y : math.max(y1, px.y);
    }
  }
  if (x0 == null) return null;
  return img.copyCrop(out, x: x0, y: y0!, width: x1! - x0 + 1, height: y1! - y0 + 1);
}

/// Decodes [jpegPath] (already oriented and ≤ 2000 px by the image engine),
/// cleans it and writes the PNG, off the UI isolate. (width, height) or null.
Future<(int, int)?> cleanSignaturePhoto(String jpegPath, String outPath, {required int cleanup, int? maxEdge}) =>
    Isolate.run(() {
      var src = img.decodeImage(File(jpegPath).readAsBytesSync());
      if (src == null) return null;
      if (maxEdge != null && math.max(src.width, src.height) > maxEdge) {
        src = src.width >= src.height ? img.copyResize(src, width: maxEdge) : img.copyResize(src, height: maxEdge);
      }
      final out = removeSignatureBackground(src, cleanup: cleanup);
      if (out == null) return null;
      File(outPath).writeAsBytesSync(img.encodePng(out));
      return (out.width, out.height);
    });
