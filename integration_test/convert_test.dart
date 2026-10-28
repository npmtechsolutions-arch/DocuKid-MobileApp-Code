// T8.7 on a device (RELEASE_V1_1 R31, FR-CNV-02/04/07): Convert Image with
// the real native encoder. HEIC inputs are made on the device with the same
// encoder (ADR-060: HEIC encode works on this emulator; output stays iOS-only).
//
//   flutter test integration_test/convert_test.dart -d <android device>
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/image_header.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_convert/application/convert_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

Uint8List photoJpeg(int w, int h, int seed) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, (x * 255 ~/ w + seed * 30) % 256, (y * 255 ~/ h) % 256, (seed * 50) % 256);
    }
  }
  return img.encodeJpg(im, quality: 92);
}

/// A transparent PNG: an opaque blue square in the middle, clear elsewhere.
Uint8List alphaPng(int w, int h) {
  final im = img.Image(width: w, height: h, numChannels: 4);
  img.fillRect(im, x1: w ~/ 4, y1: h ~/ 4, x2: w * 3 ~/ 4, y2: h * 3 ~/ 4, color: img.ColorRgba8(20, 60, 220, 255));
  return img.encodePng(im);
}

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
    inDir = paths.jobIn('it_convert')..createSync(recursive: true);
  });

  Future<PickedFile> picked(String name, Uint8List bytes) async {
    final path = p.join(inDir.path, name);
    File(path).writeAsBytesSync(bytes);
    final meta = await images.inspect(path);
    return PickedFile(path: path, displayName: name, type: meta.format, sizeBytes: bytes.length, image: meta);
  }

  Future<List<OutputOk>> run(List<PickedFile> inputs, ConvertOptions o) async {
    final before = {for (final f in inputs) f.path: sha(f.path)};
    final states = <JobState>[];
    await runner.runMulti(
      jobId: 'it_${DateTime.now().microsecondsSinceEpoch}',
      op: BatchConvertOperation(images),
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

  testWidgets('R31a: 5 HEIC → JPG: real JPEGs, same size, decodable (FR-CNV-07)', (_) async {
    final heics = <PickedFile>[];
    for (var i = 0; i < 5; i++) {
      final heic = await FlutterImageCompress.compressWithList(photoJpeg(1600 + i * 40, 1200, i), format: CompressFormat.heic, quality: 90);
      final f = await picked('IMG_${2000 + i}.heic', heic);
      expect(f.type, SniffedType.heic, reason: 'input really is HEIC');
      heics.add(f);
    }
    final out = await run(heics, const ConvertOptions());
    for (final (i, o) in out.indexed) {
      expect(o.name, 'IMG_${2000 + i}.jpg');
      final h = await readImageHeader(o.path);
      expect(h.type, SniffedType.jpeg);
      expect((h.displayWidth, h.displayHeight), (heics[i].image!.width, heics[i].image!.height));
      expect(img.decodeJpg(File(o.path).readAsBytesSync()), isNotNull, reason: 'opens with a plain JPEG decoder');
    }
    // ignore: avoid_print
    print('R31a ${out.map((o) => '${o.name} ${o.meta.width}x${o.meta.height} ${o.meta.bytes}B').join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('R31b: 2 alpha PNG → JPG: transparent areas become white, the opaque part keeps its colour (FR-CNV-04)', (_) async {
    final pngs = [await picked('logo_a.png', alphaPng(400, 300)), await picked('logo_b.png', alphaPng(300, 400))];
    expect(pngs.every((f) => f.image!.hasAlpha), isTrue);
    expect(alphaWillBeLost(pngs, ImageFormat.jpeg), isTrue, reason: 'the screen shows the warning');
    final out = await run(pngs, const ConvertOptions());
    for (final o in out) {
      final im = img.decodeJpg(File(o.path).readAsBytesSync())!;
      final corner = im.getPixel(5, 5);
      final centre = im.getPixel(im.width ~/ 2, im.height ~/ 2);
      // ignore: avoid_print
      print('R31b ${o.name} ${im.width}x${im.height} corner=(${corner.r},${corner.g},${corner.b}) centre=(${centre.r},${centre.g},${centre.b})');
      expect(corner.r > 240 && corner.g > 240 && corner.b > 240, isTrue, reason: '${o.name}: white background');
      expect(centre.b > 180 && centre.r < 80, isTrue, reason: '${o.name}: the opaque square stays blue');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('WebP output on Android keeps alpha (FR-CNV-02, ADR-060)', (_) async {
    final out = await run([await picked('logo.png', alphaPng(400, 300))], const ConvertOptions(format: ImageFormat.webp, quality: 85));
    final h = await readImageHeader(out.single.path);
    expect(h.type, SniffedType.webp);
    expect((h.displayWidth, h.displayHeight), (400, 300));
    final im = img.decodeWebP(File(out.single.path).readAsBytesSync())!;
    expect(im.getPixel(5, 5).a, lessThan(20), reason: 'corner stays transparent');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
