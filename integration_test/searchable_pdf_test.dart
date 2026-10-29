// T10.4 on a device (RELEASE_V1_3 §8.2): ML Kit on OCR-01 → SearchablePdfBuilder
// → pdfrx. Searchability (≥ 95% of the words, IoU ≥ 0.5 for found words),
// invisibility (≤ 1% pixel difference) and the mixed PDF OCR-08.
//
//   flutter test integration_test/searchable_pdf_test.dart -d <android device>
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/ocr/mlkit_text_recognizer.dart';
import 'package:docukit/core/ocr/ocr_layout.dart';
import 'package:docukit/core/ocr/searchable_pdf_builder.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

import '../tool/fixtures/ocr_text.dart';

const a4 = PdfBox(left: 0, bottom: 0, right: 595.28, top: 841.89);

/// Page 1's words with PDFium's *loose* character boxes (font ascent to
/// descent): the area a viewer highlights when the word is selected. pdfrx's
/// `charRects` are tight glyph boxes ("notes" is only x-height tall), which
/// don't measure placement. Runs in pdfrx's PDFium worker (see
/// pdfium_raw_ops.dart for why).
List<(String, double, double, double, double)> looseWordsInWorker(String path) {
  final pd = pdfium.getPdfium();
  return using((arena) {
    final doc = pd.FPDF_LoadDocument(path.toNativeUtf8(allocator: arena).cast(), nullptr);
    final page = pd.FPDF_LoadPage(doc, 0);
    final text = pd.FPDFText_LoadPage(page);
    final rect = arena<pdfium.FS_RECTF>();
    final out = <(String, double, double, double, double)>[];
    final word = StringBuffer();
    var l = double.infinity, b = double.infinity, r = -double.infinity, t = -double.infinity;
    void flush() {
      if (word.isNotEmpty) out.add((word.toString(), l, b, r, t));
      word.clear();
      l = b = double.infinity;
      r = t = -double.infinity;
    }

    for (var i = 0, n = pd.FPDFText_CountChars(text); i < n; i++) {
      final u = pd.FPDFText_GetUnicode(text, i);
      if (u == 0 || String.fromCharCode(u).trim().isEmpty) {
        flush();
        continue;
      }
      pd.FPDFText_GetLooseCharBox(text, i, rect);
      l = math.min(l, rect.ref.left);
      r = math.max(r, rect.ref.right);
      b = math.min(b, math.min(rect.ref.top, rect.ref.bottom));
      t = math.max(t, math.max(rect.ref.top, rect.ref.bottom));
      word.writeCharCode(u);
    }
    flush();
    pd.FPDFText_ClosePage(text);
    pd.FPDF_ClosePage(page);
    pd.FPDF_CloseDocument(doc);
    return out;
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late OcrFixture ocr01;
  late String jpeg, ocrJson;
  final engine = PdfrxPdfEngine();
  final builder = SearchablePdfBuilder(engine, (a) async => (await rootBundle.load(a)).buffer.asUint8List());

  JobContext ctx() {
    final w = Directory(p.join(dir.path, 'work_${DateTime.now().microsecondsSinceEpoch}'))..createSync();
    return JobContext(jobId: 'it_searchable', workDir: w, cancel: CancelToken(), report: (_) {});
  }

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_searchable'))..createSync(recursive: true);
    ocr01 = await drawOcrPage(ocrLatinText);
    jpeg = p.join(dir.path, 'ocr01.jpg');
    File(jpeg).writeAsBytesSync(img.encodeJpg(img.decodePng(ocr01.png)!, quality: 85));
    final r = MlKitTextRecognizer();
    final page = await r.recognize(jpeg, OcrScript.latin);
    await r.dispose();
    ocrJson = p.join(dir.path, 'ocr01.json');
    File(ocrJson).writeAsStringSync(jsonEncode(page.toJson()));
  });

  RecognisedPage recognised({String? json}) =>
      RecognisedPage(jpegPath: jpeg, ocrPath: json ?? ocrJson, pageWidth: a4.width, pageHeight: a4.height, imageBox: a4);

  Future<PdfPageRawText> textOf(String path, int index) async {
    final d = await PdfDocument.openFile(path);
    try {
      return (await d.pages[index].loadText())!;
    } finally {
      await d.dispose();
    }
  }

  Future<List<(String, PdfBox)>> extractedWords(String path) async => [
        for (final (w, l, b, r, t) in await PdfrxEntryFunctions.instance.compute(looseWordsInWorker, path))
          if (ocrWords(w).isNotEmpty) (ocrWords(w).join(), PdfBox(left: l, bottom: b, right: r, top: t)),
      ];

  double iouPdf(PdfBox a, PdfBox b) {
    final iw = math.min(a.right, b.right) - math.max(a.left, b.left);
    final ih = math.min(a.top, b.top) - math.max(a.bottom, b.bottom);
    if (iw <= 0 || ih <= 0) return 0;
    final inter = iw * ih;
    return inter / (a.width * a.height + b.width * b.height - inter);
  }

  testWidgets('searchability: ≥ 95% of the words found; found words on their boxes (IoU ≥ 0.5)', (_) async {
    final out = p.join(dir.path, 'searchable.pdf');
    final sw = Stopwatch()..start();
    await builder.build([recognised()], OcrScript.latin, out, ctx());
    final buildMs = sw.elapsedMilliseconds;
    final words = await extractedWords(out);
    final used = List.filled(words.length, false);
    var found = 0, onBox = 0;
    final ious = <double>[];
    for (final (text, box) in ocr01.truth) {
      final key = ocrWords(text).join();
      if (key.isEmpty) continue;
      final want = toPdfBox(box, imageWidth: ocr01.width, imageHeight: ocr01.height, page: a4);
      var best = -1;
      var bestIou = -1.0;
      for (var i = 0; i < words.length; i++) {
        if (used[i] || words[i].$1 != key) continue;
        final v = iouPdf(words[i].$2, want);
        if (v > bestIou) (best, bestIou) = (i, v);
      }
      if (best < 0) continue;
      used[best] = true;
      found++;
      ious.add(bestIou);
      if (bestIou >= 0.5) onBox++;
    }
    final total = ocr01.truth.length;
    final mean = ious.isEmpty ? 0 : ious.reduce((a, b) => a + b) / ious.length;
    final phrase = (await textOf(out, 0)).fullText.replaceAll(RegExp(r'[ \t]+'), ' ');
    // ignore: avoid_print
    print('T10.4 phrase "spring planning session": ${phrase.contains('spring planning session')} '
        'double spaces: ${(await textOf(out, 0)).fullText.contains('  ')}');
    expect((await textOf(out, 0)).fullText, contains('spring planning session'), reason: 'phrase search needs single spaces');
    // ignore: avoid_print
    print('T10.4 searchability found=${(found / total).toStringAsFixed(3)} iou>=0.5=${(onBox / found).toStringAsFixed(3)} '
        'meanIoU=${mean.toStringAsFixed(2)} size=${File(out).lengthSync()}B build=${buildMs}ms');
    expect(found / total, greaterThanOrEqualTo(0.95));
    expect(onBox / found, greaterThanOrEqualTo(0.95), reason: 'each found word overlaps its box by ≥ 50%');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('invisibility: rendered page vs the image-only page ≤ 1% different (FR-OCR-05)', (_) async {
    final empty = p.join(dir.path, 'empty.json');
    File(empty).writeAsStringSync(jsonEncode(OcrPage(imageWidth: ocr01.width, imageHeight: ocr01.height, lines: const []).toJson()));
    final withText = p.join(dir.path, 'inv_text.pdf'), imageOnly = p.join(dir.path, 'inv_image.pdf');
    await builder.build([recognised()], OcrScript.latin, withText, ctx());
    await builder.build([recognised(json: empty)], OcrScript.latin, imageOnly, ctx());
    Future<List<int>> px(String path) async {
      final d = await PdfDocument.openFile(path);
      try {
        final im = (await d.pages.first.render(fullWidth: 1240, fullHeight: 1754, backgroundColor: 0xFFFFFFFF))!;
        final c = List<int>.of(im.pixels);
        im.dispose();
        return c;
      } finally {
        await d.dispose();
      }
    }

    final a = await px(withText), b = await px(imageOnly);
    var diff = 0;
    for (var i = 0; i + 3 < a.length; i += 4) {
      if ((a[i] - b[i]).abs() > 8 || (a[i + 1] - b[i + 1]).abs() > 8 || (a[i + 2] - b[i + 2]).abs() > 8) diff++;
    }
    final share = diff / (a.length / 4);
    // ignore: avoid_print
    print('T10.4 invisibility diff=${(share * 100).toStringAsFixed(3)}%');
    expect(share, lessThanOrEqualTo(0.01));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('OCR-08 mixed PDF: page 1 keeps its original text; pages 2–3 carry the OCR words', (_) async {
    final photo = img.encodeJpg(img.decodePng(ocr01.png)!, quality: 80);
    final doc = pw.Document()
      ..addPage(pw.Page(build: (_) => pw.Text('Original vector text: invoice 2026-10-29, total 1,250.00')))
      ..addPage(pw.Page(build: (_) => pw.Image(pw.MemoryImage(photo))))
      ..addPage(pw.Page(build: (_) => pw.Image(pw.MemoryImage(photo))));
    final source = p.join(dir.path, 'ocr08.pdf');
    File(source).writeAsBytesSync(await doc.save());
    final before = (await textOf(source, 0)).fullText;

    final out = p.join(dir.path, 'ocr08_out.pdf');
    await builder.build([KeptPage(source, 0), recognised(), recognised()], OcrScript.latin, out, ctx());
    expect((await engine.inspect(out)).pageCount, 3);
    expect((await textOf(out, 0)).fullText, before, reason: "page 1's text layer is the original's");
    for (final i in [1, 2]) {
      final words = ocrWords((await textOf(out, i)).fullText);
      expect(ocrRecall(ocrWords(ocrLatinText), words), greaterThanOrEqualTo(0.95), reason: 'page ${i + 1}');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
