// T8.5 — Batch Compress (RELEASE_V1_1 FR-BAT-10/11/13/14, §4.3, ADR-036),
// written before the implementation. Runs through the real JobRunner.runMulti
// with an image engine that writes small real JPEGs.
import 'dart:io';
import 'dart:typed_data';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/validation/input_validator.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_compress/application/compress_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// Writes a real 8×8 JPEG padded to a size that falls with quality and scale:
/// `bytesFor(inputPath, quality, maxLongEdge)`.
class SizedJpegEngine implements ImageEngine {
  SizedJpegEngine(this.bytesFor);
  final int Function(String inPath, int quality, int? maxLongEdge) bytesFor;
  final calls = <(String, String)>[];
  static final _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

  @override
  bool canEncode(ImageFormat format) => format != ImageFormat.heic;
  @override
  Future<ImageMeta> inspect(String path) async => const ImageMeta(format: SniffedType.jpeg, width: 4000, height: 3000);
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    calls.add((inPath, outPath));
    final size = bytesFor(inPath, t.quality, t.maxLongEdge);
    final out = BytesBuilder()
      ..add(_jpeg)
      ..add(Uint8List(size > _jpeg.length ? size - _jpeg.length : 0));
    await File(outPath).writeAsBytes(out.toBytes());
    return EncodedImage(path: outPath, bytes: size, width: 8, height: 8, format: t.format);
  }
}

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late HistoryRepository history;
  late Directory inDir;

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    history = HistoryRepository(db);
    inDir = paths.jobIn('draft')..createSync(recursive: true);
  });
  tearDown(() => db.close());

  PickedFile photo(String name, {int size = 400000, ValidationStatus status = const ValidationStatus.ok()}) {
    final f = File(p.join(inDir.path, name))..writeAsBytesSync(List.filled(size, 1));
    return PickedFile(
      path: f.path,
      displayName: name,
      type: SniffedType.jpeg,
      sizeBytes: size,
      image: const ImageMeta(format: SniffedType.jpeg, width: 4000, height: 3000),
      status: status,
    );
  }

  Future<MultiJobResult> run(SizedJpegEngine engine, List<PickedFile> inputs, CompressOptions o) async {
    final states = <JobState>[];
    await JobRunner(paths: paths, history: history, outputs: OutputsRepository(paths), device: FakeDevice()).runMulti(
      jobId: 'b1',
      op: BatchCompressOperation(engine, clock: () => DateTime(2026, 10, 28)),
      inputs: inputs,
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code}');
    return (last as JobCompletedMulti).result;
  }

  test('limits: 1–50 images (FR-BAT-10)', () async {
    final op = BatchCompressOperation(SizedJpegEngine((_, _, _) => 100));
    expect(Limits.batchMaxImages, 50);
    await expectLater(op.validateInputs(const [], const CompressOptions()), throwsA(isA<AppError>()));
    final many = [for (var i = 0; i < 51; i++) fakeInput('/x/$i.jpg')];
    await expectLater(op.validateInputs(many, const CompressOptions()),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.tooManyFiles)));
  });

  test('one quality for all; every item gets its own output, none overwritten (FR-BAT-11)', () async {
    final engine = SizedJpegEngine((_, q, _) => 1000 + q);
    final r = await run(engine, [photo('a.jpg'), photo('b.jpg'), photo('c.jpg')], const CompressOptions(quality: 70));
    final ok = r.output.items.cast<OutputOk>();
    expect(ok.map((o) => o.meta.bytes), [1070, 1070, 1070]);
    expect(ok.map((o) => o.name), ['a_compressed.jpg', 'b_compressed.jpg', 'c_compressed.jpg']);
    expect(ok.every((o) => File(o.path).existsSync()), isTrue);
    expect(ok.map((o) => o.beforeBytes), [400000, 400000, 400000]);
    // Each item was encoded in its own folder.
    expect(engine.calls.map((c) => p.dirname(c.$2)).toSet(), hasLength(3));
  });

  test('invalid inputs become failed items with their own error; the rest run (R29)', () async {
    final r = await run(
      SizedJpegEngine((_, _, _) => 2000),
      [
        photo('ok1.jpg'),
        photo('broken.jpg', status: const ValidationStatus.invalid(AppErrorCode.corruptFile)),
        photo('doc.tiff', status: const ValidationStatus.invalid(AppErrorCode.unsupportedFormat)),
        photo('ok2.jpg'),
      ],
      const CompressOptions(),
    );
    expect(r.output.items.map((i) => i is OutputFailed ? i.code : null),
        [null, AppErrorCode.corruptFile, AppErrorCode.unsupportedFormat, null]);
    expect((r.output.items[1] as OutputFailed).sourceName, 'broken.jpg');
    expect((await history.get('b1'))!.status, OpStatus.partial);
  });

  test('target size is searched per image; only the image that cannot fit is marked (FR-BAT-13)', () async {
    // small.jpg shrinks below 100 KB at moderate quality; huge.jpg never does.
    final engine = SizedJpegEngine((inPath, q, edge) {
      final scale = (edge ?? 4000) / 4000;
      final base = inPath.endsWith('huge.jpg') ? 900000 : 160000;
      return (base * q / 100 * scale * scale).round() + 50000 * (inPath.endsWith('huge.jpg') ? 1 : 0);
    });
    final r = await run(engine, [photo('small.jpg'), photo('huge.jpg')],
        const CompressOptions(mode: CompressMode.targetSize, targetBytes: 100 * 1024));
    final small = r.output.items[0] as OutputOk;
    final huge = r.output.items[1] as OutputOk;
    expect(small.meta.bytes, lessThanOrEqualTo(100 * 1024));
    expect(small.meta.flags['targetMissed'], isFalse);
    expect(huge.meta.flags['targetMissed'], isTrue);
    expect(huge.meta.flags['targetBytes'], 100 * 1024);
    // Each search is bounded (8 attempts per image) and only the chosen attempt is kept.
    final perItem = <String, int>{};
    for (final (inPath, _) in engine.calls) {
      perItem[inPath] = (perItem[inPath] ?? 0) + 1;
    }
    expect(perItem.values.every((n) => n <= 8), isTrue);
    expect(File(small.path).existsSync() && File(huge.path).existsSync(), isTrue);
  });

  test('totals: Σ before and Σ after over the succeeded items (FR-BAT-14)', () async {
    final r = await run(
      SizedJpegEngine((_, _, _) => 1000),
      [photo('a.jpg', size: 3000), photo('b.jpg', size: 5000, status: const ValidationStatus.invalid(AppErrorCode.corruptFile))],
      const CompressOptions(),
    );
    final ok = r.output.items.whereType<OutputOk>().toList();
    expect(ok.fold<int>(0, (s, o) => s + o.beforeBytes!), 3000);
    expect(r.output.outputBytes, 1000);
  });

  test('the single tool runs the same per-image step (ADR-036)', () async {
    final engine = SizedJpegEngine((_, q, _) => 5000 + q);
    final work = Directory(p.join(paths.jobWork('s1').path))..createSync(recursive: true);
    final raw = await CompressImageOperation(engine, clock: () => DateTime(2026, 10, 28)).execute(
      JobContext(jobId: 's1', workDir: work, cancel: CancelToken(), report: (_) {}),
      [photo('one.jpg')],
      const CompressOptions(quality: 60),
    );
    expect(raw.suggestedName, 'one_compressed.jpg');
    expect(File(raw.path).lengthSync(), 5060);
    expect(raw.flags['quality'], 60);
  });
}
