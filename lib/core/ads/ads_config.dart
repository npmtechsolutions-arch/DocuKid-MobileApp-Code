import 'dart:io';

import 'package:flutter/foundation.dart';

/// ADS.md §3 phases. Phase B (AD-7 app open, AD-9 second Home card, AD-4
/// every 8 rows) ships later as an app update by changing this constant.
enum AdsPhase { a, b }

const adsPhase = AdsPhase.a;

/// AD-4: in-feed card after the 3rd row, then every [historyAdInterval] rows.
const historyAdInterval = adsPhase == AdsPhase.a ? 12 : 8;

/// One entry per AdMob unit ("Ad units" sheet of docs/DocuKit_Ad_Map.xlsx).
enum AdUnit {
  nativeHome('ADMOB_NATIVE_HOME', _native),
  nativeResult('ADMOB_NATIVE_RESULT', _native),
  nativeHistory('ADMOB_NATIVE_HISTORY', _native),
  nativeDetails('ADMOB_NATIVE_DETAILS', _native),
  bannerSettings('ADMOB_BANNER_SETTINGS', ('ca-app-pub-3940256099942544/9214589741', 'ca-app-pub-3940256099942544/2435281174')),
  interstitialDone('ADMOB_INTERSTITIAL_DONE', ('ca-app-pub-3940256099942544/1033173712', 'ca-app-pub-3940256099942544/4411468910')),
  rewardedAdFree('ADMOB_REWARDED_ADFREE', ('ca-app-pub-3940256099942544/5224354917', 'ca-app-pub-3940256099942544/1712485313'));

  const AdUnit(this.defineKey, this.testIds);

  /// `--dart-define` key carrying the real unit ID for the platform being built.
  final String defineKey;

  /// Google's public test IDs (Android, iOS).
  final (String, String) testIds;
}

const _native = ('ca-app-pub-3940256099942544/2247696110', 'ca-app-pub-3940256099942544/3986624511');

// `String.fromEnvironment` must be called with a constant key, so each define
// is read here once.
const _defined = {
  AdUnit.nativeHome: String.fromEnvironment('ADMOB_NATIVE_HOME'),
  AdUnit.nativeResult: String.fromEnvironment('ADMOB_NATIVE_RESULT'),
  AdUnit.nativeHistory: String.fromEnvironment('ADMOB_NATIVE_HISTORY'),
  AdUnit.nativeDetails: String.fromEnvironment('ADMOB_NATIVE_DETAILS'),
  AdUnit.bannerSettings: String.fromEnvironment('ADMOB_BANNER_SETTINGS'),
  AdUnit.interstitialDone: String.fromEnvironment('ADMOB_INTERSTITIAL_DONE'),
  AdUnit.rewardedAdFree: String.fromEnvironment('ADMOB_REWARDED_ADFREE'),
};

abstract final class AdUnits {
  /// Unit ID for this build, or null when the slot must not exist.
  static String? of(AdUnit unit) =>
      resolve(unit, android: Platform.isAndroid, debug: !kReleaseMode, defined: _defined[unit] ?? '');

  /// Debug/profile builds always use Google's test IDs. Release builds use
  /// only the dart-define value and never fall back to a test ID: an empty key
  /// means no ad. (A release build without real IDs is refused at build time:
  /// release_check.dart / build.gradle.kts.)
  @visibleForTesting
  static String? resolve(AdUnit unit, {required bool android, required bool debug, required String defined}) {
    if (debug) return android ? unit.testIds.$1 : unit.testIds.$2;
    return defined.isEmpty ? null : defined;
  }
}
