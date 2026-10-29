// T10.0 OCR spike (RELEASE_V1_3 §9): measures, on a device, what ADR-044…046
// depend on. Spike code: it records numbers, it isn't a product test.
//
//   flutter test integration_test/ocr_spike_test.dart -d <android device>
//
// Fixtures are drawn on the device with Flutter's text engine (no personal
// data): OCR-01 (A4 at 300 dpi, 12 pt), OCR-02 (blur, 3° skew, uneven light),
// OCR-04 (OCR-01 stored sideways with EXIF orientation 6) and OCR-05 (Hindi).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pp;
import 'package:pdfrx/pdfrx.dart';

const latinText = 'Meeting notes for the spring planning session. The budget for the second quarter was '
    'approved after a short discussion about travel costs and new equipment for the office.\n\n'
    'Anna will prepare the schedule for the workshop in April. Every team should send its list of '
    'questions before Friday so that the agenda can be printed in time.\n\n'
    'The next review is planned for the fourteenth of May. Please bring the updated figures, the '
    'customer survey results and any open issues from the delivery project.';

const hindiText = 'भारत एक विशाल देश है। यहाँ अनेक भाषाएँ बोली जाती हैं।\n\n'
    'हम सब मिलकर काम करते हैं और समय पर बैठक में आते हैं।';

final _nonWord = RegExp(r'[^\p{L}\p{M}\p{N}]', unicode: true);
List<String> words(String s) =>
    [for (final w in s.split(RegExp(r'\s+'))) if (w.replaceAll(_nonWord, '').isNotEmpty) w.replaceAll(_nonWord, '').toLowerCase()];

/// Share of [truth] words found in [found] (multiset).
double recall(List<String> truth, List<String> found) {
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

double iou(Rect a, Rect b) {
  final i = a.intersect(b);
  if (i.width <= 0 || i.height <= 0) return 0;
  final inter = i.width * i.height;
  return inter / (a.width * a.height + b.width * b.height - inter);
}

typedef Fixture = ({Uint8List png, int w, int h, List<(String, Rect)> truth});

/// White A4 page at 300 dpi with [text] in black at [fontSize] px.
Future<Fixture> drawText(String text, {double fontSize = 50, int w = 2480, int h = 3508}) async {
  const margin = 200.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.white);
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: Colors.black, fontSize: fontSize, height: 1.4)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: w - 2 * margin);
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
  final image = await rec.endRecording().toImage(w, h);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return (png: bd!.buffer.asUint8List(), w: w, h: h, truth: truth);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  const images = NativeImageEngine();
  late Fixture ocr01;
  late Uint8List ocr01Jpg;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'ocr_spike'))..createSync(recursive: true);
    ocr01 = await drawText(latinText);
    ocr01Jpg = img.encodeJpg(img.decodePng(ocr01.png)!, quality: 90);
  });

  Future<(RecognizedText, int)> recognise(String path, TextRecognitionScript script) async {
    final r = TextRecognizer(script: script);
    final sw = Stopwatch()..start();
    final out = await r.processImage(InputImage.fromFilePath(path));
    final ms = sw.elapsedMilliseconds;
    await r.close();
    return (out, ms);
  }

  List<String> foundWords(RecognizedText t) =>
      [for (final b in t.blocks) for (final l in b.lines) for (final e in l.elements) ...words(e.text)];

  Rect extent(RecognizedText t) {
    var r = Rect.zero;
    for (final b in t.blocks) {
      r = r == Rect.zero ? b.boundingBox : r.expandToInclude(b.boundingBox);
    }
    return r;
  }

  /// Mean IoU of truth words against the recognised element with the same text.
  (double, double) boxMatch(List<(String, Rect)> truth, RecognizedText t) {
    final els = [for (final b in t.blocks) for (final l in b.lines) ...l.elements];
    final ious = <double>[];
    for (final (w, box) in truth) {
      final key = words(w).join();
      var best = 0.0;
      for (final e in els) {
        if (words(e.text).join() == key) best = math.max(best, iou(box, e.boundingBox));
      }
      ious.add(best);
    }
    final mean = ious.fold(0.0, (a, b) => a + b) / ious.length;
    return (mean, ious.where((v) => v >= 0.5).length / ious.length);
  }

  String write(String name, List<int> bytes) {
    final f = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  testWidgets('OCR-01 / 02 / 04: recall, box space, time (Latin)', (_) async {
    final truth = [for (final (w, _) in ocr01.truth) ...words(w)];
    final p1 = write('ocr01.jpg', ocr01Jpg);
    final (t1, ms1) = await recognise(p1, TextRecognitionScript.latin);
    final (iouMean, iouShare) = boxMatch(ocr01.truth, t1);
    // ignore: avoid_print
    print('SPIKE OCR-01 recall=${recall(truth, foundWords(t1)).toStringAsFixed(3)} '
        'iouMean=${iouMean.toStringAsFixed(2)} iou>=0.5=${iouShare.toStringAsFixed(3)} ms=$ms1 '
        'lines=${t1.blocks.fold(0, (n, b) => n + b.lines.length)} '
        'conf=${t1.blocks.first.lines.first.confidence} angle=${t1.blocks.first.lines.first.angle}');

    // OCR-02: blur, 3° skew, light falling off to the right.
    var im = img.gaussianBlur(img.decodeJpg(ocr01Jpg)!, radius: 2);
    im = img.copyRotate(im, angle: 3, interpolation: img.Interpolation.linear);
    for (final px in im) {
      final f = 0.6 + 0.4 * (1 - px.x / im.width);
      px
        ..r = px.r * f
        ..g = px.g * f
        ..b = px.b * f;
    }
    final (t2, ms2) = await recognise(write('ocr02.jpg', img.encodeJpg(im, quality: 85)), TextRecognitionScript.latin);
    // ignore: avoid_print
    print('SPIKE OCR-02 recall=${recall(truth, foundWords(t2)).toStringAsFixed(3)} ms=$ms2');

    // OCR-04: pixels turned a quarter left, EXIF 6 says "display turned right" → upright.
    final side = img.copyRotate(img.decodeJpg(ocr01Jpg)!, angle: -90);
    side.exif.imageIfd.orientation = 6;
    final raw = write('ocr04.jpg', img.encodeJpg(side, quality: 90));
    final (t4raw, _) = await recognise(raw, TextRecognitionScript.latin);
    final (rawIou, _) = boxMatch(ocr01.truth, t4raw);
    // ignore: avoid_print
    print('SPIKE OCR-04 raw(EXIF 6, stored ${side.width}x${side.height}) recall='
        '${recall(truth, foundWords(t4raw)).toStringAsFixed(3)} extent=${extent(t4raw)} iouVsUpright=${rawIou.toStringAsFixed(2)}');
    final oriented = await images.transform(raw, p.join(dir.path, 'ocr04_oriented.jpg'),
        const ImageTransform(format: ImageFormat.jpeg, quality: 85));
    final (t4, _) = await recognise(oriented.path, TextRecognitionScript.latin);
    final (oIou, oShare) = boxMatch(ocr01.truth, t4);
    // ignore: avoid_print
    print('SPIKE OCR-04 oriented(${oriented.width}x${oriented.height}) recall='
        '${recall(truth, foundWords(t4)).toStringAsFixed(3)} iouMean=${oIou.toStringAsFixed(2)} iou>=0.5=${oShare.toStringAsFixed(3)}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  /// Image + invisible text, one line per OCR line, per RELEASE_V1_3 §4.5/§4.7.
  Future<Uint8List> searchablePdf(Uint8List jpg, int w, int h, RecognizedText t, ByteData font, {bool text = true}) async {
    final doc = pp.PdfDocument();
    const pw = 595.28, ph = 841.89;
    final page = pp.PdfPage(doc, pageFormat: const pp.PdfPageFormat(pw, ph));
    final g = page.getGraphics();
    g.drawImage(pp.PdfImage.jpeg(doc, image: jpg), 0, 0, pw, ph);
    if (text) {
      final f = pp.PdfTtfFont(doc, font);
      final sx = pw / w, sy = ph / h;
      for (final b in t.blocks) {
        for (final l in b.lines) {
          final r = l.boundingBox;
          final rect = Rect.fromLTRB(r.left * sx, (h - r.bottom) * sy, r.right * sx, (h - r.top) * sy);
          final size = (rect.height * 0.85).clamp(4.0, 200.0);
          final natural = f.stringMetrics(l.text).width * size;
          final scale = natural > 0 ? (rect.width / natural).clamp(0.5, 2.0) : 1.0;
          g.drawString(f, size, l.text, rect.left, rect.bottom + size * 0.15,
              mode: pp.PdfTextRenderingMode.invisible, scale: scale);
        }
      }
    }
    return doc.save();
  }

  Future<Uint8List> renderFirst(String path) async {
    final d = await PdfDocument.openFile(path);
    final pg = d.pages.first;
    final im = (await pg.render(fullWidth: 1240, fullHeight: 1754, width: 1240, height: 1754, backgroundColor: 0xFFFFFFFF))!;
    final px = Uint8List.fromList(im.pixels);
    im.dispose();
    await d.dispose();
    return px;
  }

  testWidgets('searchable PDF: pdfrx finds the words; the layer is invisible (ADR-046)', (_) async {
    final truth = [for (final (w, _) in ocr01.truth) ...words(w)];
    final (t, _) = await recognise(write('ocr01.jpg', ocr01Jpg), TextRecognitionScript.latin);
    final font = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final sw = Stopwatch()..start();
    final withText = write('searchable.pdf', await searchablePdf(ocr01Jpg, ocr01.w, ocr01.h, t, font));
    final buildMs = sw.elapsedMilliseconds;
    final imageOnly = write('image_only.pdf', await searchablePdf(ocr01Jpg, ocr01.w, ocr01.h, t, font, text: false));
    final d = await PdfDocument.openFile(withText);
    final pt = await d.pages.first.loadText();
    await d.dispose();
    final a = await renderFirst(withText), b = await renderFirst(imageOnly);
    var diff = 0;
    for (var i = 0; i < a.length; i += 4) {
      if ((a[i] - b[i]).abs() > 8 || (a[i + 1] - b[i + 1]).abs() > 8 || (a[i + 2] - b[i + 2]).abs() > 8) diff++;
    }
    // ignore: avoid_print
    print('SPIKE PDF textRecall=${recall(truth, words(pt?.fullText ?? '')).toStringAsFixed(3)} '
        'size=${File(withText).lengthSync()}B imageOnly=${File(imageOnly).lengthSync()}B '
        'pixelDiff=${(100 * diff / (a.length / 4)).toStringAsFixed(3)}% buildMs=$buildMs');
    // pdfrx's page-text API on the image-only page (FR-OCR-02 / §4.6).
    final d2 = await PdfDocument.openFile(imageOnly);
    final empty = await d2.pages.first.loadText();
    await d2.dispose();
    // ignore: avoid_print
    print('SPIKE §4.6 imageOnly loadText chars=${empty?.fullText.replaceAll(RegExp(r'\s'), '').length}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('OCR-05 Devanagari: recognition and a search round trip', (_) async {
    final fx = await drawText(hindiText, fontSize: 70);
    final jpg = img.encodeJpg(img.decodePng(fx.png)!, quality: 90);
    final truth = words(hindiText);
    try {
      final (t, ms) = await recognise(write('ocr05.jpg', jpg), TextRecognitionScript.devanagiri);
      // ignore: avoid_print
      print('SPIKE OCR-05 recall=${recall(truth, foundWords(t)).toStringAsFixed(3)} ms=$ms text=${t.text.length}ch');
      final font = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final path = write('hindi.pdf', await searchablePdf(jpg, fx.w, fx.h, t, font));
      final d = await PdfDocument.openFile(path);
      final pt = await d.pages.first.loadText();
      await d.dispose();
      // ignore: avoid_print
      print('SPIKE OCR-05 PDF textRecall=${recall(truth, words(pt?.fullText ?? '')).toStringAsFixed(3)} '
          'vsOcr=${recall(foundWords(t), words(pt?.fullText ?? '')).toStringAsFixed(3)}');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('SPIKE OCR-05 unavailable: ${e.code} ${e.message}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
