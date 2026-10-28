import 'dart:async';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> pump(WidgetTester tester, {bool onboarded = true, Size size = const Size(400, 900)}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // Reduce motion: also stops Home's rotating search placeholder so
    // pumpAndSettle can settle (DESIGN_SYSTEM §5).
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await tester.runAsync(() => TestHarness.create(onboarded: onboarded));
    await tester.pumpWidget(h!.app());
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  Future<void> openTool(WidgetTester tester, String slug) async {
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/$slug'));
    await tester.pumpAndSettle();
  }

  Future<void> pickFiles(WidgetTester tester) async {
    await tester.tap(find.byType(PickerDropCard));
    await tester.pumpAndSettle();
  }

  // The in-memory DB isn't closed: drift's close() waits for stream queries
  // started inside the fake-async zone, which never complete there.
  Future<void> finish(WidgetTester tester, TestHarness h) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Home shows every tool, in the 1.1 order, in two categories and the privacy promise', (tester) async {
    final h = await pump(tester);
    // RELEASE_V1_1 §4.10: Image → Compress, Resize, Convert, Images to PDF;
    // PDF → Merge, Organize, Split, PDF to Images, Reduce.
    final cards = tester.widgetList<ToolCard>(find.byType(ToolCard)).map((c) => c.tool.id).toList();
    expect(cards, [
      ToolId.imageCompress, ToolId.imageResize, ToolId.imageConvert, ToolId.imageToPdf,
      ToolId.pdfMerge, ToolId.pdfOrganize, ToolId.pdfSplit, ToolId.pdfToImages, ToolId.pdfCompress,
    ]);
    expect(find.text('Image tools'), findsOneWidget);
    expect(find.text('PDF tools'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Recent'), 300,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    expect(find.text('Your finished files will show up here.'), findsOneWidget);
    expect(find.text('Files never leave your phone'), findsWidgets);
    await finish(tester, h);
  });

  testWidgets('ToolCard is one semantics node with title and subtitle', (tester) async {
    final h = await pump(tester);
    expect(find.bySemanticsLabel('Image Compressor. Make photos smaller'), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('first run shows onboarding, Get started goes Home', (tester) async {
    final h = await pump(tester, onboarded: false);
    expect(find.text('Document tools that stay on your phone'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('search ranks "compress pdf" → Reduce PDF Size first', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.bySemanticsLabel('Search tools'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'compress pdf');
    await tester.pump();
    final tiles = find.byType(ListTile);
    expect(find.descendant(of: tiles.first, matching: find.text('Reduce PDF Size')), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('Compressor: empty state disables the button with a helper', (tester) async {
    final h = await pump(tester);
    await openTool(tester, 'image-compress');
    expect(find.text('Choose image'), findsWidgets);
    final bar = tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));
    expect(bar.onPressed, isNull);
    expect(bar.helper, 'Choose image');
    await finish(tester, h);
  });

  testWidgets('Compressor: PNG with alpha → PNG warning, then alpha warning after Switch to JPEG', (tester) async {
    final h = await pump(tester);
    h.gateway.nextImages = [fakeImage('scan.png', alpha: true, type: SniffedType.png)];
    await openTool(tester, 'image-compress');
    await pickFiles(tester);
    expect(find.text("PNG doesn't use quality. Choose JPEG or WebP for smaller files."), findsOneWidget);
    await tester.tap(find.text('Switch to JPEG'));
    await tester.pumpAndSettle();
    expect(find.text('Transparent areas will become white.'), findsOneWidget);
    expect(tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar)).onPressed, isNotNull);
    await finish(tester, h);
  });

  testWidgets('Merger: an encrypted PDF blocks Merge with a helper', (tester) async {
    final h = await pump(tester);
    h.gateway.nextPdfs = [fakePdf('a.pdf'), fakePdf('locked.pdf', encrypted: true)];
    await openTool(tester, 'pdf-merge');
    await pickFiles(tester);
    expect(find.text('Password-protected'), findsOneWidget);
    final bar = tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));
    expect(bar.onPressed, isNull);
    expect(bar.helper, "Remove 1 file that can't be merged");
    await finish(tester, h);
  });

  testWidgets('Merger: back with inputs asks before leaving (D4)', (tester) async {
    final h = await pump(tester);
    h.gateway.nextPdfs = [fakePdf('a.pdf')];
    await openTool(tester, 'pdf-merge');
    await pickFiles(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Leave without finishing?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Merge PDFs'), findsWidgets);
    await finish(tester, h);
  });

  testWidgets('unknown deep link → Home with a snackbar', (tester) async {
    final h = await pump(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen))).go('/tool/nope');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('That item is no longer available.'), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('Home at 200% text has no overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = await pump(tester, size: const Size(360, 780));
    expect(tester.takeException(), isNull);
    expect(find.byType(ToolCard), findsWidgets);
    await finish(tester, h);
  });

  testWidgets('dark theme renders Home', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final h = await pump(tester);
    expect(Theme.of(tester.element(find.byType(HomeScreen))).brightness, Brightness.dark);
    await finish(tester, h);
  });
}
