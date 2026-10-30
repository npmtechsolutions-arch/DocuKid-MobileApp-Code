// T8.8 — S24 Split PDF (RELEASE_V1_1 §3 S24, §8.2: inline range errors and
// live preview; FR-SPL-01…04).
import 'dart:async';

import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_split/presentation/split_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> open(WidgetTester tester, List<PickedFile> picked) async {
    tester.view.physicalSize = const Size(400, 1200) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = picked;
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-split'));
    await tester.pumpAndSettle();
    if (picked.isNotEmpty) {
      await tester.tap(find.byType(PickerDropCard));
      await tester.pumpAndSettle();
    }
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  PrimaryActionBar bar(WidgetTester tester) => tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));
  Future<void> type(WidgetTester tester, String s) async {
    await tester.enterText(find.byKey(const ValueKey('split-ranges')), s);
    await tester.pumpAndSettle();
  }

  testWidgets('the real screen replaces the placeholder; empty → choose a PDF', (tester) async {
    await open(tester, const []);
    expect(find.byType(SplitScreen), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    expect(bar(tester).helper, 'Choose PDF');
    await finish(tester);
  });

  testWidgets('custom ranges: live preview and "Split into 3 PDFs" (FR-SPL-02)', (tester) async {
    await open(tester, [fakePdf('report.pdf', pages: 36)]);
    expect(bar(tester).onPressed, isNull, reason: 'nothing entered yet');
    expect(bar(tester).helper, 'Enter at least one page.');
    await type(tester, '1-3, 5, 8-10');
    expect(find.text('3 files: pages 1–3 · page 5 · pages 8–10'), findsOneWidget);
    expect(bar(tester).label, 'Split into 3 PDFs');
    expect(bar(tester).onPressed, isNotNull);
    await finish(tester);
  });

  testWidgets('inline range errors (FR-SPL-05, §4.6)', (tester) async {
    await open(tester, [fakePdf('report.pdf', pages: 36)]);
    for (final (input, message) in [
      ('40', "Page 40 doesn't exist. This PDF has 36 pages."),
      ('5-3', 'Write ranges from low to high, e.g. 3-5.'),
      ('0', 'Pages start at 1.'),
      ('1-3,,5', 'Use only numbers, commas, dashes and "end".'),
    ]) {
      await type(tester, input);
      expect(find.descendant(of: find.byType(TextField), matching: find.text(message)), findsOneWidget, reason: input);
      expect(bar(tester).onPressed, isNull, reason: input);
    }
    await type(tester, '7-end');
    expect(find.text('1 file: pages 7–36'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('every N: stepper from 2, preview with the shorter last file (FR-SPL-03)', (tester) async {
    await open(tester, [fakePdf('report.pdf', pages: 11)]);
    await tester.tap(find.text('Every N pages'));
    await tester.pumpAndSettle();
    expect(find.text('6 files (the last has 1 page)'), findsOneWidget);
    await tester.tap(find.byTooltip('More pages per file'));
    await tester.pumpAndSettle();
    expect(find.text('4 files (the last has 2 pages)'), findsOneWidget);
    expect(bar(tester).label, 'Split into 4 PDFs');
    await finish(tester);
  });

  testWidgets('each page: one file per page; above 500 pages → suggest Every N (FR-SPL-04)', (tester) async {
    await open(tester, [fakePdf('big.pdf', pages: 600)]);
    await tester.tap(find.text('Each page'));
    await tester.pumpAndSettle();
    expect(bar(tester).onPressed, isNull);
    expect(find.text('That would make more than 500 files. Use Every N pages instead.'), findsWidgets);
    await tester.tap(find.descendant(of: find.byType(InlineBanner), matching: find.text('Every N pages')));
    await tester.pumpAndSettle();
    expect(find.text('300 files (the last has 2 pages)'), findsOneWidget, reason: 'N starts at the minimum for 600 pages (2)');
    await finish(tester);
  });

  testWidgets('a 1-page PDF can\'t be split (FR-SPL-01)', (tester) async {
    await open(tester, [fakePdf('one.pdf', pages: 1)]);
    expect(find.text('This PDF has only one page.'), findsWidgets);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('an encrypted PDF is blocked (FR-SPL-08): the only action is Unlock PDF (1.4, FR-UNL-08)', (tester) async {
    await open(tester, [fakePdf('locked.pdf', encrypted: true)]);
    expect(find.text('Password-protected'), findsOneWidget);
    expect((bar(tester).label, bar(tester).helper), ('Unlock PDF', 'This PDF is password-protected. Unlock it first.'));
    expect(find.textContaining('Split into'), findsNothing);
    await finish(tester);
  });

  testWidgets('Split runs one multi-output job', (tester) async {
    await open(tester, [fakePdf('report.pdf', pages: 4)]);
    await tester.tap(find.text('Each page'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(SplitScreen)));
    await tester.tap(find.text('Split into 4 PDFs'));
    await tester.pump();
    expect(container.read(jobsProvider).values.single.multi, isTrue);
    await finish(tester);
  });
}
