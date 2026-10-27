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
