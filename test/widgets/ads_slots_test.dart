// ADS.md §11 widget tests: slots collapse, excluded screens, no app data.
import 'dart:async';

import 'package:docukit/core/ads/ad_slots.dart';
import 'package:docukit/core/ads/ads_config.dart';
import 'package:docukit/core/ads/ads_controller.dart';
import 'package:docukit/core/ads/ads_service.dart';
import 'package:docukit/core/ads/google_ads_service.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

class _FakeAd implements LoadedAd {
  bool disposed = false;
  @override
  double get height => 112;
  @override
  Widget get widget => const ColoredBox(key: ValueKey('fake-ad'), color: Colors.amber);
  @override
  void dispose() => disposed = true;
}

/// Consent granted; returns an ad, nothing, or an error as configured.
class _FakeAds extends NoAdsService {
  _FakeAds({this.fill = true, this.throws = false});
  final bool fill, throws;
  final requested = <AdUnit>[];

  @override
  Future<bool> start() async => true;
  @override
  Future<bool> canRequestAds() async => true;
  @override
  Future<LoadedAd?> loadNative(AdUnit unit, NativeSize size, NativeLook look) async {
    requested.add(unit);
    if (throws) throw StateError('network');
    return fill ? _FakeAd() : null;
  }

  /// Native cards only here; bottom banners are tested in
  /// bottom_banner_test.dart / banner_placement_test.dart.
  @override
  Future<LoadedAd?> loadBanner(AdUnit unit, int width) async {
    requested.add(unit);
    return null;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> pump(WidgetTester tester, AdsService ads, {Map<String, Object> store = const {}}) async {
    tester.view.physicalSize = const Size(400, 2400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    // Second launch by default: AD-1 is hidden on the very first one.
    final h = await tester.runAsync(() => TestHarness.create(store: {AdsController.kSessions: 1, ...store}));
    await tester.pumpWidget(h!.app(ads: ads));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  final fakeAd = find.byKey(const ValueKey('fake-ad'));

  testWidgets('AD-1 shows on Home with an "Ad" badge when an ad loads', (tester) async {
    await pump(tester, _FakeAds());
    expect(fakeAd, findsOneWidget);
    expect(find.text('Ad'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('no ad / no network → AD-1 is zero height, no badge, no box', (tester) async {
    for (final ads in [_FakeAds(fill: false), _FakeAds(throws: true)]) {
      await pump(tester, ads);
      expect(fakeAd, findsNothing);
      expect(find.text('Ad'), findsNothing);
      expect(tester.getSize(find.byType(NativeAdSlot)).height, 0);
      await finish(tester);
    }
  });

  testWidgets('no consent (SDK unavailable) → nothing is even requested', (tester) async {
    await pump(tester, const NoAdsService());
    expect(tester.getSize(find.byType(NativeAdSlot)).height, 0);
    await finish(tester);
  });

  testWidgets('first launch → AD-1 not requested', (tester) async {
    final ads = _FakeAds();
    await pump(tester, ads, store: {AdsController.kSessions: 0});
    expect(fakeAd, findsNothing);
    // The first-launch rule is AD-1's; the bottom banner (ADR-035) has none.
    expect(ads.requested, isNot(contains(AdUnit.nativeHome)));
    await finish(tester);
  });

  testWidgets('Remove ads → every slot collapses immediately and the ad is disposed', (tester) async {
    await pump(tester, _FakeAds());
    expect(fakeAd, findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await container.read(adsControllerProvider.notifier).setAdsRemoved();
    await tester.pump();
    expect(fakeAd, findsNothing);
    expect(tester.getSize(find.byType(NativeAdSlot)).height, 0);
    await finish(tester);
  });

  testWidgets('ads already removed → nothing requested at all', (tester) async {
    final ads = _FakeAds();
    await pump(tester, ads, store: {AdsController.kRemoved: true});
    expect(fakeAd, findsNothing);
    expect(ads.requested, isEmpty);
    await finish(tester);
  });

  testWidgets('reward window active → no ads', (tester) async {
    final ads = _FakeAds();
    final until = DateTime.now().add(const Duration(hours: 5)).millisecondsSinceEpoch;
    await pump(tester, ads, store: {AdsController.kFreeUntil: until});
    expect(fakeAd, findsNothing);
    await finish(tester);
  });

  testWidgets('AD-1 is hidden while the tour runs', (tester) async {
    await pump(tester, _FakeAds(), store: {SettingsRepository.kTourDone: false});
    await tester.pump(const Duration(milliseconds: 700)); // tour auto-start
    await tester.pumpAndSettle();
    expect(find.text('Quick tour'), findsOneWidget);
    expect(fakeAd, findsNothing);
    await finish(tester);
  });

  testWidgets('excluded screens never build a native card (tool screens, Search, Privacy, Onboarding)', (tester) async {
    await pump(tester, _FakeAds());
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    for (final route in [
      '/tool/image-compress',
      '/tool/image-resize',
      '/tool/image-to-pdf',
      '/tool/pdf-merge',
      '/tool/pdf-organize',
      '/tool/pdf-compress',
      '/search',
      '/settings/privacy',
      '/settings/policy',
      '/onboarding',
    ]) {
      unawaited(router.push(route));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final top = find.byWidgetPredicate((w) => w is NativeAdSlot, skipOffstage: true);
      expect(top.evaluate().where((e) => ModalRoute.of(e)?.isCurrent ?? false), isEmpty, reason: route);
      router.pop();
      await tester.pump(const Duration(seconds: 1));
    }
    await finish(tester);
  });

  test('AdRequest carries no app data', () {
    const r = adRequestForTest;
    expect(r.keywords, isNull);
    expect(r.contentUrl, isNull);
    expect(r.neighboringContentUrls, isNull);
    expect(r.extras, isNull);
    expect(r.mediationExtras, isNull);
  });
}
