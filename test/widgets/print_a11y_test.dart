// Print gaps 3 — S47, S48 and the help sheet at 200 % text and with the
// accessibility guidelines (CLAUDE.md rule 9: every interactive widget
// labelled, touch targets ≥ 48 dp; TESTING R21): no overflow at large text
// (a RenderFlex overflow fails the test), labelled tap targets, 48 dp targets.
import 'dart:async';

import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/print/application/print_preview_controller.dart';
import 'package:docukit/features/print/presentation/print_preview_screen.dart';
import 'package:docukit/features/print/presentation/print_tool_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

void main() {
  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  /// A phone-width screen at [scale] text; opens [route], with [request] for
  /// S48. [height] tall enough that no control is half-scrolled out of view
  /// (the tap-target guideline measures what's visible).
  Future<TestHarness> open(WidgetTester tester, String route,
      {PrintRequest? request, double scale = 2.0, double height = 860}) async {
    tester.view.physicalSize = Size(400, height) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await settle(tester);
    final home = tester.element(find.byType(HomeScreen));
    if (request != null) ProviderScope.containerOf(home).read(printRequestProvider.notifier).set(request);
    unawaited(GoRouter.of(home).push(route));
    await settle(tester);
    return h;
  }

  Future<void> guidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  final scrollable = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

  for (final scale in [1.0, 2.0]) {
    testWidgets('S47 at ${scale}x text: no overflow; tap targets labelled and ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/tool/print', scale: scale);
      expect(find.byType(PrintToolScreen), findsOneWidget);
      expect(find.text('Choose PDF'), findsOneWidget);
      await guidelines(tester);
      handle.dispose();
      await finish(tester);
    });

    testWidgets('S48 (PDF) at ${scale}x text: no overflow top to bottom; tap targets labelled and ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      // Tall enough to show every option card at once, down to the note.
      await open(tester, '/print/preview',
          request: PrintRequest([fakePdf('Report.pdf', pages: 10)]), scale: scale, height: scale > 1 ? 4000 : 2200);
      expect(find.byType(PrintPreviewScreen), findsOneWidget);
      expect(find.text('Copies, colour and two-sided printing are set in the next step.').hitTestable(), findsOneWidget);
      expect(find.text('Margins'), findsOneWidget);
      await guidelines(tester);
      handle.dispose();
      await finish(tester);
    });
  }

  testWidgets('S48 (images) at 2x text: the Layout chips wrap; passport count fits', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, '/print/preview', request: PrintRequest([fakeImage('a.jpg')]), height: 4000);
    await tester.tap(find.text('Passport photo sheet'));
    await settle(tester, 20);
    expect(find.text('8 photos on 4 × 6 in').hitTestable(), findsOneWidget);
    await guidelines(tester);
    handle.dispose();
    await finish(tester);
  });

  testWidgets('the help sheet at 2x text: scrolls, no overflow', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, '/print/preview', request: PrintRequest([fakePdf('Report.pdf')]));
    await tester.tap(find.byTooltip("Can't find your printer?"));
    await settle(tester);
    expect(find.textContaining('Default Print Service'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('receipt printers'), 200, scrollable: scrollable.last);
    expect(find.textContaining('receipt printers'), findsOneWidget);
    handle.dispose();
    await finish(tester);
  });

  testWidgets('screen-reader labels: the sheets, thumbnails, help and Print', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, '/print/preview', request: PrintRequest([fakePdf('Report.pdf')]), scale: 1.0);
    expect(find.bySemanticsLabel('Sheet 1'), findsWidgets, reason: 'the sheet view and its thumbnail');
    expect(find.bySemanticsLabel('Sheet 2'), findsWidgets);
    expect(find.byTooltip("Can't find your printer?"), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Print 2 sheets')), findsOneWidget);
    handle.dispose();
    await finish(tester);
  });
}
