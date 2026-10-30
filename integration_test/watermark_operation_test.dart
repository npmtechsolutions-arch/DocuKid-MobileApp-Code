// T11.8 on a device (RELEASE_V1_4 R52, R53, §8.3 watermark rows, FR-WMK-09):
// the Watermark job through JobRunner with the real PdfiumStamper and
// validators. R52 text diagonal at 25% on every page (ink only inside the
// stamp's box; a blend, not solid). R53 a transparent logo bottom-right on the
// odd pages of PDF-04 (rotated pages): ±1 pt, its transparent centre shows the
// page, even pages untouched. 300-page tile: time and KB/page recorded.
//
//   flutter test integration_test/watermark_operation_test.dart -d <android device>
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_stamper.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/pdf/stamp_check.dart';
import 'package:docukit/core/pdf/text_stamp_renderer.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/core/validation/output_validator.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_watermark/application/watermark_layout.dart';
import 'package:docukit/features/pdf_watermark/application/watermark_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import '../test/helpers/pdf_page_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final engine = PdfrxPdfEngine();
  late AppPaths paths;
  late JobRunner runner;
  late Directory dir;
  final op = WatermarkPdfOperation(
    const PdfiumStamper(),
    validatePages: (path, expected) => validatePdfOutput(engine, path, expectedPages: expected),
    stampVisible: (path, page, box, size) => stampHasInk(engine, path, page, box, size, threshold: 252),
  );

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    runner = JobRunner(
        paths: paths,
        history: HistoryRepository(AppDatabase(NativeDatabase.memory())),
        outputs: OutputsRepository(paths),
        device: NativeDeviceServices(DocukitNative()));
    dir = paths.jobIn('it_wmk')..createSync(recursive: true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<PickedFile> corpus(String name, int pages, {List<int> turns = const []}) async {
    final doc = pw.Document();
    for (var i = 0; i < pages; i++) {
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Text('Report page ${i + 1}')));
    }
    var path = p.join(dir.path, 'raw_$name');
    File(path).writeAsBytesSync(await doc.save());
    if (turns.isNotEmpty) {
      final out = p.join(dir.path, name);
      expect(await PdfrxEntryFunctions.instance.compute(
          setupPagesInWorker, PageSetupRequest(path, out, Pdfrx.pdfiumModulePath, quarterTurns: turns)), '');
      path = out;
    }
    final meta = await engine.inspect(path);
    await engine.close(path);
    return PickedFile(path: path, displayName: name, type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: meta);
  }

  WatermarkOptions opts(PickedFile f, String png, double aspect,
          {required WatermarkPosition position, int size = 60, int opacity = 25, PageMode mode = PageMode.all, bool image = false}) =>
      WatermarkOptions(
        pngPath: png,
        aspect: aspect,
        image: image,
        position: position,
        sizePct: size,
        opacityPct: opacity,
        rotation: defaultRotation(position),
        pageMode: mode,
        pages: selectPages(mode, '', f.pdf!.pageCount)!,
        pageSizes: [for (final (w, h) in f.pdf!.pageSizes) Size(w, h)],
      );

  Future<JobResult> run(String id, PickedFile f, WatermarkOptions o) async {
    final states = <JobState>[];
    await runner.run(jobId: id, op: op, inputs: [f], options: o, cancel: CancelToken(), emit: states.add);
    expect(states.last, isA<JobCompleted>(), reason: '${states.last}');
    return (states.last as JobCompleted).result;
  }

  /// The page at 1 px per point: (w, h, BGRA).
  Future<(int, int, Uint8List)> render(String path, int page) async {
    final d = await PdfDocument.openFile(path);
    try {
      final pg = d.pages[page];
      final w = pg.width.round(), h = pg.height.round();
      final im = (await pg.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
      final px = Uint8List.fromList(im.pixels);
      im.dispose();
      return (w, h, px);
    } finally {
      await d.dispose();
    }
  }

  Rect? box((int, int, Uint8List) r, bool Function(int b, int g, int r) hit) {
    final (w, h, px) = r;
    int? x0, y0, x1, y1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (hit(px[i], px[i + 1], px[i + 2])) {
          x0 = x0 == null || x < x0 ? x : x0;
          y0 = y0 == null || y < y0 ? y : y0;
          x1 = x1 == null || x > x1 ? x : x1;
          y1 = y1 == null || y > y1 ? y : y1;
        }
      }
    }
    return x0 == null ? null : Rect.fromLTRB(x0.toDouble(), y0!.toDouble(), x1! + 1.0, y1! + 1.0);
  }

  testWidgets('R52: "CONFIDENTIAL", centre diagonal, 25%, all pages — inside the preview box; a blend, not solid',
      (tester) async {
    final f = await corpus('report.pdf', 3);
    final t = (await tester.runAsync(() => renderTextPng('CONFIDENTIAL',
        outPath: p.join(dir.path, 'conf.png'), colour: const Color(0xFFD32F2F), heightPt: 60, bold: true)))!;
    final o = opts(f, t.pngPath, t.widthPt / t.heightPt, position: WatermarkPosition.diagonal);
    final r = await run('it-wmk-1', f, o);
    expect(r.meta.flags['stamped'], 3);
    final expected = rotatedBounds(o.stamps().first.visualRect, -35);
    for (var i = 0; i < 3; i++) {
      final page = await render(r.outputPath, i);
      // Watermark red over white at 25%: R high, G/B lowered but far from the 0x2F of solid ink.
      final ink = box(page, (b, g, r) => r > 230 && g < 225 && g > 150 && (b - g).abs() < 20)!;
      // ignore: avoid_print
      print('T11.8 R52 page ${i + 1}: ink $ink inside $expected');
      expect(expected.inflate(1).contains(ink.topLeft) && expected.inflate(1).contains(ink.bottomRight), isTrue);
      expect(ink.width, greaterThan(expected.width * 0.8), reason: 'the whole word is there');
      final solid = box(page, (b, g, r) => r > 180 && g < 90);
      expect(solid, isNull, reason: 'opacity applied: no fully opaque red');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('R53: a logo with transparency, bottom-right, odd pages of PDF-04 (rotated) — ±1 pt, hole kept', (tester) async {
    // IMG-25 stand-in: a 300×200 green frame, 40 px thick, transparent inside.
    final logo = img.Image(width: 300, height: 200, numChannels: 4);
    for (final px in logo) {
      final edge = px.x < 40 || px.x >= 260 || px.y < 40 || px.y >= 160;
      if (edge) px.setRgba(0, 160, 0, 255);
    }
    final png = p.join(dir.path, 'logo.png');
    File(png).writeAsBytesSync(img.encodePng(logo));
    final f = await corpus('rotated_pages.pdf', 4, turns: const [0, 1, 2, 3]);
    final o = opts(f, png, 1.5, position: WatermarkPosition.bottomRight, size: 30, opacity: 80, mode: PageMode.odd, image: true);
    final r = await run('it-wmk-2', f, o);
    expect(r.meta.flags['stamped'], 2);
    bool green(int b, int g, int r) => g > 120 && r < 120 && b < 120;
    for (var i = 0; i < 4; i++) {
      final page = await render(r.outputPath, i);
      final got = box(page, green);
      if (i.isOdd) {
        expect(got, isNull, reason: 'page ${i + 1} is even: untouched');
        continue;
      }
      final want = o.stamps().firstWhere((s) => s.pageIndex == i).visualRect;
      // ignore: avoid_print
      print('T11.8 R53 page ${i + 1} (${i * 90}°): logo $got, placed $want');
      for (final (a, b) in [(got!.left, want.left), (got.top, want.top), (got.right, want.right), (got.bottom, want.bottom)]) {
        expect(a, closeTo(b, 1.0), reason: 'page ${i + 1}');
      }
      final (w, _, px) = page;
      final c = want.center;
      final k = (c.dy.round() * w + c.dx.round()) * 4;
      expect((px[k], px[k + 1], px[k + 2]), (255, 255, 255), reason: 'the transparent centre shows the white page');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('300 pages (PDF-08), tile, all pages: completes; < 30 KB/page; time recorded', (tester) async {
    final f = await corpus('p300.pdf', 300);
    final t = (await tester.runAsync(() => renderTextPng('DRAFT',
        outPath: p.join(dir.path, 'draft.png'), colour: const Color(0xFF757575), heightPt: 30, bold: true)))!;
    final sw = Stopwatch()..start();
    final r = await run('it-wmk-3', f, opts(f, t.pngPath, t.widthPt / t.heightPt, position: WatermarkPosition.tile));
    sw.stop();
    final growth = (r.meta.bytes - f.sizeBytes) / 300 / 1024;
    // ignore: avoid_print
    print('T11.8 300-page tile: ${sw.elapsedMilliseconds} ms, ${f.sizeBytes} B → ${r.meta.bytes} B, '
        '+${growth.toStringAsFixed(2)} KB/page, 3600 stamps');
    expect(r.meta.pages, 300);
    expect(growth, lessThan(30));
  }, timeout: const Timeout(Duration(minutes: 8)));
}
