import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../logging/log.dart';
import 'ads_config.dart';
import 'ads_service.dart';

/// [AdsService] on google_mobile_ads 9.2.0. The only file (with the rest of
/// `lib/core/ads/`) allowed to import the SDK; CI greps for it.
class GoogleAdsService implements AdsService {
  bool _initialized = false;

  /// No app data in requests (ADS.md §7): an empty request.
  static const _request = AdRequest();

  /// Never wait on the network for long; a slow ad is a missing ad.
  static const _loadTimeout = Duration(seconds: 30);
  static const _consentTimeout = Duration(seconds: 8);

  /// Debug builds only (ADS.md §5, regression R25): test the EEA consent form
  /// from anywhere with
  /// `--dart-define=ADMOB_DEBUG_EEA=true --dart-define=ADMOB_TEST_DEVICE=<hashed id>`
  /// (the hashed id is printed by the UMP SDK in logcat / the Xcode console).
  static ConsentDebugSettings? _debugConsent() => debugConsentSettings(
        release: kReleaseMode,
        eea: const bool.fromEnvironment('ADMOB_DEBUG_EEA'),
        device: const String.fromEnvironment('ADMOB_TEST_DEVICE'),
      );

  @override
  Future<bool> start() async {
    try {
      final info = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(consentDebugSettings: _debugConsent()),
        () => info.complete(),
        (e) {
          Log.event('consent_update_failed', '${e.errorCode}');
          info.completeError(e);
        },
      );
      // A slow network must not hold up first run: the tour waits for consent
      // to settle, so give up on the form for this session after 8 s.
      await info.future.timeout(_consentTimeout);
      await ConsentForm.loadAndShowConsentFormIfRequired((e) {
        if (e != null) Log.event('consent_form_failed', '${e.errorCode}');
      });
    } catch (_) {
      // Offline or misconfigured: fall through. canRequestAds() still reflects
      // consent cached from an earlier session.
    }
    return _initIfAllowed();
  }

  Future<bool> _initIfAllowed() async {
    try {
      final ok = await ConsentInformation.instance.canRequestAds();
      if (ok && !_initialized) {
        _initialized = true;
        await MobileAds.instance.initialize();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canRequestAds() => _initIfAllowed();

  @override
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((e) {
      if (e != null) Log.event('privacy_form_failed', '${e.errorCode}');
      done.complete();
    });
    await done.future;
  }

  @override
  Future<LoadedAd?> loadNative(AdUnit unit, NativeSize size, NativeLook look) {
    final id = AdUnits.of(unit);
    if (id == null || !_initialized) return Future.value();
    final result = Completer<LoadedAd?>();
    NativeTemplateTextStyle text(Color c) => NativeTemplateTextStyle(textColor: c, style: NativeTemplateFontStyle.normal);
    late final NativeAd ad;
    ad = NativeAd(
      adUnitId: id,
      request: _request,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: size == NativeSize.small ? TemplateType.small : TemplateType.medium,
        mainBackgroundColor: look.background,
        cornerRadius: look.radius,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: look.onCta,
          backgroundColor: look.cta,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(textColor: look.text, style: NativeTemplateFontStyle.bold),
        secondaryTextStyle: text(look.subtleText),
        tertiaryTextStyle: text(look.subtleText),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!result.isCompleted) result.complete(_Inline(AdWidget(ad: ad), size.height, ad.dispose));
        },
        onAdFailedToLoad: (a, e) {
          Log.event('ad_load_failed', '${e.code}');
          a.dispose();
          if (!result.isCompleted) result.complete(null);
        },
      ),
    );
    unawaited(ad.load());
    return result.future.timeout(_loadTimeout, onTimeout: () {
      unawaited(ad.dispose());
      return null;
    });
  }

  @override
  Future<LoadedAd?> loadBanner(AdUnit unit, int width) async {
    final id = AdUnits.of(unit);
    if (id == null || !_initialized) return null;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return null;
    final result = Completer<LoadedAd?>();
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: id,
      size: size,
      request: _request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!result.isCompleted) result.complete(_Inline(AdWidget(ad: ad), size.height.toDouble(), ad.dispose));
        },
        onAdFailedToLoad: (a, e) {
          Log.event('ad_load_failed', '${e.code}');
          a.dispose();
          if (!result.isCompleted) result.complete(null);
        },
      ),
    );
    unawaited(ad.load());
    return result.future.timeout(_loadTimeout, onTimeout: () {
      unawaited(ad.dispose());
      return null;
    });
  }

  @override
  Future<FullScreenAd?> loadInterstitial() {
    final id = AdUnits.of(AdUnit.interstitialDone);
    if (id == null || !_initialized) return Future.value();
    final result = Completer<FullScreenAd?>();
    InterstitialAd.load(
      adUnitId: id,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => result.complete(_Interstitial(ad)),
        onAdFailedToLoad: (e) {
          Log.event('ad_load_failed', '${e.code}');
          result.complete(null);
        },
      ),
    );
    return result.future.timeout(_loadTimeout, onTimeout: () => null);
  }

  @override
  Future<FullScreenAd?> loadRewarded() {
    final id = AdUnits.of(AdUnit.rewardedAdFree);
    if (id == null || !_initialized) return Future.value();
    final result = Completer<FullScreenAd?>();
    RewardedAd.load(
      adUnitId: id,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => result.complete(_Rewarded(ad)),
        onAdFailedToLoad: (e) {
          Log.event('ad_load_failed', '${e.code}');
          result.complete(null);
        },
      ),
    );
    return result.future.timeout(_loadTimeout, onTimeout: () => null);
  }
}

class _Inline implements LoadedAd {
  _Inline(this.widget, this.height, this._dispose);
  @override
  final Widget widget;
  @override
  final double height;
  final Future<void> Function() _dispose;
  @override
  void dispose() => unawaited(_dispose());
}

class _Interstitial implements FullScreenAd {
  _Interstitial(this._ad);
  final InterstitialAd _ad;
  @override
  final DateTime loadedAt = DateTime.now();

  @override
  Future<bool> show() {
    final done = Completer<bool>();
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        Log.event('ad_show_failed', '${e.code}');
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    unawaited(_ad.show());
    return done.future;
  }

  @override
  void dispose() => unawaited(_ad.dispose());
}

class _Rewarded implements FullScreenAd {
  _Rewarded(this._ad);
  final RewardedAd _ad;
  @override
  final DateTime loadedAt = DateTime.now();

  @override
  Future<bool> show() {
    final done = Completer<bool>();
    var earned = false;
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        Log.event('ad_show_failed', '${e.code}');
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    // §4.3: the reward is granted only here, never when the ad closes early.
    unawaited(_ad.show(onUserEarnedReward: (_, _) => earned = true));
    return done.future;
  }

  @override
  void dispose() => unawaited(_ad.dispose());
}

/// The request every ad uses, exposed so a test can assert it is empty.
@visibleForTesting
const adRequestForTest = GoogleAdsService._request;

/// The EEA debug geography, or null. Always null in release builds, whatever
/// ADMOB_DEBUG_EEA says.
@visibleForTesting
ConsentDebugSettings? debugConsentSettings({required bool release, required bool eea, required String device}) {
  if (release || !eea) return null;
  return ConsentDebugSettings(
    debugGeography: DebugGeography.debugGeographyEea,
    testIdentifiers: [if (device.isNotEmpty) device],
  );
}
