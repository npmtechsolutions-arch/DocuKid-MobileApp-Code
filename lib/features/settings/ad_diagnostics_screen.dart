import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ad_diagnostics.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/ads_controller.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';

/// Hidden screen (Settings → tap the version 7 times): every ad slot with its
/// last load result, whether consent allows ads, and test vs real IDs. Shows
/// only SDK result codes/messages: no personal, file or app data, no IDs.
class AdDiagnosticsScreen extends ConsumerWidget {
  const AdDiagnosticsScreen({super.key});

  static String placement(AppLocalizations l, AdUnit u) => switch (u) {
        AdUnit.nativeHome => l.diagPlaceNativeHome,
        AdUnit.nativeResult => l.diagPlaceNativeResult,
        AdUnit.nativeHistory => l.diagPlaceNativeHistory,
        AdUnit.nativeDetails => l.diagPlaceNativeDetails,
        AdUnit.bannerSettings => l.diagPlaceBannerSettings,
        AdUnit.bannerMain => l.diagPlaceBannerMain,
        AdUnit.bannerTools => l.diagPlaceBannerTools,
        AdUnit.bannerInfo => l.diagPlaceBannerInfo,
        AdUnit.interstitialDone => l.diagPlaceInterstitial,
        AdUnit.rewardedAdFree => l.diagPlaceRewarded,
      };

  static String idKind(AppLocalizations l, UnitIdKind k) => switch (k) {
        UnitIdKind.test => l.diagUnitTest,
        UnitIdKind.real => l.diagUnitReal,
        UnitIdKind.off => l.diagUnitOff,
        UnitIdKind.missing => l.diagUnitMissing,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ads = ref.watch(adsControllerProvider);
    final time = DateFormat.jms(l.localeName);
    final now = ref.read(clockProvider)();
    final freeUntil = ads.counters.adsFreeUntil;
    String yesNo(bool b) => b ? l.diagYes : l.diagNo;

    String result(AdLoadResult? r) => switch (r) {
          null => l.diagNotRequested,
          AdLoadResult(outcome: AdOutcome.loaded) => l.diagLoaded(time.format(r.at)),
          AdLoadResult(outcome: AdOutcome.noFill) => l.diagNoFill(time.format(r.at), r.code ?? 0),
          AdLoadResult(outcome: AdOutcome.error, code: final c?) => l.diagError(time.format(r.at), c, r.message ?? ''),
          AdLoadResult(outcome: AdOutcome.error) => l.diagErrorNoCode(time.format(r.at), r.message ?? ''),
        };

    Color resultColor(AdLoadResult? r) => switch (r?.outcome) {
          AdOutcome.loaded => context.docu.success,
          AdOutcome.noFill => context.docu.warning,
          AdOutcome.error => context.colors.error,
          null => context.colors.onSurfaceVariant,
        };

    return Scaffold(
      appBar: AppBar(title: Text(l.diagTitle)),
      body: ValueListenableBuilder<Map<AdUnit, AdLoadResult>>(
        valueListenable: AdDiagnostics.instance.results,
        builder: (context, results, _) => ListView(
          padding: const EdgeInsets.only(bottom: Space.x8),
          children: [
            ContentWidth(child: SectionHeader(l.diagSectionStatus)),
            ContentWidth(
              child: Card(
                child: Column(children: [
                  ListTile(title: Text(l.diagConsent(yesNo(ads.canRequestAds)))),
                  ListTile(title: Text(l.diagAdsRemoved(yesNo(ads.adsRemoved)))),
                  ListTile(
                    title: Text(freeUntil != null && freeUntil.isAfter(now)
                        ? l.diagAdFreeUntil(DateFormat.jm(l.localeName).format(freeUntil))
                        : l.diagAdFreeNone),
                  ),
                  ListTile(title: Text(l.diagBuildIds(kReleaseMode ? l.diagIdsReal : l.diagIdsTest))),
                ]),
              ),
            ),
            ContentWidth(child: SectionHeader(l.diagSectionSlots)),
            for (final u in AdUnit.values)
              ContentWidth(
                child: Card(
                  child: ListTile(
                    title: Text(u.defineKey, style: context.text.titleSmall),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(placement(l, u)),
                      Text(idKind(l, AdUnits.kind(u))),
                      Text(result(results[u]), style: TextStyle(color: resultColor(results[u]))),
                    ]),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
