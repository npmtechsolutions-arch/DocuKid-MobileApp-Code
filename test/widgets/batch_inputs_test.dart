// T8.5 — S21 batch inputs inside the Image Compressor (RELEASE_V1_1 §3 S21,
// FR-BAT-10, §8.2: valid / warning / invalid states; 0 valid disables Run).
import 'dart:async';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/resize_math.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/validation/input_validator.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/image_resize/application/resize_controller.dart';
import 'package:docukit/features/tools/batch_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

PickedFile broken(String name) => PickedFile(
      path: '/nonexistent/$name',
      displayName: name,
      type: SniffedType.jpeg,
      sizeBytes: 1000,
      status: const ValidationStatus.invalid(AppErrorCode.corruptFile),
    );

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> open(WidgetTester tester, List<PickedFile> picked, {String tool = 'image-compress'}) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextImages = picked;
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/$tool'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PickerDropCard));
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  PrimaryActionBar bar(WidgetTester tester) => tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));

  testWidgets('one image keeps the single layout, with Add to make a batch', (tester) async {
    await open(tester, [fakeImage('a.jpg')]);
    expect(find.byType(BatchInputs), findsNothing);
    expect(find.byType(SingleFileCard), findsOneWidget);
    expect(find.byTooltip('Add'), findsOneWidget);
    expect(bar(tester).label, 'Compress image');
    await finish(tester);
  });

  testWidgets('2+ images switch to the grid; the button counts the images', (tester) async {
    await open(tester, [fakeImage('a.jpg'), fakeImage('b.jpg'), fakeImage('c.jpg')]);
    expect(find.byType(BatchInputs), findsOneWidget);
    expect(find.text('Images (3)'), findsOneWidget);
    expect(find.text('Total 900 KB'), findsOneWidget);
    expect(bar(tester).label, 'Compress 3 images');
    expect(bar(tester).onPressed, isNotNull);
    await finish(tester);
  });

  testWidgets('invalid images are listed, excluded from the count, and can be removed', (tester) async {
    await open(tester, [fakeImage('a.jpg'), broken('bad.jpg'), fakeImage('c.jpg')]);
    expect(find.textContaining(RegExp(r"^Total .+ · 1 can't be used$")), findsOneWidget);
    expect(bar(tester).label, 'Compress 2 images');
    expect(find.bySemanticsLabel(RegExp(r'^bad\.jpg, ')), findsOneWidget, reason: 'the badge is announced, not only shown');
    await tester.tap(find.text('Remove them'));
    await tester.pumpAndSettle();
    expect(find.text('Images (2)'), findsOneWidget);
    expect(find.text('Remove them'), findsNothing);
    await finish(tester);
  });

  testWidgets('warnings show a badge but still count', (tester) async {
    await open(tester, [fakeImage('a.jpg'), fakeImage('alpha.png', alpha: true, type: SniffedType.png)]);
    expect(bar(tester).label, 'Compress 2 images');
    expect(find.text('Remove them'), findsNothing);
    await finish(tester);
  });

  testWidgets('0 valid → Run disabled with "Add images that DocuKit can open"', (tester) async {
    await open(tester, [broken('x.jpg'), broken('y.jpg')]);
    expect(bar(tester).onPressed, isNull);
    expect(bar(tester).helper, 'Add images that DocuKit can open');
    await finish(tester);
  });

  testWidgets('removing a tile with ✕ (48 dp target)', (tester) async {
    await open(tester, [fakeImage('a.jpg'), fakeImage('b.jpg'), fakeImage('c.jpg')]);
    final remove = find.byTooltip('Remove');
    expect(remove, findsNWidgets(3));
    expect(tester.getSize(remove.first).height, greaterThanOrEqualTo(48));
    await tester.tap(remove.first);
    await tester.pumpAndSettle();
    expect(find.text('Images (2)'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('more than 12 → first 12 shown and "Show all n"', (tester) async {
    await open(tester, [for (var i = 0; i < 14; i++) fakeImage('p$i.jpg')]);
    expect(find.byTooltip('Remove'), findsNWidgets(BatchInputs.gridLimit));
    expect(find.text('Show all 14'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Run starts ONE multi-output job with every picked file', (tester) async {
    await open(tester, [fakeImage('a.jpg'), broken('bad.jpg'), fakeImage('c.jpg')]);
    final container = ProviderScope.containerOf(tester.element(find.byType(BatchInputs)));
    await tester.tap(find.text('Compress 2 images'));
    await tester.pump();
    final jobs = container.read(jobsProvider).values.toList();
    expect(jobs, hasLength(1));
    expect(jobs.single.multi, isTrue);
    expect(Limits.batchMaxImages, 50);
    await finish(tester);
  });

  group('Resizer (T8.6)', () {
    testWidgets('2+ images: grid, "Resize n images", a box without the ratio lock, Fit inside by default', (tester) async {
      await open(tester, [fakeImage('a.jpg'), fakeImage('b.jpg')], tool: 'image-resize');
      expect(find.byType(BatchInputs), findsOneWidget);
      expect(bar(tester).label, 'Resize 2 images');
      expect(find.byTooltip('Aspect ratio locked'), findsNothing);
      expect(find.byTooltip('Aspect ratio unlocked'), findsNothing);
      final inside = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Fit inside'));
      expect(inside.selected, isTrue);
      expect(find.textContaining('fits inside 4000 × 3000 px'), findsOneWidget, reason: 'box seeded from the first image');
      await finish(tester);
    });

    testWidgets('a preset in a batch starts with a border (R30)', (tester) async {
      await open(tester, [fakeImage('a.jpg'), fakeImage('b.jpg')], tool: 'image-resize');
      await tester.tap(find.text('Preset'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Passport').first);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(BatchInputs)));
      final o = container.read(resizeOptionsProvider);
      expect((o.presetWidth, o.presetHeight, o.fit, o.pad), (413, 531, FitMode.contain, PadColor.white));
      expect(bar(tester).onPressed, isNotNull);
      await finish(tester);
    });

    testWidgets('one image keeps the 1.0 layout with the ratio lock', (tester) async {
      await open(tester, [fakeImage('a.jpg')], tool: 'image-resize');
      expect(find.byType(BatchInputs), findsNothing);
      expect(find.byTooltip('Aspect ratio locked'), findsOneWidget);
      expect(bar(tester).label, 'Resize image');
      await finish(tester);
    });
  });
}
