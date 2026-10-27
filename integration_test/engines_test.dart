// On-device end-to-end checks with the real native engines (TESTING §2, §4):
// one happy path per tool through the JobRunner, plus the checksum guard that
// every input is byte-identical afterwards (CLAUDE.md rule 1).
//
//   flutter test integration_test -d <deviceId>
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/image_header.dart';
import 'package:docukit/core/image/resize_math.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/page_edit.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_compress/application/compress_operation.dart';
import 'package:docukit/features/image_resize/application/resize_operation.dart';
import 'package:docukit/features/image_to_pdf/application/image_to_pdf_operation.dart';
import 'package:docukit/features/pdf_compress/application/reduce_operation.dart';
import 'package:docukit/features/pdf_merge/application/merge_operation.dart';
import 'package:docukit/features/pdf_organize/application/organize_controller.dart';
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

Uint8List photo(int w, int h, {int seed = 1, int orientation = 1}) {
  final r = math.Random(seed);
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y += 1) {
    for (var x = 0; x < w; x += 1) {
      im.setPixelRgb(x, y, (x * 255 ~/ w + r.nextInt(40)) % 256, (y * 255 ~/ h) % 256, r.nextInt(256));
    }
  }
  if (orientation != 1) im.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(im, quality: 95);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPaths paths;
  late JobRunner runner;
  late Directory inDir;
  const images = NativeImageEngine();
  final pdfs = PdfrxPdfEngine();

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    final db = AppDatabase(NativeDatabase.memory());
    runner = JobRunner(
      paths: paths,
      history: HistoryRepository(db),
      outputs: OutputsRepository(paths),
      device: NativeDeviceServices(DocukitNative()),
    );
    inDir = paths.jobIn('it_draft')..createSync(recursive: true);
  });

  Future<PickedFile> pickedImage(String name, Uint8List bytes) async {
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(bytes);
    final meta = await images.inspect(path);
    return PickedFile(path: path, displayName: name, type: meta.format, sizeBytes: bytes.length, image: meta);
  }

  Future<PickedFile> pickedPdf(String name, List<pw.Page> pages) async {
    final doc = pw.Document();
    pages.forEach(doc.addPage);
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(await doc.save());
    final meta = await pdfs.inspect(path);
    return PickedFile(path: path, displayName: name, type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: meta);
  }

  Future<JobResult> run<O extends ToolOptions>(ToolOperation<O> op, List<PickedFile> inputs, O o) async {
    final before = {for (final f in inputs) f.path: sha(f.path)};
    final states = <JobState>[];
    await runner.run<O>(
      jobId: 'it_${DateTime.now().microsecondsSinceEpoch}',
      op: op,
      inputs: inputs,
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    for (final f in inputs) {
      expect(sha(f.path), before[f.path], reason: 'input must be unchanged (rule 1)');
    }
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    return (last as JobCompleted).result;
  }

  testWidgets('Compressor: q60 JPEG is smaller, valid JPEG, upright', (_) async {
    final input = await pickedImage('photo.jpg', photo(2000, 1500, orientation: 6));
    expect((input.image!.width, input.image!.height), (1500, 2000), reason: 'EXIF 6 swaps display dims');
    final r = await run(CompressImageOperation(images), [input], const CompressOptions(quality: 60));
    final h = await readImageHeader(r.outputPath);
    expect(h.type, SniffedType.jpeg);
    expect((h.displayWidth, h.displayHeight), (1500, 2000));
    expect(h.orientation, 1, reason: 'orientation baked into pixels, tag reset');
    expect(r.meta.bytes, lessThan(input.sizeBytes));
  });

  testWidgets('Compressor: target size ≤ 100 KB or flagged as missed', (_) async {
    final input = await pickedImage('big.jpg', photo(2400, 1800, seed: 3));
    final r = await run(CompressImageOperation(images), [input], const CompressOptions(mode: CompressMode.targetSize, targetBytes: 100 * 1024));
    expect(r.targetMissed || r.meta.bytes <= 100 * 1024, isTrue);
  });

  testWidgets('Resizer: passport preset is exactly 413×531', (_) async {
    final input = await pickedImage('face.jpg', photo(1200, 1600, seed: 4));
    final r = await run(
      ResizeImageOperation(images),
      [input],
      ResizeOptions(
        mode: ResizeMode.preset,
        preset: BuiltInPreset.passport.name,
        presetWidth: 413,
        presetHeight: 531,
        fit: FitMode.cover,
      ),
    );
    final h = await readImageHeader(r.outputPath);
    expect((h.displayWidth, h.displayHeight), (413, 531));
  });

  testWidgets('Images → PDF: page count equals image count', (_) async {
    final a = await pickedImage('a.jpg', photo(800, 600, seed: 5));
    final b = await pickedImage('b.jpg', photo(600, 800, seed: 6));
    final r = await run(ImageToPdfOperation(images, pdfs), [a, b], const ImageToPdfOptions(rotations: [0, 1]));
    expect(r.meta.pages, 2);
  });

  testWidgets('Merge, Organize and Reduce on real PDFs', (_) async {
    pw.Page page(String t) => pw.Page(build: (_) => pw.Center(child: pw.Text(t)));
    final x = await pickedPdf('x.pdf', [page('1'), page('2')]);
    final y = await pickedPdf('y.pdf', [page('3')]);
    final merged = await run(MergePdfOperation(pdfs), [x, y], const MergeOptions());
    expect(merged.meta.pages, 3);

    final org = await run(OrganizePdfOperation(pdfs), [x], const OrganizeOptions([PageEdit(1, 1), PageEdit(0)]));
    expect(org.meta.pages, 2);

    final photoPdf = await pickedPdf('photos.pdf', [
      for (var i = 0; i < 2; i++)
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(photo(1600, 2200, seed: 20 + i)), fit: pw.BoxFit.fill),
        ),
    ]);
    final reduced = await run(ReducePdfOperation(pdfs), [photoPdf], const ReduceOptions(level: ReduceLevel.balanced));
    expect(reduced.meta.pages, 2);
    expect(reduced.meta.bytes, lessThan(photoPdf.sizeBytes));
  });
}
