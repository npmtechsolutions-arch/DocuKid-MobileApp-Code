// Item 4: hidden ad diagnostics (written before the implementation).
import 'package:docukit/core/ads/ad_diagnostics.dart';
import 'package:docukit/core/ads/ads_config.dart';
import 'package:docukit/core/ads/ads_controller.dart';
import 'package:docukit/core/ads/ads_service.dart';
import 'package:docukit/features/settings/ad_diagnostics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

class _ConsentAds extends NoAdsService {
  @override
  Future<bool> start() async => true;
  @override
  Future<bool> canRequestAds() async => true;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  setUp(AdDiagnostics.instance.clear);

  group('AdLoadResult', () {
    test('no fill is recognised per platform (Android 3, iOS 1); other codes are errors', () {
      expect(AdLoadResult.fromError(3, 'No fill.', android: true).outcome, AdOutcome.noFill);
      expect(AdLoadResult.fromError(1, 'No ad to show.', android: false).outcome, AdOutcome.noFill);
      final e = AdLoadResult.fromError(2, 'Network error.', android: true);
      expect(e.outcome, AdOutcome.error);
      expect((e.code, e.message), (2, 'Network error.'));
    });

    test('the recorder keeps the last result per unit', () {
      final d = AdDiagnostics.instance;
      d.record(AdUnit.bannerMain, AdLoadResult.fromError(3, 'No fill.', android: true));
      d.record(AdUnit.bannerMain, AdLoadResult.loaded());
      expect(d.results.value[AdUnit.bannerMain]!.outcome, AdOutcome.loaded);
      expect(d.results.value.containsKey(AdUnit.nativeHome), isFalse);
    });
  });

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await tester.runAsync(() => TestHarness.create(store: {AdsController.kSessions: 2}));
    h!.gateway.nextPdfs = [fakePdf('Bank_statement_private.pdf')];
    await tester.pumpWidget(h.app(ads: _ConsentAds()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('settings-version')), 300);
  }

  Future<void> tapVersion(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(const ValueKey('settings-version')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('6 taps on the version: nothing; 7 taps: the diagnostics screen', (tester) async {
    await openSettings(tester);
    await tapVersion(tester, 6);
    expect(find.byType(AdDiagnosticsScreen), findsNothing);
    await tapVersion(tester, 1);
    expect(find.byType(AdDiagnosticsScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('lists every ad slot with its last result, consent and test/real IDs', (tester) async {
    final d = AdDiagnostics.instance;
    d.record(AdUnit.bannerMain, AdLoadResult.loaded());
    d.record(AdUnit.nativeHome, AdLoadResult.fromError(3, 'No fill.', android: true));
    d.record(AdUnit.interstitialDone, AdLoadResult.fromError(2, 'Network error.', android: true));
    await openSettings(tester);
    await tapVersion(tester, 7);

    const expected = {
      AdUnit.bannerMain: 'Loaded at',
      AdUnit.nativeHome: 'No fill at',
      AdUnit.interstitialDone: 'code 2, Network error.',
    };
    for (final u in AdUnit.values) {
      await tester.scrollUntilVisible(find.text(u.defineKey), 200);
      final row = find.ancestor(of: find.text(u.defineKey), matching: find.byType(ListTile));
      expect(row, findsOneWidget, reason: u.name);
      final want = expected[u] ?? 'Not requested yet';
      expect(find.descendant(of: row, matching: find.textContaining(want)), findsOneWidget, reason: '${u.name}: $want');
      expect(find.descendant(of: row, matching: find.text('Test ID')), findsOneWidget, reason: u.name);
    }

    await tester.scrollUntilVisible(find.textContaining('Consent allows ads'), -200);
    expect(find.textContaining('Consent allows ads: Yes'), findsOneWidget);
    expect(find.textContaining('Test IDs'), findsWidgets, reason: 'tests run as a debug build');
    await finish(tester);
  });

  testWidgets('no personal or file data on the screen', (tester) async {
    await openSettings(tester);
    await tapVersion(tester, 7);
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText() ?? '').join(' | ');
    expect(texts, isNot(contains('Bank_statement')));
    expect(texts, isNot(contains('/')), reason: 'no paths');
    await finish(tester);
  });
}
