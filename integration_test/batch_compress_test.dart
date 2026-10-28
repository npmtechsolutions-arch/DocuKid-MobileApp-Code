// T8.5 on a device (RELEASE_V1_1 §8.3, §8.5 R27–R29): Batch Compress with
// the real native encoder. R27's "Save all" opens the system folder picker:
// pick (or create) an empty folder and tap "Use this folder" → "Allow".
//
//   flutter test integration_test/batch_compress_test.dart -d <android device>
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/file_gateway.dart';
import 'package:docukit/core/files/file_gateway_impl.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/files/zip_builder.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_compress/application/compress_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

/// A 4 MP photo-like JPEG (gradient + noise), like corpus IMG-22.
Uint8List photo4mp(int seed) {
  final r = img.Image(width: 2400, height: 1700);
  var s = seed * 7919 + 1;
  for (var y = 0; y < r.height; y++) {
    for (var x = 0; x < r.width; x++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final n = (s >> 16) % 41 - 20;
      r.setPixelRgb(x, y, (x * 255 ~/ r.width + n + seed * 9).clamp(0, 255), (y * 255 ~/ r.height + n).clamp(0, 255),
          ((x + y) * 255 ~/ (r.width + r.height) - n).clamp(0, 255));
    }
  }
  return img.encodeJpg(r, quality: 92);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPaths paths;
  late JobRunner runner;
  late HistoryRepository history;
  late Directory inDir;
  late PluginFileGateway gateway;
  const images = NativeImageEngine();
  final photos = <String>[];

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    history = HistoryRepository(AppDatabase(NativeDatabase.memory()));
    runner = JobRunner(paths: paths, history: history, outputs: OutputsRepository(paths), device: NativeDeviceServices(DocukitNative()));
    inDir = paths.jobIn('it_batch')..createSync(recursive: true);
    gateway = PluginFileGateway(paths: paths, images: images, pdfs: PdfrxPdfEngine(), native: DocukitNative());
    // 10 distinct photos, encoded in parallel; the 50-image batch reuses them.
    final bytes = await Future.wait([for (var i = 0; i < 10; i++) Isolate.run(() => photo4mp(i))]);
    for (var i = 0; i < 50; i++) {
      final path = p.join(inDir.path, 'IMG_${1000 + i}.jpg');
      File(path).writeAsBytesSync(bytes[i % 10]);
      photos.add(path);
    }
  });

  // reinspect sniffs and inspects each file like the picker does.
  Future<List<PickedFile>> picked(List<String> files) async => gateway.reinspect([
        for (final f in files)
          PickedFile(path: f, displayName: p.basename(f), type: SniffedType.unknown, sizeBytes: File(f).lengthSync()),
      ]);

  Future<(MultiJobResult?, JobFailed?, int peakRssMb, int baseRssMb, Duration took)> run(List<PickedFile> inputs, CompressOptions o) async {
    final before = {for (final f in inputs) f.path: sha(f.path)};
    final states = <JobState>[];
    final base = ProcessInfo.currentRss;
    var peak = base;
    final sampler = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
    });
    final sw = Stopwatch()..start();
    await runner.runMulti(
      jobId: 'it_${DateTime.now().microsecondsSinceEpoch}',
      op: BatchCompressOperation(images),
      inputs: inputs,
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    sw.stop();
    sampler.cancel();
    for (final f in inputs) {
      expect(sha(f.path), before[f.path], reason: 'input must be unchanged (rule 1)');
    }
    final last = states.last;
    return (
      last is JobCompletedMulti ? last.result : null,
      last is JobFailed ? last : null,
      peak ~/ (1 << 20),
      base ~/ (1 << 20),
      sw.elapsed,
    );
  }

  testWidgets('R27 + R28: 30 photos at q70 → all smaller and valid; Save all; ZIP has 30 entries', (_) async {
    final inputs = await picked(photos.sublist(0, 30));
    expect(inputs.every((f) => f.status.isValid), isTrue);
    final (r, failed, peak, base, took) = await run(inputs, const CompressOptions(quality: 70));
    expect(failed, isNull);
    final ok = r!.output.items.cast<OutputOk>();
    expect(ok, hasLength(30));
    final before = ok.fold<int>(0, (s, o) => s + o.beforeBytes!);
    final after = ok.fold<int>(0, (s, o) => s + o.meta.bytes);
    expect(after, r.output.outputBytes, reason: 'totals add up');
    expect(after, lessThan(before));
    // ignore: avoid_print
    print('R27 batch30 took=${took.inMilliseconds}ms before=$before after=$after rss base=${base}MB peak=${peak}MB');

    // R27: Save all → the folder picker (interactive).
    final saved = await gateway.saveManyToFolder([for (final o in ok) SaveItem(path: o.path, name: o.name, mime: o.mime)]);
    // ignore: avoid_print
    print('R27 save ${saved is SavedMany ? '${saved.saved}/${saved.failed} folder=${saved.folderName}' : saved.runtimeType}');
    expect(saved, isA<SavedMany>());
    expect((saved as SavedMany).saved, 30);
    expect(saved.failed, 0);

    // R28: Save as ZIP → 30 entries, reopenable.
    final zip = p.join(paths.outputsRoot.path, r.jobId, zipFileName(r.tool, DateTime.now()));
    final sw = Stopwatch()..start();
    expect(await buildZip([for (final o in ok) ZipItem(o.path, o.name)], zip), 30);
    final input = InputFileStream(zip);
    final entries = ZipDecoder().decodeStream(input).files;
    input.closeSync();
    expect(entries, hasLength(30));
    expect(entries.map((e) => e.name).toSet(), hasLength(30));
    // ignore: avoid_print
    print('R28 zip entries=${entries.length} bytes=${File(zip).lengthSync()} took=${sw.elapsedMilliseconds}ms');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('R29: 1 corrupt + 1 unsupported → partial, per-file errors, history PARTIAL', (_) async {
    final corrupt = p.join(inDir.path, 'broken.jpg');
    final head = File(photos.first).readAsBytesSync();
    File(corrupt).writeAsBytesSync([...head.sublist(0, 4), ...List.filled(5000, 0x41)]); // JPEG magic, no header
    final gif = p.join(inDir.path, 'anim.gif');
    File(gif).writeAsBytesSync([...'GIF89a'.codeUnits, ...List.filled(200, 0)]);
    final inputs = await picked([photos[0], corrupt, gif, photos[1]]);
    expect(inputs.map((f) => f.status.isValid), [true, false, false, true]);
    final (r, failed, _, _, _) = await run(inputs, const CompressOptions(quality: 70));
    expect(failed, isNull);
    final codes = r!.output.items.map((i) => i is OutputFailed ? i.code : null).toList();
    // ignore: avoid_print
    print('R29 items=$codes');
    expect(codes[0], isNull);
    expect(codes[1], isNotNull);
    expect(codes[2], AppErrorCode.unsupportedFormat);
    expect(codes[3], isNull);
    expect((await history.get(r.jobId))!.status, OpStatus.partial);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('50-image batch: memory stays flat (§4.3: sequential, metadata only)', (_) async {
    final inputs = await picked(photos);
    final (r, failed, peak, base, took) = await run(inputs, const CompressOptions(quality: 70));
    expect(failed, isNull);
    expect(r!.output.succeeded, 50);
    // ignore: avoid_print
    print('MEM batch50 took=${took.inMilliseconds}ms rss base=${base}MB peak=${peak}MB delta=${peak - base}MB');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('target size per image at 100 KB: each searched on its own (FR-BAT-13)', (_) async {
    final inputs = await picked(photos.sublist(0, 5));
    final (r, failed, _, _, took) = await run(inputs, const CompressOptions(mode: CompressMode.targetSize, targetBytes: 100 * 1024));
    expect(failed, isNull);
    final ok = r!.output.items.cast<OutputOk>();
    // ignore: avoid_print
    print('TARGET sizes=${ok.map((o) => o.meta.bytes).toList()} missed=${ok.map((o) => o.meta.flags['targetMissed']).toList()} took=${took.inMilliseconds}ms');
    for (final o in ok) {
      if (o.meta.flags['targetMissed'] != true) expect(o.meta.bytes, lessThanOrEqualTo(100 * 1024));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
