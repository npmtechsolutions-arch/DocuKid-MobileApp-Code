// T8.7 — Convert Image (RELEASE_V1_1 FR-CNV-01…07), written before the
// implementation. Runs through the real JobRunner with an engine that writes
// real images at the input's oriented size.
import 'dart:io';

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
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/image_convert/application/convert_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// Writes a real image in the requested format at the input's oriented size
/// (it never receives a target size from Convert).
class FormatEngine implements ImageEngine {
  FormatEngine({this.heic = false});
  final bool heic;
  final transforms = <ImageTransform>[];
  @override
  bool canEncode(ImageFormat format) => format != ImageFormat.heic || heic;
  @override
  Future<ImageMeta> inspect(String path) async => throw UnimplementedError();
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    transforms.add(t);
    final im = img.Image(width: meta!.width, height: meta.height);
    final bytes = switch (t.format) {
      ImageFormat.png => img.encodePng(im),
      _ => img.encodeJpg(im), // WebP/HEIC aren't encodable by the image package; JPEG stands in
    };
    await File(outPath).writeAsBytes(bytes);
    return EncodedImage(path: outPath, bytes: bytes.length, width: meta.width, height: meta.height, format: t.format);
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

  PickedFile image(String name, SniffedType type, {int w = 60, int h = 40, bool alpha = false, ValidationStatus status = const ValidationStatus.ok()}) {
    final f = File(p.join(inDir.path, name))..writeAsBytesSync(List.filled(300, 1));
    return PickedFile(
      path: f.path,
      displayName: name,
      type: type,
      sizeBytes: 300,
      image: ImageMeta(format: type, width: w, height: h, hasAlpha: alpha),
      status: status,
    );
  }

  test('formats come from the engine: HEIC only where it can be encoded (FR-CNV-02)', () {
    expect(convertFormats(FormatEngine()), [ImageFormat.jpeg, ImageFormat.png, ImageFormat.webp]);
    expect(convertFormats(FormatEngine(heic: true)), [ImageFormat.jpeg, ImageFormat.png, ImageFormat.webp, ImageFormat.heic]);
  });

  test('defaults: JPG, quality 90, metadata removed (FR-CNV-03/05)', () {
    const o = ConvertOptions();
    expect((o.format, o.quality, o.stripMetadata), (ImageFormat.jpeg, 90, true));
    expect(o.hasQuality, isTrue);
    expect(const ConvertOptions(format: ImageFormat.png).hasQuality, isFalse);
    expect(ConvertOptions.fromJson(const ConvertOptions(format: ImageFormat.webp, quality: 70).toJson(), const ConvertOptions()).format,
        ImageFormat.webp);
  });

  test('alpha warning only when a transparent input goes to a format without alpha (FR-CNV-04)', () {
    final files = [image('a.png', SniffedType.png, alpha: true), image('b.jpg', SniffedType.jpeg)];
    expect(alphaWillBeLost(files, ImageFormat.jpeg), isTrue);
    expect(alphaWillBeLost(files, ImageFormat.png), isFalse);
    expect(alphaWillBeLost(files, ImageFormat.webp), isFalse);
    expect(alphaWillBeLost([image('b.jpg', SniffedType.jpeg)], ImageFormat.jpeg), isFalse);
  });

  test('same-format count for the hint (FR-CNV-06); HEIF counts as HEIC', () {
    final files = [image('a.jpg', SniffedType.jpeg), image('b.jpg', SniffedType.jpeg), image('c.png', SniffedType.png)];
    expect(sameFormatCount(files, ImageFormat.jpeg), 2);
    expect(sameFormatCount(files, ImageFormat.webp), 0);
    expect(sameFormatCount([image('d.heic', SniffedType.heic)], ImageFormat.heic), 1);
  });

  test('one image: same base name, new extension; size unchanged; options passed through (FR-CNV-07)', () async {
    final engine = FormatEngine();
    final work = paths.jobWork('s1')..createSync(recursive: true);
    final op = ConvertImageOperation(engine);
    final input = image('IMG_1234.heic', SniffedType.heic, w: 120, h: 90);
    final raw = await op.execute(JobContext(jobId: 's1', workDir: work, cancel: CancelToken(), report: (_) {}), [input],
        const ConvertOptions(quality: 75, stripMetadata: false));
    expect(raw.suggestedName, 'IMG_1234.jpg');
    expect(raw.mime, 'image/jpeg');
    final t = engine.transforms.single;
    expect((t.format, t.quality, t.stripMetadata), (ImageFormat.jpeg, 75, false));
    expect((t.targetWidth, t.targetHeight, t.maxLongEdge), (null, null, null), reason: 'Convert never resizes');
    final meta = await op.validateOutput(raw, [input], const ConvertOptions());
    expect((meta.width, meta.height), (120, 90));
  });

  test('validation fails when the output size differs from the input (FR-CNV-07)', () async {
    final out = File(p.join(inDir.path, 'wrong.jpg'))..writeAsBytesSync(img.encodeJpg(img.Image(width: 10, height: 10)));
    final raw = RawOutput(path: out.path, suggestedName: 'x.jpg', mime: 'image/jpeg', flags: const {'format': 'jpeg', 'w': 120, 'h': 90});
    await expectLater(validateConverted(raw), throwsA(isA<AppError>()));
  });

  test('batch: one output per image, invalid ones fail alone, PNG keeps PNG (FR-CNV-01)', () async {
    final states = <JobState>[];
    await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice()).runMulti(
      jobId: 'c1',
      op: BatchConvertOperation(FormatEngine()),
      inputs: [
        image('a.heic', SniffedType.heic),
        image('bad.jpg', SniffedType.jpeg, status: const ValidationStatus.invalid(AppErrorCode.corruptFile)),
        image('c.webp', SniffedType.webp, w: 30, h: 50),
      ],
      options: const ConvertOptions(format: ImageFormat.png),
      cancel: CancelToken(),
      emit: states.add,
    );
    final items = (states.last as JobCompletedMulti).result.output.items;
    expect((items[0] as OutputOk).name, 'a.png');
    expect((items[1] as OutputFailed).code, AppErrorCode.corruptFile);
    final c = items[2] as OutputOk;
    expect((c.name, c.mime, c.meta.width, c.meta.height), ('c.png', 'image/png', 30, 50));
  });

  test('remembered choices: convert_format / convert_quality (§5.2)', () async {
    final store = MemoryStore();
    final repo = SettingsRepository(store);
    expect((repo.load().convertFormat, repo.load().convertQuality), (ImageFormat.jpeg, 90));
    await repo.save(repo.load().copyWith(convertFormat: ImageFormat.webp, convertQuality: 70));
    expect(store.get(SettingsRepository.kConvertFormat), 'webp');
    expect(store.get(SettingsRepository.kConvertQuality), 70);
    expect(repo.load().convertFormat, ImageFormat.webp);
  });
}
