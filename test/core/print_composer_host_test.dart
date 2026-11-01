// T13.2 — PdfiumPrintComposer on real PDFium (host), written before the
// implementation (RELEASE_PRINT §4.3, §8, ADR-070): sheet count and sizes,
// vector text kept, /Rotate and crop boxes upright, R70 grouping, Fill
// clipped, real progress, cancel, and an untouched input.
//
//   PDFIUM_PATH=… flutter test test/core/print_composer_host_test.dart   (see tool/test_pdf_host.sh)
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:crypto/crypto.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/print/print_composer.dart';
import 'package:docukit/core/print/print_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../helpers/pdf_page_setup.dart';

const a4W = 595.28, a4H = 841.89;

/// One-token labels: 1 → A, 2 → B, …
String tag(int i) => String.fromCharCode(64 + i);

/// Orients, turns and caps like the native engine, with the `image` package;
/// records each request.
class _HostImageEngine implements ImageEngine {
  final requests = <ImageTransform>[];
  @override
  bool canEncode(ImageFormat format) => true;
  @override
  Future<ImageMeta> inspect(String path) => throw UnimplementedError();
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    requests.add(t);
    var im = img.bakeOrientation(img.decodeImage(File(inPath).readAsBytesSync())!);
    if (t.extraRotation != 0) im = img.copyRotate(im, angle: t.extraRotation);
    final cap = t.maxLongEdge;
    if (cap != null && (im.width > cap || im.height > cap)) {
      im = im.width >= im.height ? img.copyResize(im, width: cap) : img.copyResize(im, height: cap);
    }
    final bytes = img.encodeJpg(im, quality: t.quality);
    File(outPath).writeAsBytesSync(bytes);
    return EncodedImage(path: outPath, bytes: bytes.length, width: im.width, height: im.height, format: ImageFormat.jpeg);
  }
}

({double x, double y}) centre(pdfrx.PdfRect r) => (x: (r.left + r.right) / 2, y: (r.top + r.bottom) / 2);

void main() {
  if (Platform.environment['PDFIUM_PATH'] == null) {
    test('PdfiumPrintComposer (host)', () {}, skip: 'Set PDFIUM_PATH (see tool/test_pdf_host.sh)');
    return;
  }
  late Directory tmp;
  const composer = PdfiumPrintComposer();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('print_host');
    await pdfrx.pdfrxInitialize(tmpPath: tmp.path);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  var jobs = 0;
  JobContext ctx({CancelToken? cancel, List<JobProgress>? progress}) {
    final dir = Directory(p.join(tmp.path, 'job${jobs++}'))..createSync();
    return JobContext(jobId: 'j', workDir: dir, cancel: cancel ?? CancelToken(), report: (pr) => progress?.add(pr));
  }

  /// [n] A4 pages "TOPk" at the top and "BOTk" at the bottom (or solid blue),
  /// then /Rotate and a crop box.
  Future<String> source(String name, int n, {List<int> turns = const [], double crop = 0, bool blue = false}) async {
    final doc = pw.Document();
    for (var i = 1; i <= n; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: blue ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(60),
          build: (_) => blue
              ? pw.Container(color: const PdfColor(0, 0, 1))
              : pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOP${tag(i)}', style: const pw.TextStyle(fontSize: 28)),
                    pw.Text('BOT${tag(i)}', style: const pw.TextStyle(fontSize: 28)),
                  ],
                ),
        ),
      );
    }
    final raw = p.join(tmp.path, 'raw_$name');
    File(raw).writeAsBytesSync(await doc.save());
    if (turns.isEmpty && crop == 0) return raw;
    final out = p.join(tmp.path, name);
    expect(
      await pdfrx.PdfrxEntryFunctions.instance.compute(
        setupPagesInWorker,
        PageSetupRequest(raw, out, pdfrx.Pdfrx.pdfiumModulePath, quarterTurns: turns, cropInset: crop),
      ),
      '',
    );
    return out;
  }

  Future<List<String>> texts(String path) async {
    final d = await pdfrx.PdfDocument.openFile(path);
    try {
      return [for (final pg in d.pages) (await pg.loadText())?.fullText ?? ''];
    } finally {
      await d.dispose();
    }
  }

  Future<(String, pdfrx.PdfRect? Function(String))> words(String path, int page) async {
    final d = await pdfrx.PdfDocument.openFile(path);
    try {
      final t = await d.pages[page].loadStructuredText();
      return (
        t.fullText,
        (String s) {
          final i = t.fullText.indexOf(s);
          return i < 0 ? null : t.charRects.boundingRect(start: i, end: i + s.length);
        },
      );
    } finally {
      await d.dispose();
    }
  }

  test('R69 shape: 10 A4 pages, A4, Auto, Fit, 1 per sheet → print.pdf in the work dir, 10 A4 sheets, text kept', () async {
    final src = await source('ten.pdf', 10);
    final before = sha256.convert(File(src).readAsBytesSync());
    final progress = <JobProgress>[];
    final c = ctx(progress: progress);
    final out = await composer.compose(PdfPrintSource(src), const PrintSettings(), c);
    expect(p.dirname(out.path), c.workDir.path);
    expect(p.basename(out.path), 'print.pdf');
    expect(out.sheetCount, 10);
    expect(out.sheetSizesPt, hasLength(10));
    for (final s in out.sheetSizesPt) {
      expect(s.width, closeTo(a4W, 0.5));
      expect(s.height, closeTo(a4H, 0.5));
    }
    final t = await texts(out.path);
    for (var i = 1; i <= 10; i++) {
      expect(t[i - 1], contains('TOP${tag(i)}'), reason: 'vector text on sheet $i');
    }
    // Real progress per sheet, ending at 10 of 10.
    final det = progress.whereType<Determinate>().toList();
    expect(det, isNotEmpty);
    expect(det.every((d) => d.total == 10 && d.unit == ProgressUnit.pages), isTrue);
    expect(det.last.done, 10);
    expect(sha256.convert(File(src).readAsBytesSync()), before, reason: 'the original is untouched');
  });

  test('R70: Range "2-4, 7", 2 per sheet, Landscape → 2 landscape sheets, pages 2,3 then 4,7, left → right', () async {
    final src = await source('r70.pdf', 10);
    final out = await composer.compose(
      PdfPrintSource(src),
      const PrintSettings(pages: PageSelection.range('2-4, 7'), perSheet: 2, orientation: PrintOrientation.landscape),
      ctx(),
    );
    expect(out.sheetCount, 2);
    for (final s in out.sheetSizesPt) {
      expect(s.width, closeTo(a4H, 0.5));
      expect(s.height, closeTo(a4W, 0.5));
    }
    for (final (sheet, pair) in [(0, (2, 3)), (1, (4, 7))]) {
      final (text, at) = await words(out.path, sheet);
      expect(RegExp(r'TOP[A-Z]').allMatches(text).map((m) => m[0]).toSet(), {'TOP${tag(pair.$1)}', 'TOP${tag(pair.$2)}'});
      expect(at('TOP${tag(pair.$1)}')!.left, lessThan(at('TOP${tag(pair.$2)}')!.left));
    }
  });

  for (final crop in [0.0, 36.0]) {
    test('2 per sheet, Fit: /Rotate 0/90/180/270${crop > 0 ? ' + 36 pt crop' : ''} → each page as a viewer shows it', () async {
      final src = await source('rot$crop.pdf', 4, turns: [0, 1, 2, 3], crop: crop);
      // Portrait keeps the 2 cells stacked whatever the pages' shapes.
      final out = await composer.compose(
        PdfPrintSource(src),
        const PrintSettings(perSheet: 2, orientation: PrintOrientation.portrait, margins: PrintMargins.none),
        ctx(),
      );
      expect(out.sheetCount, 2);
      for (var sheet = 0; sheet < 2; sheet++) {
        final (_, at) = await words(out.path, sheet);
        for (var c = 0; c < 2; c++) {
          final k = sheet * 2 + c + 1;
          final (o0, o1) = (centre(at('TOP${tag(k)}')!), centre(at('BOT${tag(k)}')!));
          final (_, srcAt) = await words(src, k - 1);
          final (s0, s1) = (centre(srcAt('TOP${tag(k)}')!), centre(srcAt('BOT${tag(k)}')!));
          // pdfrx reports source text unrotated; a viewer turns the page
          // clockwise by /Rotate. Pages that show portrait (/Rotate 0, 180)
          // print bigger turned a quarter anticlockwise in the wide cells.
          var (ex, ey) = (s1.x - s0.x, s1.y - s0.y);
          final turnsShown = ((k - 1) + ((k - 1).isEven ? 3 : 0)) % 4;
          for (var q = 0; q < turnsShown; q++) {
            (ex, ey) = (ey, -ex);
          }
          (String, double) dominant(double dx, double dy) => dx.abs() > dy.abs() ? ('x', dx.sign) : ('y', dy.sign);
          final (odx, ody) = (o1.x - o0.x, o1.y - o0.y);
          expect(dominant(odx, ody), dominant(ex, ey), reason: 'page $k (/Rotate ${(k - 1) * 90})');
          // In its own half of the sheet.
          final top = c == 0;
          expect(o0.y > a4H / 2, top, reason: 'page $k in cell $c');
        }
      }
    });
  }

  test('Fill, 2 per sheet: overflow clipped — no ink in the 4 mm gap or the margins', () async {
    final src = await source('blue.pdf', 2, blue: true);
    final out = await composer.compose(
      PdfPrintSource(src),
      const PrintSettings(perSheet: 2, orientation: PrintOrientation.portrait, scaling: PrintScaling.fill),
      ctx(),
    );
    final d = await pdfrx.PdfDocument.openFile(out.path);
    final pg = d.pages[0];
    final w = pg.width.round(), h = pg.height.round();
    final im = (await pg.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
    final px = Uint8List.fromList(im.pixels);
    im.dispose();
    await d.dispose();
    bool blueAt(int x, int y) {
      final i = (y * w + x) * 4;
      return px[i] > 200 && px[i + 2] < 60;
    }

    var gapInk = 0, cellInk = 0, marginInk = 0;
    for (var x = 30; x < w - 30; x++) {
      if (blueAt(x, (h / 2).round())) gapInk++;
      if (blueAt(x, h ~/ 4)) cellInk++;
      if (blueAt(x, 5)) marginInk++;
    }
    expect(cellInk, greaterThan((w - 60) * 0.9));
    expect(gapInk, 0);
    expect(marginInk, 0);
  });

  test('Odd on 5 pages → 3 sheets: A, C, E', () async {
    final out = await composer.compose(
      PdfPrintSource(await source('odd.pdf', 5)),
      const PrintSettings(pages: PageSelection.odd),
      ctx(),
    );
    final t = await texts(out.path);
    expect([for (final s in t) RegExp(r'TOP[A-Z]').firstMatch(s)![0]], ['TOPA', 'TOPC', 'TOPE']);
  });

  test('an invalid range or no pages → invalidInput, nothing written', () async {
    final src = await source('one.pdf', 1);
    for (final s in [
      const PrintSettings(pages: PageSelection.range('3-9')),
      const PrintSettings(pages: PageSelection.even),
    ]) {
      final c = ctx();
      await expectLater(
        composer.compose(PdfPrintSource(src), s, c),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.invalidInput)),
      );
      expect(c.workDir.listSync(), isEmpty);
    }
  });

  test('a corrupt file → corruptFile', () async {
    final bad = p.join(tmp.path, 'bad.pdf');
    File(bad).writeAsStringSync('%PDF-1.7 not really');
    await expectLater(
      composer.compose(PdfPrintSource(bad), const PrintSettings(), ctx()),
      throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.corruptFile)),
    );
  });

  test('cancel → CancelledException and no print.pdf left', () async {
    final src = await source('cancel.pdf', 40);
    final cancel = CancelToken()..cancel();
    final c = ctx(cancel: cancel);
    await expectLater(composer.compose(PdfPrintSource(src), const PrintSettings(), c), throwsA(isA<CancelledException>()));
    expect(File(p.join(c.workDir.path, 'print.pdf')).existsSync(), isFalse);
  });

  test('cancel during the build (after the first sheet) → CancelledException, no print.pdf', () async {
    final src = await source('cancel_mid.pdf', 200);
    final cancel = CancelToken();
    final progress = <JobProgress>[];
    final c = JobContext(
      jobId: 'j',
      workDir: Directory(p.join(tmp.path, 'mid'))..createSync(),
      cancel: cancel,
      report: (pr) {
        progress.add(pr);
        if (pr is Determinate && pr.done >= 1) cancel.cancel();
      },
    );
    await expectLater(composer.compose(PdfPrintSource(src), const PrintSettings(), c), throwsA(isA<CancelledException>()));
    expect(progress.whereType<Determinate>().last.done, lessThan(200), reason: 'stopped before the end');
    expect(File(p.join(c.workDir.path, 'print.pdf')).existsSync(), isFalse);
  });

  test('composing again in the same work dir replaces print.pdf (the preview rebuilds)', () async {
    final src = await source('again.pdf', 4);
    final c = ctx();
    expect((await composer.compose(PdfPrintSource(src), const PrintSettings(), c)).sheetCount, 4);
    final second = await composer.compose(PdfPrintSource(src), const PrintSettings(perSheet: 4), c);
    expect(second.sheetCount, 1);
    expect((await texts(second.path)), hasLength(1));
  });

  group('images (T13.3)', () {
    late _HostImageEngine engine;
    late PdfiumPrintComposer imageComposer;
    setUp(() {
      engine = _HostImageEngine();
      imageComposer = PdfiumPrintComposer(images: engine, pdf: PdfrxPdfEngine());
    });

    var n = 0;
    PickedFile jpeg(int w, int h, {List<int> rgb = const [220, 30, 30], bool missingMeta = false}) {
      final im = img.Image(width: w, height: h)..clear(img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
      final path = p.join(tmp.path, 'img${n++}.jpg');
      final bytes = img.encodeJpg(im, quality: 95);
      File(path).writeAsBytesSync(bytes);
      return PickedFile(
        path: path,
        displayName: 'photo.jpg',
        type: SniffedType.jpeg,
        sizeBytes: bytes.length,
        image: missingMeta ? null : ImageMeta(format: SniffedType.jpeg, width: w, height: h),
      );
    }

    Future<(int, int, Uint8List)> render(String path, int page, double scale) async {
      final d = await pdfrx.PdfDocument.openFile(path);
      try {
        final pg = d.pages[page];
        final w = (pg.width * scale).round(), h = (pg.height * scale).round();
        final im = (await pg.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
        final px = Uint8List.fromList(im.pixels);
        im.dispose();
        return (w, h, px);
      } finally {
        await d.dispose();
      }
    }

    test('Full page: one sheet per image, Auto per image, ≤ 300 dpi requested, original untouched', () async {
      final wide = jpeg(600, 450), tall = jpeg(450, 600, rgb: [30, 30, 220]);
      final before = sha256.convert(File(wide.path).readAsBytesSync());
      final progress = <JobProgress>[];
      final c = ctx(progress: progress);
      final out = await imageComposer.compose(ImagesPrintSource([wide, tall]), const PrintSettings(), c);
      expect(out.sheetCount, 2);
      expect(out.sheetSizesPt[0].width, closeTo(a4H, 0.5), reason: 'landscape for the wide photo');
      expect(out.sheetSizesPt[1].width, closeTo(a4W, 0.5));
      for (final t in engine.requests) {
        expect(t.format, ImageFormat.jpeg);
        expect(t.maxLongEdge, 600, reason: 'already under 300 dpi of the printed size: not upscaled');
        expect(t.extraRotation, 0);
        expect(t.stripMetadata, isTrue);
      }
      final (w, h, px) = await render(out.path, 0, 0.5);
      final i = ((h ~/ 2) * w + w ~/ 2) * 4;
      // pdfrx renders BGRA.
      expect(px[i + 2], greaterThan(180), reason: 'red at the centre');
      expect(px[i], lessThan(80));
      expect(sha256.convert(File(wide.path).readAsBytesSync()), before);
      expect(progress.whereType<Determinate>().last.done, 2);
      // Only print.pdf is left in the work dir.
      expect(c.workDir.listSync().map((e) => p.basename(e.path)), ['print.pdf']);
    });

    test('a big photo is capped at 300 dpi of its printed size', () async {
      final big = jpeg(4000, 3000);
      await imageComposer.compose(ImagesPrintSource([big]), const PrintSettings(paper: PaperSize.in4x6), ctx());
      // 4000 × 3000 px is 1920 × 1440 pt at 150 dpi; Fit on landscape 4×6 in
      // inside 6 mm margins is limited by the height; then 300 dpi of that.
      final m = PrintMargins.narrow.pt;
      final fit = math.min((432 - 2 * m) / 1920, (288 - 2 * m) / 1440);
      final expected = (1920 * fit / 72 * 300).ceil();
      expect(expected, lessThan(4000));
      expect(engine.requests.single.maxLongEdge, closeTo(expected, 2));
    });

    test('Portrait chosen for a wide photo at 1 per sheet: the photo is turned a quarter anticlockwise', () async {
      final out = await imageComposer.compose(
        ImagesPrintSource([jpeg(600, 450)]),
        const PrintSettings(orientation: PrintOrientation.portrait),
        ctx(),
      );
      expect(out.sheetSizesPt.single.width, closeTo(a4W, 0.5));
      expect(engine.requests.single.extraRotation, 270);
    });

    test('2 per sheet: 5 photos → 3 sheets; 45 photos full page → 45 sheets in order (chunks of 20 merged)', () async {
      final five = await imageComposer.compose(
        ImagesPrintSource([for (var i = 0; i < 5; i++) jpeg(60, 80)]),
        const PrintSettings(imageLayout: ImageLayout.twoUp),
        ctx(),
      );
      expect(five.sheetCount, 3);
      final many = [for (var i = 0; i < 45; i++) i % 3 == 0 ? jpeg(80, 60) : jpeg(60, 80)];
      final c = ctx();
      final out = await imageComposer.compose(ImagesPrintSource(many), const PrintSettings(), c);
      expect(out.sheetCount, 45);
      final d = await pdfrx.PdfDocument.openFile(out.path);
      expect([for (final pg in d.pages) pg.width > pg.height], [for (var i = 0; i < 45; i++) i % 3 == 0]);
      await d.dispose();
      expect(c.workDir.listSync().map((e) => p.basename(e.path)), ['print.pdf'], reason: 'chunks and JPEGs removed');
    });

    test('R72 shape: passport sheet on 4×6 in, no margins → 8 photos, 35 × 45 mm, the JPEG embedded once, cut marks', () async {
      final face = jpeg(413, 531, rgb: [40, 160, 60]);
      final second = jpeg(600, 450);
      final out = await imageComposer.compose(
        ImagesPrintSource([face, second]),
        const PrintSettings(imageLayout: ImageLayout.passportSheet, paper: PaperSize.in4x6, margins: PrintMargins.none),
        ctx(),
      );
      expect(out.sheetCount, 1);
      expect(out.sheetSizesPt.single, const Size(432, 288));
      expect(engine.requests, hasLength(1), reason: 'the first image only, prepared once');
      expect(engine.requests.single.maxLongEdge, 531, reason: '45 mm at 300 dpi ≈ 532 px, capped at the original');
      final raw = File(out.path).readAsBytesSync();
      expect(RegExp('/Subtype\\s*/Image').allMatches(String.fromCharCodes(raw)).length, 1, reason: 'one shared image');

      // Measure on a 4 px/pt render: each photo is 35 × 45 mm (±0.5 mm), and
      // the photos are green; the 2 mm gaps aren't.
      const scale = 4.0, mmPx = scale * 72 / 25.4;
      final (w, h, px) = await render(out.path, 0, scale);
      bool green(int x, int y) {
        final i = (y * w + x) * 4;
        return px[i + 1] > 120 && px[i] < 100;
      }

      final midRow = (h * 0.25).round();
      final runs = <int>[];
      var run = 0;
      for (var x = 0; x < w; x++) {
        if (green(x, midRow)) {
          run++;
        } else if (run > 0) {
          runs.add(run);
          run = 0;
        }
      }
      if (run > 0) runs.add(run);
      expect(runs, hasLength(4), reason: '4 photos across');
      for (final r in runs) {
        expect(r / mmPx, closeTo(35, 0.5));
      }
      final midCol = (w * 0.1).round();
      var down = 0, best = 0;
      for (var y = 0; y < h; y++) {
        down = green(midCol, y) ? down + 1 : 0;
        if (down > best) best = down;
      }
      expect(best / mmPx, closeTo(45, 0.5));

      // A cut mark: light grey ink just outside the first photo's top-left corner.
      final x0 = ((432 - (4 * 35 + 3 * 2) * 72 / 25.4) / 2 * scale).round();
      final y0 = ((288 - (2 * 45 + 2) * 72 / 25.4) / 2 * scale).round();
      var marks = 0;
      for (var y = (y0 - 3 * mmPx).round().clamp(0, h - 1); y < y0 - 1; y++) {
        for (var x = x0 - 2; x <= x0 + 2; x++) {
          final i = (y * w + x) * 4;
          if (px[i] < 245 && !green(x, y)) marks++;
        }
      }
      expect(marks, greaterThan(0), reason: 'a cut mark above the corner');
    });

    test('passport counts with margins on 4×6 in: narrow 2 × 3 = 6, normal 2 × 2 = 4 (portrait)', () async {
      for (final (m, cols, rows) in [(PrintMargins.narrow, 2, 3), (PrintMargins.normal, 2, 2)]) {
        final out = await imageComposer.compose(
          ImagesPrintSource([jpeg(413, 531, rgb: [40, 160, 60])]),
          PrintSettings(imageLayout: ImageLayout.passportSheet, paper: PaperSize.in4x6, margins: m),
          ctx(),
        );
        expect(out.sheetSizesPt.single, const Size(288, 432));
        final (w, h, px) = await render(out.path, 0, 2);
        bool green(int x, int y) {
          final i = (y * w + x) * 4;
          return px[i + 1] > 120 && px[i] < 100;
        }

        // Runs of green across the middle of the first photo row / down its first column.
        int runs(Iterable<bool> line) {
          var count = 0, prev = false;
          for (final g in line) {
            if (g && !prev) count++;
            prev = g;
          }
          return count;
        }

        final firstRowY = List.generate(h, (y) => y).firstWhere((y) => List.generate(w, (x) => x).any((x) => green(x, y)));
        final firstColX = List.generate(w, (x) => x).firstWhere((x) => List.generate(h, (y) => y).any((y) => green(x, y)));
        expect(runs([for (var x = 0; x < w; x++) green(x, firstRowY + 20)]), cols, reason: '$m across');
        expect(runs([for (var y = 0; y < h; y++) green(firstColX + 20, y)]), rows, reason: '$m down');
      }
    });

    test('an image without metadata → corruptFile; a failed conversion → its error; nothing left', () async {
      final c = ctx();
      await expectLater(
        imageComposer.compose(ImagesPrintSource([jpeg(60, 80, missingMeta: true)]), const PrintSettings(), c),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.corruptFile)),
      );
      final broken = PickedFile(
        path: p.join(tmp.path, 'missing.jpg'),
        displayName: 'x.jpg',
        type: SniffedType.jpeg,
        sizeBytes: 1,
        image: const ImageMeta(format: SniffedType.jpeg, width: 10, height: 10),
      );
      final c2 = ctx();
      await expectLater(
        PdfiumPrintComposer(images: _FailingEngine(), pdf: PdfrxPdfEngine())
            .compose(ImagesPrintSource([broken]), const PrintSettings(), c2),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.unsupportedFormat)),
      );
      expect(c.workDir.listSync(), isEmpty);
      expect(c2.workDir.listSync(), isEmpty);
    });

    test('passport on paper too small for a photo → invalidInput', () async {
      await expectLater(
        imageComposer.compose(
          ImagesPrintSource([jpeg(100, 100)]),
          const PrintSettings(imageLayout: ImageLayout.passportSheet, paper: PaperSize.sameAsDocument),
          ctx(),
        ),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.invalidInput)),
      );
    });

    test('cancel while preparing images → CancelledException, nothing left', () async {
      final cancel = CancelToken();
      final c = JobContext(
        jobId: 'j',
        workDir: Directory(p.join(tmp.path, 'imgcancel'))..createSync(),
        cancel: cancel,
        report: (pr) {
          if (pr is Determinate && pr.done >= 1) cancel.cancel();
        },
      );
      await expectLater(
        imageComposer.compose(ImagesPrintSource([for (var i = 0; i < 5; i++) jpeg(60, 80)]), const PrintSettings(), c),
        throwsA(isA<CancelledException>()),
      );
      expect(c.workDir.listSync(), isEmpty);
    });
  });
}

class _FailingEngine implements ImageEngine {
  @override
  bool canEncode(ImageFormat format) => true;
  @override
  Future<ImageMeta> inspect(String path) => throw UnimplementedError();
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) =>
      throw const AppError(AppErrorCode.unsupportedFormat);
}
