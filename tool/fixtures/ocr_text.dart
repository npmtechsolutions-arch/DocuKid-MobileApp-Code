// OCR fixtures (RELEASE_V1_3 §8.1) drawn with Flutter's text engine, so they
// need a Flutter binding (integration tests): OCR-01 is an A4 page at 300 dpi
// with three paragraphs at 12 pt; the ground-truth word boxes come from the
// layout. No personal data.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const ocrLatinText = 'Meeting notes for the spring planning session. The budget for the second quarter was '
    'approved after a short discussion about travel costs and new equipment for the office.\n\n'
    'Anna will prepare the schedule for the workshop in April. Every team should send its list of '
    'questions before Friday so that the agenda can be printed in time.\n\n'
    'The next review is planned for the fourteenth of May. Please bring the updated figures, the '
    'customer survey results and any open issues from the delivery project.';

const ocrHindiText = 'भारत एक विशाल देश है। यहाँ अनेक भाषाएँ बोली जाती हैं।\n\n'
    'हम सब मिलकर काम करते हैं और समय पर बैठक में आते हैं।';

typedef OcrFixture = ({Uint8List png, int width, int height, List<(String, Rect)> truth});

/// A white page ([width]×[height] px) with [text] in black at [fontSize] px
/// (50 px = 12 pt at 300 dpi), and each word's box in the page's pixels.
Future<OcrFixture> drawOcrPage(String text, {double fontSize = 50, int width = 2480, int height = 3508}) async {
  const margin = 200.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)
    ..drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.white);
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: Colors.black, fontSize: fontSize, height: 1.4)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 2 * margin);
  tp.paint(c, const Offset(margin, margin));
  final truth = <(String, Rect)>[];
  for (final m in RegExp(r'\S+').allMatches(text)) {
    final boxes = tp.getBoxesForSelection(TextSelection(baseOffset: m.start, extentOffset: m.end));
    if (boxes.isEmpty) continue;
    var r = boxes.first.toRect();
    for (final b in boxes.skip(1)) {
      r = r.expandToInclude(b.toRect());
    }
    truth.add((m.group(0)!, r.shift(const Offset(margin, margin))));
  }
  tp.dispose();
  final image = await rec.endRecording().toImage(width, height);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return (png: bd!.buffer.asUint8List(), width: width, height: height, truth: truth);
}

final _nonWord = RegExp(r'[^\p{L}\p{M}\p{N}]', unicode: true);

/// Lower-case words without punctuation (any script).
List<String> ocrWords(String s) => [
      for (final w in s.split(RegExp(r'\s+')))
        if (w.replaceAll(_nonWord, '').isNotEmpty) w.replaceAll(_nonWord, '').toLowerCase(),
    ];

/// Share of [truth] words found in [found], counting repeats.
double ocrRecall(List<String> truth, List<String> found) {
  final bag = <String, int>{};
  for (final w in found) {
    bag[w] = (bag[w] ?? 0) + 1;
  }
  var hit = 0;
  for (final w in truth) {
    final n = bag[w] ?? 0;
    if (n > 0) {
      hit++;
      bag[w] = n - 1;
    }
  }
  return truth.isEmpty ? 0 : hit / truth.length;
}

double rectIou(Rect a, Rect b) {
  final i = a.intersect(b);
  if (i.width <= 0 || i.height <= 0) return 0;
  final inter = i.width * i.height;
  return inter / (a.width * a.height + b.width * b.height - inter);
}
