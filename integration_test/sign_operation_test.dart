// T11.7 on a device (RELEASE_V1_4 R49–R51, FR-SIG-09/12, §4.8): the Sign job
// through JobRunner with the real PdfiumStamper and validators —
// R49 a drawn signature on page 1; R50 a typed signature on all 6 pages;
// R51 a photo signature (IMG-24 stand-in, background removed) on PDF-04's
// rotated pages: upright ink exactly where the editor put it (±1.5 pt).
//
//   flutter test integration_test/sign_operation_test.dart -d <android device>
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_stamper.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/pdf/text_stamp_renderer.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/core/validation/output_validator.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_sign/application/ink.dart';
import 'package:docukit/features/pdf_sign/application/photo_signature.dart';
import 'package:docukit/features/pdf_sign/application/placement.dart';
import 'package:docukit/features/pdf_sign/application/sign_operation.dart';
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

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final engine = PdfrxPdfEngine();
  late AppPaths paths;
  late JobRunner runner;
  late Directory dir;
  final op = SignPdfOperation(
    const PdfiumStamper(),
    validatePages: (path, expected) => validatePdfOutput(engine, path, expectedPages: expected),
    stampVisible: (path, page, box, size) => stampHasInk(engine, path, page, box, size),
  );

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    runner = JobRunner(
        paths: paths,
        history: HistoryRepository(AppDatabase(NativeDatabase.memory())),
        outputs: OutputsRepository(paths),
        device: NativeDeviceServices(DocukitNative()));
    dir = paths.jobIn('it_sign')..createSync(recursive: true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<PickedFile> corpus(String name, int pages, {List<int> turns = const []}) async {
    final doc = pw.Document();
    for (var i = 0; i < pages; i++) {
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Text('Lease page ${i + 1}')));
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

  Future<JobResult> run(String id, PickedFile f, List<Placement> placements) async {
    final states = <JobState>[];
    await runner.run(
        jobId: id, op: op, inputs: [f], options: SignOptions(placements), cancel: CancelToken(), emit: states.add);
    expect(states.last, isA<JobCompleted>(), reason: '${states.last}');
    return (states.last as JobCompleted).result;
  }

  Placement pl(int page, String png, Rect rect) =>
      Placement(id: 'p$page', pageIndex: page, pngPath: png, rect: rect, kind: PlacementKind.signature);

  /// Bounding box of blue ink (BGRA) on [page] rendered at 1 px per point.
  Future<Rect?> inkBox(String path, int page) async {
    final d = await PdfDocument.openFile(path);
    try {
      final pg = d.pages[page];
      final w = pg.width.round(), h = pg.height.round();
      final im = (await pg.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
      final px = Uint8List.fromList(im.pixels);
      im.dispose();
      int? x0, y0, x1, y1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          if (px[i] > 90 && px[i + 2] < 60 && px[i] - px[i + 2] > 60) {
            x0 = x0 == null || x < x0 ? x : x0;
            y0 = y0 == null || y < y0 ? y : y0;
            x1 = x1 == null || x > x1 ? x : x1;
            y1 = y1 == null || y > y1 ? y : y1;
          }
        }
      }
      return x0 == null ? null : Rect.fromLTRB(x0.toDouble(), y0!.toDouble(), x1! + 1.0, y1! + 1.0);
    } finally {
      await d.dispose();
    }
  }

  testWidgets('R49: a drawn (unsaved) signature on page 1 → a validated signed copy; the source unchanged', (tester) async {
    final f = await corpus('lease.pdf', 3);
    final before = sha(f.path);
    final ink = (await tester.runAsync(() => exportInkPng(
          const [InkStroke([Offset(0, 20), Offset(40, 0), Offset(80, 30), Offset(120, 5)])],
          colour: InkColour.blue,
          thickness: InkThickness.medium,
          outPath: p.join(dir.path, 'drawn.png'),
        )))!;
    final r = await run('it-sign-1', f, [pl(0, ink.pngPath, Rect.fromLTWH(380, 740, 150, 150 * ink.heightPx / ink.widthPx))]);
    expect((r.outputName, r.meta.pages, r.meta.flags['stamped']), ('lease_signed.pdf', 3, 1));
    expect(sha(f.path), before, reason: 'FR-SIG-12');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('R50: a typed signature on all 6 pages → 6 stamped pages, each with ink at the same place', (tester) async {
    final f = await corpus('six.pdf', 6);
    final t = (await tester.runAsync(() => renderTextPng('Neha Patel',
        outPath: p.join(dir.path, 'typed.png'), colour: const Color(0xFF1A3FB0), heightPt: 60, fontFamily: 'DancingScript')))!;
    const rect = Rect.fromLTWH(360, 720, 180, 60);
    final r = await run('it-sign-2', f, [for (var i = 0; i < 6; i++) pl(i, t.pngPath, rect)]);
    expect(r.meta.flags['stamped'], 6);
    for (var i = 0; i < 6; i++) {
      final box = await inkBox(r.outputPath, i);
      expect(box, isNotNull, reason: 'page ${i + 1}');
      expect(rect.inflate(1.5).contains(box!.topLeft) && rect.inflate(1.5).contains(box.bottomRight), isTrue,
          reason: 'page ${i + 1}: $box inside $rect');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('R51: a photo signature on PDF-04 rotated pages: upright, transparent around the ink, ±1.5 pt',
      (tester) async {
    // IMG-24 stand-in: blue ink on off-white paper, background removed (§4.7).
    final photo = img.Image(width: 900, height: 300);
    img.fill(photo, color: img.ColorRgb8(238, 236, 228));
    img.fillRect(photo, x1: 150, y1: 120, x2: 750, y2: 180, color: img.ColorRgb8(25, 50, 160));
    final jpg = p.join(dir.path, 'IMG-24.jpg');
    File(jpg).writeAsBytesSync(img.encodeJpg(photo, quality: 95));
    final png = p.join(dir.path, 'photo_sig.png');
    final size = (await tester.runAsync(() => cleanSignaturePhoto(jpg, png, cleanup: defaultCleanup)))!;
    final f = await corpus('rotated_pages.pdf', 4, turns: const [0, 1, 2, 3]);
    // 200 pt wide at the photo's aspect (≈ 10:1), visual (60, 100).
    final rect = Rect.fromLTWH(60, 100, 200, 200 * size.$2 / size.$1);
    final r = await run('it-sign-3', f, [for (var i = 0; i < 4; i++) pl(i, png, rect)]);
    for (var i = 0; i < 4; i++) {
      final box = (await inkBox(r.outputPath, i))!;
      // ignore: avoid_print
      print('T11.7 R51 page ${i * 90}°: ink $box, placed $rect');
      for (final (got, want) in [(box.left, rect.left), (box.top, rect.top), (box.right, rect.right), (box.bottom, rect.bottom)]) {
        expect(got, closeTo(want, 1.5), reason: 'page ${i * 90}°');
      }
      expect(box.width / box.height, greaterThan(5), reason: 'upright: still wide, not turned with the page');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
