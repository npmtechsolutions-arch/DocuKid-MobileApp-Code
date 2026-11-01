// T13.0 spike (a), host PDFium (RELEASE_PRINT §4.3, ADR-070): pages placed as
// form XObjects stay vector (text extractable), come out upright from
// /Rotate 0/90/180/270 (with and without a crop box), land inside their
// cells, and Fill is clipped to its cell (no ink in the gaps).
//
//   PDFIUM_PATH=… flutter test test/core/print_spike_host_test.dart   (see tool/test_pdf_host.sh)
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../../tool/spikes/print_nup_spike.dart';
import '../helpers/pdf_page_setup.dart';

const a4W = 595.28, a4H = 841.89;

/// One-token labels (sideways text can't split them): 1 → A, 2 → B, …
String tag(int i) => String.fromCharCode(64 + i);

({double x, double y}) centre(pdfrx.PdfRect r) => (x: (r.left + r.right) / 2, y: (r.top + r.bottom) / 2);

void main() {
  if (Platform.environment['PDFIUM_PATH'] == null) {
    test('print N-up spike (host)', () {}, skip: 'Set PDFIUM_PATH (see tool/test_pdf_host.sh)');
    return;
  }
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('print_spike');
    await pdfrx.pdfrxInitialize(tmpPath: tmp.path);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  /// [n] A4 pages "TOP k" at the top and "BOTTOM k" at the bottom (or solid
  /// blue), then /Rotate and the crop box.
  Future<String> source(String name, int n, {List<int> turns = const [], double crop = 0, bool blue = false}) async {
    final doc = pw.Document();
    for (var i = 1; i <= n; i++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: blue ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(60),
        build: (_) => blue
            ? pw.Container(color: const PdfColor(0, 0, 1))
            : pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOP${tag(i)}', style: const pw.TextStyle(fontSize: 28)),
                pw.Text('BOT${tag(i)}', style: const pw.TextStyle(fontSize: 28)),
              ]),
      ));
    }
    final raw = p.join(tmp.path, 'raw_$name');
    File(raw).writeAsBytesSync(await doc.save());
    if (turns.isEmpty && crop == 0) return raw;
    final out = p.join(tmp.path, name);
    expect(
        await pdfrx.PdfrxEntryFunctions.instance.compute(
            setupPagesInWorker, PageSetupRequest(raw, out, pdfrx.Pdfrx.pdfiumModulePath, quarterTurns: turns, cropInset: crop)),
        '');
    return out;
  }

  Future<String> compose(String input, String name, {int cols = 1, int rows = 2, SpikeScale scale = SpikeScale.fit}) async {
    final out = p.join(tmp.path, name);
    final err = await pdfrx.PdfrxEntryFunctions.instance.compute(
        nupInWorker,
        NupRequest(
            input: input,
            output: out,
            modulePath: pdfrx.Pdfrx.pdfiumModulePath,
            sheetW: a4W,
            sheetH: a4H,
            cols: cols,
            rows: rows,
            scale: scale,
            debug: true));
    expect(err, '');
    return out;
  }

  /// The sheet's text and a lookup for where a string sits (PDF space, y up).
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

  for (final crop in [0.0, 36.0]) {
    test('2-up, Fit: /Rotate 0/90/180/270${crop > 0 ? ' + 36 pt crop' : ''} → each page as a viewer shows it, in its cell, text extractable',
        () async {
      final src = await source('rot$crop.pdf', 4, turns: [0, 1, 2, 3], crop: crop);
      final out = await compose(src, 'out$crop.pdf');
      final d = await pdfrx.PdfDocument.openFile(out);
      expect(d.pages.length, 2);
      for (final pg in d.pages) {
        expect(pg.width, closeTo(a4W, 0.5));
        expect(pg.height, closeTo(a4H, 0.5));
      }
      await d.dispose();
      final grid = cells(const NupRequest(input: '', output: '', modulePath: null, sheetW: a4W, sheetH: a4H, cols: 1, rows: 2));
      for (var sheet = 0; sheet < 2; sheet++) {
        final (text, at) = await words(out, sheet);
        // ignore: avoid_print
        print('SPIKE crop=$crop sheet $sheet: ${text.replaceAll('\n', ' | ')}');
        for (var c = 0; c < 2; c++) {
          final k = sheet * 2 + c + 1;
          final top = at('TOP${tag(k)}')!, bottom = at('BOT${tag(k)}')!;
          final (cx, cy, cw, ch) = grid[c];
          for (final r in [top, bottom]) {
            expect(r.left >= cx - 0.5 && r.right <= cx + cw + 0.5 && r.bottom >= cy - 0.5 && r.top <= cy + ch + 0.5, isTrue,
                reason: 'page $k inside cell $c');
          }
          // As displayed: TOP→BOT points the same way on the sheet as on the
          // source page the way pdfrx (a viewer) shows it.
          final (_, srcAt) = await words(src, k - 1);
          final (s0, s1) = (centre(srcAt('TOP${tag(k)}')!), centre(srcAt('BOT${tag(k)}')!));
          final (o0, o1) = (centre(top), centre(bottom));
          final (sdx, sdy, odx, ody) = (s1.x - s0.x, s1.y - s0.y, o1.x - o0.x, o1.y - o0.y);
          // ignore: avoid_print
          print('SPIKE page $k (/Rotate ${(k - 1) * 90}): source TOP→BOT (${sdx.round()}, ${sdy.round()}), sheet (${odx.round()}, ${ody.round()})');
          // pdfrx reports text in the page's unrotated space; a viewer turns
          // the page clockwise by /Rotate, so turn the source vector the same way.
          var (ex, ey) = (sdx, sdy);
          for (var q = 0; q < k - 1; q++) {
            (ex, ey) = (ey, -ex); // 90° clockwise, y up
          }
          (String, double) dominant(double dx, double dy) => dx.abs() > dy.abs() ? ('x', dx.sign) : ('y', dy.sign);
          expect(dominant(odx, ody), dominant(ex, ey), reason: 'page $k: as a viewer displays it');
        }
      }
    });
  }

  test('4-up, Fit: 5 pages → 2 sheets; the 5th alone, top-left', () async {
    final out = await compose(await source('five.pdf', 5), 'four.pdf', cols: 2, rows: 2);
    final d = await pdfrx.PdfDocument.openFile(out);
    expect(d.pages.length, 2);
    await d.dispose();
    final (text, at) = await words(out, 1);
    expect(RegExp(r'TOP[A-Z]').allMatches(text).map((m) => m[0]), ['TOPE']);
    expect(at('TOPE')!.left, lessThan(a4W / 2));
    expect(at('TOPE')!.bottom, greaterThan(a4H / 2), reason: 'top row');
  });

  test('2-up, Fill: landscape-cell overflow is clipped to the cell — no ink in the gap or margins', () async {
    final out = await compose(await source('blue.pdf', 2, blue: true), 'fill.pdf', scale: SpikeScale.fill);
    final d = await pdfrx.PdfDocument.openFile(out);
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

    // Gap between the two cells (y in image space, top-down): around the middle.
    final mid = (h / 2).round();
    var gapInk = 0, cellInk = 0, marginInk = 0;
    for (var x = 30; x < w - 30; x++) {
      if (blueAt(x, mid)) gapInk++;
      if (blueAt(x, h ~/ 4)) cellInk++;
      if (blueAt(x, 5)) marginInk++;
    }
    // ignore: avoid_print
    print('SPIKE fill: gap ink=$gapInk cell ink=$cellInk margin ink=$marginInk (of ${w - 60})');
    expect(cellInk, greaterThan((w - 60) * 0.9), reason: 'the cell is filled');
    expect(gapInk, 0, reason: 'clipped: nothing in the 4 mm gap');
    expect(marginInk, 0, reason: 'clipped: nothing in the margin');
  });
}
