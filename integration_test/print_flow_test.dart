// T13.8 regression R69–R74 (RELEASE_PRINT §8) through the real app on a
// device: DocuKitApp with real paths, PDFium composer, native print gateway
// and image engine (in-memory DB, no ads). S48 is opened as the entry points
// do (a request, then /print/preview); its buttons are tapped for real. The
// host drives the system dialog — "FLOW dialog open" → Save as PDF (R69, R70,
// R72) or Back (R73) — and checks the saved file.
//
//   flutter test integration_test/print_flow_test.dart -d <android device> --plain-name R69   (R70, R72, R73, R74)
import 'dart:async';
import 'dart:io';

import 'package:docukit/app/app.dart';
import 'package:docukit/core/ads/ads_service.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/print/print_composer.dart';
import 'package:docukit/core/print/print_settings.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/print/application/print_preview_controller.dart';
import 'package:docukit/features/print/presentation/print_preview_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tour/tour_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

// ignore: avoid_print
void log(String s) => print('FLOW $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppPaths paths;
  late ProviderContainer container;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    dir = Directory(p.join(paths.cacheRoot.path, 'it_print_flow'))..createSync(recursive: true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<String> makePdf(String name, int n) async {
    final doc = pw.Document();
    for (var i = 1; i <= n; i++) {
      final tag = n <= 26 ? 'PAGE${String.fromCharCode(64 + i)}' : 'PAGE$i';
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(60),
        build: (_) => pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(tag, style: const pw.TextStyle(fontSize: 40)),
          pw.Text('Page $i of $n', style: const pw.TextStyle(fontSize: 14)),
        ]),
      ));
    }
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(await doc.save());
    return path;
  }

  Future<PickedFile> pdfFile(String path) async {
    final meta = await PdfrxPdfEngine().inspect(path);
    return PickedFile(
        path: path, displayName: p.basename(path), type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: meta);
  }

  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<bool> waitFor(WidgetTester tester, bool Function() ok, {Duration timeout = const Duration(seconds: 60)}) async {
    final end = DateTime.now().add(timeout);
    while (!ok() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return ok();
  }

  bool enabled(WidgetTester tester, String label) {
    final f = find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>());
    return f.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(f.first).onPressed != null;
  }

  /// The real app, Home first; then S48 with [request], as an entry point opens it.
  Future<void> openPreview(WidgetTester tester, PrintRequest request) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    container = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(paths),
      databaseProvider.overrideWithValue(db),
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(
        MemoryStore({
          SettingsRepository.kOnboarding: true,
          SettingsRepository.kTourDone: true,
          SettingsRepository.kTourVersion: currentTourVersion,
        }),
        countryCode: 'IN',
      )),
      adsServiceProvider.overrideWithValue(const NoAdsService()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const DocuKitApp()));
    expect(await waitFor(tester, () => find.byType(HomeScreen).evaluate().isNotEmpty), isTrue);
    container.read(printRequestProvider.notifier).set(request);
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/print/preview'));
    expect(await waitFor(tester, () => find.byType(PrintPreviewScreen).evaluate().isNotEmpty), isTrue);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Taps Print, waits for "Sent to printer" while the host saves the PDF.
  Future<void> printAndSave(WidgetTester tester, String button) async {
    expect(await waitFor(tester, () => enabled(tester, button)), isTrue, reason: '"$button" enabled');
    log('dialog open');
    await tap(tester, find.text(button));
    final sent = await waitFor(tester, () => find.text('Sent to printer').evaluate().isNotEmpty,
        timeout: const Duration(minutes: 3));
    log('sent snackbar: $sent');
    expect(sent, isTrue);
    final rows = await container.read(historyRepositoryProvider).watchRecent(5).first;
    log('history: ${rows.map((r) => '${r.tool?.name} ${r.status} ${r.outputMeta['sheets']}').toList()}');
    expect(rows.first.tool, ToolId.print);
    expect(rows.first.status, OpStatus.success);
  }

  testWidgets('R69: 10 A4 pages, A4, Auto, Fit, 1 per sheet → Save as PDF', (tester) async {
    await openPreview(tester, PrintRequest([await pdfFile(await makePdf('R69 ten.pdf', 10))]));
    expect(await waitFor(tester, () => find.text('Sheet 1 of 10').evaluate().isNotEmpty), isTrue);
    await printAndSave(tester, 'Print 10 sheets');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('R70: Range "2-4, 7", 2 per sheet, Landscape → 2 sheets → Save as PDF', (tester) async {
    await openPreview(tester, PrintRequest([await pdfFile(await makePdf('R70 range.pdf', 10))]));
    expect(await waitFor(tester, () => find.text('Sheet 1 of 10').evaluate().isNotEmpty), isTrue);
    await tap(tester, find.text('Range'));
    await tester.enterText(find.byKey(const ValueKey('prn-range')), '2-4, 7');
    await tap(tester, find.text('2').last);
    await tap(tester, find.text('Landscape'));
    expect(await waitFor(tester, () => find.text('Sheet 1 of 2').evaluate().isNotEmpty), isTrue, reason: '2 sheets');
    await printAndSave(tester, 'Print 2 sheets');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('R72: passport sheet on 4×6 in from a 413 × 531 passport photo → 8 photos → Save as PDF', (tester) async {
    // The Resizer's passport preset output: 413 × 531 px (green, red band on top).
    final im = img.Image(width: 413, height: 531)..clear(img.ColorRgb8(40, 160, 60));
    img.fillRect(im, x1: 0, y1: 0, x2: 412, y2: 176, color: img.ColorRgb8(210, 40, 40));
    final path = p.join(dir.path, 'passport_413x531.jpg');
    File(path).writeAsBytesSync(img.encodeJpg(im, quality: 95));
    final meta = await const NativeImageEngine().inspect(path);
    await openPreview(tester, PrintRequest([
      PickedFile(path: path, displayName: 'passport.jpg', type: SniffedType.jpeg, sizeBytes: File(path).lengthSync(), image: meta),
    ]));
    expect(await waitFor(tester, () => find.text('Sheet 1 of 1').evaluate().isNotEmpty), isTrue);
    await tap(tester, find.text('Passport photo sheet'));
    expect(await waitFor(tester, () => find.text('8 photos on 4 × 6 in').evaluate().isNotEmpty), isTrue);
    await printAndSave(tester, 'Print 1 sheet');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('R73 (cancel): Back in the system dialog → no message, no banner, nothing in History', (tester) async {
    await openPreview(tester, PrintRequest([await pdfFile(await makePdf('R73 cancel.pdf', 3))]));
    expect(await waitFor(tester, () => enabled(tester, 'Print 3 sheets')), isTrue);
    log('dialog open');
    await tap(tester, find.text('Print 3 sheets'));
    // The host presses Back; the button comes back once the gateway answers.
    await pumpFor(tester, const Duration(seconds: 3));
    expect(await waitFor(tester, () => enabled(tester, 'Print 3 sheets'), timeout: const Duration(minutes: 2)), isTrue);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Sent to printer'), findsNothing);
    expect(find.byKey(const ValueKey('prn-failed')), findsNothing);
    expect(await container.read(historyRepositoryProvider).watchRecent(5).first, isEmpty);
    log('cancel: silent, nothing recorded');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('R74: 300 pages → 4 per sheet: progress, Cancel keeps the last good, 75 sheets, memory', (tester) async {
    var sw = Stopwatch()..start();
    final path = await makePdf('R74 300.pdf', 300);
    log('made 300-page PDF in ${sw.elapsedMilliseconds} ms, ${File(path).lengthSync()} B');
    var maxRss = ProcessInfo.currentRss;
    void sample() => maxRss = ProcessInfo.currentRss > maxRss ? ProcessInfo.currentRss : maxRss;
    await openPreview(tester, PrintRequest([await pdfFile(path)]));
    sw = Stopwatch()..start();
    var sawProgress = false;
    final first = await waitFor(tester, () {
      sample();
      sawProgress |= find.textContaining('Preparing sheet').evaluate().isNotEmpty;
      return find.text('Sheet 1 of 300').evaluate().isNotEmpty && enabled(tester, 'Print 300 sheets');
    }, timeout: const Duration(minutes: 3));
    log('1 per sheet: 300 sheets in ${sw.elapsedMilliseconds} ms; progress shown: $sawProgress');
    expect(first, isTrue);
    expect(sawProgress, isTrue, reason: 'determinate progress while building');

    // Baseline: the same 10 frames with nothing building (this emulator renders in software).
    final idle = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    log('10 frames idle: ${idle.elapsedMilliseconds} ms');

    // Reference: the composer alone in the background, no UI change.
    final diagDir = Directory(p.join(dir.path, 'diag'))..createSync();
    final diag = container.read(printComposerProvider).compose(
        PdfPrintSource(path),
        const PrintSettings(perSheet: 4),
        JobContext(jobId: 'diag', workDir: diagDir, cancel: CancelToken(), report: (_) {}));
    final bg = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    log('reference: 10 frames, composer running, UI unchanged: ${bg.elapsedMilliseconds} ms');
    await diag;

    // Reference: a tap that builds nothing (Range, empty → range error).
    await tap(tester, find.text('Range'));
    final noBuild = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    log('reference: 10 frames right after a tap that builds nothing: ${noBuild.elapsedMilliseconds} ms');
    await tap(tester, find.text('All'));
    expect(await waitFor(tester, () => enabled(tester, 'Print 300 sheets'), timeout: const Duration(minutes: 3)), isTrue);

    // Responsive while building: switch to 4 per sheet, then Cancel.
    await tap(tester, find.text('4'));
    final building = await waitFor(tester, () => find.byKey(const ValueKey('prn-cancel-build')).evaluate().isNotEmpty);
    expect(building, isTrue);
    final frames = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    log('10 frames right after the tap: ${frames.elapsedMilliseconds} ms');
    // Steady state: 1 s into the build (the tap's own transition is over).
    await pumpFor(tester, const Duration(seconds: 1));
    final steady = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    log('10 frames during the build (steady): ${steady.elapsedMilliseconds} ms; still building: '
        '${find.byKey(const ValueKey('prn-cancel-build')).evaluate().isNotEmpty}');
    await tap(tester, find.byKey(const ValueKey('prn-cancel-build')));
    final cancelled = await waitFor(tester, () => find.byKey(const ValueKey('prn-cancel-build')).evaluate().isEmpty,
        timeout: const Duration(seconds: 10));
    log('cancel: stopped $cancelled; last good kept: ${find.text('Sheet 1 of 300').evaluate().isNotEmpty}');
    expect(cancelled, isTrue);
    expect(find.text('Sheet 1 of 300'), findsOneWidget);

    // Build 4 per sheet to the end.
    await tap(tester, find.text('2'));
    await tap(tester, find.text('4'));
    sw = Stopwatch()..start();
    final four = await waitFor(tester, () {
      sample();
      return find.text('Sheet 1 of 75').evaluate().isNotEmpty && enabled(tester, 'Print 75 sheets');
    }, timeout: const Duration(minutes: 3));
    log('4 per sheet: 75 sheets in ${sw.elapsedMilliseconds} ms');
    expect(four, isTrue);
    // Swipe to the last sheet: rendered lazily.
    await tester.fling(find.byKey(const ValueKey('prn-sheets')), const Offset(-600, 0), 2000);
    await pumpFor(tester, const Duration(seconds: 2));
    sample();
    log('max RSS ${(maxRss / 1048576).toStringAsFixed(0)} MB');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
