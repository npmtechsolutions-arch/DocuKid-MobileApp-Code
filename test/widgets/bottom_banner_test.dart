// ADR-035 item 1: the shared AppBottomBanner (hosted on Settings here).
// Reserved space below all content, never over it; collapses with no ad,
// Remove ads, the 24 h ad-free pass, the tour, the keyboard, a dialog/sheet.
import 'package:docukit/core/ads/ads_config.dart';
import 'package:docukit/core/ads/ads_controller.dart';
import 'package:docukit/core/ads/ads_service.dart';
import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/tour/tour_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

class _Banner implements LoadedAd {
  @override
  double get height => 60;
  @override
  Widget get widget => const ColoredBox(color: Colors.amber);
  @override
  void dispose() {}
}

/// Consent granted; banners fill (unless [fill] is false), native cards never do.
class _BannerAds extends NoAdsService {
  _BannerAds({this.fill = true});
  final bool fill;
  final requested = <AdUnit>[];
  @override
  Future<bool> start() async => true;
  @override
  Future<bool> canRequestAds() async => true;
  @override
  Future<LoadedAd?> loadBanner(AdUnit unit, int width) async {
    requested.add(unit);
    return fill ? _Banner() : null;
  }
}

final banner = find.byKey(const ValueKey('app-bottom-banner-ad'));

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<ProviderContainer> settings(
    WidgetTester tester,
    AdsService ads, {
    Map<String, Object> store = const {},
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await tester.runAsync(() => TestHarness.create(store: {AdsController.kSessions: 1, ...store}));
    await tester.pumpWidget(h!.app(
      ads: ads,
      overrides: [if (!enabled) bannerUnitEnabledProvider(AdUnit.bannerSettings).overrideWithValue(false)],
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return c;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Rect settingsScaffold(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.text('Appearance'), matching: find.byType(Scaffold)).first);

  testWidgets('loaded ad: below all content, in its own space (never over it)', (tester) async {
    await settings(tester, _BannerAds());
    expect(banner, findsOneWidget);
    final ad = tester.getRect(banner);
    expect(settingsScaffold(tester).bottom, lessThanOrEqualTo(ad.top), reason: 'the screen ends where the banner starts');
    expect(ad.bottom, lessThanOrEqualTo(900));
    expect(ad.height, 60);
    await finish(tester);
  });

  testWidgets('no ad: zero height, the screen uses the full height', (tester) async {
    await settings(tester, _BannerAds(fill: false));
    expect(banner, findsNothing);
    expect(settingsScaffold(tester).bottom, 900);
    await finish(tester);
  });

  testWidgets('Remove ads bought: collapses immediately', (tester) async {
    final c = await settings(tester, _BannerAds());
    expect(banner, findsOneWidget);
    await c.read(adsControllerProvider.notifier).setAdsRemoved();
    await tester.pump();
    expect(banner, findsNothing);
    expect(settingsScaffold(tester).bottom, 900);
    await finish(tester);
  });

  testWidgets('24 h ad-free pass: nothing shown, nothing requested', (tester) async {
    final ads = _BannerAds();
    final until = DateTime.now().add(const Duration(hours: 5)).millisecondsSinceEpoch;
    await settings(tester, ads, store: {AdsController.kFreeUntil: until});
    expect(banner, findsNothing);
    expect(ads.requested, isEmpty);
    await finish(tester);
  });

  testWidgets('tour running: collapses', (tester) async {
    final c = await settings(tester, _BannerAds());
    expect(banner, findsOneWidget);
    c.read(tourControllerProvider.notifier).begin(total: 11);
    await tester.pump();
    expect(banner, findsNothing);
    c.read(tourControllerProvider.notifier).skip();
    await tester.pump();
    expect(banner, findsOneWidget);
    await finish(tester);
  });

  testWidgets('keyboard open: collapses, comes back when it closes', (tester) async {
    await settings(tester, _BannerAds());
    expect(banner, findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();
    expect(banner, findsNothing);
    tester.view.resetViewInsets();
    await tester.pump();
    expect(banner, findsOneWidget);
    await finish(tester);
  });

  testWidgets('sheet open over the screen: collapses, back after it closes', (tester) async {
    await settings(tester, _BannerAds());
    expect(banner, findsOneWidget);
    await tester.tap(find.text('Theme'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('System').last, findsOneWidget);
    expect(banner, findsNothing);
    await tester.tapAt(const Offset(200, 50)); // dismiss the sheet
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(banner, findsOneWidget);
    await finish(tester);
  });

  testWidgets('key set to off: the slot is never built and nothing is requested', (tester) async {
    final ads = _BannerAds();
    await settings(tester, ads, enabled: false);
    expect(find.byType(AppBottomBanner), findsOneWidget, reason: 'the wrapper stays, as a pass-through');
    expect(banner, findsNothing);
    expect(ads.requested, isNot(contains(AdUnit.bannerSettings)));
    expect(settingsScaffold(tester).bottom, 900);
    await finish(tester);
  });
}
