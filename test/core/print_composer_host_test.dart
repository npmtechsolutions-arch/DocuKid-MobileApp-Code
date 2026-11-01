// T13.2 — PdfiumPrintComposer on real PDFium (host), written before the
// implementation (RELEASE_PRINT §4.3, §8, ADR-070): sheet count and sizes,
// vector text kept, /Rotate and crop boxes upright, R70 grouping, Fill
// clipped, real progress, cancel, and an untouched input.
//
//   PDFIUM_PATH=… flutter test test/core/print_composer_host_test.dart   (see tool/test_pdf_host.sh)
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/print/print_composer.dart';
import 'package:docukit/core/print/print_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../helpers/pdf_page_setup.dart';

const a4W = 595.28, a4H = 841.89;

/// One-token labels: 1 → A, 2 → B, …
String tag(int i) => String.fromCharCode(64 + i);

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
}
