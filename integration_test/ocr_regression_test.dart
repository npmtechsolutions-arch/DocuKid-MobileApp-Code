// T10.10 — regression rows R45, R46 and R48 (RELEASE_V1_3 §8.3) through
// JobRunner.runComposite with the real engines on a device. R48 runs with
// the device in airplane mode when OCR_EXPECT_OFFLINE=true (set by the
// runner after `adb shell cmd connectivity airplane-mode enable`).
//
//   flutter test integration_test/ocr_regression_test.dart -d <android device>
import 'dart:io';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/ocr/mlkit_text_recognizer.dart';
import 'package:docukit/core/ocr/pdfrx_text_reader.dart';
import 'package:docukit/core/ocr/searchable_pdf_builder.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
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

const expectOffline = bool.fromEnvironment('OCR_EXPECT_OFFLINE');

/// Counts recognitions so a test can tell OCR from "Get text".
class _Counting implements TextRecognizer {
  _Counting(this.inner);
  final TextRecognizer inner;
  int recognised = 0;
  @override
  Future<Set<OcrScript>> availableScripts() => inner.availableScripts();
  @override
  Future<void> ensureModel(OcrScript script) => inner.ensureModel(script);
  @override
  Future<OcrPage> recognize(String imagePath, OcrScript script) {
    recognised++;
    return inner.recognize(imagePath, script);
  }

  @override
  Future<void> dispose() => inner.dispose();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late AppPaths paths;
  late JobRunner runner;
  late HistoryRepository history;
  late Directory inDir;
  late List<int> photo;
  final pdfs = PdfrxPdfEngine();
  const reader = PdfrxTextReader();
  final made = <_Counting>[];

  OcrOperation op() => OcrOperation(
        pdfEngine: pdfs,
        textReader: reader,
        pipeline: OcrPipeline(
          images: const NativeImageEngine(),
          encoder: const NativePageImageEncoder(),
          textReader: reader,
          recognizer: () {
            final r = _Counting(MlKitTextRecognizer());
            made.add(r);
            return r;
          },
          openPages: pdfs.openExtractor,
          buildPdf: SearchablePdfBuilder(pdfs, (a) async => (await rootBundle.load(a)).buffer.asUint8List()).build,
        ),
      );

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    history = HistoryRepository(AppDatabase(NativeDatabase.memory()));
    runner = JobRunner(
        paths: paths, history: history, outputs: OutputsRepository(paths), device: NativeDeviceServices(DocukitNative()));
    inDir = paths.jobIn('it_ocr_regression')..createSync(recursive: true);
    photo = img.encodeJpg(img.decodePng((await drawOcrPage(ocrLatinText)).png)!, quality: 80);
  });

  Future<PickedFile> pdfOf(String name, List<pw.Page> pages) async {
    final doc = pw.Document();
    pages.forEach(doc.addPage);
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(await doc.save());
    return PickedFile(
        path: path, displayName: name, type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: await pdfs.inspect(path));
  }

  pw.Page scanned() => pw.Page(build: (_) => pw.Image(pw.MemoryImage(Uint8List.fromList(photo))));

  Future<String> textOf(String path, int i) async {
    final d = await PdfDocument.openFile(path);
    try {
      return (await d.pages[i].loadText())?.fullText ?? '';
    } finally {
      await d.dispose();
    }
  }

  testWidgets('R45: a 12-page scanned PDF — cancel at page 4 leaves nothing; the full run is searchable', (_) async {
    final input = await pdfOf('scanned_12.pdf', List.generate(12, (_) => scanned()));
    final cancel = CancelToken();
    final states = <JobState>[];
    await runner.runComposite(
      jobId: 'r45_cancel',
      op: op(),
      inputs: [input],
      options: const OcrOptions(txt: true),
      cancel: cancel,
      emit: (s) {
        states.add(s);
        if (s is JobProcessing && s.progress is Determinate && (s.progress as Determinate).done == 3) cancel.cancel();
      },
    );
    expect(states.last, isA<JobCancelled>());
    expect(states.whereType<JobProcessing>().map((s) => s.progress).whereType<Determinate>().last.done, 3,
        reason: 'stopped between pages, at page 4');
    expect(Directory(p.join(paths.outputsRoot.path, 'r45_cancel')).existsSync(), isFalse);
    expect(paths.reviewDir('r45_cancel').existsSync(), isFalse);
    expect(paths.jobDir('r45_cancel').existsSync(), isFalse);
    expect((await history.get('r45_cancel'))!.status, OpStatus.cancelled);

    final sw = Stopwatch()..start();
    final full = <JobState>[];
    await runner.runComposite(
        jobId: 'r45_full', op: op(), inputs: [input], options: const OcrOptions(txt: true), cancel: CancelToken(), emit: full.add);
    final last = full.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final r = (last as JobCompletedMulti).result;
    final pdf = r.output.items.cast<OutputOk>().first.path;
    for (var i = 0; i < 12; i++) {
      expect(ocrRecall(ocrWords(ocrLatinText), ocrWords(await textOf(pdf, i))), greaterThanOrEqualTo(0.95), reason: 'page ${i + 1}');
    }
    // ignore: avoid_print
    print('R45 12 pages ${sw.elapsedMilliseconds}ms ${r.stats} pdf=${r.output.items.cast<OutputOk>().first.meta.bytes}B');
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('R46: a PDF that already has text → "Get text" without OCR, the original text', (_) async {
    const body = 'Quarterly report. Revenue grew in every region and the board approved the new budget for travel.';
    final input = await pdfOf('has_text.pdf', [
      pw.Page(build: (_) => pw.Text(body)),
      pw.Page(build: (_) => pw.Text('$body Page two.')),
    ]);
    expect(await reader.textPages(input.path), [true, true], reason: 'S30 shows "Already has text"');
    made.clear();
    final states = <JobState>[];
    await runner.runComposite(
      jobId: 'r46',
      op: op(),
      inputs: [input],
      // S30 turns the PDF output off for a fully text PDF ("Get text").
      options: const OcrOptions(searchablePdf: false, review: true, txt: true),
      cancel: CancelToken(),
      emit: states.add,
    );
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final r = (last as JobCompletedMulti).result;
    expect(made, isEmpty, reason: 'no recogniser created: nothing to recognise');
    expect(r.output.items.cast<OutputOk>().map((o) => o.name), ['has_text_text.txt']);
    final review = await OcrReviewFiles.read(paths.reviewDir('r46').path);
    expect(review.pages.map((pg) => pg.existingText), [true, true]);
    expect(await review.text(0), contains('Revenue grew in every region'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('R48: Latin and Devanagari work offline (bundled models, ADR-045)', (_) async {
    if (expectOffline) {
      final online = await () async {
        try {
          final s = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 3));
          s.destroy();
          return true;
        } on Object {
          return false;
        }
      }();
      expect(online, isFalse, reason: 'the runner put the device in airplane mode');
    }
    final hindi = p.join(inDir.path, 'hindi.jpg');
    File(hindi).writeAsBytesSync(img.encodeJpg(img.decodePng((await drawOcrPage(ocrHindiText, fontSize: 70)).png)!, quality: 85));
    final latin = p.join(inDir.path, 'latin.jpg');
    File(latin).writeAsBytesSync(photo);
    for (final (path, script, text) in [(latin, OcrScript.latin, ocrLatinText), (hindi, OcrScript.devanagari, ocrHindiText)]) {
      final meta = await const NativeImageEngine().inspect(path);
      final input = PickedFile(path: path, displayName: p.basename(path), type: meta.format, sizeBytes: File(path).lengthSync(), image: meta);
      final states = <JobState>[];
      await runner.runComposite(
        jobId: 'r48_${script.name}',
        op: op(),
        inputs: [input],
        options: OcrOptions(script: script, review: false),
        cancel: CancelToken(),
        emit: states.add,
      );
      final last = states.last;
      if (last is JobFailed) fail('${script.name} failed offline: ${last.error.code.name}');
      final pdf = ((last as JobCompletedMulti).result.output.items.single as OutputOk).path;
      final got = await textOf(pdf, 0);
      expect(ocrRecall(ocrWords(text), ocrWords(got)), greaterThanOrEqualTo(0.95), reason: script.name);
    }
    // ignore: avoid_print
    print('R48 offline=$expectOffline: Latin + Devanagari OK');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
