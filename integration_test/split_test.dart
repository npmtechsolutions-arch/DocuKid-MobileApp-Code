// T8.8 on a device (RELEASE_V1_1 R32, FR-SPL-02…07): Split PDF with the real
// PDFium engine. Each source page has its own width (200 + index pt), so the
// test can tell exactly which pages ended up in each output.
//
//   flutter test integration_test/split_test.dart -d <android device>
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_split/application/split_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
    inDir = paths.jobIn('it_split')..createSync(recursive: true);
  });

  /// [pages] pages; page i (0-based) is (200 + i) × 400 pt and says its number.
  Future<PickedFile> numberedPdf(String name, int pages) async {
    final doc = pw.Document();
    for (var i = 0; i < pages; i++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(200.0 + i, 400),
        build: (_) => pw.Center(child: pw.Text('Page ${i + 1}', style: const pw.TextStyle(fontSize: 24))),
      ));
    }
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(await doc.save());
    final meta = await pdfs.inspect(path);
    return PickedFile(path: path, displayName: name, type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: meta);
  }

  /// Source page numbers (1-based) found in an output, from the page widths.
  Future<List<int>> pagesIn(String path) async {
    final meta = await pdfs.inspect(path);
    return [for (final (w, _) in meta.pageSizes) w.round() - 200 + 1];
  }

  Future<List<OutputOk>> run(PickedFile input, SplitOptions o) async {
    final before = sha(input.path);
    final states = <JobState>[];
    final sw = Stopwatch()..start();
    await runner.runMulti(
      jobId: 'it_${DateTime.now().microsecondsSinceEpoch}',
      op: SplitPdfOperation(pdfs),
      inputs: [input],
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    expect(sha(input.path), before, reason: 'input must be unchanged (rule 1)');
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final items = (last as JobCompletedMulti).result.output.items;
    expect(items.whereType<OutputFailed>(), isEmpty);
    // ignore: avoid_print
    print('SPLIT ${o.toJson()} → ${items.length} files in ${sw.elapsedMilliseconds}ms');
    return items.cast<OutputOk>();
  }

  testWidgets('R32a: 300 pages, "1-3, 5, 8-end" → 3 files with exactly those pages', (_) async {
    final input = await numberedPdf('large_300p.pdf', 300);
    final out = await run(input, const SplitOptions(ranges: '1-3, 5, 8-end'));
    expect(out.map((o) => o.name), ['large_300p_p1-3.pdf', 'large_300p_p5.pdf', 'large_300p_p8-300.pdf']);
    expect(out.map((o) => o.meta.pages), [3, 1, 293]);
    expect(await pagesIn(out[0].path), [1, 2, 3]);
    expect(await pagesIn(out[1].path), [5]);
    expect(await pagesIn(out[2].path), [for (var i = 8; i <= 300; i++) i]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('R32b: every 25 → 12 files of 25 pages, in order', (_) async {
    final input = await numberedPdf('large_300p.pdf', 300);
    final out = await run(input, const SplitOptions(mode: SplitMode.everyN, everyN: 25));
    expect(out, hasLength(12));
    expect(out.first.name, 'large_300p_part01.pdf');
    expect(out.last.name, 'large_300p_part12.pdf');
    expect(out.every((o) => o.meta.pages == 25), isTrue);
    expect(await pagesIn(out[11].path), [for (var i = 276; i <= 300; i++) i]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('R32c: each page of a 10-page PDF → 10 one-page files', (_) async {
    final input = await numberedPdf('ten.pdf', 10);
    final out = await run(input, const SplitOptions(mode: SplitMode.each));
    expect(out.map((o) => o.meta.pages), List.filled(10, 1));
    for (var i = 0; i < 10; i++) {
      expect(await pagesIn(out[i].path), [i + 1]);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('overlaps and duplicates are kept (FR-SPL-05)', (_) async {
    final input = await numberedPdf('ten.pdf', 10);
    final out = await run(input, const SplitOptions(ranges: '2-4, 3, 3'));
    expect([for (final o in out) await pagesIn(o.path)], [
      [2, 3, 4],
      [3],
      [3],
    ]);
    expect(out.map((o) => o.name).toSet(), hasLength(3), reason: 'same suggested name made unique');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
