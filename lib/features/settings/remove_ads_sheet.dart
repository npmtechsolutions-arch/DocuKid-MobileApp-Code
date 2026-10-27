import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ads_controller.dart';
import '../../core/ads/remove_ads.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../l10n/gen/app_localizations.dart';

/// ADS.md §6: Remove ads (one-time purchase), Restore, and below a divider the
/// free 24 h pass (AD-8) — shown only when a rewarded ad is actually loaded.
Future<void> showRemoveAdsSheet(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RemoveAdsSheet(messenger: messenger),
  );
}

/// Plays the rewarded ad and reports the outcome (sheet and the Result link).
/// Takes the container, not a `ref`, because the caller may be gone by the end.
Future<void> watchRewardedAd(ProviderContainer c, ScaffoldMessengerState messenger, AppLocalizations l) async {
  final earned = await c.read(adsControllerProvider.notifier).watchRewarded();
  final until = c.read(adsControllerProvider).counters.adsFreeUntil;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(earned && until != null ? l.rewGranted(DateFormat.jm(l.localeName).format(until)) : l.rewNotEarned),
    ));
}

class _RemoveAdsSheet extends ConsumerStatefulWidget {
  const _RemoveAdsSheet({required this.messenger});
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_RemoveAdsSheet> createState() => _RemoveAdsSheetState();
}

class _RemoveAdsSheetState extends ConsumerState<_RemoveAdsSheet> {
  @override
  void initState() {
    super.initState();
    ref.read(removeAdsProvider.notifier).loadPrice();
    ref.read(adsControllerProvider.notifier).preloadRewarded();
  }

  void _snack(String text) => widget.messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rem = ref.watch(removeAdsProvider);
    final ads = ref.watch(adsControllerProvider);
    final ctrl = ref.read(adsControllerProvider.notifier);
    ref.listen(removeAdsProvider.select((s) => s.last), (_, o) {
      if (o == PurchaseOutcome.purchased || o == PurchaseOutcome.restored) {
        _snack(l.remThanks);
        if (mounted) Navigator.of(context).pop();
      } else if (o == PurchaseOutcome.failed) {
        _snack(l.remFailed);
      }
    });

    final now = ref.read(clockProvider)();
    final rewardsLeft = AdsController.policy.rewardsToday(now, ads.counters) < 2;
    final freeUntil = ads.counters.adsFreeUntil;

    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x1),
          child: Row(children: [
            Icon(icon, size: 20, color: context.docu.success),
            const SizedBox(width: Space.x3),
            Expanded(child: Text(text, style: context.text.bodyMedium)),
          ]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Semantics(header: true, child: Text(l.remTitle, style: context.text.titleLarge)),
        const SizedBox(height: Space.x2),
        Text(l.remBody, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: Space.x4),
        point(Icons.block_rounded, l.remPoint1),
        point(Icons.devices_rounded, l.remPoint2),
        point(Icons.lock_rounded, l.remPoint3),
        const SizedBox(height: Space.x5),
        if (ads.adsRemoved)
          InlineBanner(kind: BannerKind.success, text: l.remOwned)
        else ...[
          if (rem.loading)
            const Center(child: Padding(padding: EdgeInsets.all(Space.x3), child: CircularProgressIndicator.adaptive()))
          else if (rem.price == null)
            InlineBanner(kind: BannerKind.info, text: l.remUnavailable)
          else
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: rem.busy ? null : () => ref.read(removeAdsProvider.notifier).buy(),
              child: Text(l.remBuy(rem.price!)),
            ),
          const SizedBox(height: Space.x2),
          TextButton(
            onPressed: rem.busy ? null : () => ref.read(removeAdsProvider.notifier).restore(),
            child: Text(l.remRestore),
          ),
          if (freeUntil != null && freeUntil.isAfter(now)) ...[
            const SizedBox(height: Space.x2),
            Text(l.adsFreeUntil(DateFormat.jm(l.localeName).format(freeUntil)),
                textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
          // AD-8: never a button that leads to "no ad available".
          if (ads.rewardLoaded || !rewardsLeft) ...[
            const SizedBox(height: Space.x3),
            const Divider(),
            const SizedBox(height: Space.x3),
            if (ctrl.canOfferReward)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: Text(l.rewOffer, textAlign: TextAlign.center),
                onPressed: () {
                  final container = ProviderScope.containerOf(context);
                  Navigator.of(context).pop();
                  watchRewardedAd(container, widget.messenger, l);
                },
              )
            else if (!rewardsLeft)
              Text(l.rewLimit, textAlign: TextAlign.center, style: context.text.bodySmall),
          ],
        ],
      ]),
    );
  }
}
