// T8.6 on a device (RELEASE_V1_1 R30, FR-BAT-12): Batch Resize with the real
// native encoder.
//
//   flutter test integration_test/batch_resize_test.dart -d <android device>
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/image_header.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/resize_math.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_resize/application/resize_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import '../tool/fixtures/orientation.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPaths paths;
  late JobRunner runner;
  late Directory inDir;
  const images = NativeImageEngine();

  setUpAll(() async {
    paths = await AppPaths.resolve();
    runner = JobRunner(
      paths: paths,
      history: HistoryRepository(AppDatabase(NativeDatabase.memory())),
      outputs: OutputsRepository(paths),
      device: NativeDeviceServices(DocukitNative()),
    );
    inDir = paths.jobIn('it_resize')..createSync(recursive: true);
  });

  Future<PickedFile> picked(String name, Uint8List bytes) async {
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(bytes);
    final meta = await images.inspect(path);
    return PickedFile(path: path, displayName: name, type: meta.format, sizeBytes: bytes.length, image: meta);
  }

  Future<List<OutputOk>> run(List<PickedFile> inputs, ResizeOptions o) async {
    final before = {for (final f in inputs) f.path: sha(f.path)};
    final states = <JobState>[];
    await runner.runMulti(
      jobId: 'it_${DateTime.now().microsecondsSinceEpoch}',
      op: BatchResizeOperation(images),
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
    final items = (last as JobCompletedMulti).result.output.items;
    expect(items.whereType<OutputFailed>(), isEmpty);
    return items.cast<OutputOk>();
  }

  testWidgets('R30: 10 photos, Passport preset with a white border → all 413×531, upright, not stretched', (_) async {
    // Orientations 1–8 display as 900×1200 portraits; two landscapes 1200×900.
    final inputs = [
      for (var o = 1; o <= 8; o++) await picked('orient_$o.jpg', orientationFixture(o)),
      await picked('land_1.jpg', orientationFixture(1, width: 1200, height: 900)),
      await picked('land_6.jpg', orientationFixture(6, width: 1200, height: 900)),
    ];
    final out = await run(
      inputs,
      ResizeOptions(
        mode: ResizeMode.preset,
        preset: BuiltInPreset.passport.name,
        presetWidth: 413,
        presetHeight: 531,
        fit: FitMode.contain,
        pad: PadColor.white,
      ),
    );
    expect(out, hasLength(10));
    for (final (i, o) in out.indexed) {
      final h = await readImageHeader(o.path);
      expect((h.displayWidth, h.displayHeight), (413, 531), reason: o.name);
      expect(h.orientation, 1, reason: '${o.name}: orientation baked into the pixels');
      final im = img.decodeJpg(File(o.path).readAsBytesSync())!;
      bool red(int x, int y) {
        final px = im.getPixel(x, y);
        return px.r > 150 && px.g < 100 && px.b < 100;
      }

      bool white(int x, int y) {
        final px = im.getPixel(x, y);
        return px.r > 235 && px.g > 235 && px.b > 235;
      }

      if (i < 8) {
        // 900×1200 → 398×531 centred: thin white side bands, marker top-left.
        expect(white(2, 265) && white(410, 265), isTrue, reason: '${o.name}: side border, not stretched');
        expect(red(40, 40), isTrue, reason: '${o.name}: marker top-left (upright)');
        expect(red(372, 490), isFalse, reason: o.name);
      } else {
        // 1200×900 → 413×310 centred: white bands top and bottom (~110 px).
        expect(white(206, 40) && white(206, 490), isTrue, reason: '${o.name}: top/bottom border, not stretched');
        expect(red(40, 150), isTrue, reason: '${o.name}: marker top-left of the picture (upright)');
        expect(red(372, 400), isFalse, reason: o.name);
      }
    }
    // ignore: avoid_print
    print('R30 ok: ${out.map((o) => o.name).join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Fit inside 1080×1080: each keeps its ratio, small ones keep their size (FR-BAT-12, ADR-062)', (_) async {
    final inputs = [
      await picked('wide.jpg', orientationFixture(1, width: 2400, height: 1800)),
      await picked('tall.jpg', orientationFixture(6, width: 1800, height: 2400)),
      await picked('small.jpg', orientationFixture(1, width: 800, height: 600)),
    ];
    final out = await run(inputs, const ResizeOptions(width: 1080, height: 1080));
    final dims = [for (final o in out) (o.meta.width, o.meta.height)];
    // ignore: avoid_print
    print('FIT_INSIDE dims=$dims');
    expect(dims, [(1080, 810), (810, 1080), (800, 600)]);
    for (final o in out) {
      final h = await readImageHeader(o.path);
      expect((h.displayWidth, h.displayHeight), (o.meta.width, o.meta.height));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
