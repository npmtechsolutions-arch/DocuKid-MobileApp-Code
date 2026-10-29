// T10.10 — OCR-10 benchmark (RELEASE_V1_3 §8.1, FR-OCR-12): 50 page images
// through Text Recognition (searchable PDF + .txt + review) with the real
// engines. Peak extra memory must stay ≤ 250 MB; time is recorded, not
// promised (TESTING §6).
//
//   flutter test integration_test/ocr_stress_test.dart -d <android device>
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/ocr/mlkit_text_recognizer.dart';
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
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../tool/fixtures/ocr_text.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR-10: 50 pages, peak extra memory ≤ 250 MB (FR-OCR-12)', (_) async {
    await pdfrxFlutterInitialize();
    final paths = await AppPaths.resolve();
    final pdfs = PdfrxPdfEngine();
    const reader = PdfrxTextReader();
    const images = NativeImageEngine();
    final runner = JobRunner(
      paths: paths,
      history: HistoryRepository(AppDatabase(NativeDatabase.memory())),
      outputs: OutputsRepository(paths),
      device: NativeDeviceServices(DocukitNative()),
    );
    final op = OcrOperation(
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
    // 50 A4 pages at 300 dpi (2480×3508), generated once and copied.
    final inDir = paths.jobIn('it_ocr_stress')..createSync(recursive: true);
    final jpg = img.encodeJpg(img.decodePng((await drawOcrPage(ocrLatinText)).png)!, quality: 85);
    final inputs = <PickedFile>[];
    for (var i = 0; i < 50; i++) {
      final path = p.join(inDir.path, 'page_${(i + 1).toString().padLeft(2, '0')}.jpg');
      File(path).writeAsBytesSync(jpg);
      final meta = await images.inspect(path);
      inputs.add(PickedFile(path: path, displayName: p.basename(path), type: meta.format, sizeBytes: jpg.length, image: meta));
    }

    const mb = 1024 * 1024;
    final base = ProcessInfo.currentRss;
    var peak = base;
    final sampler = Timer.periodic(const Duration(milliseconds: 200), (_) => peak = math.max(peak, ProcessInfo.currentRss));
    final sw = Stopwatch()..start();
    final states = <JobState>[];
    await runner.runComposite(
      jobId: 'ocr10',
      op: op,
      inputs: inputs,
      options: const OcrOptions(txt: true),
      cancel: CancelToken(),
      emit: states.add,
    );
    sampler.cancel();
    peak = math.max(peak, ProcessInfo.currentRss);
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final r = (last as JobCompletedMulti).result;
    final pdf = r.output.items.cast<OutputOk>().first;
    final extra = (peak - base) / mb;
    // ignore: avoid_print
    print('OCR-10 50 pages ${sw.elapsed.inSeconds}s (${(sw.elapsedMilliseconds / 50).round()} ms/page) '
        'rss base=${(base / mb).round()}MB peak=${(peak / mb).round()}MB extra=${extra.round()}MB '
        'stats=${r.stats} pdf=${(pdf.meta.bytes / mb).toStringAsFixed(1)}MB');
    expect(r.stats['pages'], 50);
    expect(extra, lessThanOrEqualTo(250));
    final d = await PdfDocument.openFile(pdf.path);
    try {
      expect(d.pages.length, 50);
      expect(ocrRecall(ocrWords(ocrLatinText), ocrWords((await d.pages[49].loadText())?.fullText ?? '')), greaterThanOrEqualTo(0.95));
    } finally {
      await d.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 45)));
}
