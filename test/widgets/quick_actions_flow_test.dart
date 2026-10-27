// End to end: tapping a Home quick action opens the tool already set up
// (UI_REFRESH §2.1). Guards the regression where the prefill was written to a
// provider while the route was building (Riverpod threw on device).
import 'package:docukit/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<void> open(WidgetTester tester, String chip) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await tester.runAsync(() => TestHarness.create());
    await tester.pumpWidget(h!.app());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(chip));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('"Under 100 KB" opens the Compressor in Target size mode', (tester) async {
    await open(tester, 'Under 100 KB');
    expect(find.text('Image Compressor'), findsOneWidget);
    final seg = tester.widget<SegmentedButton<Object?>>(find.byWidgetPredicate((w) => w is SegmentedButton));
    expect(seg.selected.single.toString(), contains('targetSize'));
    expect(find.text('100 KB'), findsWidgets); // the quick-target chip is selected
    await finish(tester);
  });

  // R21 regression: at 200 % text on a phone the grid drops to one column, so
  // titles never break mid-word ("Image Co / mpressor").
  testWidgets('200% text: tool cards are full width', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await tester.runAsync(() => TestHarness.create());
    await tester.pumpWidget(h!.app());
    await tester.pump(const Duration(milliseconds: 200));
    final card = tester.getSize(find.byType(ToolCard).first);
    expect(card.width, greaterThan(300));
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('"Passport photo" opens the Resizer with the passport preset', (tester) async {
    await open(tester, 'Passport photo');
    expect(find.text('Image Resizer'), findsOneWidget);
    final seg = tester.widget<SegmentedButton<Object?>>(find.byWidgetPredicate((w) => w is SegmentedButton).first);
    expect(seg.selected.single.toString(), contains('preset'));
    await finish(tester);
  });

  testWidgets('Resizer with no image shows no field errors', (tester) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await tester.runAsync(() => TestHarness.create());
    await tester.pumpWidget(h!.app());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Image Resizer'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enter a number from 1 to 12000.'), findsNothing);
    await finish(tester);
  });
}
