// Runs the real PDFium (via pdfrx + pdfium_dart's native-assets hook) on the
// host. Verifies the spike T3.0 questions with generated PDFs.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_header.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/ocr/ocr_layout.dart';
import 'package:docukit/core/ocr/pdfrx_text_reader.dart';
import 'package:docukit/core/ocr/searchable_pdf_builder.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/image_to_pdf_builder.dart';
import 'package:docukit/core/pdf/page_edit.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/validation/output_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx show PdfDocument, PdfPageRawText, pdfrxInitialize;

late Directory tmp;

Future<String> writePdf(String name, List<pw.Page> pages) async {
  final doc = pw.Document();
  pages.forEach(doc.addPage);
  final path = p.join(tmp.path, name);
  await File(path).writeAsBytes(await doc.save());
  return path;
}

pw.Page textPage(String t, {PdfPageFormat format = PdfPageFormat.a4}) =>
    pw.Page(pageFormat: format, build: (_) => pw.Center(child: pw.Text(t, style: const pw.TextStyle(fontSize: 40))));

/// A noisy photo-like JPEG so recompression has something to save.
Uint8List photoJpeg(int w, int h, {int seed = 1}) {
  final r = math.Random(seed);
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, (x * 255 ~/ w + r.nextInt(60)) % 256, (y * 255 ~/ h + r.nextInt(60)) % 256, r.nextInt(256));
    }
  }
  return img.encodeJpg(im, quality: 95);
}

/// Average luminance (0–255) of a page rendered at 60 px wide.
Future<double> meanLuma(String path, int page) async {
  final doc = await pdfrx.PdfDocument.openFile(path);
  try {
    final pg = doc.pages[page];
    final img = (await pg.render(fullWidth: 60, fullHeight: 60 * pg.height / pg.width, backgroundColor: 0xFFFFFFFF))!;
    final px = img.pixels;
    var sum = 0;
    for (var i = 0; i + 3 < px.length; i += 4) {
      sum += (px[i] + px[i + 1] + px[i + 2]) ~/ 3;
    }
    final mean = sum / (px.length / 4);
    img.dispose();
    return mean;
  } finally {
    await doc.dispose();
  }
}

JobContext ctx() {
  final work = Directory(p.join(tmp.path, 'work_${DateTime.now().microsecondsSinceEpoch}'))..createSync();
  return JobContext(jobId: 'test', workDir: work, cancel: CancelToken(), report: (_) {});
}

/// Host stand-in for the native image engine: writes oriented JPEGs with package:image.
class DartImageEngine implements ImageEngine {
  @override
  bool canEncode(ImageFormat format) => format == ImageFormat.jpeg;
  @override
  Future<ImageMeta> inspect(String path) async {
    final h = await readImageHeader(path);
    return ImageMeta(format: h.type, width: h.displayWidth, height: h.displayHeight);
  }

  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    var im = img.decodeImage(File(inPath).readAsBytesSync())!;
    if (t.extraRotation != 0) im = img.copyRotate(im, angle: t.extraRotation);
    final long = math.max(im.width, im.height);
    if (t.maxLongEdge != null && long > t.maxLongEdge!) {
      final s = t.maxLongEdge! / long;
      im = img.copyResize(im, width: (im.width * s).round(), height: (im.height * s).round());
    }
    File(outPath).writeAsBytesSync(img.encodeJpg(im, quality: t.quality));
    return EncodedImage(path: outPath, bytes: File(outPath).lengthSync(), width: im.width, height: im.height, format: ImageFormat.jpeg);
  }
}

void main() {
  // Needs a host PDFium build: run `tool/test_pdf_host.sh` (sets PDFIUM_PATH
  // to the library pdfium_dart's build hook downloads into .dart_tool/).
  if (Platform.environment['PDFIUM_PATH'] == null) {
    test('PDF engine host tests', () {}, skip: 'Set PDFIUM_PATH (see tool/test_pdf_host.sh)');
    return;
  }
  final engine = PdfrxPdfEngine();
  late String text3, photo2, landscape1;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('dk_pdf_');
    await pdfrx.pdfrxInitialize(tmpPath: tmp.path);
    // Removed afterwards: each run left ~230 MB behind before.
    addTearDown(() => tmp.delete(recursive: true));
    text3 = await writePdf('text3.pdf', [textPage('one'), textPage('two'), textPage('three')]);
    // Distinct photos per page: Balanced deliberately skips images shared by
    // several pages (replacing one copy would duplicate the data).
    photo2 = await writePdf('photo2.pdf', [
      for (var i = 0; i < 2; i++)
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(photoJpeg(1600, 2200, seed: 10 + i)), fit: pw.BoxFit.fill),
        ),
    ]);
    landscape1 = await writePdf('land.pdf', [textPage('wide', format: PdfPageFormat.a4.landscape)]);
  });

  test('inspect: page count and sizes', () async {
    final m = await engine.inspect(text3);
    expect(m.pageCount, 3);
    expect(m.pageSizes.first.$1, closeTo(595.28, 1));
    expect((await engine.inspect(landscape1)).pageSizes.single.$1, greaterThan(800));
  });

  test('corrupt and non-PDF inputs map to error codes', () async {
    final bad = p.join(tmp.path, 'bad.pdf');
    await File(bad).writeAsString('%PDF-1.4\n garbage garbage');
    await expectLater(engine.inspect(bad), throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.corruptFile)));
    final notPdf = p.join(tmp.path, 'not.pdf');
    await File(notPdf).writeAsString('hello');
    await expectLater(engine.inspect(notPdf), throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.unsupportedFormat)));
  });

  test('merge: page count is the sum and the output validates', () async {
    final out = p.join(tmp.path, 'merged.pdf');
    await engine.merge([text3, landscape1, photo2], out, ctx());
    expect(await validatePdfOutput(engine, out, expectedPages: 6), 6);
    final m = await engine.inspect(out);
    expect(m.pageSizes[3].$1, greaterThan(m.pageSizes[3].$2), reason: 'landscape page kept');
  });

  test('organize: reorder, rotate and delete are applied', () async {
    final out = p.join(tmp.path, 'org.pdf');
    final edits = [const PageEdit(2, 1), const PageEdit(0)]; // page 3 rotated 90°, then page 1; page 2 deleted
    await engine.organize(text3, edits, out, ctx());
    final m = await engine.inspect(out);
    expect(m.pageCount, 2);
    final (w0, h0) = m.pageSizes[0];
    expect(w0, greaterThan(h0), reason: 'rotated portrait page becomes landscape');
    final (w1, h1) = m.pageSizes[1];
    expect(w1, lessThan(h1));
  });

  test('inputs are never modified', () async {
    final before = await File(text3).readAsBytes();
    await engine.organize(text3, [const PageEdit(0, 2)], p.join(tmp.path, 'x.pdf'), ctx());
    await engine.reduce(text3, p.join(tmp.path, 'y.pdf'), ReduceLevel.basic, ctx());
    expect(await File(text3).readAsBytes(), before);
  });

  test('reduce Basic keeps every page', () async {
    final out = p.join(tmp.path, 'basic.pdf');
    await engine.reduce(text3, out, ReduceLevel.basic, ctx());
    expect(await validatePdfOutput(engine, out, expectedPages: 3, renderLast: true), 3);
  });

  test('reduce Balanced shrinks an image-heavy PDF and keeps pages', () async {
    final out = p.join(tmp.path, 'balanced.pdf');
    await engine.reduce(photo2, out, ReduceLevel.balanced, ctx());
    expect(await validatePdfOutput(engine, out, expectedPages: 2, renderLast: true), 2);
    final inBytes = await File(photo2).length(), outBytes = await File(out).length();
    expect(outBytes, lessThan(inBytes), reason: 'in=$inBytes out=$outBytes');
  });

  test('reduce Strong rasterises every page and keeps the content', () async {
    final out = p.join(tmp.path, 'strong.pdf');
    await engine.reduce(photo2, out, ReduceLevel.strong, ctx());
    expect(await validatePdfOutput(engine, out, expectedPages: 2, renderLast: true), 2);
    expect(await File(out).length(), lessThan(await File(photo2).length()));
    // Regression (found on device): pages came out black when pixels were
    // read after the rendered image was disposed.
    expect(await meanLuma(out, 0), greaterThan(40));
  });

  test('analysis flags an image-heavy PDF', () async {
    final a = await engine.analyse(photo2, await File(photo2).length());
    expect(a.pageCount, 2);
    expect(a.imageCount, 2);
    expect(a.imageHeavy, isTrue);
    final t = await engine.analyse(text3, await File(text3).length());
    expect(t.imageCount, 0);
  });

  test('Images → PDF: one page per image, order and orientation follow the list', () async {
    final portrait = p.join(tmp.path, 'p.jpg'), landscape = p.join(tmp.path, 'l.jpg');
    File(portrait).writeAsBytesSync(photoJpeg(300, 400, seed: 2));
    File(landscape).writeAsBytesSync(photoJpeg(400, 300, seed: 3));
    PickedFile f(String path, int w, int h) => PickedFile(
          path: path,
          displayName: p.basename(path),
          type: SniffedType.jpeg,
          sizeBytes: File(path).lengthSync(),
          image: ImageMeta(format: SniffedType.jpeg, width: w, height: h),
        );
    final builder = ImageToPdfBuilder(DartImageEngine(), engine);
    final out = await builder.build(
      [ImageToPdfItem(f(portrait, 300, 400), 0), ImageToPdfItem(f(landscape, 400, 300), 0), ImageToPdfItem(f(portrait, 300, 400), 1)],
      const ImageToPdfSettings(
        size: PdfPageSize.a4,
        orientation: PdfOrientation.auto,
        fit: PdfFit.fit,
        margin: PdfMargin.small,
        quality: PdfImageQuality.high,
      ),
      ctx(),
    );
    final m = await engine.inspect(out);
    expect(m.pageCount, 3);
    expect(m.pageSizes[0].$1, lessThan(m.pageSizes[0].$2), reason: 'portrait image → portrait page');
    expect(m.pageSizes[1].$1, greaterThan(m.pageSizes[1].$2), reason: 'landscape image → landscape page');
    expect(m.pageSizes[2].$1, greaterThan(m.pageSizes[2].$2), reason: 'rotated portrait → landscape page');
    expect(await validatePdfOutput(engine, out, expectedPages: 3), 3);
  });

  group('existing-text detection (T10.3, RELEASE_V1_3 §4.6)', () {
    const reader = PdfrxTextReader();
    const sentence = 'Meeting notes for the spring planning session';
    pw.Page imagePage(int seed) => pw.Page(
        build: (_) => pw.Image(pw.MemoryImage(photoJpeg(200, 280, seed: seed)), fit: pw.BoxFit.fill));
    pw.Page sentencePage(String t) =>
        pw.Page(build: (_) => pw.Text(t, style: const pw.TextStyle(fontSize: 14)));

    test('OCR-07: an image-only PDF → no page has text', () async {
      final path = await writePdf('ocr07.pdf', [imagePage(1), imagePage(2), imagePage(3)]);
      expect(await reader.textPages(path), [false, false, false]);
    });

    test('OCR-08: page 1 has real text, pages 2–3 are images; the text reads back', () async {
      final path = await writePdf('ocr08.pdf', [sentencePage(sentence), imagePage(4), imagePage(5)]);
      expect(await reader.textPages(path), [true, false, false]);
      expect(await reader.pageText(path, 0), contains('spring planning'));
      expect((await reader.pageText(path, 1)).trim(), isEmpty);
    });

    test('OCR-09: every page has text', () async {
      final path = await writePdf('ocr09.pdf', [sentencePage(sentence), sentencePage('$sentence, page two')]);
      expect(await reader.textPages(path), [true, true]);
    });

    test('a page number alone (< 20 characters) still needs recognising', () async {
      final path = await writePdf('ocr_pageno.pdf', [sentencePage('3')]);
      expect(await reader.textPages(path), [false]);
    });

    test('not a PDF, or a missing file → corruptFile (the engine\'s open rules)', () async {
      final bad = File(p.join(tmp.path, 'bad.pdf'))..writeAsStringSync('not a pdf');
      await expectLater(reader.textPages(bad.path),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.corruptFile)));
      // pdfrx reports a missing file as an open failure, not a FileSystemException.
      await expectLater(reader.textPages(p.join(tmp.path, 'missing.pdf')),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.corruptFile)));
    });
  });

  group('searchable PDF (T10.4, RELEASE_V1_3 §4.7)', () {
    final builder = SearchablePdfBuilder(engine, (a) => File(a).readAsBytes());
    // A 1000×1414 px "photo" drawn full-page on A4.
    const a4 = PdfBox(left: 0, bottom: 0, right: 595.28, top: 841.89);
    late String jpeg;
    setUpAll(() => jpeg = p.join(tmp.path, 'page.jpg'));

    OcrLine line(String text, Rect box, {List<Offset> corners = const []}) => OcrLine(
        text: text,
        box: box,
        corners: corners,
        words: [for (final w in text.split(' ')) OcrWord(text: w, box: box, corners: const [])]);

    Future<RecognisedPage> page(String name, List<OcrLine> lines, {String? image}) async {
      if (!File(jpeg).existsSync()) {
        File(jpeg).writeAsBytesSync(img.encodeJpg(img.Image(width: 1000, height: 1414)..clear(img.ColorRgb8(250, 250, 250))));
      }
      final json = p.join(tmp.path, '$name.json');
      File(json).writeAsStringSync(jsonEncode(OcrPage(imageWidth: 1000, imageHeight: 1414, lines: lines).toJson()));
      return RecognisedPage(jpegPath: image ?? jpeg, ocrPath: json, pageWidth: 595.28, pageHeight: 841.89, imageBox: a4);
    }

    Future<pdfrx.PdfPageRawText> textOf(String path, int index) async {
      final d = await pdfrx.PdfDocument.openFile(path);
      try {
        return (await d.pages[index].loadText())!;
      } finally {
        await d.dispose();
      }
    }

    test('text is extractable, in reading order, and sits on the words', () async {
      final pg = await page('p1', [
        line('Budget approved for Q2', const Rect.fromLTRB(100, 300, 700, 340)),
        line('Meeting notes', const Rect.fromLTRB(100, 100, 500, 150)),
      ]);
      final out = p.join(tmp.path, 'searchable1.pdf');
      final r = await builder.build([pg], OcrScript.latin, out, ctx());
      expect((r.path, r.missingGlyphs), (out, 0));
      final m = await engine.inspect(out);
      expect(m.pageCount, 1);
      expect(m.pageSizes.single.$1, closeTo(595.28, 0.01));
      final t = await textOf(out, 0);
      final text = t.fullText.replaceAll(RegExp(r'\s+'), ' ').trim();
      expect(text, 'Meeting notes Budget approved for Q2', reason: 'reading order (top first)');
      // The characters of "Meeting" overlap where the line is on the page.
      final start = t.fullText.indexOf('Meeting');
      var l = double.infinity, b = double.infinity, rt = -double.infinity, tp = -double.infinity;
      for (var i = start; i < start + 'Meeting notes'.length; i++) {
        final c = t.charRects[i];
        l = math.min(l, c.left);
        b = math.min(b, c.bottom);
        rt = math.max(rt, c.right);
        tp = math.max(tp, c.top);
      }
      final want = toPdfBox(const Rect.fromLTRB(100, 100, 500, 150), imageWidth: 1000, imageHeight: 1414, page: a4);
      final iw = math.min(rt, want.right) - math.max(l, want.left), ih = math.min(tp, want.top) - math.max(b, want.bottom);
      final inter = math.max(0.0, iw) * math.max(0.0, ih);
      final iou = inter / ((rt - l) * (tp - b) + want.width * want.height - inter);
      // ignore: avoid_print
      print('T10.4 host line IoU=${iou.toStringAsFixed(2)} got=($l,$b,$rt,$tp) want=$want');
      expect(iou, greaterThanOrEqualTo(0.5));
    });

    test('the text layer is invisible: same pixels as the image alone (FR-OCR-05)', () async {
      final photo = p.join(tmp.path, 'photo.jpg');
      File(photo).writeAsBytesSync(photoJpeg(1000, 1414, seed: 7));
      final withText = p.join(tmp.path, 'inv_text.pdf'), imageOnly = p.join(tmp.path, 'inv_img.pdf');
      await builder.build([await page('inv1', [line('Hidden words here', const Rect.fromLTRB(100, 100, 900, 200))], image: photo)],
          OcrScript.latin, withText, ctx());
      await builder.build([await page('inv2', const [], image: photo)], OcrScript.latin, imageOnly, ctx());
      Future<List<int>> px(String path) async {
        final d = await pdfrx.PdfDocument.openFile(path);
        try {
          final im = (await d.pages.first.render(fullWidth: 300, fullHeight: 424, backgroundColor: 0xFFFFFFFF))!;
          final copy = List<int>.of(im.pixels);
          im.dispose();
          return copy;
        } finally {
          await d.dispose();
        }
      }

      final a = await px(withText), b = await px(imageOnly);
      var diff = 0;
      for (var i = 0; i < a.length; i++) {
        if ((a[i] - b[i]).abs() > 8) diff++;
      }
      expect(diff, 0);
      expect((await textOf(withText, 0)).fullText, contains('Hidden words here'));
    });

    test('mixed: kept pages are imported unchanged, in order (OCR-08)', () async {
      final source = await writePdf('mixed_src.pdf', [
        pw.Page(build: (_) => pw.Text('Original vector text on the first page')),
        pw.Page(build: (_) => pw.Text('second')),
        pw.Page(build: (_) => pw.Text('Original vector text on the third page')),
      ]);
      final before = (await textOf(source, 0)).fullText;
      final out = p.join(tmp.path, 'mixed_out.pdf');
      await builder.build([
        KeptPage(source, 0),
        await page('m2', [line('Recognised page two', const Rect.fromLTRB(100, 100, 800, 160))]),
        KeptPage(source, 2),
      ], OcrScript.latin, out, ctx());
      expect((await engine.inspect(out)).pageCount, 3);
      expect((await textOf(out, 0)).fullText, before, reason: "page 1's text layer is the original");
      expect((await textOf(out, 1)).fullText, contains('Recognised page two'));
      expect((await textOf(out, 2)).fullText, contains('third page'));
    });

    test('45 pages: three chunks merged in order; work files removed', () async {
      final pages = [
        for (var i = 0; i < 45; i++) await page('c$i', [line('Page number $i', const Rect.fromLTRB(100, 100, 600, 150))]),
      ];
      final c = ctx();
      final out = p.join(tmp.path, 'chunks.pdf');
      await builder.build(pages, OcrScript.latin, out, c);
      expect((await engine.inspect(out)).pageCount, 45);
      for (final i in [0, 19, 20, 44]) {
        expect((await textOf(out, i)).fullText, contains('Page number $i'));
      }
      expect(c.workDir.listSync().where((f) => f.path.contains('searchable_part_')), isEmpty);
    });

    test('cancel before writing → CancelledException, no output', () async {
      final c = ctx();
      c.cancel.cancel();
      final out = p.join(tmp.path, 'cancelled.pdf');
      await expectLater(builder.build([await page('x', const [])], OcrScript.latin, out, c),
          throwsA(isA<CancelledException>()));
      expect(File(out).existsSync(), isFalse);
    });

    test('per-word Devanagari keeps every space (T10.10: "करते हैं" came out "करतेहैं")', () async {
      const words = ['हम', 'सब', 'मिलकर', 'काम', 'करते', 'हैं', 'और', 'मेरे', 'घर', 'में', 'आते', 'हैं'];
      final boxes = <Rect>[];
      var x = 20.0;
      for (final (i, w) in words.indexed) {
        final width = 20.0 * w.runes.length;
        boxes.add(Rect.fromLTRB(x, 100, x + width, 150));
        x += width + (i == 2 ? 80 : 12); // uneven gaps → per-word placement
      }
      final ln = OcrLine(text: words.join(' '), box: Rect.fromLTRB(20, 100, x, 150), corners: const [], words: [
        for (final (i, w) in words.indexed) OcrWord(text: w, box: boxes[i], corners: const []),
      ]);
      expect(placeWordsSeparately(ln), isTrue);
      final out = p.join(tmp.path, 'deva_words.pdf');
      await builder.build([await page('dw', [ln])], OcrScript.devanagari, out, ctx());
      expect((await textOf(out, 0)).fullText.replaceAll(RegExp(r'\s+'), ' ').trim(), words.join(' '));
    });

    test('Devanagari with Latin digits, skewed line, and characters no font has', () async {
      const tilted = [Offset(100, 500), Offset(800, 560), Offset(796, 610), Offset(96, 550)];
      final out = p.join(tmp.path, 'deva.pdf');
      final r = await builder.build([
        await page('d1', [
          line('कुल 250 रुपये', const Rect.fromLTRB(100, 100, 700, 170)),
          line('Price 中文', const Rect.fromLTRB(100, 300, 500, 350)),
          line('tilted line text', const Rect.fromLTRB(96, 500, 800, 610), corners: tilted),
        ]),
      ], OcrScript.devanagari, out, ctx());
      expect(r.missingGlyphs, 2, reason: 'the two CJK characters');
      final text = (await textOf(out, 0)).fullText;
      expect(text, contains('कुल 250 रुपये'));
      expect(text, anyOf(contains('Price \uFFFD\uFFFD'), contains('Price ??')), reason: 'replaced (§4.8), not a crash');
      expect(text, contains('tilted line text'));
    });
  });
}
