// Release safety: a release build must carry real AdMob IDs (written before the fix).
import 'package:docukit/core/ads/google_ads_service.dart';
import 'package:docukit/core/ads/release_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  const pub = '1234509876123450';
  final good = {
    'ADMOB_APP_ID_ANDROID': 'ca-app-pub-$pub~1111111111',
    'ADMOB_NATIVE_HOME': 'ca-app-pub-$pub/2000000001',
    'ADMOB_NATIVE_RESULT': 'ca-app-pub-$pub/2000000002',
    'ADMOB_NATIVE_HISTORY': 'ca-app-pub-$pub/2000000003',
    'ADMOB_NATIVE_DETAILS': 'ca-app-pub-$pub/2000000004',
    'ADMOB_BANNER_SETTINGS': 'ca-app-pub-$pub/2000000005',
    'ADMOB_INTERSTITIAL_DONE': 'ca-app-pub-$pub/2000000006',
    'ADMOB_REWARDED_ADFREE': 'ca-app-pub-$pub/2000000007',
    'ADMOB_BANNER_MAIN': 'ca-app-pub-$pub/2000000008',
    'ADMOB_BANNER_TOOLS': 'ca-app-pub-$pub/2000000009',
    'ADMOB_BANNER_INFO': 'ca-app-pub-$pub/2000000010',
  };

  group('releaseAdsProblems', () {
    test('real-looking IDs for every Phase A key pass', () {
      expect(releaseAdsProblems(good, platform: AdsPlatform.android), isEmpty);
      expect(releaseAdsProblems({...good}..remove('ADMOB_APP_ID_ANDROID'), platform: AdsPlatform.ios, iosAppId: 'ca-app-pub-$pub~3333333333'),
          isEmpty);
    });

    test('a missing App ID or unit ID fails, naming the key', () {
      final noApp = releaseAdsProblems({...good}..remove('ADMOB_APP_ID_ANDROID'), platform: AdsPlatform.android);
      expect(noApp.single, contains('ADMOB_APP_ID_ANDROID'));
      expect(noApp.single, contains('missing'));
      for (final k in phaseAUnitKeys) {
        final p = releaseAdsProblems({...good}..remove(k), platform: AdsPlatform.android);
        expect(p, hasLength(1), reason: k);
        expect(p.single, contains(k));
      }
      expect(releaseAdsProblems(good, platform: AdsPlatform.ios).single, contains('GADApplicationIdentifier'));
    });

    test("Google's sample/test IDs and the example IDs fail", () {
      final test = {...good, 'ADMOB_NATIVE_HOME': 'ca-app-pub-3940256099942544/2247696110'};
      expect(releaseAdsProblems(test, platform: AdsPlatform.android).single, contains('test'));
      final testApp = {...good, 'ADMOB_APP_ID_ANDROID': 'ca-app-pub-3940256099942544~3347511713'};
      expect(releaseAdsProblems(testApp, platform: AdsPlatform.android).single, contains('ADMOB_APP_ID_ANDROID'));
      final example = {...good, 'ADMOB_REWARDED_ADFREE': 'ca-app-pub-1234567890123456/1111111111'};
      expect(releaseAdsProblems(example, platform: AdsPlatform.android), hasLength(1));
      expect(
        releaseAdsProblems(good, platform: AdsPlatform.ios, iosAppId: 'ca-app-pub-3940256099942544~1458002511').single,
        contains('GADApplicationIdentifier'),
      );
    });

    test('malformed IDs fail (unit vs app separator, wrong prefix)', () {
      expect(releaseAdsProblems({...good, 'ADMOB_NATIVE_HOME': 'ca-app-pub-$pub~2000000001'}, platform: AdsPlatform.android),
          hasLength(1));
      expect(releaseAdsProblems({...good, 'ADMOB_APP_ID_ANDROID': 'ca-app-pub-$pub/1111111111'}, platform: AdsPlatform.android),
          hasLength(1));
      expect(releaseAdsProblems({...good, 'ADMOB_INTERSTITIAL_DONE': 'TODO'}, platform: AdsPlatform.android), hasLength(1));
    });
  });

  group('ADMOB_BANNER_SETTINGS=off', () {
    test('the release check accepts "off" for the Settings banner', () {
      expect(releaseAdsProblems({...good, 'ADMOB_BANNER_SETTINGS': 'off'}, platform: AdsPlatform.android), isEmpty);
      expect(releaseAdsProblems({...good, 'ADMOB_BANNER_SETTINGS': ' OFF '}, platform: AdsPlatform.android), isEmpty);
    });

    test('"off" is only accepted for the banner', () {
      final p = releaseAdsProblems({...good, 'ADMOB_NATIVE_HOME': 'off'}, platform: AdsPlatform.android);
      expect(p.single, contains('ADMOB_NATIVE_HOME'));
    });

    test('empty is still refused (switching the banner off must be explicit)', () {
      final p = releaseAdsProblems({...good, 'ADMOB_BANNER_SETTINGS': ''}, platform: AdsPlatform.android);
      expect(p.single, contains('ADMOB_BANNER_SETTINGS'));
      expect(p.single, contains('off'));
    });

    test('isBannerOff', () {
      expect(isBannerOff('off'), isTrue);
      expect(isBannerOff(' Off '), isTrue);
      expect(isBannerOff(''), isFalse);
      expect(isBannerOff('ca-app-pub-$pub/2000000005'), isFalse);
    });
  });

  group('ADR-035 bottom banner keys', () {
    const keys = ['ADMOB_BANNER_MAIN', 'ADMOB_BANNER_TOOLS', 'ADMOB_BANNER_INFO'];

    test('each is required: missing, malformed or a test ID is refused', () {
      for (final k in keys) {
        expect(releaseAdsProblems({...good}..remove(k), platform: AdsPlatform.android).single, contains(k), reason: k);
        expect(releaseAdsProblems({...good, k: 'TODO'}, platform: AdsPlatform.android).single, contains(k));
        expect(releaseAdsProblems({...good, k: 'ca-app-pub-3940256099942544/9214589741'}, platform: AdsPlatform.android).single,
            contains('sample/test'));
      }
    });

    test('each accepts "off" (and empty is still refused)', () {
      for (final k in keys) {
        expect(releaseAdsProblems({...good, k: 'off'}, platform: AdsPlatform.android), isEmpty, reason: k);
        expect(releaseAdsProblems({...good, k: ''}, platform: AdsPlatform.android).single, contains('"off"'));
      }
      expect(releaseAdsProblems({...good, for (final k in keys) k: 'off', 'ADMOB_BANNER_SETTINGS': 'off'}, platform: AdsPlatform.ios,
          iosAppId: 'ca-app-pub-$pub~3333333333'), isEmpty);
    });

    test('"off" is still refused for non-banner units', () {
      for (final k in ['ADMOB_NATIVE_RESULT', 'ADMOB_INTERSTITIAL_DONE', 'ADMOB_REWARDED_ADFREE']) {
        expect(releaseAdsProblems({...good, k: 'off'}, platform: AdsPlatform.android), hasLength(1), reason: k);
      }
    });
  });

  group('iOS App ID (Release xcconfig chain)', () {
    const base = '// sample\nADMOB_APP_ID_IOS = ca-app-pub-3940256099942544~1458002511\n';
    test('the untracked local override wins, like in Release.xcconfig', () {
      expect(iosReleaseAppId(base: base, local: 'ADMOB_APP_ID_IOS = ca-app-pub-$pub~3333333333'), 'ca-app-pub-$pub~3333333333');
    });

    test('without the local file, the tracked sample ID is used (and then refused)', () {
      final id = iosReleaseAppId(base: base, local: null);
      expect(id, 'ca-app-pub-3940256099942544~1458002511');
      expect(releaseAdsProblems(good, platform: AdsPlatform.ios, iosAppId: id).single, contains('sample/test'));
    });

    test('comments are ignored', () {
      expect(iosReleaseAppId(base: base, local: '// ADMOB_APP_ID_IOS = x\n'), 'ca-app-pub-3940256099942544~1458002511');
    });
  });

  group('ADMOB_DEBUG_EEA', () {
    test('has no effect in release builds', () {
      expect(debugConsentSettings(release: true, eea: true, device: 'ABC'), isNull);
    });

    test('debug: EEA geography + the test device; off without the flag', () {
      final s = debugConsentSettings(release: false, eea: true, device: 'ABC')!;
      expect(s.debugGeography, DebugGeography.debugGeographyEea);
      expect(s.testIdentifiers, ['ABC']);
      expect(debugConsentSettings(release: false, eea: false, device: 'ABC'), isNull);
    });
  });
}
