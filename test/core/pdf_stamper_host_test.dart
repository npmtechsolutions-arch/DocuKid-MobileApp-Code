// T11.5 — PdfiumStamper on real PDFium (host), written before the
// implementation (RELEASE_V1_4 §4.2, §4.4, ADR-048): placement within ±1 pt
// on /Rotate 0/90/180/270 with and without a crop box, a rotated stamp,
// transparency, opacity, one shared XObject per image (size), real progress,
// cancel, and an untouched input.
//
//   PDFIUM_PATH=… flutter test test/core/pdf_stamper_host_test.dart   (see tool/test_pdf_host.sh)
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_stamper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx show PdfDocument, PdfrxEntryFunctions, Pdfrx, pdfrxInitialize;

import '../helpers/pdf_page_setup.dart';

void main() {
  if (Platform.environment['PDFIUM_PATH'] == null) {
    test('PdfiumStamper (host)', () {}, skip: 'Set PDFIUM_PATH (see tool/test_pdf_host.sh)');
    return;
  }
  late Directory tmp;
  late String marker;
  const stamper = PdfiumStamper();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('stamper_host');
    await pdfrx.pdfrxInitialize(tmpPath: tmp.path);
    // 200×100 px, transparent, with a red marker in its top-left quarter.
    final im = img.Image(width: 200, height: 100, numChannels: 4);
    for (var y = 0; y < 25; y++) {
      for (var x = 0; x < 50; x++) {
        im.setPixelRgba(x, y, 255, 0, 0, 255);
      }
    }
    marker = p.join(tmp.path, 'marker.png');
    File(marker).writeAsBytesSync(img.encodePng(im));
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  /// [pages] A4 pages filled with solid blue, then /Rotate and crop applied.
  Future<String> base(String name, int pages, {List<int> turns = const [], double crop = 0}) async {
    final doc = pw.Document();
    for (var i = 0; i < pages; i++) {
      doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (_) => pw.Container(color: const PdfColor(0, 0, 1))));
    }
    final raw = p.join(tmp.path, 'raw_$name');
    File(raw).writeAsBytesSync(await doc.save());
    if (turns.isEmpty && crop == 0) return raw;
    final out = p.join(tmp.path, name);
    final err = await pdfrx.PdfrxEntryFunctions.instance.compute(
        setupPagesInWorker, PageSetupRequest(raw, out, pdfrx.Pdfrx.pdfiumModulePath, quarterTurns: turns, cropInset: crop));
    expect(err, '');
    return out;
  }

  JobContext ctx({CancelToken? cancel, List<JobProgress>? progress}) => JobContext(
      jobId: 'j', workDir: tmp, cancel: cancel ?? CancelToken(), report: (pr) => progress?.add(pr));

  /// Rendered at 1 px per point in visual space: (b, g, r) at (x, y).
  Future<(int, int, int) Function(int, int)> render(String path, int page) async {
    final d = await pdfrx.PdfDocument.openFile(path);
    final pg = d.pages[page];
    final w = pg.width.round(), h = pg.height.round();
    final im = (await pg.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
    final Uint8List px = Uint8List.fromList(im.pixels);
    im.dispose();
    await d.dispose();
    return (int x, int y) {
      final i = (y * w + x) * 4;
      return (px[i], px[i + 1], px[i + 2]);
    };
  }

  bool isRed((int, int, int) c) => c.$3 > 200 && c.$1 < 60 && c.$2 < 60;
  bool isBlue((int, int, int) c) => c.$1 > 200 && c.$3 < 60;
  Stamp at(int page, {double rot = 0, double opacity = 1, String? png}) => Stamp(
      pageIndex: page, pngPath: png ?? marker, visualRect: const Rect.fromLTWH(40, 60, 200, 100), rotationDegrees: rot, opacity: opacity);

  for (final crop in [0.0, 36.0]) {
    test('placement on /Rotate 0/90/180/270${crop > 0 ? ' with a 36 pt crop box (PDF-15)' : ' (PDF-04)'}: '
        'marker where the editor put it (±1 pt); transparency kept', () async {
      final input = await base('rot_$crop.pdf', 4, turns: const [0, 1, 2, 3], crop: crop);
      final out = p.join(tmp.path, 'rot_${crop}_out.pdf');
      await stamper.apply(input, [for (var i = 0; i < 4; i++) at(i)], out, ctx());
      for (var i = 0; i < 4; i++) {
        final px = await render(out, i);
        expect(isRed(px(65, 72)), isTrue, reason: 'page ${i * 90}°: marker inside');
        expect(isRed(px(41, 61)), isTrue, reason: 'page ${i * 90}°: marker corner (±1 pt)');
        expect(isBlue(px(38, 58)), isTrue, reason: 'page ${i * 90}°: outside the stamp');
        expect(isBlue(px(92, 72)), isTrue, reason: 'page ${i * 90}°: marker ends at 90 (±1 pt)');
        expect(isBlue(px(180, 140)), isTrue, reason: 'page ${i * 90}°: transparent part shows the page');
      }
    });
  }

  test('a stamp rotated 90° clockwise: its marker moves to the top-right', () async {
    final input = await base('srot.pdf', 1);
    final out = p.join(tmp.path, 'srot_out.pdf');
    await stamper.apply(input, [at(0, rot: 90)], out, ctx());
    final px = await render(out, 0);
    expect(isRed(px(178, 35)), isTrue);
    expect(isBlue(px(100, 35)), isTrue);
  });

  test('opacity 50% is a blend; the same PNG at two opacities is two images; two stamps on one page', () async {
    final input = await base('alpha.pdf', 1);
    final out = p.join(tmp.path, 'alpha_out.pdf');
    await stamper.apply(
        input,
        [
          at(0, opacity: 0.5),
          Stamp(pageIndex: 0, pngPath: marker, visualRect: const Rect.fromLTWH(300, 500, 200, 100), rotationDegrees: 0, opacity: 1),
        ],
        out,
        ctx());
    final px = await render(out, 0);
    final half = px(65, 72);
    expect(half.$3, inInclusiveRange(90, 170), reason: 'half red');
    expect(half.$1, inInclusiveRange(90, 170), reason: 'half the blue page');
    expect(isRed(px(325, 512)), isTrue, reason: 'the second, opaque stamp');
  });

  test('300 pages, one stamp each: one shared XObject (< 30 KB/page), real progress, input unchanged', () async {
    final input = await base('p300.pdf', 300);
    final before = sha256.convert(File(input).readAsBytesSync());
    final out = p.join(tmp.path, 'p300_out.pdf');
    final progress = <JobProgress>[];
    await stamper.apply(input, [for (var i = 0; i < 300; i++) at(i)], out, ctx(progress: progress));
    final grow = (File(out).lengthSync() - File(input).lengthSync()) / 300 / 1024;
    // ignore: avoid_print
    print('T11.5 300 pages: +${grow.toStringAsFixed(2)} KB/page');
    expect(grow, lessThan(30));
    final d = progress.whereType<Determinate>().toList();
    expect(d.first.stepKey, 'stepAddingStamps');
    expect(d.map((x) => x.total).toSet(), {300});
    expect(d.last.done, 299, reason: 'a real page count, not invented');
    expect(sha256.convert(File(input).readAsBytesSync()), before);
    final doc = await pdfrx.PdfDocument.openFile(out);
    expect(doc.pages.length, 300);
    await doc.dispose();
  });

  test('only some pages: pages without a stamp are left as they were; progress counts stamped pages only', () async {
    final input = await base('some.pdf', 5);
    final out = p.join(tmp.path, 'some_out.pdf');
    final progress = <JobProgress>[];
    await stamper.apply(input, [at(1), at(3)], out, ctx(progress: progress));
    expect(progress.whereType<Determinate>().map((x) => x.total).toSet(), {2});
    expect(isRed((await render(out, 1))(65, 72)), isTrue);
    expect(isBlue((await render(out, 2))(65, 72)), isTrue);
  });

  test('cancel → CancelledException and no output; a page outside the PDF → invalidInput', () async {
    final input = await base('cancel.pdf', 3);
    final out = p.join(tmp.path, 'cancel_out.pdf');
    await expectLater(stamper.apply(input, [at(0)], out, ctx(cancel: CancelToken()..cancel())),
        throwsA(isA<CancelledException>()));
    expect(File(out).existsSync(), isFalse);
    await expectLater(stamper.apply(input, [at(7)], out, ctx()),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.invalidInput)));
    expect(File(out).existsSync(), isFalse);
  });

  test('a PNG larger than 2400 px is scaled down and still placed', () async {
    final big = img.Image(width: 3000, height: 1500, numChannels: 4);
    for (var y = 0; y < 375; y++) {
      for (var x = 0; x < 750; x++) {
        big.setPixelRgba(x, y, 255, 0, 0, 255);
      }
    }
    final png = p.join(tmp.path, 'big.png');
    File(png).writeAsBytesSync(img.encodePng(big));
    final input = await base('big.pdf', 1);
    final out = p.join(tmp.path, 'big_out.pdf');
    await stamper.apply(input, [at(0, png: png)], out, ctx());
    expect(isRed((await render(out, 0))(65, 72)), isTrue);
  });
}
