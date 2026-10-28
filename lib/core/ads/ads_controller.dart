import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings/settings_repository.dart';
import '../operation/jobs_controller.dart';
import '../providers.dart';
import 'ad_policy.dart';
import 'ads_service.dart';
import 'consent_state.dart';

class AdsState {
  const AdsState({
    this.started = false,
    this.canRequestAds = false,
    this.adsRemoved = false,
    this.counters = const AdCounters(),
    this.sessionNumber = 1,
    this.privacyOptionsRequired = false,
    this.rewardLoaded = false,
  });

  final bool started, canRequestAds, adsRemoved, privacyOptionsRequired, rewardLoaded;
  final AdCounters counters;

  /// Cold starts so far, including this one (AD-1 is hidden on the first).
  final int sessionNumber;

  AdsState copyWith({
    bool? started,
    bool? canRequestAds,
    bool? adsRemoved,
    AdCounters? counters,
    bool? privacyOptionsRequired,
    bool? rewardLoaded,
  }) =>
      AdsState(
        started: started ?? this.started,
        canRequestAds: canRequestAds ?? this.canRequestAds,
        adsRemoved: adsRemoved ?? this.adsRemoved,
        counters: counters ?? this.counters,
        sessionNumber: sessionNumber,
        privacyOptionsRequired: privacyOptionsRequired ?? this.privacyOptionsRequired,
        rewardLoaded: rewardLoaded ?? this.rewardLoaded,
      );
}

/// Owns consent start-up, counters (shared_preferences keys from ADS.md §4),
/// the AD-3 interstitial and the AD-8 rewarded ad.
class AdsController extends Notifier<AdsState> {
  static const kJobsSince = 'ads_jobs_since_interstitial';
  static const kLastInterstitial = 'ads_last_interstitial_at';
  static const kLastFullScreen = 'ads_last_fullscreen_at';
  static const kLifetimeJobs = 'ads_lifetime_jobs';
  static const kFreeUntil = 'ads_free_until';
  static const kRewardsToday = 'ads_rewards_today';
  static const kRewardsDay = 'ads_rewards_day';
  static const kRemoved = 'ads_removed';
  static const kSessions = 'ads_sessions';

  static const policy = AdPolicy();

  /// Ads expire after about an hour; drop a preloaded one after 55 minutes.
  static const maxAdAge = Duration(minutes: 55);

  FullScreenAd? _interstitial;
  FullScreenAd? _rewarded;
  bool _loadingInterstitial = false, _loadingRewarded = false;
  late DateTime _foregroundedAt;
  AppLifecycleListener? _lifecycle;

  KeyValueStore get _store => ref.read(settingsRepositoryProvider).store;
  DateTime _now() => ref.read(clockProvider)();
  AdsService get _service => ref.read(adsServiceProvider);

  @override
  AdsState build() {
    _foregroundedAt = _now();
    _lifecycle = AppLifecycleListener(onResume: () => _foregroundedAt = _now());
    ref.onDispose(() {
      _lifecycle?.dispose();
      _interstitial?.dispose();
      _rewarded?.dispose();
    });

    // Job counters and AD-3 preloading (load when a job starts, ready on Done).
    ref.listen(jobsProvider, (prev, next) {
      for (final e in next.entries) {
        final before = prev?[e.key]?.state;
        if (before == null) unawaited(_preloadInterstitial());
        // A batch counts as one job (ADR-040): one transition per job id.
        if (e.value.state.isCompleted && !(before?.isCompleted ?? false)) {
          _setCounters(policy.afterJobCompleted(state.counters));
        }
      }
    });

    final s = _store;
    DateTime? at(String k) => switch (s.get(k)) {
          final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
          _ => null,
        };
    int n(String k) => (s.get(k) as int?) ?? 0;
    final session = n(kSessions) + 1;
    unawaited(s.setInt(kSessions, session));
    return AdsState(
      adsRemoved: s.get(kRemoved) == true,
      sessionNumber: session,
      counters: AdCounters(
        lifetimeJobs: n(kLifetimeJobs),
        jobsSinceInterstitial: n(kJobsSince),
        lastInterstitialAt: at(kLastInterstitial),
        lastFullScreenAt: at(kLastFullScreen),
        adsFreeUntil: at(kFreeUntil),
        rewardsToday: n(kRewardsToday),
        rewardsDay: n(kRewardsDay),
      ),
    );
  }

  void _setCounters(AdCounters c) {
    state = state.copyWith(counters: c);
    final s = _store;
    Future<void> put(String k, DateTime? t) => t == null ? s.remove(k) : s.setInt(k, t.millisecondsSinceEpoch);
    unawaited(Future.wait([
      s.setInt(kLifetimeJobs, c.lifetimeJobs),
      s.setInt(kJobsSince, c.jobsSinceInterstitial),
      put(kLastInterstitial, c.lastInterstitialAt),
      put(kLastFullScreen, c.lastFullScreenAt),
      put(kFreeUntil, c.adsFreeUntil),
      s.setInt(kRewardsToday, c.rewardsToday),
      s.setInt(kRewardsDay, c.rewardsDay),
    ]));
  }

  bool get suppressed => policy.adsSuppressed(_now(), state.counters, adsRemoved: state.adsRemoved);

  /// ADS.md §5, once per process, after onboarding (Home calls it). The tour
  /// waits on [ConsentState.settled], so the consent form never stacks on it.
  Future<void> startOnce() async {
    if (state.started) return;
    state = state.copyWith(started: true);
    if (state.adsRemoved) return; // Remove ads: no SDK, no requests.
    final consent = ref.read(consentStateProvider.notifier)..beginFlow();
    try {
      final ok = await _service.start();
      final options = await _service.privacyOptionsRequired();
      state = state.copyWith(canRequestAds: ok, privacyOptionsRequired: options);
    } finally {
      consent.markSettled();
    }
  }

  Future<void> showPrivacyOptions() async {
    await _service.showPrivacyOptions();
    state = state.copyWith(canRequestAds: await _service.canRequestAds());
  }

  // ---------------------------------------------------------------- AD-3

  bool _fresh(FullScreenAd? a) => a != null && _now().difference(a.loadedAt) < maxAdAge;

  Future<void> _preloadInterstitial() async {
    if (!state.canRequestAds || suppressed || _loadingInterstitial) return;
    if (_fresh(_interstitial)) return;
    _interstitial?.dispose();
    _interstitial = null;
    _loadingInterstitial = true;
    try {
      _interstitial = await _service.loadInterstitial();
    } finally {
      _loadingInterstitial = false;
    }
  }

  /// Result → Done. Shows AD-3 first when every rule allows it, then
  /// navigates; with no ad ready it navigates at once (never waits).
  Future<void> onResultDone({required bool tourDone, required VoidCallback navigate}) async {
    final ad = _fresh(_interstitial) ? _interstitial : null;
    final now = _now();
    final allowed = policy.canShowInterstitial(
      now,
      state.counters,
      adsRemoved: state.adsRemoved,
      canRequestAds: state.canRequestAds,
      tourDone: tourDone,
      foregroundedAt: _foregroundedAt,
      jobSucceeded: true, // Done exists only on a successful Result.
      userTappedDone: true,
      loaded: ad != null,
    );
    if (!allowed) {
      navigate();
      return;
    }
    _interstitial = null;
    _setCounters(policy.afterFullScreen(now, state.counters, interstitial: true));
    await ad!.show();
    navigate();
  }

  // ---------------------------------------------------------------- AD-8

  bool get canOfferReward => policy.canOfferReward(_now(), state.counters,
      adsRemoved: state.adsRemoved, canRequestAds: state.canRequestAds, loaded: _fresh(_rewarded));

  /// Load in the background so the offer can appear once an ad is ready.
  Future<void> preloadRewarded() async {
    if (!state.canRequestAds || state.adsRemoved || _loadingRewarded || _fresh(_rewarded)) return;
    _loadingRewarded = true;
    try {
      _rewarded = await _service.loadRewarded();
    } finally {
      _loadingRewarded = false;
    }
    state = state.copyWith(rewardLoaded: _rewarded != null);
  }

  /// Plays the rewarded ad. True when the reward was earned (24 h ad-free).
  Future<bool> watchRewarded() async {
    final ad = _fresh(_rewarded) ? _rewarded : null;
    _rewarded = null;
    state = state.copyWith(rewardLoaded: false);
    if (ad == null) return false;
    final earned = await ad.show();
    if (earned) {
      _setCounters(policy.afterReward(_now(), state.counters));
      _interstitial?.dispose();
      _interstitial = null;
    }
    return earned;
  }

  // ---------------------------------------------------------------- Remove ads

  Future<void> setAdsRemoved() async {
    await _store.setBool(kRemoved, true);
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = _rewarded = null;
    state = state.copyWith(adsRemoved: true, rewardLoaded: false);
  }
}

final adsControllerProvider = NotifierProvider<AdsController, AdsState>(AdsController.new);
