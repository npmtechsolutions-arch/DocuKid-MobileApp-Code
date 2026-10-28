// T8.6 — Batch Resize (RELEASE_V1_1 FR-BAT-11/12, R30, ADR-036, ADR-062),
// written before the implementation. Runs through JobRunner.runMulti with an
// engine that writes real JPEGs at the requested size.
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/resize_math.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_resize/application/resize_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

class ExactSizeEngine implements ImageEngine {
  final transforms = <ImageTransform>[];
  @override
  bool canEncode(ImageFormat format) => format != ImageFormat.heic;
  @override
  Future<ImageMeta> inspect(String path) async => throw UnimplementedError();
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    transforms.add(t);
    final bytes = img.encodeJpg(img.Image(width: t.targetWidth!, height: t.targetHeight!));
    await File(outPath).writeAsBytes(bytes);
    return EncodedImage(path: outPath, bytes: bytes.length, width: t.targetWidth!, height: t.targetHeight!, format: t.format);
  }
}

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late Directory inDir;

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    inDir = paths.jobIn('draft')..createSync(recursive: true);
  });
  tearDown(() => db.close());

  PickedFile photo(String name, int w, int h, {ValidationStatus status = const ValidationStatus.ok()}) {
    final f = File(p.join(inDir.path, name))..writeAsBytesSync(List.filled(500, 1));
    return PickedFile(
      path: f.path,
      displayName: name,
      type: SniffedType.jpeg,
      sizeBytes: 500,
      image: ImageMeta(format: SniffedType.jpeg, width: w, height: h),
      status: status,
    );
  }

  Future<List<OutputItem>> run(ExactSizeEngine engine, List<PickedFile> inputs, ResizeOptions o) async {
    final states = <JobState>[];
    await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice())
        .runMulti(
      jobId: 'r1',
      op: BatchResizeOperation(engine, clock: () => DateTime(2026, 10, 28)),
      inputs: inputs,
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code}');
    return (last as JobCompletedMulti).result.output.items;
  }

  (int, int) dims(OutputItem i) => ((i as OutputOk).meta.width!, i.meta.height!);

  test('pixels in a batch default to Fit inside: each keeps its shape, never enlarged (FR-BAT-12, ADR-062)', () async {
    expect(const ResizeOptions().fitInside, isTrue);
    final engine = ExactSizeEngine();
    final items = await run(
      engine,
      [photo('land.jpg', 4000, 3000), photo('port.jpg', 3000, 4000), photo('small.jpg', 800, 600)],
      const ResizeOptions(width: 1080, height: 1080),
    );
    expect(items.map(dims), [(1080, 810), (810, 1080), (800, 600)]);
    expect(engine.transforms.every((t) => t.fit == FitMode.stretch), isTrue, reason: 'same ratio: nothing to pad or crop');
    expect((items[0] as OutputOk).name, 'land_1080x810.jpg');
  });

  test('pixels with Fit inside off use the exact box and the chosen fit', () async {
    final engine = ExactSizeEngine();
    final items = await run(engine, [photo('a.jpg', 4000, 3000), photo('b.jpg', 3000, 4000)],
        const ResizeOptions(width: 1000, height: 1000, fitInside: false, fit: FitMode.cover));
    expect(items.map(dims), [(1000, 1000), (1000, 1000)]);
    expect(engine.transforms.map((t) => t.fit), [FitMode.cover, FitMode.cover]);
  });

  test('R30: Passport preset with a white border → every image exactly 413×531, padded, not stretched', () async {
    final engine = ExactSizeEngine();
    final items = await run(
      engine,
      [for (var i = 0; i < 10; i++) photo('p$i.jpg', i.isEven ? 4000 : 3000, i.isEven ? 3000 : 4000)],
      const ResizeOptions(mode: ResizeMode.preset, preset: 'passport', presetWidth: 413, presetHeight: 531, fit: FitMode.contain),
    );
    expect(items.map(dims).toSet(), {(413, 531)});
    expect(engine.transforms.every((t) => t.fit == FitMode.contain && t.pad == PadColor.white), isTrue);
  });

  test('percent applies to each image\'s own size', () async {
    final items = await run(ExactSizeEngine(), [photo('a.jpg', 4000, 3000), photo('b.jpg', 1000, 500)],
        const ResizeOptions(mode: ResizeMode.percent, percent: 50));
    expect(items.map(dims), [(2000, 1500), (500, 250)]);
  });

  test('an image whose result would be too large fails alone; invalid inputs fail with their error', () async {
    final items = await run(
      ExactSizeEngine(),
      [
        photo('ok.jpg', 1000, 800),
        photo('huge.jpg', 11000, 11000),
        photo('bad.jpg', 10, 10, status: const ValidationStatus.invalid(AppErrorCode.corruptFile)),
      ],
      const ResizeOptions(mode: ResizeMode.percent, percent: 200),
    );
    expect(items[0], isA<OutputOk>());
    expect((items[1] as OutputFailed).code, AppErrorCode.invalidInput);
    expect((items[2] as OutputFailed).code, AppErrorCode.corruptFile);
  });

  test('a missing box or preset is caught before the batch starts', () async {
    final op = BatchResizeOperation(ExactSizeEngine());
    await expectLater(op.validateInputs([photo('a.jpg', 100, 100)], const ResizeOptions()), throwsA(isA<AppError>()));
    await expectLater(
        op.validateInputs([photo('a.jpg', 100, 100)], const ResizeOptions(mode: ResizeMode.preset)), throwsA(isA<AppError>()));
  });

  test('the single tool runs the same per-image step (ADR-036)', () async {
    final engine = ExactSizeEngine();
    final work = paths.jobWork('s1')..createSync(recursive: true);
    final raw = await ResizeImageOperation(engine, clock: () => DateTime(2026, 10, 28)).execute(
      JobContext(jobId: 's1', workDir: work, cancel: CancelToken(), report: (_) {}),
      [photo('one.jpg', 4000, 3000)],
      const ResizeOptions(width: 400, height: 300),
    );
    expect(raw.suggestedName, 'one_400x300.jpg');
    expect((raw.flags['w'], raw.flags['h']), (400, 300));
  });

  test('fitInsideDims is what the batch uses', () => expect(fitInsideDims(1080, 1080, 4000, 3000), (1080, 810)));
}
