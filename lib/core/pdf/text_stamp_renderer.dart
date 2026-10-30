import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:intl/intl.dart' show Bidi;

/// A rendered text stamp: its PNG and its placed size (RELEASE_V1_4 §4.3).
class TextStampImage {
  const TextStampImage({
    required this.pngPath,
    required this.widthPx,
    required this.heightPx,
    required this.widthPt,
    required this.heightPt,
  });
  final String pngPath;
  final int widthPx, heightPx;

  /// The stamp's size on the page; the PNG has the same aspect ratio.
  final double widthPt, heightPt;
}

/// Renders [text] onto a transparent PNG at [dpi] of [heightPt] (capped at
/// [maxSide] px on the long side), with the device's fonts — so any script
/// the phone can show works, and the result isn't searchable text. Runs on
/// the UI isolate (dart:ui); a stamp is one short line, so it's quick.
Future<TextStampImage> renderTextPng(
  String text, {
  required String outPath,
  required ui.Color colour,
  required double heightPt,
  String? fontFamily,
  bool bold = false,
  double dpi = 300,
  int maxSide = 2400,
}) async {
  if (text.trim().isEmpty) throw ArgumentError.value(text, 'text', 'empty');
  final direction = Bidi.detectRtlDirectionality(text) ? ui.TextDirection.rtl : ui.TextDirection.ltr;

  ui.Paragraph layout(double fontSize) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      textDirection: direction,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
      maxLines: 3,
    ))
      ..pushStyle(ui.TextStyle(color: colour))
      ..addText(text);
    final para = b.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
    return para..layout(ui.ParagraphConstraints(width: para.maxIntrinsicWidth.ceilToDouble()));
  }

  final px = heightPt / 72 * dpi;
  var para = layout(px * 0.8);
  var pad = (px * 0.1).ceil();
  var w = para.width.ceil() + 2 * pad, h = para.height.ceil() + 2 * pad;
  final long = math.max(w, h);
  if (long > maxSide) {
    final k = maxSide / long;
    para = layout(px * 0.8 * k);
    pad = (px * 0.1 * k).ceil();
    w = math.min(maxSide, para.width.ceil() + 2 * pad);
    h = math.min(maxSide, para.height.ceil() + 2 * pad);
  }

  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawParagraph(para, ui.Offset(pad.toDouble(), pad.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(outPath).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
    picture.dispose();
  }
  return TextStampImage(pngPath: outPath, widthPx: w, heightPx: h, widthPt: heightPt * w / h, heightPt: heightPt);
}
