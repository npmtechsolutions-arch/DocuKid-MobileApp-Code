// TOUR.md §6 — written before the implementation (T7.5).
import 'dart:async';

import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tour/tour_controller.dart';
import 'package:docukit/features/tour/tour_overlay.dart';
import 'package:docukit/features/tour/tour_step.dart';
import 'package:docukit/features/tour/tour_steps.dart';
import 'package:docukit/features/tour/tour_targets.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

/// Numbered steps (the intro isn't counted): search + one per tool + the
/// "Secure & Sign" section step (1.4) + recent + nav + done. Derived, so a new
/// tool doesn't break these tests.
const secureTools = [ToolId.pdfSign, ToolId.pdfWatermark, ToolId.pdfProtect, ToolId.pdfUnlock];

final numberedSteps = toolCatalog.length + 6; // + My Documents (1.5)

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('steps (unit)', () {
    late AppLocalizations l;
    setUpAll(() async => l = await AppLocalizations.delegate.load(const Locale('en')));

    test('intro + search + one step per catalogue tool (in order) + recent + nav + done', () {
      final steps = buildHomeTourSteps(l: l, targets: TourTargets(), period: '7 days');
      expect(steps.length, 23); // #0 intro … #22 done (16 tools + the Secure & Sign section step in 1.4 + My Documents in 1.5)
      expect(steps.first.target, isNull);
      expect(steps.last.target, isNull);
      final toolSteps = steps.where((s) => s.tryTool != null).map((s) => s.tryTool).toList();
      expect(toolSteps, [for (final t in toolCatalog) t.id]);
      // FR-SEC-02: the section step comes right before Sign PDF.
      final section = steps.indexWhere((s) => s.title == 'Secure & Sign');
      expect(steps[section + 1].tryTool, ToolId.pdfSign);
      expect(steps[section].body, 'Sign, watermark, or add and remove passwords — all on your phone.');
      expect(steps[3].title, 'Image Resizer');
      expect(steps[3].example, contains('413×531'));
      expect(steps[20].body, contains('7 days'));
      // 1.6: Print last in the PDF section, before Scan (catalogue order).
      expect(toolSteps.indexOf(ToolId.print), toolSteps.indexOf(ToolId.scanDocument) - 1);
      // 1.5: My Documents after the tools, on Home's 📁 button.
      expect((steps[19].title, steps[19].body), ('My Documents',
          'Keep important documents here in folders. Search their text and get a reminder before they expire. They stay on this phone.'));
    });

    test('What\'s new (FR-TOUR-10/11, FR-FAV-05): a 1.0 user gets the 1.1 steps, Scan and Text Recognition, intro "New in DocuKit", then done', () {
      final steps = buildWhatsNewSteps(l: l, targets: TourTargets(), since: 1);
      expect(steps.first.title, 'New in DocuKit');
      expect(steps.first.target, isNull);
      expect(steps.where((s) => s.tryTool != null).map((s) => s.tryTool),
          [ToolId.imageConvert, ToolId.pdfSplit, ToolId.pdfToImages, ToolId.print, ToolId.scanDocument, ToolId.ocr, ...secureTools]);
      final fav = steps[steps.length - 3];
      expect((fav.title, fav.body), ('Favourites', 'Long-press any tool to pin it here.'));
      expect(steps[steps.length - 2].title, 'My Documents');
      expect(steps.last.title, l.tourDoneTitle);
      expect(steps, hasLength(15)); // intro, 6 earlier tools (Print in catalogue order), section, 4 secure tools, Favourites, My Documents, done
    });

    test('FR-SCN-26: a 1.1 user (tour_version 2) gets Scan, Text Recognition and Secure & Sign', () {
      final steps = buildWhatsNewSteps(l: l, targets: TourTargets(), since: 2);
      expect(steps.where((s) => s.tryTool != null).map((s) => s.tryTool),
          [ToolId.print, ToolId.scanDocument, ToolId.ocr, ...secureTools]);
      final scan = steps.firstWhere((s) => s.tryTool == ToolId.scanDocument);
      expect((scan.title, scan.example), ('Scan Document', 'Notes, receipts or a signed form in one PDF.'));
      expect(steps.any((s) => s.title == 'Favourites'), isFalse, reason: 'already shown with 1.1');
      expect(steps, hasLength(11)); // intro, Print, Scan, Text Recognition, section, 4 secure tools, My Documents, done
    });

    test('1.3 (RELEASE_V1_3 §3.6): a 1.2 user (tour_version 3) gets Text Recognition, then Secure & Sign', () {
      final steps = buildWhatsNewSteps(l: l, targets: TourTargets(), since: 3);
      expect(steps.where((s) => s.tryTool != null).map((s) => s.tryTool), [ToolId.print, ToolId.ocr, ...secureTools]);
      final ocr = steps.firstWhere((s) => s.tryTool == ToolId.ocr);
      expect((ocr.title, ocr.body, ocr.example), (
        'Text Recognition',
        'Find the text in photos and scans. Copy it, or make a PDF you can search.',
        'Turn a photo of notes into text you can paste.',
      ));
      expect(steps, hasLength(10)); // intro, Print, Text Recognition, section, 4 secure tools, My Documents, done
    });

    test('1.4 (FR-SEC-02): a 1.3 user (tour_version 4) gets the Secure & Sign section, then its 4 tools', () {
      final steps = buildWhatsNewSteps(l: l, targets: TourTargets(), since: 4);
      expect(steps.map((s) => s.title).skip(1).take(6),
          ['Print', 'Secure & Sign', 'Sign PDF', 'Watermark PDF', 'Protect PDF', 'Unlock PDF']);
      final sign = steps.firstWhere((s) => s.tryTool == ToolId.pdfSign);
      expect((sign.body, sign.example), ('Add your signature to pages', 'Sign a rental agreement without printing it.'));
      expect(steps, hasLength(9)); // intro, Print, section, 4 tools, My Documents, done
    });

    test('1.5 (T12.9): a 1.4 user (tour_version 5) gets Print (1.6) and My Documents, on the 📁 button', () {
      final targets = TourTargets();
      final steps = buildWhatsNewSteps(l: l, targets: targets, since: 5);
      expect(steps.map((s) => s.title), ['New in DocuKit', 'Print', 'My Documents', l.tourDoneTitle]);
      expect(steps[2].target, targets.library);
      expect(steps.where((s) => s.tryTool != null).map((s) => s.tryTool), [ToolId.print]);
    });

    test('1.6 (T13.6): a 1.5 user (tour_version 6) gets one step, Print, on its Home card', () {
      expect(currentTourVersion, 7);
      final targets = TourTargets();
      final steps = buildWhatsNewSteps(l: l, targets: targets, since: 6);
      expect(steps.map((s) => s.title), ['New in DocuKit', 'Print', l.tourDoneTitle]);
      final print = steps[1];
      expect((print.body, print.example), (
        'Preview how your document will look on paper, then print to any Wi-Fi or connected printer.',
        'Print a sheet of passport photos.',
      ));
      expect(print.target, targets.toolKey(ToolId.print));
      expect(print.tryTool, ToolId.print);
    });

    test('nothing new for a user already on this version', () {
      expect(buildWhatsNewSteps(l: l, targets: TourTargets(), since: currentTourVersion), isEmpty);
    });

    test('the full tour has no Favourites step (it\'s shown once, in What\'s new — FR-FAV-05)', () {
      final steps = buildHomeTourSteps(l: l, targets: TourTargets(), period: '7 days');
      expect(steps.any((s) => s.title == 'Favourites'), isFalse);
    });

    test('1.1 tools get their own steps (FR-TOUR-11)', () {
      final steps = buildHomeTourSteps(l: l, targets: TourTargets(), period: '7 days');
      TourStep stepFor(ToolId id) => steps.firstWhere((s) => s.tryTool == id);
      expect(stepFor(ToolId.imageConvert).title, 'Convert Image');
      expect(stepFor(ToolId.imageConvert).example, contains('HEIC'));
      expect(stepFor(ToolId.pdfSplit).title, 'Split PDF');
      expect(stepFor(ToolId.pdfSplit).body, 'Break one PDF into several smaller ones.');
      expect(stepFor(ToolId.pdfToImages).title, 'PDF to Images');
      expect(stepFor(ToolId.pdfToImages).example, 'Post a page of a PDF as a photo.');
    });
  });

  group('controller (unit)', () {
    late ProviderContainer c;
    late MemoryStore store;
    setUp(() {
      store = MemoryStore({SettingsRepository.kOnboarding: true});
      c = ProviderContainer(overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(store)),
      ]);
    });
    tearDown(() => c.dispose());

    test('next/back stay in bounds', () {
      final t = c.read(tourControllerProvider.notifier);
      t.begin(total: 11);
      t.back();
      expect(c.read(tourControllerProvider).index, 0);
      for (var i = 0; i < 10; i++) {
        t.next();
      }
      expect(c.read(tourControllerProvider).index, 10);
      t.back();
      expect(c.read(tourControllerProvider).index, 9);
    });

    test('next on the last step finishes; finish sets tour_done + tour_version', () async {
      final t = c.read(tourControllerProvider.notifier);
      t.begin(total: 11);
      for (var i = 0; i < 11; i++) {
        t.next();
      }
      expect(c.read(tourControllerProvider).active, isFalse);
      await pumpEventQueue();
      expect(store.get(SettingsRepository.kTourDone), isTrue);
      expect(store.get(SettingsRepository.kTourVersion), currentTourVersion);
    });

    test('skip sets tour_done', () async {
      final t = c.read(tourControllerProvider.notifier);
      t.begin(total: 11);
      t.next();
      t.skip();
      expect(c.read(tourControllerProvider).active, isFalse);
      await pumpEventQueue();
      expect(store.get(SettingsRepository.kTourDone), isTrue);
    });
  });

  group('overlay (widget)', () {
    Future<TestHarness> pump(WidgetTester tester,
        {bool tourDone = false, bool onboarded = true, Size size = const Size(400, 860)}) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = await tester.runAsync(() => TestHarness.create(onboarded: onboarded, tourDone: tourDone));
      await tester.pumpWidget(h!.app());
      await tester.pump(const Duration(milliseconds: 100));
      return h;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 700)); // auto-start delay (600 ms)
      await tester.pumpAndSettle();
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('auto-starts once for a new user (intro card)', (tester) async {
      final h = await pump(tester);
      await settle(tester);
      expect(find.byType(TourOverlay), findsOneWidget);
      expect(find.text('Quick tour'), findsOneWidget);
      await finish(tester);
      expect(h, isNotNull);
    });

    testWidgets('a 1.0 user (tour done, version 1) gets the What\'s new mini-tour once, then never again', (tester) async {
      tester.view.physicalSize = const Size(400, 860) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = (await tester.runAsync(() => TestHarness.create(store: {
            SettingsRepository.kOnboarding: true,
            SettingsRepository.kTourDone: true,
            SettingsRepository.kTourVersion: 1,
          })))!;
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.byType(TourOverlay), findsOneWidget);
      expect(find.text('New in DocuKit'), findsOneWidget);
      // Intro → Convert → Split → PDF to Images → Print (1.6) → Scan (1.2) → Text Recognition (1.3) → … → Favourites → done.
      for (final (i, title) in [
        'Convert Image', 'Split PDF', 'PDF to Images', 'Print', 'Scan Document', 'Text Recognition', //
        'Secure & Sign', 'Sign PDF', 'Watermark PDF', 'Protect PDF', 'Unlock PDF', 'Favourites',
      ].indexed) {
        await tester.tap(find.text(i == 0 ? 'Start tour' : 'Next').last);
        await tester.pumpAndSettle();
        expect(find.text(title), findsWidgets, reason: title);
      }
      expect(find.text('Step 12 of 14'), findsOneWidget, reason: 'the count uses the steps actually shown');
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(h.store.get(SettingsRepository.kTourVersion), currentTourVersion);
      await finish(tester);
    });

    testWidgets('FR-SCN-26: a 1.1 user (version 2) gets Scan Document (then Text Recognition), then never again', (tester) async {
      tester.view.physicalSize = const Size(400, 860) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = (await tester.runAsync(() => TestHarness.create(store: {
            SettingsRepository.kOnboarding: true,
            SettingsRepository.kTourDone: true,
            SettingsRepository.kTourVersion: 2,
          })))!;
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.text('New in DocuKit'), findsOneWidget);
      await tester.tap(find.text('Start tour').last);
      await tester.pumpAndSettle();
      expect(find.text('Preview how your document will look on paper, then print to any Wi-Fi or connected printer.'), findsOneWidget, reason: 'Print (1.6) first, in catalogue order');
      expect(find.text('Step 1 of 10'), findsOneWidget); // Print, Scan, OCR, section, 4 secure tools, My Documents, done
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
      expect(find.text('Scan Document'), findsWidgets);
      expect(find.text('Scan paper with your camera. Edges are found and straightened automatically.'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(h.store.get(SettingsRepository.kTourVersion), currentTourVersion);
      await finish(tester);
    });

    testWidgets('1.3: a 1.2 user (version 3) gets one new step, Text Recognition, then never again', (tester) async {
      tester.view.physicalSize = const Size(400, 860) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = (await tester.runAsync(() => TestHarness.create(store: {
            SettingsRepository.kOnboarding: true,
            SettingsRepository.kTourDone: true,
            SettingsRepository.kTourVersion: 3,
          })))!;
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.text('New in DocuKit'), findsOneWidget);
      await tester.tap(find.text('Start tour').last);
      await tester.pumpAndSettle();
      expect(find.text('Preview how your document will look on paper, then print to any Wi-Fi or connected printer.'), findsOneWidget);
      expect(find.text('Step 1 of 9'), findsOneWidget); // Print, OCR, section, 4 secure tools, My Documents, done
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
      expect(find.text('Text Recognition'), findsWidgets);
      expect(find.text('Find the text in photos and scans. Copy it, or make a PDF you can search.'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(h.store.get(SettingsRepository.kTourVersion), currentTourVersion);
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.text('New in DocuKit'), findsNothing, reason: 'once only');
      await finish(tester);
    });

    testWidgets('1.4: a 1.3 user (version 4) gets Secure & Sign: the section, then its 4 tools, once', (tester) async {
      tester.view.physicalSize = const Size(400, 860) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = (await tester.runAsync(() => TestHarness.create(store: {
            SettingsRepository.kOnboarding: true,
            SettingsRepository.kTourDone: true,
            SettingsRepository.kTourVersion: 4,
          })))!;
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.text('New in DocuKit'), findsOneWidget);
      await tester.tap(find.text('Start tour').last);
      await tester.pumpAndSettle();
      expect(find.text('Preview how your document will look on paper, then print to any Wi-Fi or connected printer.'), findsOneWidget);
      expect(find.text('Step 1 of 8'), findsOneWidget);
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
      expect(find.text('Sign, watermark, or add and remove passwords — all on your phone.'), findsOneWidget);
      for (final title in ['Sign PDF', 'Watermark PDF', 'Protect PDF', 'Unlock PDF']) {
        await tester.tap(find.text('Next').last);
        await tester.pumpAndSettle();
        expect(find.text(title), findsWidgets, reason: title);
      }
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(h.store.get(SettingsRepository.kTourVersion), currentTourVersion);
      await finish(tester);
    });

    testWidgets('1.5 (T12.9): a 1.4 user (version 5) gets Print (1.6) and My Documents, then never again', (tester) async {
      tester.view.physicalSize = const Size(400, 860) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = (await tester.runAsync(() => TestHarness.create(store: {
            SettingsRepository.kOnboarding: true,
            SettingsRepository.kTourDone: true,
            SettingsRepository.kTourVersion: 5,
          })))!;
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.text('New in DocuKit'), findsOneWidget);
      await tester.tap(find.text('Start tour').last);
      await tester.pumpAndSettle();
      expect(find.text('Preview how your document will look on paper, then print to any Wi-Fi or connected printer.'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
      expect(find.text('Keep important documents here in folders. Search their text and get a reminder before they expire. They stay on this phone.'),
          findsOneWidget);
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(h.store.get(SettingsRepository.kTourVersion), currentTourVersion);
      await finish(tester);
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.text('New in DocuKit'), findsNothing, reason: 'shown once');
      await finish(tester);
    });

    testWidgets('does not start when tour_done is set', (tester) async {
      await pump(tester, tourDone: true);
      await settle(tester);
      expect(find.byType(TourOverlay), findsNothing);
      await finish(tester);
    });

    testWidgets('does not start before onboarding closes, then starts after it', (tester) async {
      await pump(tester, onboarded: false);
      await settle(tester);
      expect(find.byType(TourOverlay), findsNothing);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle(); // Home builds; its 600 ms auto-start timer begins
      await settle(tester);
      expect(find.byType(TourOverlay), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Skip is on every step; skipping persists tour_done', (tester) async {
      final h = await pump(tester);
      await settle(tester);
      await tester.tap(find.text('Start tour'));
      await tester.pumpAndSettle();
      for (var step = 1; step <= numberedSteps; step++) {
        expect(find.text('Skip'), findsOneWidget, reason: 'step $step');
        expect(find.text('Step $step of $numberedSteps'), findsOneWidget);
        if (step < numberedSteps) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(TourOverlay), findsNothing);
      expect(h.store.get(SettingsRepository.kTourDone), isTrue);
      await finish(tester);
    });

    testWidgets('Back is hidden on step 1; last step says Done', (tester) async {
      await pump(tester);
      await settle(tester);
      await tester.tap(find.text('Start tour'));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);
      for (var i = 2; i < numberedSteps; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('taps on the scrim do not open tools', (tester) async {
      await pump(tester);
      await settle(tester);
      await tester.tap(find.text('Start tour'));
      await tester.pumpAndSettle();
      // Tap where the first tool card is, through the scrim.
      final card = tester.getCenter(find.byType(ToolCard).first, warnIfMissed: false);
      await tester.tapAt(card);
      await tester.pumpAndSettle();
      expect(find.byType(TourOverlay), findsOneWidget);
      expect(find.text('Choose image'), findsNothing);
      await finish(tester);
    });

    testWidgets('Android back: previous step, and skip on step 1', (tester) async {
      final h = await pump(tester);
      await settle(tester);
      await tester.tap(find.text('Start tour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of $numberedSteps'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of $numberedSteps'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TourOverlay), findsNothing);
      expect(h.store.get(SettingsRepository.kTourDone), isTrue);
      await finish(tester);
    });

    testWidgets('320×568: a tool card below the fold is scrolled into view', (tester) async {
      await pump(tester, size: const Size(320, 568));
      await settle(tester);
      await tester.tap(find.text('Start tour'));
      await tester.pumpAndSettle();
      // Advance to Reduce PDF Size (the last tool) — far below the fold here.
      final step = 2 + toolCatalog.indexWhere((t) => t.id == ToolId.pdfCompress);
      for (var i = 1; i < step; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Step $step of $numberedSteps'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      final key = container.read(tourTargetsProvider).toolKey(ToolId.pdfCompress);
      final rect = tester.getRect(find.byKey(key));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(568));
      await finish(tester);
    });

    testWidgets('200% text: the tooltip fits on every step', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, size: const Size(360, 780));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Start tour'));
      await tester.pumpAndSettle();
      for (var i = 1; i <= numberedSteps; i++) {
        expect(tester.takeException(), isNull, reason: 'step $i');
        final next = i < numberedSteps ? find.text('Next') : find.text('Done');
        await tester.ensureVisible(next.last);
        await tester.tap(next.last);
        await tester.pumpAndSettle();
      }
      expect(find.byType(TourOverlay), findsNothing);
      await finish(tester);
    });

    testWidgets('"Try it" ends the tour and opens that tool', (tester) async {
      final h = await pump(tester);
      await settle(tester);
      await tester.tap(find.text('Start tour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // → Image Compressor (step 2)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try it'));
      await tester.pumpAndSettle();
      expect(find.byType(TourOverlay), findsNothing);
      expect(find.text('Choose image'), findsWidgets);
      expect(h.store.get(SettingsRepository.kTourDone), isTrue);
      await finish(tester);
    });

    testWidgets('replay from the Home help (?) button', (tester) async {
      await pump(tester, tourDone: true);
      await settle(tester);
      await tester.tap(find.byTooltip('Take the tour'));
      await tester.pumpAndSettle();
      expect(find.byType(TourOverlay), findsOneWidget);
      await finish(tester);
      unawaited(Future<void>.value());
    });

    testWidgets('replay from Settings → Take the tour goes Home and starts at step 1', (tester) async {
      await pump(tester, tourDone: true);
      await settle(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Take the tour'), 300);
      await tester.tap(find.text('Take the tour'));
      await tester.pumpAndSettle();
      await settle(tester); // Home waits for the route transition to finish
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TourOverlay), findsOneWidget);
      expect(find.text('Quick tour'), findsOneWidget);
      await finish(tester);
    });
  });
}
