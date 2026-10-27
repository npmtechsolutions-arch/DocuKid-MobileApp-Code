import 'ads_config.dart';

/// Persisted + per-session counters the rules read (ADS.md §4).
class AdCounters {
  const AdCounters({
    this.lifetimeJobs = 0,
    this.jobsSinceInterstitial = 0,
    this.lastInterstitialAt,
    this.lastFullScreenAt,
    this.interstitialsThisSession = 0,
    this.fullScreenThisSession = 0,
    this.adsFreeUntil,
    this.rewardsToday = 0,
    this.rewardsDay = 0,
  });

  final int lifetimeJobs, jobsSinceInterstitial;
  final DateTime? lastInterstitialAt, lastFullScreenAt;

  /// Not persisted: reset on every cold start.
  final int interstitialsThisSession, fullScreenThisSession;

  /// AD-8 reward window.
  final DateTime? adsFreeUntil;

  /// Rewards granted on [rewardsDay] (yyyyMMdd).
  final int rewardsToday, rewardsDay;

  AdCounters copyWith({
    int? lifetimeJobs,
    int? jobsSinceInterstitial,
    DateTime? Function()? lastInterstitialAt,
    DateTime? Function()? lastFullScreenAt,
    int? interstitialsThisSession,
    int? fullScreenThisSession,
    DateTime? Function()? adsFreeUntil,
    int? rewardsToday,
    int? rewardsDay,
  }) =>
      AdCounters(
        lifetimeJobs: lifetimeJobs ?? this.lifetimeJobs,
        jobsSinceInterstitial: jobsSinceInterstitial ?? this.jobsSinceInterstitial,
        lastInterstitialAt: lastInterstitialAt == null ? this.lastInterstitialAt : lastInterstitialAt(),
        lastFullScreenAt: lastFullScreenAt == null ? this.lastFullScreenAt : lastFullScreenAt(),
        interstitialsThisSession: interstitialsThisSession ?? this.interstitialsThisSession,
        fullScreenThisSession: fullScreenThisSession ?? this.fullScreenThisSession,
        adsFreeUntil: adsFreeUntil == null ? this.adsFreeUntil : adsFreeUntil(),
        rewardsToday: rewardsToday ?? this.rewardsToday,
        rewardsDay: rewardsDay ?? this.rewardsDay,
      );
}

/// ADS.md §4 frequency and timing rules. Pure: no plugin, clock or storage.
class AdPolicy {
  const AdPolicy();

  static const jobsBeforeFirstInterstitial = 2;
  static const jobsBetweenInterstitials = 3;
  static const fullScreenGap = Duration(minutes: 4);
  static const afterForeground = Duration(seconds: 60);
  static const interstitialsPerSession = 2;
  static const fullScreenPerSession = 3;
  static const rewardWindow = Duration(hours: 24);
  static const rewardsPerDay = 2;

  /// AD-7 (app open) and AD-9 (second Home card) only exist in Phase B.
  bool get appOpenEnabled => adsPhase.index >= AdsPhase.b.index;
  bool get home2Enabled => adsPhase.index >= AdsPhase.b.index;

  /// §4.4: no ads at all after Remove ads, or during the reward window.
  bool adsSuppressed(DateTime now, AdCounters c, {required bool adsRemoved}) =>
      adsRemoved || (c.adsFreeUntil != null && now.isBefore(c.adsFreeUntil!));

  /// AD-1/2/4/6: hidden during the tour and on the very first launch.
  bool canShowNative(
    DateTime now,
    AdCounters c, {
    required bool adsRemoved,
    required bool canRequestAds,
    required bool tourActive,
    required int sessionNumber,
  }) =>
      canRequestAds && !tourActive && sessionNumber >= 2 && !adsSuppressed(now, c, adsRemoved: adsRemoved);

  /// AD-3 on Result → Done (§4 + §4.4).
  bool canShowInterstitial(
    DateTime now,
    AdCounters c, {
    required bool adsRemoved,
    required bool canRequestAds,
    required bool tourDone,
    required DateTime foregroundedAt,
    required bool jobSucceeded,
    required bool userTappedDone,
    required bool loaded,
  }) {
    bool since(DateTime? t, Duration d) => t == null || now.difference(t) >= d;
    return !adsSuppressed(now, c, adsRemoved: adsRemoved) &&
        canRequestAds &&
        tourDone &&
        c.lifetimeJobs >= jobsBeforeFirstInterstitial &&
        c.jobsSinceInterstitial >= jobsBetweenInterstitials &&
        since(c.lastInterstitialAt, fullScreenGap) &&
        since(c.lastFullScreenAt, fullScreenGap) &&
        now.difference(foregroundedAt) >= afterForeground &&
        c.interstitialsThisSession < interstitialsPerSession &&
        c.fullScreenThisSession < fullScreenPerSession &&
        jobSucceeded &&
        userTappedDone &&
        loaded;
  }

  AdCounters afterJobCompleted(AdCounters c) =>
      c.copyWith(lifetimeJobs: c.lifetimeJobs + 1, jobsSinceInterstitial: c.jobsSinceInterstitial + 1);

  AdCounters afterFullScreen(DateTime now, AdCounters c, {required bool interstitial}) => c.copyWith(
        lastFullScreenAt: () => now,
        fullScreenThisSession: c.fullScreenThisSession + 1,
        lastInterstitialAt: interstitial ? () => now : null,
        jobsSinceInterstitial: interstitial ? 0 : null,
        interstitialsThisSession: interstitial ? c.interstitialsThisSession + 1 : null,
      );

  static int dayOf(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

  int rewardsToday(DateTime now, AdCounters c) => c.rewardsDay == dayOf(now) ? c.rewardsToday : 0;

  /// §4.3: the offer only exists when an ad is ready to play.
  bool canOfferReward(DateTime now, AdCounters c, {required bool adsRemoved, required bool canRequestAds, required bool loaded}) =>
      !adsRemoved && canRequestAds && rewardsToday(now, c) < rewardsPerDay && loaded;

  /// Granted only from `onUserEarnedReward`.
  AdCounters afterReward(DateTime now, AdCounters c) => c.copyWith(
        adsFreeUntil: () => now.add(rewardWindow),
        rewardsToday: rewardsToday(now, c) + 1,
        rewardsDay: dayOf(now),
      );

  /// AD-4 positions: the card goes after these row counts (≥ 5 rows only).
  List<int> historyAdSlots(int rows) {
    if (rows < 5) return const [];
    return [for (var i = 3; i <= rows; i += historyAdInterval) i];
  }
}
