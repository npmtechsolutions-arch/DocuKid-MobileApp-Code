import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../features/tour/tour_controller.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'ads_config.dart';
import 'ads_controller.dart';
import 'ads_service.dart';

/// Loads one native ad per screen visit and renders it inside [frame]. Until
/// an ad has loaded — or with no network, no consent, Remove ads, the reward
/// window, or the tour running — it is a zero-size box (ADS.md §1, §4.4).
class NativeAdSlot extends ConsumerStatefulWidget {
  const NativeAdSlot({
    super.key,
    required this.unit,
    required this.size,
    required this.frame,
    this.hideOnFirstLaunch = false,
    this.revealAfter = Duration.zero,
  });

  final AdUnit unit;
  final NativeSize size;
  final Widget Function(BuildContext context, Widget ad) frame;

  /// AD-1 only: never on the very first launch.
  final bool hideOnFirstLaunch;

  /// AD-2: wait before showing so a tap meant for the success screen can't land on it.
  final Duration revealAfter;

  @override
  ConsumerState<NativeAdSlot> createState() => _NativeAdSlotState();
}

class _NativeAdSlotState extends ConsumerState<NativeAdSlot> {
  LoadedAd? _ad;
  bool _requested = false, _revealed = false;
  Timer? _reveal;

  @override
  void initState() {
    super.initState();
    if (widget.revealAfter == Duration.zero) {
      _revealed = true;
    } else {
      _reveal = Timer(widget.revealAfter, () {
        if (mounted) setState(() => _revealed = true);
      });
    }
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _requested = true;
    final c = context.colors;
    final look = NativeLook(
      background: c.surfaceContainerLow,
      text: c.onSurface,
      subtleText: c.onSurfaceVariant,
      cta: c.primary,
      onCta: c.onPrimary,
      radius: Radii.md,
    );
    LoadedAd? ad;
    try {
      ad = await ref.read(adsServiceProvider).loadNative(widget.unit, widget.size, look);
    } catch (_) {
      ad = null; // a failed load is just a missing ad
    }
    if (!mounted) {
      ad?.dispose();
      return;
    }
    setState(() => _ad = ad);
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adsControllerProvider);
    final tourActive = ref.watch(tourControllerProvider.select((t) => t.active));
    final visible = AdsController.policy.canShowNative(
      ref.read(clockProvider)(),
      ads.counters,
      adsRemoved: ads.adsRemoved,
      canRequestAds: ads.canRequestAds,
      tourActive: tourActive,
      sessionNumber: widget.hideOnFirstLaunch ? ads.sessionNumber : 2,
    );
    if (!visible) return const SizedBox.shrink();
    if (!_requested) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _load() : null);
    final ad = _ad;
    if (ad == null || !_revealed) return const SizedBox.shrink();
    return widget.frame(context, SizedBox(height: ad.height, child: ad.widget));
  }
}

/// Small "Ad" badge: an ad card must never look like a tool (UI-REF-05).
class AdBadge extends StatelessWidget {
  const AdBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(color: context.colors.outline),
      ),
      child: Text(context.l10n.adBadge, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
    );
  }
}

/// AD-1 / AD-4 frame: outlined, muted, "Ad" badge, no gradient tile.
Widget adCardFrame(BuildContext context, Widget ad) => Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      padding: const EdgeInsets.all(Space.x2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdBadge(),
        const SizedBox(height: Space.x1),
        ad,
      ]),
    );

/// AD-2 / AD-6 frame: ≥ 32 dp gap, divider and a "Sponsored" label.
Widget sponsoredFrame(BuildContext context, Widget ad, {VoidCallback? onRemoveAds, Widget? footer}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.x8),
        const Divider(height: 1),
        Row(children: [
          Expanded(
            child: Text(context.l10n.adSponsored,
                style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          if (onRemoveAds != null) TextButton(onPressed: onRemoveAds, child: Text(context.l10n.setRemoveAds)),
        ]),
        ad,
        ?footer,
      ],
    );

/// AD-1: Home, between the PDF grid and Recent (24 dp above and below).
class HomeAdSlot extends StatelessWidget {
  const HomeAdSlot({super.key});

  @override
  Widget build(BuildContext context) => NativeAdSlot(
        unit: AdUnit.nativeHome,
        size: NativeSize.small,
        hideOnFirstLaunch: true,
        frame: (context, ad) => Padding(padding: const EdgeInsets.only(top: Space.x6), child: adCardFrame(context, ad)),
      );
}

/// AD-4: Recent activity, in-feed.
class HistoryAdCard extends StatelessWidget {
  const HistoryAdCard({super.key});

  @override
  Widget build(BuildContext context) => NativeAdSlot(
        unit: AdUnit.nativeHistory,
        size: NativeSize.small,
        frame: (context, ad) => Padding(padding: const EdgeInsets.symmetric(vertical: Space.x2), child: adCardFrame(context, ad)),
      );
}

/// AD-2: Result, below the retention note, revealed after 600 ms. Offers the
/// Remove-ads sheet and, when a rewarded ad is ready, the 24 h pass (AD-8).
class ResultAdSlot extends ConsumerWidget {
  const ResultAdSlot({super.key, required this.onRemoveAds, required this.onWatchReward});
  final VoidCallback onRemoveAds;
  final VoidCallback onWatchReward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adsControllerProvider);
    final offer = ref.read(adsControllerProvider.notifier).canOfferReward;
    return NativeAdSlot(
      unit: AdUnit.nativeResult,
      size: NativeSize.medium,
      revealAfter: const Duration(milliseconds: 600),
      frame: (context, ad) => sponsoredFrame(
        context,
        ad,
        onRemoveAds: onRemoveAds,
        footer: offer
            ? Align(child: TextButton(onPressed: onWatchReward, child: Text(context.l10n.rewOfferShort)))
            : null,
      ),
    );
  }
}

/// AD-6: Operation details, below [content]'s last button — built only when
/// [content] is taller than the ad, measured after layout.
class DetailsAdBelow extends StatefulWidget {
  const DetailsAdBelow({super.key, required this.content, required this.enabled});
  final Widget content;
  final bool enabled;

  @override
  State<DetailsAdBelow> createState() => _DetailsAdBelowState();
}

class _DetailsAdBelowState extends State<DetailsAdBelow> {
  final _key = GlobalKey();
  bool _tall = false;

  void _measure() {
    final h = _key.currentContext?.size?.height ?? 0;
    final tall = h > NativeSize.medium.height;
    if (mounted && tall != _tall) setState(() => _tall = tall);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enabled) WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KeyedSubtree(key: _key, child: widget.content),
      if (widget.enabled && _tall)
        NativeAdSlot(unit: AdUnit.nativeDetails, size: NativeSize.medium, frame: (context, ad) => sponsoredFrame(context, ad)),
    ]);
  }
}

/// AD-5: anchored adaptive banner in its own reserved space at the bottom of
/// Settings (outside the scroll view). Zero height until loaded.
class BannerAdSlot extends ConsumerStatefulWidget {
  const BannerAdSlot({super.key});

  @override
  ConsumerState<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends ConsumerState<BannerAdSlot> {
  LoadedAd? _ad;
  int? _width;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load(int width) async {
    _width = width;
    LoadedAd? ad;
    try {
      ad = await ref.read(adsServiceProvider).loadBanner(AdUnit.bannerSettings, width);
    } catch (_) {
      ad = null;
    }
    if (!mounted) {
      ad?.dispose();
      return;
    }
    final old = _ad;
    setState(() => _ad = ad);
    old?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adsControllerProvider);
    final suppressed = AdsController.policy.adsSuppressed(ref.read(clockProvider)(), ads.counters, adsRemoved: ads.adsRemoved);
    if (!ads.canRequestAds || suppressed) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.floor();
      if (_width != w && w > 0) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _load(w) : null);
      final ad = _ad;
      if (ad == null) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Material(
          color: context.colors.surface,
          // Align with heightFactor 1, not Center: Center would expand to the
          // whole screen inside bottomNavigationBar.
          child: Align(heightFactor: 1, child: SizedBox(height: ad.height, child: ad.widget)),
        ),
      );
    });
  }
}

/// Whether Settings builds the AD-5 slot at all (false with
/// ADMOB_BANNER_SETTINGS=off). A provider so tests can switch it.
final settingsBannerEnabledProvider = Provider<bool>((ref) => bannerSettingsEnabled);
