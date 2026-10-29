// T10.5 on a device: OcrOperation through JobRunner.runComposite with the real
// image engine, ML Kit, PDFium and fonts (RELEASE_V1_3 §4.3–4.4, §8.2).
//
//   flutter test integration_test/ocr_operation_test.dart -d <android device>
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/ocr/mlkit_text_recognizer.dart';
import 'package:docukit/core/ocr/ocr_text_file.dart';
import 'package:docukit/core/ocr/pdfrx_text_reader.dart';
import 'package:docukit/core/ocr/searchable_pdf_builder.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/ocr/application/ocr_operation.dart';
import 'package:docukit/features/ocr/application/ocr_options.dart';
import 'package:docukit/features/ocr/application/ocr_pipeline.dart';
import 'package:docukit/features/ocr/application/ocr_review_files.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import '../tool/fixtures/ocr_text.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late AppPaths paths;
  late JobRunner runner;
  late HistoryRepository history;
  late OcrOperation op;
  late Directory inDir;
  late img.Image ocr01;
  const images = NativeImageEngine();
  final pdfs = PdfrxPdfEngine();

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    history = HistoryRepository(AppDatabase(NativeDatabase.memory()));
    runner = JobRunner(
        paths: paths, history: history, outputs: OutputsRepository(paths), device: NativeDeviceServices(DocukitNative()));
    const reader = PdfrxTextReader();
    op = OcrOperation(
      pdfEngine: pdfs,
      textReader: reader,
      pipeline: OcrPipeline(
        images: images,
        encoder: const NativePageImageEncoder(),
        textReader: reader,
        recognizer: MlKitTextRecognizer.new,
        openPages: pdfs.openExtractor,
        buildPdf: SearchablePdfBuilder(pdfs, (a) async => (await rootBundle.load(a)).buffer.asUint8List()).build,
      ),
    );
    inDir = paths.jobIn('it_ocr_op')..createSync(recursive: true);
    ocr01 = img.decodePng((await drawOcrPage(ocrLatinText)).png)!;
  });

  Future<PickedFile> imageInput(String name, img.Image im, {int orientation = 1}) async {
    if (orientation != 1) im.exif.imageIfd.orientation = orientation;
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(img.encodeJpg(im, quality: 90));
    final meta = await images.inspect(path);
    return PickedFile(path: path, displayName: name, type: meta.format, sizeBytes: File(path).lengthSync(), image: meta);
  }

  Future<List<JobState>> run(String id, List<PickedFile> inputs, OcrOptions o, {CancelToken? cancel}) async {
    final states = <JobState>[];
    await runner.runComposite(jobId: id, op: op, inputs: inputs, options: o, cancel: cancel ?? CancelToken(), emit: states.add);
    return states;
  }

  Future<String> pageText(String path, int i) async {
    final d = await PdfDocument.openFile(path);
    try {
      return (await d.pages[i].loadText())?.fullText ?? '';
    } finally {
      await d.dispose();
    }
  }

  final truth = ocrWords(ocrLatinText);

  testWidgets('2 photos (one EXIF 6) → searchable PDF + .txt + review; originals unchanged', (_) async {
    final a = await imageInput('notes.jpg', ocr01.clone());
    final b = await imageInput('notes_side.jpg', img.copyRotate(ocr01, angle: -90), orientation: 6);
    final before = [sha(a.path), sha(b.path)];
    final sw = Stopwatch()..start();
    final states = await run('it_ocr_images', [a, b], const OcrOptions(txt: true));
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final r = (last as JobCompletedMulti).result;
    final files = r.output.items.cast<OutputOk>();
    expect(files.map((f) => f.name), ['notes_searchable.pdf', 'notes_text.txt']);
    expect(states.whereType<JobProcessing>().map((s) => s.progress).whereType<Determinate>().map((d) => d.done), [0, 1]);
    for (var i = 0; i < 2; i++) {
      expect(ocrRecall(truth, ocrWords(await pageText(files.first.path, i))), greaterThanOrEqualTo(0.95), reason: 'page ${i + 1}');
    }
    expect(await isValidOcrTxt(files.last.path, pageCount: 2), isTrue);
    expect(r.stats['pages'], 2);
    expect(r.reviewAvailable, isTrue);
    final review = await OcrReviewFiles.read(paths.reviewDir('it_ocr_images').path);
    expect(review.pages.map((pg) => pg.lowText), [false, false]);
    expect(ocrRecall(truth, ocrWords(await review.text(1))), greaterThanOrEqualTo(0.95), reason: 'EXIF 6 page upright');
    expect([sha(a.path), sha(b.path)], before, reason: 'originals never modified');
    final row = (await history.get('it_ocr_images'))!;
    expect((row.status, row.tool), (OpStatus.success, ToolId.ocr));
    expect(row.row.optionsJson ?? '', isNot(contains('Meeting')), reason: 'no text in history (ADR-047)');
    // ignore: avoid_print
    print('T10.5 images: ${r.stats} pdf=${files.first.meta.bytes}B ${sw.elapsedMilliseconds}ms');
  }, timeout: const Timeout(Duration(minutes: 5)));

  // ML Kit reads sideways Latin text directly (84/84 words on OCR-03), so
  // FR-OCR-15's retry (only below 3 words) doesn't run: the page stays as
  // photographed and the invisible lines are rotated along the text.
  testWidgets('OCR-03: a page photographed sideways is still searchable', (_) async {
    final side = await imageInput('sideways.jpg', img.copyRotate(ocr01, angle: 90));
    final states = await run('it_ocr_rot', [side], const OcrOptions(review: false));
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final pdf = ((last as JobCompletedMulti).result.output.items.single as OutputOk).path;
    final meta = await pdfs.inspect(pdf);
    // ignore: avoid_print
    print('T10.5 OCR-03 page=${meta.pageSizes.single} words=${last.result.stats['words']}');
    expect(meta.pageSizes.single.$1, greaterThan(meta.pageSizes.single.$2), reason: 'kept as photographed');
    final text = await pageText(pdf, 0);
    expect(ocrRecall(truth, ocrWords(text)), greaterThanOrEqualTo(0.95));
    expect(text, contains('spring planning session'), reason: 'rotated lines read in order');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('OCR-08 PDF: page 1 kept, pages 2–3 recognised; text only (no file) also succeeds', (_) async {
    final photo = img.encodeJpg(ocr01, quality: 80);
    final doc = pw.Document()
      ..addPage(pw.Page(build: (_) => pw.Text('Original vector text: invoice 2026-10-29, total 1,250.00')))
      ..addPage(pw.Page(build: (_) => pw.Image(pw.MemoryImage(photo))))
      ..addPage(pw.Page(build: (_) => pw.Image(pw.MemoryImage(photo))));
    final path = p.join(inDir.path, 'mixed.pdf');
    File(path).writeAsBytesSync(await doc.save());
    final input = PickedFile(
        path: path, displayName: 'mixed.pdf', type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: await pdfs.inspect(path));
    final original = await pageText(path, 0);

    final states = await run('it_ocr_pdf', [input], const OcrOptions(txt: true));
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final files = (last as JobCompletedMulti).result.output.items.cast<OutputOk>().toList();
    expect(await pageText(files.first.path, 0), original, reason: 'kept unchanged');
    for (final i in [1, 2]) {
      expect(ocrRecall(truth, ocrWords(await pageText(files.first.path, i))), greaterThanOrEqualTo(0.95));
    }
    final review = await OcrReviewFiles.read(paths.reviewDir('it_ocr_pdf').path);
    expect(review.pages.map((pg) => pg.existingText), [true, false, false]);

    final textOnly = await run('it_ocr_textonly', [input], const OcrOptions(searchablePdf: false));
    final t = (textOnly.last as JobCompletedMulti).result;
    expect(t.output.items, isEmpty);
    expect(t.reviewAvailable, isTrue);
    expect((await history.get('it_ocr_textonly'))!.status, OpStatus.success);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('cancel after the first page: no outputs, no review text, history cancelled', (_) async {
    final inputs = [for (var i = 0; i < 3; i++) await imageInput('c$i.jpg', ocr01.clone())];
    final cancel = CancelToken();
    final states = <JobState>[];
    await runner.runComposite(
      jobId: 'it_ocr_cancel',
      op: op,
      inputs: inputs,
      options: const OcrOptions(txt: true),
      cancel: cancel,
      emit: (s) {
        states.add(s);
        if (s is JobProcessing && s.progress is Determinate && (s.progress as Determinate).done == 1) cancel.cancel();
      },
    );
    expect(states.last, isA<JobCancelled>());
    expect(Directory(p.join(paths.outputsRoot.path, 'it_ocr_cancel')).existsSync(), isFalse);
    expect(paths.reviewDir('it_ocr_cancel').existsSync(), isFalse);
    expect((await history.get('it_ocr_cancel'))!.status, OpStatus.cancelled);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
