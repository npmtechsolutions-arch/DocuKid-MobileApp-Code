// T8.9 — S25 PDF to Images (RELEASE_V1_1 §3 S25, §8.2 estimate text,
// FR-P2I-02…04/07).
import 'dart:async';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/options.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_to_images/presentation/pdf_to_images_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

PickedFile a4Pdf(String name, {int pages = 3, (double, double) size = (595.28, 841.89)}) => PickedFile(
      path: '/nonexistent/$name',
      displayName: name,
      type: SniffedType.pdf,
      sizeBytes: 100000,
      pdf: PdfMeta(pageCount: pages, pageSizes: List.filled(pages, size)),
    );

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> open(WidgetTester tester, List<PickedFile> picked) async {
    tester.view.physicalSize = const Size(400, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = picked;
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-to-images'));
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

  testWidgets('the real screen replaces the placeholder; empty → choose a PDF', (tester) async {
    await open(tester, const []);
    expect(find.byType(PdfToImagesScreen), findsOneWidget);
    expect(bar(tester).helper, 'Choose PDF');
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('all pages at 150 dpi by default; the estimate follows the resolution (FR-P2I-04)', (tester) async {
    await open(tester, [a4Pdf('brochure.pdf')]);
    expect(bar(tester).label, 'Create 3 images');
    expect(find.text('≈ 1240 × 1754 px per page'), findsOneWidget);
    await tester.tap(find.text('300 · Print'));
    await tester.pumpAndSettle();
    expect(find.text('≈ 2480 × 3508 px per page'), findsOneWidget);
    await tester.tap(find.text('72 · Screen'));
    await tester.pumpAndSettle();
    expect(find.text('≈ 595 × 842 px per page'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('choose pages: union in document order; inline errors (FR-P2I-02)', (tester) async {
    await open(tester, [a4Pdf('brochure.pdf', pages: 5)]);
    await tester.tap(find.text('Choose pages'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('p2i-ranges')), '4-5, 1, 4');
    await tester.pumpAndSettle();
    expect(bar(tester).label, 'Create 3 images');
    await tester.enterText(find.byKey(const ValueKey('p2i-ranges')), '9');
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(TextField), matching: find.text("Page 9 doesn't exist. This PDF has 5 pages.")),
        findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('PNG hides quality and offers a transparent background, off by default (FR-P2I-03/07)', (tester) async {
    await open(tester, [a4Pdf('brochure.pdf')]);
    expect(find.byType(QualitySlider), findsOneWidget);
    await tester.tap(find.text('PNG'));
    await tester.pumpAndSettle();
    expect(find.byType(QualitySlider), findsNothing);
    final toggle = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Keep transparent background'));
    expect(toggle.value, isFalse);
    await finish(tester);
  });

  testWidgets('a page that would pass 40 MP says it was limited (FR-P2I-04)', (tester) async {
    await open(tester, [a4Pdf('poster.pdf', pages: 1, size: (2000, 2000))]);
    await tester.tap(find.text('300 · Print'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(InlineBanner), matching: find.textContaining('Page 1 was limited to')), findsOneWidget);
    expect(bar(tester).onPressed, isNotNull, reason: 'capped pages still run');
    await finish(tester);
  });

  testWidgets('Create runs one multi-output job', (tester) async {
    await open(tester, [a4Pdf('brochure.pdf')]);
    final container = ProviderScope.containerOf(tester.element(find.byType(PdfToImagesScreen)));
    await tester.tap(find.text('Create 3 images'));
    await tester.pump();
    expect(container.read(jobsProvider).values.single.multi, isTrue);
    await finish(tester);
  });
}
