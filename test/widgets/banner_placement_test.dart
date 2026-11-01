// ADR-035 item 2: where the bottom banner appears, with which key, and the
// 24 dp gap + divider below the action button on the tool screens.
import 'dart:async';

import 'package:docukit/core/ads/ads_config.dart';
import 'package:docukit/core/ads/ads_controller.dart';
import 'package:docukit/core/ads/ads_service.dart';
import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/core/scan/document_scanner.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tour/tour_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

class _Banner implements LoadedAd {
  @override
  double get height => 60;
  @override
  Widget get widget => const ColoredBox(color: Colors.amber);
  @override
  void dispose() {}
}

/// Consent granted; banners always fill; native cards never (kept out of the way).
class BannerAds extends NoAdsService {
  @override
  Future<bool> start() async => true;
  @override
  Future<bool> canRequestAds() async => true;
  @override
  Future<LoadedAd?> loadBanner(AdUnit unit, int width) async => _Banner();
}

class SeededJobs extends JobsController {
  SeededJobs(this.seed);
  final Map<String, LiveJob> seed;
  @override
  Map<String, LiveJob> build() => seed;
}

LiveJob job(String id, JobState state) =>
    LiveJob(id: id, tool: ToolId.pdfCompress, state: state, cancel: CancelToken(), restart: () => id, inputBytes: 3000000);

final seededJobs = {
  'result': job(
    'result',
    const JobCompleted(JobResult(
      jobId: 'result',
      tool: ToolId.pdfCompress,
      outputPath: '/nonexistent/out.pdf',
      outputName: 'out.pdf',
      mime: 'application/pdf',
      meta: OutputMeta(bytes: 400000, pages: 3),
      inputBytes: 3000000,
      inputCount: 1,
      duration: Duration(seconds: 1),
    )),
  ),
  'processing': job('processing', const JobProcessing(Determinate(1, 3, 'stepOptimizing'))),
  'error': job('error', const JobFailed(AppError(AppErrorCode.processingFailed))),
};

final bannerAd = find.byKey(const ValueKey('app-bottom-banner-ad'));

/// Opens the app with banners filling, seeded jobs and one history entry.
Future<GoRouter> openApp(WidgetTester tester, {Size size = const Size(400, 900), bool onboarded = true}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final h = await tester.runAsync(() async {
    final h = await TestHarness.create(onboarded: onboarded, store: {AdsController.kSessions: 2});
    final history = HistoryRepository(h.db);
    final t = DateTime(2026, 10, 27, 10);
    await history.insertRunning(
      id: 'op1',
      tool: ToolId.pdfMerge,
      createdAt: t,
      inputs: const [InputRecord(displayName: 'a.pdf', mime: 'application/pdf', sizeBytes: 1000)],
    );
    await history.complete('op1',
        finishedAt: t, duration: const Duration(seconds: 1), outputName: 'm.pdf', outputMime: 'application/pdf', outputBytes: 900, outputRelPath: 'op1/m.pdf');
    return h;
  });
  h!.gateway.nextPdfs = [fakePdf('doc.pdf', pages: 3)];
  await tester.pumpWidget(h.app(ads: BannerAds(), overrides: [jobsProvider.overrideWith(() => SeededJobs(seededJobs))]));
  await tester.pump(const Duration(milliseconds: 300));
  return GoRouter.of(tester.element(find.byType(onboarded ? HomeScreen : Scaffold).first));
}

Future<void> show(WidgetTester tester, GoRouter router, String route) async {
  unawaited(router.push(route));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The AppBottomBanner slots on the visible screen (covered routes are offstage).
List<AppBottomBanner> visibleSlots(WidgetTester tester) => tester.widgetList<AppBottomBanner>(find.byType(AppBottomBanner)).toList();

const listed = <String, AdUnit>{
  '/search': AdUnit.bannerMain,
  '/job/result': AdUnit.bannerMain,
  '/history': AdUnit.bannerMain,
  '/history/op1': AdUnit.bannerMain,
  '/tool/image-compress': AdUnit.bannerTools,
  '/tool/image-resize': AdUnit.bannerTools,
  '/tool/image-to-pdf': AdUnit.bannerTools,
  '/tool/pdf-merge': AdUnit.bannerTools,
  '/tool/pdf-organize': AdUnit.bannerTools,
  '/tool/pdf-compress': AdUnit.bannerTools,
  '/tool/pdf-merge/review': AdUnit.bannerTools,
  '/tool/scan': AdUnit.bannerTools,
  '/settings/privacy': AdUnit.bannerInfo,
  '/settings/licenses': AdUnit.bannerInfo,
  '/settings': AdUnit.bannerSettings,
  // 1.6 Print (ADS.md §3.1).
  '/tool/print': AdUnit.bannerTools,
  '/print/preview': AdUnit.bannerTools,
  // ADR-072 (owner, 2026-11-01): Settings sub-pages.
  '/settings/signatures': AdUnit.bannerSettings,
  '/settings/policy': AdUnit.bannerInfo,
};

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('Home: exactly one banner slot (ADMOB_BANNER_MAIN), showing one ad', (tester) async {
    await openApp(tester);
    await tester.pump(const Duration(seconds: 1)); // consent start-up, then the load
    await tester.pump(const Duration(seconds: 1));
    expect(visibleSlots(tester).map((b) => b.unit), [AdUnit.bannerMain]);
    expect(bannerAd, findsOneWidget);
    await finish(tester);
  });

  for (final e in listed.entries) {
    testWidgets('${e.key}: exactly one banner slot (${e.value.defineKey}), showing one ad', (tester) async {
      final router = await openApp(tester);
      await show(tester, router, e.key);
      expect(visibleSlots(tester).map((b) => b.unit), [e.value], reason: e.key);
      expect(bannerAd, findsOneWidget, reason: e.key);
      await finish(tester);
    });
  }

  // S27 has no sticky action button (its Start button sits in the card).
  for (final t in toolCatalog.where((t) => t.id != ToolId.scanDocument)) {
    testWidgets('${t.route}: 24 dp gap + 1 dp divider between the action button and the banner', (tester) async {
      final router = await openApp(tester);
      await show(tester, router, t.route);
      final button = tester.getRect(find.descendant(of: find.byType(PrimaryActionBar), matching: find.byType(FilledButton)));
      final ad = tester.getRect(bannerAd);
      expect(ad.top - button.bottom, greaterThanOrEqualTo(AppBottomBanner.gap + 1), reason: 'the button must never touch the banner');
      final divider = tester.getRect(find.descendant(of: find.byType(AppBottomBanner), matching: find.byType(Divider)).last);
      expect(divider.height, 1);
      expect(divider.top, greaterThanOrEqualTo(button.bottom + AppBottomBanner.gap));
      expect(divider.bottom, lessThanOrEqualTo(ad.top));
      await finish(tester);
    });
  }

  testWidgets('/tool/scan (S27): gap + divider above the banner; no banner while getting the scanner ready', (tester) async {
    final router = await openApp(tester);
    await show(tester, router, '/tool/scan');
    final divider = tester.getRect(find.descendant(of: find.byType(AppBottomBanner), matching: find.byType(Divider)).last);
    final ad = tester.getRect(bannerAd);
    expect(divider.height, 1);
    expect(divider.bottom, lessThanOrEqualTo(ad.top));
    final scaffold = tester.element(find.byType(ToolScaffold));
    final scope = ProviderScope.containerOf(scaffold);
    final h = scope.read(documentScannerProvider) as FakeDocumentScanner;
    h
      ..nextAvailability = ScannerAvailability.needsDownload
      ..nextPrepare = null; // stays on "Getting the scanner ready…"
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Getting the scanner ready…'), findsOneWidget);
    expect(bannerAd, findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(bannerAd, findsOneWidget, reason: 'back after Cancel');
    await tester.pump(const Duration(seconds: 61)); // the cancelled wait runs out
    await finish(tester);
  });

  testWidgets('Organizer with the selection bar: the gap sits below bar + button', (tester) async {
    final router = await openApp(tester);
    await show(tester, router, '/tool/pdf-organize');
    await tester.tap(find.text('Choose PDF').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel(RegExp('^Page 1 of 3')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Delete'), findsOneWidget, reason: 'selection bar shown');
    final button = tester.getRect(find.descendant(of: find.byType(PrimaryActionBar), matching: find.byType(FilledButton)));
    final bar = tester.getRect(find.text('Delete'));
    expect(bar.bottom, lessThan(button.top), reason: 'selection bar above the action button');
    expect(tester.getRect(bannerAd).top - button.bottom, greaterThanOrEqualTo(AppBottomBanner.gap + 1));
    await finish(tester);
  });

  group('excluded: no banner', () {
    testWidgets('onboarding', (tester) async {
      await openApp(tester, onboarded: false);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Get started'), findsOneWidget);
      expect(visibleSlots(tester), isEmpty);
      expect(bannerAd, findsNothing);
      await finish(tester);
    });

    testWidgets('Processing', (tester) async {
      final router = await openApp(tester);
      await show(tester, router, '/job/processing');
      expect(visibleSlots(tester), isEmpty);
      expect(bannerAd, findsNothing);
      await finish(tester);
    });

    testWidgets('Error', (tester) async {
      final router = await openApp(tester);
      await show(tester, router, '/job/error');
      expect(find.text('Back to tool'), findsWidgets);
      expect(visibleSlots(tester), isEmpty);
      expect(bannerAd, findsNothing);
      await finish(tester);
    });

    testWidgets('the tour (Home under the overlay shows no ad)', (tester) async {
      await openApp(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(bannerAd, findsOneWidget, reason: 'shown before the tour');
      await tester.tap(find.byTooltip('Take the tour'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(ProviderScope.containerOf(tester.element(find.byType(HomeScreen))).read(tourControllerProvider).active, isTrue);
      expect(bannerAd, findsNothing);
      await finish(tester);
    });

    testWidgets('a bottom sheet over a screen', (tester) async {
      final router = await openApp(tester);
      await show(tester, router, '/settings');
      expect(bannerAd, findsOneWidget);
      await tester.tap(find.text('Theme'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(bannerAd, findsNothing);
      await finish(tester);
    });

    testWidgets('a dialog over a screen', (tester) async {
      final router = await openApp(tester);
      await show(tester, router, '/settings');
      expect(bannerAd, findsOneWidget);
      await tester.scrollUntilVisible(find.text('Clear history'), 300);
      await tester.tap(find.text('Clear history'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Dialog), findsOneWidget);
      expect(bannerAd, findsNothing);
      await finish(tester);
    });

    testWidgets('the full-screen page preview', (tester) async {
      final router = await openApp(tester);
      await show(tester, router, '/tool/pdf-organize');
      await tester.tap(find.text('Choose PDF').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await show(tester, router, '/tool/pdf-organize/preview/0');
      expect(visibleSlots(tester), isEmpty);
      expect(bannerAd, findsNothing);
      await finish(tester);
    });
  });
}
