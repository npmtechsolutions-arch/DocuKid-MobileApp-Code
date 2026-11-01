// T13.6 — S47 Print tool and the entry points (RELEASE_PRINT §3, §3.4,
// FR-PRN-02, -17): the Home card and S47 (two pickers, banner with the gap),
// Incoming → S48 with the files (no re-picking; Back lands on S47 with them),
// search keywords, and History lines for sent / failed prints.
import 'dart:io';

import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/print/print_composer.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/print/presentation/print_preview_screen.dart';
import 'package:docukit/features/print/presentation/print_tool_screen.dart';
import 'package:docukit/features/search/search_ranking.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  Future<TestHarness> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  /// Real files in an incoming draft (a hand-over moves them).
  Future<List<PickedFile>> realFiles(WidgetTester tester, TestHarness h, List<String> names) async =>
      (await tester.runAsync(() async {
        final dir = h.paths.jobIn('incoming_print')..createSync(recursive: true);
        return [
          for (final n in names)
            n.endsWith('.pdf')
                ? PickedFile(
                    path: (File('${dir.path}/$n')..writeAsStringSync('%PDF')).path,
                    displayName: n,
                    type: SniffedType.pdf,
                    sizeBytes: 4,
                    pdf: const PdfMeta(pageCount: 3),
                  )
                : PickedFile(
                    path: (File('${dir.path}/$n')..writeAsBytesSync([1, 2, 3])).path,
                    displayName: n,
                    type: SniffedType.jpeg,
                    sizeBytes: 3,
                    image: const ImageMeta(format: SniffedType.jpeg, width: 400, height: 300),
                  ),
        ];
      }))!;

  Future<void> deliver(WidgetTester tester, TestHarness h, List<PickedFile> files) async {
    h.gateway.nextIncoming = files;
    h.native.send(const IncomingBatch(dir: '/nonexistent/incoming/p', files: [(path: '/x/a', name: 'a')]));
    await settle(tester);
  }

  Future<void> untilPreview(WidgetTester tester) async {
    for (var i = 0; i < 80 && find.byType(PrintPreviewScreen).evaluate().isEmpty; i++) {
      await settle(tester, 1);
    }
    await settle(tester);
  }

  testWidgets('Home → the Print card (PDF section) → S47: two pickers, the hint, Preview & print disabled, banner with the gap',
      (tester) async {
    await open(tester);
    await tester.scrollUntilVisible(find.text('Print PDFs and photos'), 300,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await tester.tap(find.text('Print PDFs and photos'));
    await settle(tester);
    expect(find.byType(PrintToolScreen), findsOneWidget);
    expect(find.text('Choose PDF'), findsOneWidget);
    expect(find.text('Choose images'), findsOneWidget);
    expect(find.text('PDF or up to 100 images'), findsOneWidget, reason: 'under the cards only');
    final button = tester.widget<ButtonStyleButton>(
        find.ancestor(of: find.text('Preview & print'), matching: find.bySubtype<ButtonStyleButton>()));
    expect(button.onPressed, isNull);
    final banner = tester.widget<AppBottomBanner>(
        find.descendant(of: find.byType(PrintToolScreen), matching: find.byType(AppBottomBanner)));
    expect(banner.separated, isTrue);
    await finish(tester);
  });

  testWidgets('Incoming 1 PDF → "Print" → S48 with it (no re-picking); Back → S47 with the file', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, await realFiles(tester, h, ['Lease.pdf']));
    expect(find.text('Print'), findsOneWidget);
    await tester.tap(find.text('Print'));
    await untilPreview(tester);
    expect(find.byType(PrintPreviewScreen), findsOneWidget);
    final src = h.printComposer.sources.last;
    expect(src, isA<PdfPrintSource>());
    expect((src as PdfPrintSource).path, endsWith('Lease.pdf'));
    expect(src.path, isNot(contains('incoming_print')), reason: 'moved into the Print tool draft');
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(PrintToolScreen), findsOneWidget);
    expect(find.text('Lease.pdf'), findsWidgets);
    expect(find.byType(PrintPreviewScreen), findsNothing, reason: 'opened once, not again');
    await finish(tester);
  });

  testWidgets('Incoming images → "Print" → S48 with all of them', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, await realFiles(tester, h, ['a.jpg', 'b.jpg']));
    await tester.tap(find.text('Print'));
    await untilPreview(tester);
    expect(find.byType(PrintPreviewScreen), findsOneWidget);
    expect((h.printComposer.sources.last as ImagesPrintSource).images, hasLength(2));
    await finish(tester);
  });

  testWidgets('History: "Sent to printer · 5 sheets" and "Printing failed"; never "no longer available"', (tester) async {
    tester.view.physicalSize = const Size(420, 2000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    final repo = HistoryRepository(h.db);
    const inputs = [InputRecord(displayName: 'Report.pdf', mime: 'application/pdf', sizeBytes: 1000, meta: {'p': 10})];
    final now = DateTime.now();
    // Rows go in before the app runs (as in secure_history_test).
    await tester.runAsync(() async {
      await repo.recordPrint(
          id: 'a', createdAt: now, duration: const Duration(seconds: 5), inputs: inputs, name: 'Report.pdf', sheets: 5, sent: true);
      await repo.recordPrint(
          id: 'b',
          createdAt: now.subtract(const Duration(minutes: 1)),
          duration: const Duration(seconds: 5),
          inputs: inputs,
          name: 'Report.pdf',
          sheets: 5,
          sent: false);
    });
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    GoRouter.of(tester.element(find.byType(HomeScreen))).go('/history');
    await settle(tester);
    expect(find.textContaining('Sent to printer · 5 sheets'), findsOneWidget);
    expect(find.textContaining('Printing failed'), findsOneWidget);
    expect(find.text('File no longer available'), findsNothing);
    expect(find.textContaining('Printed'), findsNothing, reason: 'owner decision: never "Printed"');
    await finish(tester);
  });

  test('search: printer words find Print first; "paper" keeps Scan first and still lists Print', () {
    String title(ToolId id) => id.name;
    for (final q in ['print', 'printer', 'airprint', 'hard copy', 'passport photo print', 'wifi printer']) {
      expect(searchTools(q, title).first.tool, ToolId.print, reason: q);
    }
    final paper = searchTools('paper', title).map((h) => h.tool).toList();
    expect(paper.first, ToolId.scanDocument);
    expect(paper, contains(ToolId.print));
  });

  test('catalogue: Print is last in the PDF section, one PDF or up to 100 images', () {
    final pdfTools = [for (final t in toolCatalog) if (t.category == ToolCategory.pdf) t.id];
    expect(pdfTools.last, ToolId.print);
    final d = toolById(ToolId.print);
    expect((d.inputKind, d.maxInputs, d.route), (InputKind.imagesOrPdf, 100, '/tool/print'));
  });

  test('providers are wired', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(printComposerProvider), isA<PdfiumPrintComposer>());
  });
}
