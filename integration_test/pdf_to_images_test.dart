// T8.9 on a device (RELEASE_V1_1 R33, FR-P2I-04/05/07, §8.3): PDF to Images
// with the real PDFium renderer and native encoder; peak memory recorded.
//
//   flutter test integration_test/pdf_to_images_test.dart -d <android device>
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_header.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_to_images/application/pdf_to_images_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPaths paths;
  late JobRunner runner;
  late Directory inDir;
  final pdfs = PdfrxPdfEngine();

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    runner = JobRunner(
      paths: paths,
      history: HistoryRepository(AppDatabase(NativeDatabase.memory())),
      outputs: OutputsRepository(paths),
      device: NativeDeviceServices(DocukitNative()),
    );
    inDir = paths.jobIn('it_p2i')..createSync(recursive: true);
  });

  /// Like corpus PDF-03: A4, Letter and landscape pages with text, a coloured
  /// block and an embedded photo.
  Future<PickedFile> mixedPdf(String name, int pages) async {
    final photo = img.Image(width: 800, height: 600);
    for (var y = 0; y < 600; y++) {
      for (var x = 0; x < 800; x++) {
        photo.setPixelRgb(x, y, x * 255 ~/ 800, y * 255 ~/ 600, 120);
      }
    }
    final jpg = pw.MemoryImage(img.encodeJpg(photo, quality: 85));
    final formats = [PdfPageFormat.a4, PdfPageFormat.letter, PdfPageFormat.a4.landscape];
    final doc = pw.Document();
    for (var i = 0; i < pages; i++) {
      doc.addPage(pw.Page(
        pageFormat: formats[i % 3],
        build: (_) => pw.Column(children: [
          pw.Text('Page ${i + 1}', style: const pw.TextStyle(fontSize: 32)),
          for (var k = 0; k < 8; k++) pw.Text('Line $k — The quick brown fox jumps over the lazy dog.'),
          pw.Container(width: 200, height: 60, color: PdfColors.teal),
          pw.SizedBox(height: 12),
          pw.Image(jpg, width: 300),
        ]),
      ));
    }
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(await doc.save());
    final meta = await pdfs.inspect(path);
    return PickedFile(path: path, displayName: name, type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: meta);
  }

  Future<(List<OutputOk>, int, int, Duration)> run(PickedFile input, PdfToImagesOptions o) async {
    final before = sha(input.path);
    final states = <JobState>[];
    final base = ProcessInfo.currentRss;
    var peak = base;
    final sampler = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
    });
    final sw = Stopwatch()..start();
    await runner.runMulti(
      jobId: 'it_${DateTime.now().microsecondsSinceEpoch}',
      op: PdfToImagesOperation(pdfs, const NativePageImageEncoder()),
      inputs: [input],
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    sw.stop();
    sampler.cancel();
    expect(sha(input.path), before, reason: 'input must be unchanged (rule 1)');
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final items = (last as JobCompletedMulti).result.output.items;
    expect(items.whereType<OutputFailed>(), isEmpty);
    return (items.cast<OutputOk>(), base ~/ (1 << 20), peak ~/ (1 << 20), sw.elapsed);
  }

  testWidgets('R33: 30 pages at 300 dpi → completes, sizes as estimated, memory bounded (FR-P2I-05)', (_) async {
    final input = await mixedPdf('mixed_30p.pdf', 30);
    final (out, base, peak, took) = await run(input, const PdfToImagesOptions(dpi: 300));
    expect(out, hasLength(30));
    for (final (i, o) in out.indexed) {
      final (wPt, hPt) = input.pdf!.pageSizes[i];
      final (ew, eh, _) = pagePixelSize(wPt, hPt, 300);
      final h = await readImageHeader(o.path);
      expect(h.type, SniffedType.jpeg);
      expect((h.displayWidth, h.displayHeight), (ew, eh), reason: o.name);
    }
    expect(out.first.name, 'mixed_30p_page01.jpg');
    // ignore: avoid_print
    print('R33 30p@300dpi took=${took.inMilliseconds}ms rss base=${base}MB peak=${peak}MB delta=${peak - base}MB '
        'first=${out.first.meta.width}x${out.first.meta.height} ${out.first.meta.bytes ~/ 1024}KB');
    expect(peak - base, lessThan(200), reason: 'FR-P2I-05: peak growth < 200 MB at 300 dpi');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('PNG: white background by default; transparent when asked (FR-P2I-07)', (_) async {
    final input = await mixedPdf('two.pdf', 2);
    final (white, _, _, _) = await run(input, const PdfToImagesOptions(allPages: false, ranges: '1', format: ImageFormat.png, dpi: 72));
    final (clear, _, _, _) = await run(
        input, const PdfToImagesOptions(allPages: false, ranges: '1', format: ImageFormat.png, dpi: 72, keepTransparent: true));
    final a = img.decodePng(File(white.single.path).readAsBytesSync())!;
    final b = img.decodePng(File(clear.single.path).readAsBytesSync())!;
    // Bottom-right corner is empty page area.
    final pa = a.getPixel(a.width - 5, a.height - 5), pb = b.getPixel(b.width - 5, b.height - 5);
    // ignore: avoid_print
    print('PNG white corner=(${pa.r},${pa.g},${pa.b},${pa.a}) transparent corner alpha=${pb.a} channels=${b.numChannels}');
    expect(pa.r > 240 && pa.g > 240 && pa.b > 240, isTrue);
    expect(b.numChannels, 4);
    expect(pb.a, lessThan(20));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
