// Images → PDF stress test (TESTING.md §6): 20 and 100 generated 12 MP photos,
// default options (A4, auto orientation, Fit, Small margins, High quality).
// Records build time and peak process RSS, and checks the page count and the
// page order. Slow (the photos are generated on the device), so it lives
// apart from engines_test.dart:
//
//   flutter test integration_test/i2p_stress_test.dart -d <deviceId>
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_to_pdf/application/image_to_pdf_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

/// Ten well-separated colours; a photo's index is coded as
/// (tens, units) = (top-left quadrant colour, top-right quadrant colour).
const palette = <(int, int, int)>[
  (230, 30, 30), (30, 200, 60), (30, 60, 230), (240, 220, 30), (220, 40, 220),
  (30, 220, 230), (20, 20, 20), (245, 245, 245), (245, 140, 20), (120, 40, 160),
];

int nearest(int r, int g, int b) {
  var best = 0, bestD = 1 << 30;
  for (var i = 0; i < palette.length; i++) {
    final (pr, pg, pb) = palette[i];
    final d = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb);
    if (d < bestD) (best, bestD) = (i, d);
  }
  return best;
}

/// A 4000×3000 "photo": noisy gradient, with the two code quadrants on top.
Uint8List photo12mp(img.Image base, int index) {
  final im = img.Image.from(base);
  void block(int x1, int x2, (int, int, int) c) {
    final rnd = math.Random(index);
    for (var y = 0; y < 1500; y++) {
      for (var x = x1; x < x2; x++) {
        final n = rnd.nextInt(31) - 15;
        im.setPixelRgb(x, y, (c.$1 + n).clamp(0, 255), (c.$2 + n).clamp(0, 255), (c.$3 + n).clamp(0, 255));
      }
    }
  }

  block(0, 2000, palette[index ~/ 10]);
  block(2000, 4000, palette[index % 10]);
  return img.encodeJpg(im, quality: 92);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPaths paths;
  late JobRunner runner;
  const images = NativeImageEngine();
  final pdfs = PdfrxPdfEngine();
  late img.Image base;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    runner = JobRunner(
      paths: paths,
      history: HistoryRepository(AppDatabase(NativeDatabase.memory())),
      outputs: OutputsRepository(paths),
      device: NativeDeviceServices(DocukitNative()),
    );
    final r = math.Random(7);
    base = img.Image(width: 4000, height: 3000);
    for (var y = 0; y < 3000; y++) {
      for (var x = 0; x < 4000; x++) {
        final n = r.nextInt(49) - 24;
        base.setPixelRgb(x, y, (x * 255 ~/ 4000 + n).clamp(0, 255), (y * 255 ~/ 3000 + n).clamp(0, 255), (128 + n).clamp(0, 255));
      }
    }
  });

  Future<List<PickedFile>> generate(int n) async {
    final dir = paths.jobIn('stress_$n')..createSync(recursive: true);
    final files = <PickedFile>[];
    for (var i = 0; i < n; i++) {
      final path = p.join(dir.path, 'photo_${i.toString().padLeft(3, '0')}.jpg');
      if (!File(path).existsSync()) File(path).writeAsBytesSync(photo12mp(base, i));
      final meta = await images.inspect(path);
      files.add(PickedFile(path: path, displayName: p.basename(path), type: meta.format, sizeBytes: File(path).lengthSync(), image: meta));
    }
    return files;
  }

  Future<void> stress(int n) async {
    final inputs = await generate(n);
    expect(inputs.first.image!.width, 4000);
    final inputMb = inputs.fold<int>(0, (a, f) => a + f.sizeBytes) / (1 << 20);

    // Peak RSS of the whole process (native decoders included), sampled during the build.
    final rssBefore = ProcessInfo.currentRss;
    var peak = rssBefore;
    final sampler = Timer.periodic(const Duration(milliseconds: 200), (_) => peak = math.max(peak, ProcessInfo.currentRss));
    final states = <JobState>[];
    final sw = Stopwatch()..start();
    await runner.run<ImageToPdfOptions>(
      jobId: 'stress_${n}_${DateTime.now().millisecondsSinceEpoch}',
      op: ImageToPdfOperation(images, pdfs),
      inputs: inputs,
      options: const ImageToPdfOptions(),
      cancel: CancelToken(),
      emit: states.add,
    );
    sw.stop();
    sampler.cancel();
    peak = math.max(peak, ProcessInfo.currentRss);

    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final r = (last as JobCompleted).result;
    expect(r.meta.pages, n, reason: 'one page per image');

    // Page order: read each page's code colours back.
    final order = <int>[];
    for (var i = 0; i < n; i++) {
      final page = await pdfs.renderPage(r.outputPath, i, targetWidthPx: 300);
      final data = (await page!.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int code(double fx, double fy) {
        final (x0, y0) = ((page.width * fx).round(), (page.height * fy).round());
        var (rs, gs, bs) = (0, 0, 0);
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final o = ((y0 + dy) * page.width + (x0 + dx)) * 4;
            rs += data.getUint8(o);
            gs += data.getUint8(o + 1);
            bs += data.getUint8(o + 2);
          }
        }
        return nearest(rs ~/ 25, gs ~/ 25, bs ~/ 25);
      }

      order.add(code(0.28, 0.27) * 10 + code(0.72, 0.27));
      page.dispose();
    }
    expect(order, [for (var i = 0; i < n; i++) i], reason: 'pages in input order');

    final mb = (1 << 20).toDouble();
    debugPrint('STRESS n=$n time=${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s '
        'peakRSS=${(peak / mb).round()}MB rssBefore=${(rssBefore / mb).round()}MB '
        'input=${inputMb.round()}MB output=${(r.meta.bytes / mb).toStringAsFixed(1)}MB pages=${r.meta.pages}');

    // Free the device space for the next run.
    File(r.outputPath).parent.deleteSync(recursive: true);
  }

  testWidgets('Images → PDF: 20 × 12 MP', (_) => stress(20), timeout: const Timeout(Duration(minutes: 60)));
  testWidgets('Images → PDF: 100 × 12 MP', (_) => stress(100), timeout: const Timeout(Duration(minutes: 120)));
}
