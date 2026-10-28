// T8.7 — S23 Convert Image (RELEASE_V1_1 §3 S23, §8.2: alpha warning,
// same-format hint, HEIC hidden where it can't be encoded).
import 'dart:async';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/options.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/image_convert/presentation/convert_screen.dart';
import 'package:docukit/features/tools/batch_inputs.dart';
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
    h.gateway.nextImages = picked;
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/image-convert'));
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
  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets('the real screen replaces the placeholder; empty → pick images', (tester) async {
    await open(tester, const []);
    expect(find.byType(ConvertScreen), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    expect(bar(tester).helper, 'Choose images');
    await finish(tester);
  });

  testWidgets('formats come from the engine: JPEG, PNG, WebP; HEIC hidden when it can\'t be encoded (FR-CNV-02)', (tester) async {
    await open(tester, [fakeImage('a.heic', type: SniffedType.heic)]);
    for (final f in ['JPEG', 'PNG', 'WebP']) {
      expect(chip(f), findsOneWidget, reason: f);
    }
    expect(chip('HEIC'), findsNothing);
    expect(tester.widget<ChoiceChip>(chip('JPEG')).selected, isTrue, reason: 'JPG by default');
    expect(bar(tester).label, 'Convert 1 image');
    await finish(tester);
  });

  testWidgets('alpha input → JPG warns; PNG keeps transparency and hides the quality slider (FR-CNV-03/04)', (tester) async {
    await open(tester, [fakeImage('logo.png', alpha: true, type: SniffedType.png)]);
    expect(find.text('Transparent areas will become white.'), findsOneWidget);
    expect(find.byType(QualitySlider), findsOneWidget);
    await tester.tap(chip('PNG'));
    await tester.pumpAndSettle();
    expect(find.text('Transparent areas will become white.'), findsNothing);
    expect(find.byType(QualitySlider), findsNothing);
    await finish(tester);
  });

  testWidgets('same format is allowed, with a hint (FR-CNV-06)', (tester) async {
    await open(tester, [fakeImage('a.jpg'), fakeImage('b.jpg'), fakeImage('c.png', type: SniffedType.png)]);
    expect(find.byType(BatchInputs), findsOneWidget);
    expect(find.text("2 images are already JPEG. They'll be re-saved."), findsOneWidget);
    expect(find.byType(InlineBanner), findsOneWidget);
    expect(bar(tester).label, 'Convert 3 images');
    await finish(tester);
  });

  testWidgets('a batch runs as one multi-output job; the format choice is remembered (§5.2)', (tester) async {
    final h = await open(tester, [fakeImage('a.jpg'), fakeImage('b.jpg')]);
    await tester.tap(chip('WebP'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ConvertScreen)));
    await tester.tap(find.text('Convert 2 images'));
    await tester.pump();
    expect(container.read(jobsProvider).values.single.multi, isTrue);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(h.store.get('convert_format'), 'webp');
    await finish(tester);
  });
}
