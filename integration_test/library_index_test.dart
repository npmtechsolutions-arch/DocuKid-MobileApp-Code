// T12.5 on a device (RELEASE_V1_5 R63, R68): the index queue with the real
// PDFium (text layer + 200 dpi render), ML Kit and SQLite FTS5, and the real
// battery reading from docukit_native.
//
// R68 needs the host to fake the battery around the run:
//   adb shell dumpsys battery unplug && adb shell dumpsys battery set level 15
//   flutter test integration_test/library_index_test.dart -d <android device> &
//   sleep 60; adb shell dumpsys battery set ac 1      # "plug in" → resumes
//   adb shell dumpsys battery reset                    # afterwards
import 'dart:io';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/ocr/mlkit_text_recognizer.dart';
import 'package:docukit/core/ocr/pdfrx_text_reader.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/library/application/index_queue.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import '../tool/fixtures/ocr_text.dart';

const billText = 'Municipal water bill. Account 4471. Amount due 1250 rupees, payable before the fifteenth of March.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppDatabase db;
  late LibraryRepositoryImpl repo;
  final device = NativeDeviceServices(DocukitNative());

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    final paths = await AppPaths.resolve();
    dir = Directory(p.join(paths.cacheRoot.path, 'it_library_index'))..createSync(recursive: true);
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(db, Directory(p.join(dir.path, 'support'))..createSync());
  });
  tearDownAll(() async {
    await repo.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// An image-only PDF: one A4 page that is a photo of [text] (no text layer).
  Future<String> scannedPdf(String name, String text) async {
    final f = await drawOcrPage(text);
    final jpg = img.encodeJpg(img.decodePng(f.png)!, quality: 90);
    final doc = pw.Document()
      ..addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(jpg), fit: pw.BoxFit.fill)));
    final out = File(p.join(dir.path, name));
    await out.writeAsBytes(await doc.save());
    return out.path;
  }

  IndexQueue queue({required SettingsRepository store}) => IndexQueue(
        repo: repo,
        source: LibraryTextSource(
          pdfs: PdfrxPdfEngine(),
          images: const NativeImageEngine(),
          encoder: const NativePageImageEncoder(),
          textLayer: pdfrxAllText,
          recognizer: MlKitTextRecognizer.new,
        ),
        store: store,
        settings: () => const AppSettings(),
        battery: device.battery,
        busy: () => false,
        workRoot: Directory(p.join(dir.path, 'index')),
        poll: const Duration(seconds: 2),
      );

  Future<void> until(IndexQueue q, bool Function(IndexStatus) done, {Duration max = const Duration(seconds: 120)}) async {
    final end = DateTime.now().add(max);
    while (!done(q.status) && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  testWidgets('R63 + R68: a scan waits on low battery, resumes when plugged in, is OCR\'d; a word on it is found with a snippet',
      (_) async {
    final b = await device.battery();
    // ignore: avoid_print
    print('R68 battery at start: level=${b.level} charging=${b.charging}');
    final low = batteryLow(b);

    final store = SettingsRepository(MemoryStore());
    final added = await repo.addFile(await scannedPdf('scan.pdf', billText),
        displayName: 'Scan 2026-10-31.pdf', source: DocSource.scan, mime: 'application/pdf');
    final doc = (added as Added).doc;
    final q = queue(store: store);
    await q.start();

    if (low) {
      await until(q, (s) => s.paused == IndexPause.battery, max: const Duration(seconds: 10));
      // ignore: avoid_print
      print('R68 paused: ${q.status}');
      expect(q.status.paused, IndexPause.battery);
      expect((await repo.get(doc.id))!.indexState, IndexState.queued);
      // The host plugs the "charger" in (see the header); the queue polls.
    } else {
      // ignore: avoid_print
      print('R68 not exercised: battery not low (run the adb steps in the header)');
    }

    final sw = Stopwatch()..start();
    await until(q, (s) => s == const IndexStatus());
    // ignore: avoid_print
    print('R63 indexed in ${sw.elapsedMilliseconds} ms after resuming; status ${q.status}');
    expect((await repo.get(doc.id))!.indexState, IndexState.done);

    final hits = await repo.search('payable').first;
    // ignore: avoid_print
    print('R63 snippet: ${hits.single.snippet}');
    expect(hits.single.doc.id, doc.id);
    expect(hits.single.snippet, contains('[payable]'));
    expect([for (final h in await repo.search('4471').first) h.doc.id], [doc.id]);
    await q.dispose();
  });

  testWidgets('a PDF with a text layer is indexed without OCR, whatever the settings', (_) async {
    final pdf = pw.Document()
      ..addPage(pw.Page(build: (_) => pw.Text('Tenancy agreement between the landlord and the tenant for flat 12B.')));
    final path = p.join(dir.path, 'lease.pdf');
    await File(path).writeAsBytes(await pdf.save());
    final doc = ((await repo.addFile(path, displayName: 'Lease.pdf', source: DocSource.import, mime: 'application/pdf')) as Added).doc;
    final q = IndexQueue(
      repo: repo,
      source: LibraryTextSource(
        pdfs: PdfrxPdfEngine(),
        images: const NativeImageEngine(),
        encoder: const NativePageImageEncoder(),
        textLayer: pdfrxAllText,
        recognizer: () => throw StateError('OCR must not run'),
      ),
      store: SettingsRepository(MemoryStore()),
      settings: () => const AppSettings(),
      battery: () async => (level: 90, charging: true),
      busy: () => false,
      workRoot: Directory(p.join(dir.path, 'index2')),
    );
    await q.start();
    // The status starts idle, so wait on the document itself.
    final end = DateTime.now().add(const Duration(seconds: 30));
    while ((await repo.get(doc.id))!.indexState != IndexState.done && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect((await repo.get(doc.id))!.indexState, IndexState.done);
    expect([for (final h in await repo.search('landlord').first) h.doc.id], [doc.id]);
    await q.dispose();
  });
}
