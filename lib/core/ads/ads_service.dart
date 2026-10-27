import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_config.dart';
import 'google_ads_service.dart';

/// Native template sizes (ADS.md §3): small ≈ 90–120 dp, medium ≈ 300 dp.
enum NativeSize {
  small(112),
  medium(320);

  const NativeSize(this.height);
  final double height;
}

/// Theme colours handed to the native template, so ads follow light/dark.
class NativeLook {
  const NativeLook({
    required this.background,
    required this.text,
    required this.subtleText,
    required this.cta,
    required this.onCta,
    required this.radius,
  });
  final Color background, text, subtleText, cta, onCta;
  final double radius;
}

/// A loaded inline ad (native or banner), ready to place in the tree.
abstract interface class LoadedAd {
  Widget get widget;
  double get height;
  void dispose();
}

/// A loaded full-screen ad (interstitial or rewarded).
abstract interface class FullScreenAd {
  DateTime get loadedAt;

  /// Shows the ad; completes when it is dismissed or fails to show.
  /// Returns true only if the user earned the reward (rewarded ads).
  Future<bool> show();
  void dispose();
}

/// Everything that talks to the ads SDK sits behind this interface
/// (ARCHITECTURE "every plugin behind an interface"; ADS.md §7). Requests
/// never carry app data: no keywords, content URLs or custom targeting.
abstract interface class AdsService {
  /// UMP consent flow (§5) then SDK init. Returns `canRequestAds`; never throws.
  Future<bool> start();

  /// Settings → "Privacy & ad choices" is shown only when this is true.
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
  Future<bool> canRequestAds();

  /// Null when there is no ad, no network, or the unit isn't configured.
  Future<LoadedAd?> loadNative(AdUnit unit, NativeSize size, NativeLook look);
  Future<LoadedAd?> loadBanner(AdUnit unit, int width);
  Future<FullScreenAd?> loadInterstitial();
  Future<FullScreenAd?> loadRewarded();
}

/// No SDK at all: every slot collapses. Used by tests by default.
class NoAdsService implements AdsService {
  const NoAdsService();
  @override
  Future<bool> start() async => false;
  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Future<bool> canRequestAds() async => false;
  @override
  Future<LoadedAd?> loadNative(AdUnit unit, NativeSize size, NativeLook look) async => null;
  @override
  Future<LoadedAd?> loadBanner(AdUnit unit, int width) async => null;
  @override
  Future<FullScreenAd?> loadInterstitial() async => null;
  @override
  Future<FullScreenAd?> loadRewarded() async => null;
}

final adsServiceProvider = Provider<AdsService>((ref) => GoogleAdsService());
