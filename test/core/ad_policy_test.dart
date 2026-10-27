// ADS.md §4, §4.3, §4.4 — written before the implementation (T7.8).
import 'package:docukit/core/ads/ad_policy.dart';
import 'package:docukit/core/ads/ads_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AdPolicy();
  final t0 = DateTime(2026, 10, 27, 12);

  // A state in which an interstitial IS allowed; each test breaks one rule.
  final ok = AdCounters(lifetimeJobs: 5, jobsSinceInterstitial: 3, lastInterstitialAt: t0.subtract(const Duration(minutes: 10)));
  bool interstitial({
    AdCounters? c,
    DateTime? now,
    bool adsRemoved = false,
    bool canRequestAds = true,
    bool tourDone = true,
    DateTime? foregroundedAt,
    bool jobSucceeded = true,
    bool userTappedDone = true,
    bool loaded = true,
  }) =>
      policy.canShowInterstitial(
        now ?? t0,
        c ?? ok,
        adsRemoved: adsRemoved,
        canRequestAds: canRequestAds,
        tourDone: tourDone,
        foregroundedAt: foregroundedAt ?? t0.subtract(const Duration(minutes: 5)),
        jobSucceeded: jobSucceeded,
        userTappedDone: userTappedDone,
        loaded: loaded,
      );

  group('§4 interstitial (AD-3)', () {
    test('allowed when every rule holds', () => expect(interstitial(), isTrue));

    test("never in a new user's first two jobs", () {
      expect(interstitial(c: ok.copyWith(lifetimeJobs: 1)), isFalse);
      expect(interstitial(c: ok.copyWith(lifetimeJobs: 2)), isTrue);
    });

    test('at most one per 3 completed jobs', () {
      expect(interstitial(c: ok.copyWith(jobsSinceInterstitial: 2)), isFalse);
      expect(interstitial(c: ok.copyWith(jobsSinceInterstitial: 3)), isTrue);
    });

    test('4 minutes since the last interstitial', () {
      expect(interstitial(c: ok.copyWith(lastInterstitialAt: () => t0.subtract(const Duration(minutes: 3, seconds: 59)))), isFalse);
      expect(interstitial(c: ok.copyWith(lastInterstitialAt: () => t0.subtract(const Duration(minutes: 4)))), isTrue);
      expect(interstitial(c: ok.copyWith(lastInterstitialAt: () => null)), isTrue);
    });

    test('never within 60 s of launch or resume', () {
      expect(interstitial(foregroundedAt: t0.subtract(const Duration(seconds: 59))), isFalse);
      expect(interstitial(foregroundedAt: t0.subtract(const Duration(seconds: 60))), isTrue);
    });

    test('session cap of 2 interstitials', () {
      expect(interstitial(c: ok.copyWith(interstitialsThisSession: 1, fullScreenThisSession: 1)), isTrue);
      expect(interstitial(c: ok.copyWith(interstitialsThisSession: 2, fullScreenThisSession: 2)), isFalse);
    });

    test('never after a failed job, or on system back instead of Done', () {
      expect(interstitial(jobSucceeded: false), isFalse);
      expect(interstitial(userTappedDone: false), isFalse);
    });

    test('ads removed, no consent, tour not done, nothing loaded → no', () {
      expect(interstitial(adsRemoved: true), isFalse);
      expect(interstitial(canRequestAds: false), isFalse);
      expect(interstitial(tourDone: false), isFalse);
      expect(interstitial(loaded: false), isFalse);
    });

    test('counters: a completed job counts; showing resets the gap', () {
      var c = const AdCounters();
      c = policy.afterJobCompleted(c);
      c = policy.afterJobCompleted(c);
      expect(c.lifetimeJobs, 2);
      expect(c.jobsSinceInterstitial, 2);
      c = policy.afterFullScreen(t0, c, interstitial: true);
      expect(c.jobsSinceInterstitial, 0);
      expect(c.lastInterstitialAt, t0);
      expect(c.lastFullScreenAt, t0);
      expect(c.interstitialsThisSession, 1);
      expect(c.fullScreenThisSession, 1);
      expect(c.lifetimeJobs, 2);
    });
  });

  group('§4.3 rewarded (AD-8)', () {
    bool offer({AdCounters c = const AdCounters(), bool adsRemoved = false, bool canRequestAds = true, bool loaded = true, DateTime? now}) =>
        policy.canOfferReward(now ?? t0, c, adsRemoved: adsRemoved, canRequestAds: canRequestAds, loaded: loaded);

    test('offered only when loaded, consented and not removed', () {
      expect(offer(), isTrue);
      expect(offer(loaded: false), isFalse);
      expect(offer(canRequestAds: false), isFalse);
      expect(offer(adsRemoved: true), isFalse);
    });

    test('reward = no ads for 24 hours', () {
      final c = policy.afterReward(t0, const AdCounters());
      expect(c.adsFreeUntil, t0.add(const Duration(hours: 24)));
      expect(policy.adsSuppressed(t0.add(const Duration(hours: 23, minutes: 59)), c, adsRemoved: false), isTrue);
      expect(policy.adsSuppressed(t0.add(const Duration(hours: 24)), c, adsRemoved: false), isFalse);
    });

    test('max 2 rewards a day, reset the next day', () {
      var c = policy.afterReward(t0, const AdCounters());
      expect(offer(c: c), isTrue);
      c = policy.afterReward(t0.add(const Duration(hours: 1)), c);
      expect(policy.rewardsToday(t0, c), 2);
      expect(offer(c: c), isFalse);
      final tomorrow = DateTime(2026, 10, 28, 9);
      expect(policy.rewardsToday(tomorrow, c), 0);
      expect(offer(c: c, now: tomorrow), isTrue);
      c = policy.afterReward(tomorrow, c);
      expect(policy.rewardsToday(tomorrow, c), 1);
    });

    test('a second reward extends from now, never shortens the window', () {
      var c = policy.afterReward(t0, const AdCounters());
      c = policy.afterReward(t0.add(const Duration(hours: 2)), c);
      expect(c.adsFreeUntil, t0.add(const Duration(hours: 26)));
    });
  });

  group('§4.4 global caps', () {
    test('no interstitial while ad-free (reward window)', () {
      final c = policy.afterReward(t0.subtract(const Duration(hours: 1)), ok);
      expect(interstitial(c: c), isFalse);
    });

    test('full-screen ads never within 4 minutes of each other (any format)', () {
      final c = ok.copyWith(lastFullScreenAt: () => t0.subtract(const Duration(minutes: 2)));
      expect(interstitial(c: c), isFalse);
    });

    test('at most 3 full-screen ads per session combined', () {
      final c = ok.copyWith(interstitialsThisSession: 1, fullScreenThisSession: 3);
      expect(interstitial(c: c), isFalse);
    });

    test('nothing at all when ads are removed or during the ad-free window', () {
      expect(policy.adsSuppressed(t0, const AdCounters(), adsRemoved: true), isTrue);
      expect(policy.adsSuppressed(t0, const AdCounters(), adsRemoved: false), isFalse);
    });

    test('native cards: hidden during the tour, on the first launch, without consent, or when suppressed', () {
      bool native({bool tourActive = false, int session = 2, bool canRequestAds = true, bool adsRemoved = false}) =>
          policy.canShowNative(t0, const AdCounters(),
              adsRemoved: adsRemoved, canRequestAds: canRequestAds, tourActive: tourActive, sessionNumber: session);
      expect(native(), isTrue);
      expect(native(tourActive: true), isFalse);
      expect(native(session: 1), isFalse);
      expect(native(canRequestAds: false), isFalse);
      expect(native(adsRemoved: true), isFalse);
    });

    test('AD-4 in-feed: after the 3rd row, then every interval; only with ≥ 5 rows', () {
      expect(policy.historyAdSlots(4), isEmpty);
      expect(policy.historyAdSlots(5), [3]);
      expect(policy.historyAdSlots(15), [3, 15]);
      expect(policy.historyAdSlots(40), [3, 15, 27, 39]);
      // One native card per screen: consecutive cards are a full interval apart.
      final s = policy.historyAdSlots(200);
      for (var i = 1; i < s.length; i++) {
        expect(s[i] - s[i - 1], historyAdInterval);
      }
    });
  });

  group('phase A', () {
    test('adsPhase = A: AD-7 and AD-9 are off; AD-4 interval is 12', () {
      expect(adsPhase, AdsPhase.a);
      expect(policy.appOpenEnabled, isFalse);
      expect(policy.home2Enabled, isFalse);
      expect(historyAdInterval, 12);
    });
  });

  group('unit IDs', () {
    test('debug uses Google test IDs; release never does (empty key → no ad)', () {
      expect(AdUnits.resolve(AdUnit.nativeHome, android: true, debug: true, defined: ''), 'ca-app-pub-3940256099942544/2247696110');
      expect(AdUnits.resolve(AdUnit.nativeHome, android: false, debug: true, defined: ''), 'ca-app-pub-3940256099942544/3986624511');
      expect(AdUnits.resolve(AdUnit.interstitialDone, android: true, debug: false, defined: ''), isNull);
      expect(AdUnits.resolve(AdUnit.rewardedAdFree, android: false, debug: false, defined: ''), isNull);
      // Debug always uses test IDs, even when a real one is passed.
      expect(AdUnits.resolve(AdUnit.nativeHome, android: true, debug: true, defined: 'ca-app-pub-1/2'), 'ca-app-pub-3940256099942544/2247696110');
      expect(AdUnits.resolve(AdUnit.nativeHome, android: true, debug: false, defined: 'ca-app-pub-1/2'), 'ca-app-pub-1/2');
      expect(AdUnits.resolve(AdUnit.bannerSettings, android: true, debug: false, defined: ''), isNull);
      expect(AdUnits.resolve(AdUnit.bannerSettings, android: true, debug: true, defined: ''), 'ca-app-pub-3940256099942544/9214589741');
    });
  });
}
