// T9.6 on a device (RELEASE_V1_2 §8 corpus: scan_fixture pages at 3 MP):
// Scan pages → PDF and → JPG images with the real native encoder and PDFium.
// The pages stand in for scanner output (the scanner itself is manual, R37).
//
//   flutter test integration_test/scan_operation_test.dart -d <android device>
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/image_header.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/core/scan/scan_options.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/scan/application/scan_operation.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

/// A "paper photo": a light page with dark text-like bars, 2000×1500 (3 MP).
Uint8List paperJpeg(int seed, {bool landscape = true}) {
  final (w, h) = landscape ? (2000, 1500) : (1500, 2000);
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(235, 232, 225));
  for (var y = 120 + seed * 7; y < h - 120; y += 60) {
    img.fillRect(im, x1: 150, y1: y, x2: w - 150 - (y * 13 % 400), y2: y + 18, color: img.ColorRgb8(40, 40, 50));
  }
  return img.encodeJpg(im, quality: 90);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPaths paths;
  late JobRunner runner;
  late HistoryRepository history;
  late Directory inDir;
  const images = NativeImageEngine();
  final pdfs = PdfrxPdfEngine();

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    history = HistoryRepository(AppDatabase(NativeDatabase.memory()));
    runner = JobRunner(
      paths: paths,
      history: history,
      outputs: OutputsRepository(paths),
      device: NativeDeviceServices(DocukitNative()),
    );
    inDir = paths.jobIn('it_scan')..createSync(recursive: true);
  });

  Future<List<PickedFile>> pages(int n) async => [
        for (var i = 0; i < n; i++)
          await () async {
            final path = p.join(inDir.path, 'page_${(i + 1).toString().padLeft(3, '0')}.jpg');
            File(path).writeAsBytesSync(paperJpeg(i, landscape: i != 1));
            final meta = await images.inspect(path);
            return PickedFile(
                path: path, displayName: p.basename(path), type: meta.format, sizeBytes: File(path).lengthSync(), image: meta);
          }(),
      ];

  testWidgets('R37 (pipeline): 4 pages → A4 PDF, rotation kept, history row (FR-SCN-13, 17)', (_) async {
    final input = await pages(4);
    final before = {for (final f in input) f.path: sha(f.path)};
    final states = <JobState>[];
    final sw = Stopwatch()..start();
    await runner.run(
      jobId: 'it_scan_pdf',
      op: ScanPdfOperation(images, pdfs),
      inputs: input,
      options: const ScanOptions(rotations: [0, 0, 1, 0], baseName: 'Scan_it'),
      cancel: CancelToken(),
      emit: states.add,
    );
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final r = (last as JobCompleted).result;
    expect((r.outputName, r.meta.pages, r.tool), ('Scan_it.pdf', 4, ToolId.scanDocument));
    final doc = await PdfDocument.openFile(r.outputPath);
    final sizes = [for (final pg in doc.pages) (pg.width.round(), pg.height.round())];
    await doc.dispose();
    // A4 portrait 595×842 / landscape 842×595 (auto orientation per page).
    expect(sizes.every((s) => {(595, 842), (842, 595)}.contains(s)), isTrue, reason: '$sizes');
    expect(sizes[2], (595, 842), reason: 'the landscape page turned a quarter is portrait');
    for (final f in input) {
      expect(sha(f.path), before[f.path], reason: 'scanned pages are never modified');
    }
    final row = (await history.get('it_scan_pdf'))!;
    expect((row.status, row.tool), (OpStatus.success, ToolId.scanDocument));
    expect(row.row.optionsJson, contains('"format":"pdf"'));
    // ignore: avoid_print
    print('R37 pdf ${r.meta.bytes}B pages=$sizes ${sw.elapsedMilliseconds}ms');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Fit to scan: each page has the scan\'s aspect at 200 dpi (FR-SCN-14)', (_) async {
    final input = await pages(2);
    final states = <JobState>[];
    await runner.run(
      jobId: 'it_scan_fit',
      op: ScanPdfOperation(images, pdfs),
      inputs: input,
      options: const ScanOptions(pageSize: ScanPageSize.fitToScan, quality: ScanQuality.compact),
      cancel: CancelToken(),
      emit: states.add,
    );
    final r = (states.last as JobCompleted).result;
    final doc = await PdfDocument.openFile(r.outputPath);
    final sizes = [for (final pg in doc.pages) (pg.width.round(), pg.height.round())];
    await doc.dispose();
    expect(sizes, [(720, 540), (540, 720)]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('R39 (pipeline): 3 pages → JPG images _p01…, capped at A4 200 dpi, decodable', (_) async {
    final input = await pages(3);
    final states = <JobState>[];
    await runner.runMulti(
      jobId: 'it_scan_jpg',
      op: ScanJpgOperation(images),
      inputs: input,
      options: const ScanOptions(format: ScanOutputFormat.jpg, baseName: 'Receipt', rotations: [1, 0, 0]),
      cancel: CancelToken(),
      emit: states.add,
    );
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final items = (last as JobCompletedMulti).result.output.items.cast<OutputOk>();
    expect(items.map((o) => o.name), ['Receipt_p01.jpg', 'Receipt_p02.jpg', 'Receipt_p03.jpg']);
    final dims = <(int, int)>[];
    for (final o in items) {
      final h = await readImageHeader(o.path);
      dims.add((h.displayWidth, h.displayHeight));
      expect(img.decodeJpg(File(o.path).readAsBytesSync()), isNotNull);
    }
    expect(dims, [(1500, 2000), (1500, 2000), (2000, 1500)], reason: 'rotated first page; 3 MP is under the 2339 px cap');
    // ignore: avoid_print
    print('R39 jpg ${items.map((o) => '${o.name} ${o.meta.bytes}B').join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
