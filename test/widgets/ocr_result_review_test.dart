// T10.7 — S32 Result for OCR and S31 Review text (RELEASE_V1_3 §3.3–3.4,
// FR-OCR-08/11/16, ADR-066), plus the "Text only, not saved" history row.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/ads_config.dart';
import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/ocr/ocr_text_file.dart';
import 'package:docukit/core/operation/composite_operation.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/features/history/history_screen.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/job/job_screen.dart';
import 'package:docukit/features/ocr/application/ocr_options.dart';
import 'package:docukit/features/ocr/application/ocr_review_files.dart';
import 'package:docukit/features/ocr/presentation/ocr_result_view.dart';
import 'package:docukit/features/ocr/presentation/ocr_review_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

/// Writes a .txt and/or a PDF stand-in and the review folder for [pages].
class _Ocr implements CompositeToolOperation<OcrOptions> {
  _Ocr(this.pages, {this.pdf = true, this.txt = true, this.review = true, this.low = const {}});
  final List<String> pages;
  final bool pdf, txt, review;
  final Set<int> low;

  @override
  ToolId get tool => ToolId.ocr;
  @override
  Future<void> validateInputs(List<PickedFile> inputs, OcrOptions options) async {}
  @override
  int estimateRequiredBytes(List<PickedFile> inputs, OcrOptions options) => 0;

  @override
  Future<CompositeOutput> execute(JobContext ctx, List<PickedFile> inputs, OcrOptions options) async {
    final dir = p.join(ctx.workDir.path, 'review');
    final w = OcrReviewWriter(dir);
    for (final (i, t) in pages.indexed) {
      await w.page(i, t, OcrReviewPage(words: t.split(' ').length, lowText: low.contains(i), existingText: false));
    }
    await w.finish(pages.length, baseName: 'notes');
    return CompositeOutput(
      files: [
        if (pdf)
          RawOutput(
              path: (File(p.join(ctx.workDir.path, 'a.pdf'))..writeAsStringSync('%PDF-1.4')).path,
              suggestedName: 'notes_searchable.pdf',
              mime: 'application/pdf'),
        if (txt)
          RawOutput(
              path: (File(p.join(ctx.workDir.path, 'a.txt'))..writeAsStringSync(formatOcrTxt(pages))).path,
              suggestedName: 'notes_text.txt',
              mime: 'text/plain'),
      ],
      stats: {'pages': pages.length, 'words': 120, 'lowTextPages': low.length},
      reviewDir: review ? dir : null,
    );
  }

  @override
  Future<List<OutputMeta>> validateOutputs(CompositeOutput out, List<PickedFile> inputs, OcrOptions options) async =>
      [for (final f in out.files) OutputMeta(bytes: File(f.path).lengthSync())];
}

Finder nameShown(String name) => find.byWidgetPredicate((w) => w is MiddleEllipsisText && w.text == name);

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late List<String> clipboard;
  late String jobId;

  Future<void> settle(WidgetTester tester, [int n = 40]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Taps (or anything) whose handler does real file IO: run it where real
  /// async completes, then let the UI catch up.
  Future<void> act(WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester);
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));

  /// Runs [op] to the end and opens its Result.
  Future<void> result(WidgetTester tester, _Ocr op) async {
    tester.view.physicalSize = const Size(400, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    clipboard = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    final c = container(tester);
    jobId = c.read(jobsProvider.notifier).startComposite(op, const [], const OcrOptions());
    // Real IO runs in runAsync; drift's history streams need frames too.
    for (var i = 0; i < 200 && !(c.read(jobsProvider)[jobId]?.state.isTerminal ?? false); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(c.read(jobsProvider)[jobId]!.state, isA<JobCompletedMulti>());
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/job/$jobId'));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('S32: stats with little-text pages, Review text, Copy text, both files (FR-OCR-16)', (tester) async {
    await result(tester, _Ocr(['Meeting notes', 'Budget approved', ''], low: {2}));
    expect(find.byType(OcrResultView), findsOneWidget);
    expect(find.textContaining('3 pages · 120 words found'), findsOneWidget);
    expect(find.textContaining('1 page with little text'), findsOneWidget);
    expect(find.text('Review text'), findsOneWidget);
    expect(nameShown('notes_searchable.pdf'), findsOneWidget);
    expect(nameShown('notes_text.txt'), findsOneWidget);
    await act(tester, () => tester.tap(find.text('Copy text')));
    expect(clipboard.single, 'Meeting notes\n\nBudget approved');
    expect(find.text('Copied'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('every page has little text → the "couldn\'t find much text" banner (FR-OCR-11)', (tester) async {
    await result(tester, _Ocr(['', 'a b'], low: {0, 1}));
    expect(find.text("We couldn't find much text. Try a sharper photo, or check the language."), findsOneWidget);
    await finish(tester);
  });

  testWidgets('text only: no file list; the first lines as a preview; Copy text still works', (tester) async {
    await result(tester, _Ocr(['Line one\nLine two', 'Line three'], pdf: false, txt: false));
    expect(find.textContaining('Your files'), findsNothing);
    expect(find.textContaining('Line one'), findsOneWidget);
    await tester.tap(find.text('Copy text'));
    await settle(tester);
    expect(clipboard.single, 'Line one\nLine two\n\nLine three');
    await finish(tester);
  });

  testWidgets('.txt only (no review): Copy text reads the .txt; no Review button', (tester) async {
    await result(tester, _Ocr(['From the file', 'Page two'], pdf: false, review: false));
    expect(find.text('Review text'), findsNothing);
    await tester.tap(find.text('Copy text'));
    await settle(tester);
    expect(clipboard.single, 'From the file\n\nPage two');
    await finish(tester);
  });

  testWidgets('S31: pager, low-text note, Copy page / Copy all, Share text, Save .txt; the main banner (ADR-072)', (tester) async {
    await result(tester, _Ocr(['Meeting notes', 'Budget approved', ''], low: {2}));
    await tester.tap(find.text('Review text'));
    await settle(tester);
    expect(find.byType(OcrReviewScreen), findsOneWidget);
    final slot = find.descendant(of: find.byType(OcrReviewScreen), matching: find.byType(AppBottomBanner));
    expect(tester.widget<AppBottomBanner>(slot).unit, AdUnit.bannerMain, reason: 'ADR-072 (1.6): S31 has the main banner');
    expect(find.text('Page 1 of 3'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Meeting notes'), findsOneWidget);
    await tester.tap(find.text('Copy page'));
    await settle(tester);
    expect(clipboard.last, 'Meeting notes');
    await tester.tap(find.byTooltip('Next page'));
    await settle(tester);
    await tester.tap(find.byTooltip('Next page'));
    await settle(tester);
    expect(find.text('Page 3 of 3'), findsWidgets);
    expect(find.text('Little or no text found on page 3.'), findsOneWidget);
    await tester.tap(find.text('Copy all'));
    await settle(tester);
    expect(clipboard.last, 'Meeting notes\n\nBudget approved');
    await tester.tap(find.text('Share'));
    await settle(tester);
    expect(h.gateway.sharedTexts.single, 'Meeting notes\n\nBudget approved');
    await tester.tap(find.text('Save .txt'));
    await settle(tester);
    expect(find.textContaining('Saved'), findsWidgets);
    await finish(tester);
  });

  testWidgets('S31: an edit marks the page, is used by Copy all, and Back asks first (D4)', (tester) async {
    await result(tester, _Ocr(['Meeting notes', 'Budget']));
    await tester.tap(find.text('Review text'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Meeting notes — 14 March');
    await settle(tester);
    expect(find.text('Edited •'), findsOneWidget);
    await tester.tap(find.text('Copy all'));
    await settle(tester);
    expect(clipboard.last, 'Meeting notes — 14 March\n\nBudget');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Discard your text changes?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await settle(tester);
    expect(find.byType(OcrReviewScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('Leave'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OcrReviewScreen), findsNothing);
    expect(find.byType(OcrResultView), findsOneWidget);
    await finish(tester);
  });

  testWidgets('leaving Result deletes the review text (ADR-066)', (tester) async {
    await result(tester, _Ocr(['secret text']));
    final dir = h.paths.reviewDir(jobId);
    expect(await tester.runAsync(dir.exists), isTrue);
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(JobScreen), findsNothing);
    await settle(tester); // the delete started when Result went away
    expect(await tester.runAsync(dir.exists), isFalse);
    await finish(tester);
  });

  testWidgets('History: a text-only job reads "Text only, not saved", never "no longer available"', (tester) async {
    await result(tester, _Ocr(['some text'], pdf: false, txt: false));
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await settle(tester, 8);
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/history'));
    await settle(tester);
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.textContaining('Text only, not saved'), findsWidgets);
    expect(find.text('File no longer available'), findsNothing);
    await finish(tester);
  });
}
