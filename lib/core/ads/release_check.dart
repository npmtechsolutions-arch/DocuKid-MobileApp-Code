// Release safety for AdMob IDs. Pure Dart (no Flutter imports) so that
// `tool/check_release_ads.dart` can run it in CI. The Android Gradle build
// applies the same rules to release builds (android/app/build.gradle.kts).

enum AdsPlatform { android, ios }

/// Phase A ad units (ADS.md §3; "Ad units" sheet of docs/DocuKit_Ad_Map.xlsx).
const phaseAUnitKeys = [
  'ADMOB_NATIVE_HOME',
  'ADMOB_NATIVE_RESULT',
  'ADMOB_NATIVE_HISTORY',
  'ADMOB_NATIVE_DETAILS',
  'ADMOB_BANNER_SETTINGS',
  'ADMOB_INTERSTITIAL_DONE',
  'ADMOB_REWARDED_ADFREE',
];

/// Google's public sample/test publisher, and the example used in the Ad map.
const _samplePublishers = {'3940256099942544', '1234567890123456'};

final _appId = RegExp(r'^ca-app-pub-(\d{16})~\d{10}$');
final _unitId = RegExp(r'^ca-app-pub-(\d{16})/\d{10}$');

/// Problems that must stop a release build; empty when the IDs look real.
/// [defines] are the `--dart-define` values. The iOS App ID lives in
/// `ios/Flutter/AdMob.xcconfig`, so it's passed separately as [iosAppId].
List<String> releaseAdsProblems(Map<String, String> defines, {required AdsPlatform platform, String? iosAppId}) {
  final problems = <String>[];

  void check(String name, String? value, RegExp shape, String kind) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      problems.add('$name is missing: set your real AdMob $kind.');
      return;
    }
    final m = shape.firstMatch(v);
    if (m == null) {
      problems.add('$name is not a valid AdMob $kind ("$v").');
    } else if (_samplePublishers.contains(m.group(1))) {
      problems.add('$name is a Google sample/test ID ("$v"): use your own AdMob $kind.');
    }
  }

  if (platform == AdsPlatform.android) {
    check('ADMOB_APP_ID_ANDROID', defines['ADMOB_APP_ID_ANDROID'], _appId, 'App ID (ca-app-pub-…~…)');
  } else {
    check('GADApplicationIdentifier (ios/Flutter/AdMob.xcconfig)', iosAppId, _appId, 'App ID (ca-app-pub-…~…)');
  }
  for (final k in phaseAUnitKeys) {
    if (k == 'ADMOB_BANNER_SETTINGS' && isBannerOff(defines[k])) continue;
    check(
      k,
      defines[k],
      _unitId,
      k == 'ADMOB_BANNER_SETTINGS' ? 'ad unit ID (ca-app-pub-…/…), or "off" to hide the Settings banner' : 'ad unit ID (ca-app-pub-…/…)',
    );
  }
  return problems;
}

/// ADMOB_BANNER_SETTINGS=off switches the Settings banner (AD-5) off for good:
/// the slot is never built and the release check accepts it.
bool isBannerOff(String? value) => value?.trim().toLowerCase() == 'off';
