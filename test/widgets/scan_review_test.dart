// T9.5 — S29 Scan Review (RELEASE_V1_2 §3, FR-SCN-10…16, 19, 21; §8 S29 row:
// page size hidden for JPG, primary label plurals, D4 on back, Add pages
// disabled at 50).
import 'dart:async';

import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/scan/scan_options.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/job/job_screen.dart';
import 'package:docukit/features/scan/application/scan_options_controller.dart';
import 'package:docukit/features/scan/presentation/scan_review.dart';
import 'package:docukit/features/scan/presentation/scan_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tools/tool_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

Finder nameShown(RegExp r) => find.byWidgetPredicate((w) => w is MiddleEllipsisText && r.hasMatch(w.text));

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  late TestHarness h;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  /// Opens S27 and scans [pages] pages, landing on S29.
  Future<void> review(WidgetTester tester, {int pages = 3}) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/scan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    h.scanner.pagesToWrite = pages;
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await settle(tester);
  }

  /// Opens page [i]'s ⋮ menu and taps [item] once the menu has finished opening.
  Future<void> menu(WidgetTester tester, int i, String item) async {
    await tester.tap(find.byTooltip('Page options').at(i));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(item).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(ScanScreen)));
  ToolInputs inputs(WidgetTester tester) => container(tester).read(toolInputsProvider(ToolId.scanDocument));

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('pages in order with a count; PDF options and "Save scan (3 pages)" (FR-SCN-10, 13)', (tester) async {
    await review(tester);
    expect(find.text('3 pages'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      expect(find.bySemanticsLabel(RegExp('^Page $i of 3')), findsOneWidget);
    }
    expect(inputs(tester).files.map((f) => p.basename(f.path)), ['page_001.jpg', 'page_002.jpg', 'page_003.jpg']);
    expect(find.text('Save scan (3 pages)'), findsOneWidget);
    expect(find.text('Page size'), findsOneWidget);
    expect(find.text('Fit to scan'), findsOneWidget);
    expect(nameShown(RegExp(r'^Scan_\d{8}_\d{4}\.pdf$')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('one page: singular label', (tester) async {
    await review(tester, pages: 1);
    expect(find.text('1 page'), findsOneWidget);
    expect(find.text('Save scan (1 page)'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('JPG: page size hidden, "Save 3 images", name _p01.jpg (FR-SCN-13, 16)', (tester) async {
    await review(tester);
    await tester.tap(find.text('JPG images'));
    await tester.pump();
    expect(find.text('Page size'), findsNothing);
    expect(find.text('Save 3 images'), findsOneWidget);
    expect(nameShown(RegExp(r'^Scan_\d{8}_\d{4}_p01\.jpg$')), findsOneWidget);
    expect(container(tester).read(scanOptionsProvider).format, ScanOutputFormat.jpg);
    await finish(tester);
  });

  testWidgets('quality and page size choices are kept (FR-SCN-14, 15)', (tester) async {
    await review(tester);
    await tester.tap(find.text('Fit to scan'));
    await tester.pump();
    await tester.ensureVisible(find.text('Compact'));
    await tester.tap(find.text('Compact'));
    await tester.pump();
    final o = container(tester).read(scanOptionsProvider);
    expect((o.pageSize, o.quality), (ScanPageSize.fitToScan, ScanQuality.compact));
    await finish(tester);
  });

  testWidgets('rename keeps the base name (D3, FR-SCN-16)', (tester) async {
    await review(tester);
    await tester.ensureVisible(nameShown(RegExp(r'\.pdf$')));
    await tester.tap(nameShown(RegExp(r'\.pdf$')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Receipts');
    await tester.pump();
    await tester.tap(find.text('Rename').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(container(tester).read(scanOptionsProvider).baseName, 'Receipts');
    expect(nameShown(RegExp(r'^Receipts\.pdf$')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('rotate right on the tile, left from the menu (FR-SCN-11)', (tester) async {
    await review(tester);
    await tester.tap(find.byTooltip('Rotate right').first);
    await tester.pump();
    expect(inputs(tester).rotations, [1, 0, 0]);
    await menu(tester, 1, 'Rotate left');
    expect(inputs(tester).rotations, [1, 3, 0]);
    await finish(tester);
  });

  testWidgets('delete with Undo puts the page back in place (FR-SCN-11)', (tester) async {
    await review(tester);
    final before = inputs(tester).files.map((f) => f.path).toList();
    await tester.tap(find.byTooltip('Remove').at(1));
    await tester.pump();
    expect(find.text('2 pages'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500)); // snackbar slides in
    expect(find.text('Page deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(inputs(tester).files.map((f) => f.path), before);
    expect(find.text('3 pages'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('deleting the last page asks "Discard this scan?" → back to the entry', (tester) async {
    await review(tester, pages: 1);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Discard this scan?'), findsOneWidget);
    expect(find.text('The scanned pages will be deleted.'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.text('Start scanning'), findsOneWidget);
    expect(inputs(tester).files, isEmpty);
    await finish(tester);
  });

  testWidgets('back with pages → D4 "Discard this scan?" (FR-SCN-19)', (tester) async {
    await review(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Discard this scan?'), findsOneWidget);
    expect(find.text('The scanned pages will be deleted.'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ScanScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Add pages appends after the existing ones (FR-SCN-12)', (tester) async {
    await review(tester, pages: 2);
    await tester.tap(find.text('Add pages'));
    await settle(tester);
    expect(h.scanner.scans.map((s) => s.maxPages), [50, 48]);
    expect(inputs(tester).files.map((f) => p.basename(f.path)),
        ['page_001.jpg', 'page_002.jpg', 'page_003.jpg', 'page_004.jpg']);
    expect(find.text('4 pages'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Add pages is disabled at 50', (tester) async {
    await review(tester, pages: 50);
    expect(find.text('50 pages'), findsOneWidget);
    final add = tester.widget<TextButton>(find.ancestor(of: find.text('Add pages'), matching: find.byType(TextButton)));
    expect(add.onPressed, isNull);
    await finish(tester);
  });

  testWidgets('Rescan this page replaces it with one new page (FR-SCN-21)', (tester) async {
    await review(tester);
    await menu(tester, 1, 'Rescan this page');
    await settle(tester);
    expect(h.scanner.scans.last.maxPages, 1);
    expect(inputs(tester).files.map((f) => p.basename(f.path)), ['page_001.jpg', 'page_004.jpg', 'page_003.jpg']);
    await finish(tester);
  });

  testWidgets('Move to… top', (tester) async {
    await review(tester);
    await menu(tester, 2, 'Move to…');
    await tester.tap(find.text('Move to top'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(inputs(tester).files.map((f) => p.basename(f.path)), ['page_003.jpg', 'page_001.jpg', 'page_002.jpg']);
    await finish(tester);
  });

  testWidgets('tap a page → full-screen preview, no banner slot', (tester) async {
    await review(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^Page 2 of 3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ScanPagePreview), findsOneWidget);
    expect(find.text('Page 2 of 3'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Save scan (PDF) starts one Scan job and opens Processing (FR-SCN-13)', (tester) async {
    await review(tester);
    await tester.tap(find.text('Save scan (3 pages)'));
    await tester.pump();
    final jobs = container(tester).read(jobsProvider).values.toList();
    expect(jobs, hasLength(1));
    expect((jobs.single.tool, jobs.single.multi), (ToolId.scanDocument, false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JobScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Save N images (JPG) starts a multi-output job (S22)', (tester) async {
    await review(tester, pages: 2);
    await tester.tap(find.text('JPG images'));
    await tester.pump();
    await tester.tap(find.text('Save 2 images'));
    await tester.pump();
    final jobs = container(tester).read(jobsProvider).values.toList();
    expect((jobs.single.tool, jobs.single.multi), (ToolId.scanDocument, true));
    await finish(tester);
  });

  testWidgets('Make searchable (FR-OCR-13): PDF only, off by default, the language when on, remembered', (tester) async {
    await review(tester);
    await tester.scrollUntilVisible(find.text('Make searchable (recognise text)'), 200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    final sw = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Make searchable (recognise text)'));
    expect(sw.value, isFalse);
    expect(find.text('Text language'), findsNothing);
    await tester.tap(find.text('Make searchable (recognise text)'));
    await settle(tester);
    expect(find.text('Text language'), findsWidgets);
    expect(h.store.get('scan_make_searchable'), isTrue);
    await tester.scrollUntilVisible(find.text('JPG images'), -200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await tester.tap(find.text('JPG images'));
    await settle(tester);
    expect(find.text('Make searchable (recognise text)'), findsNothing, reason: 'images can\'t be searchable');
    await finish(tester);
  });

  testWidgets('Save with Make searchable starts one Scan PDF job (S11 result)', (tester) async {
    await review(tester);
    await tester.scrollUntilVisible(find.text('Make searchable (recognise text)'), 200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await tester.tap(find.text('Make searchable (recognise text)'));
    await settle(tester);
    await tester.tap(find.text('Save scan (3 pages)'));
    await tester.pump();
    final jobs = container(tester).read(jobsProvider).values.toList();
    expect((jobs.single.tool, jobs.single.multi), (ToolId.scanDocument, false));
    await finish(tester);
  });
}
