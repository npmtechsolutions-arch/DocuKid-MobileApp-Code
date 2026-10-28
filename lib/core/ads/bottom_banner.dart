import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../features/tour/tour_controller.dart';
import '../providers.dart';
import 'ads_config.dart';
import 'ads_controller.dart';
import 'ads_service.dart';

/// Counts dialogs and bottom sheets (popup routes) open on any navigator.
/// Bottom banners collapse while one is open, so no sheet slides over an ad
/// and no ad shows "inside" a dialog (ADR-035).
class OverlayRouteTracker {
  final open = ValueNotifier<int>(0);

  /// A new observer for one navigator (an observer can't be shared).
  NavigatorObserver observer() => _PopupObserver(this);

  /// Called when the router is rebuilt (also keeps tests independent).
  void reset() => open.value = 0;
}

class _PopupObserver extends NavigatorObserver {
  _PopupObserver(this._t);
  final OverlayRouteTracker _t;

  void _change(Route<dynamic> r, int d) {
    if (r is PopupRoute) _t.open.value = (_t.open.value + d).clamp(0, 1 << 20);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _change(route, 1);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _change(route, -1);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _change(route, -1);
}

final overlayRoutes = OverlayRouteTracker();

/// Whether a banner unit exists at all in this build (false with
/// `ADMOB_BANNER_…=off`): then the slot is never built. A provider so tests
/// can switch it.
final bannerUnitEnabledProvider = Provider.family<bool, AdUnit>((ref, unit) => AdUnits.enabled(unit));

/// The shared bottom banner (ADR-035): wraps a screen and adds an anchored
/// adaptive banner in its own reserved space below all of the screen's
/// content, never drawn over it. Opt in by wrapping the screen's Scaffold:
///
///     AppBottomBanner(unit: AdUnit.bannerMain, child: Scaffold(…))
///
/// It takes no space when there's no ad, after Remove ads, during the 24 h
/// ad-free pass, during the tour, while the keyboard is open, and while a
/// dialog or sheet is open. [separated] adds the 24 dp gap and 1 dp divider
/// required below a bottom action button (tool screens, Organizer).
class AppBottomBanner extends ConsumerStatefulWidget {
  const AppBottomBanner({super.key, required this.unit, required this.child, this.separated = false, this.hidden = false});

  final AdUnit unit;
  final Widget child;
  final bool separated;

  /// Collapses the slot for a transient state (the loaded ad is kept).
  final bool hidden;

  /// The gap between a bottom action button and the banner.
  static const gap = 24.0;

  @override
  ConsumerState<AppBottomBanner> createState() => _AppBottomBannerState();
}

class _AppBottomBannerState extends ConsumerState<AppBottomBanner> {
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
      ad = await ref.read(adsServiceProvider).loadBanner(widget.unit, width);
    } catch (_) {
      ad = null; // a failed load is just a missing ad
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
    if (!ref.watch(bannerUnitEnabledProvider(widget.unit))) return widget.child;
    final ads = ref.watch(adsControllerProvider);
    final tourActive = ref.watch(tourControllerProvider.select((t) => t.active));
    final suppressed = AdsController.policy.adsSuppressed(ref.read(clockProvider)(), ads.counters, adsRemoved: ads.adsRemoved);
    final canLoad = ads.canRequestAds && !suppressed;
    if (!canLoad) return widget.child;

    final w = MediaQuery.sizeOf(context).width.floor();
    if (_width != w && w > 0) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _load(w) : null);

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return ValueListenableBuilder<int>(
      valueListenable: overlayRoutes.open,
      builder: (context, overlays, _) {
        final ad = _ad;
        final show = ad != null && !widget.hidden && !tourActive && !keyboardOpen && overlays == 0;
        if (!show) return widget.child;
        return Column(children: [
          // The banner takes over the bottom safe area, so the screen above
          // lays out as if it ended at the banner: nothing overlaps the ad.
          Expanded(child: MediaQuery.removePadding(context: context, removeBottom: true, child: widget.child)),
          Material(
            color: context.colors.surface,
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.separated) ...[
                  const SizedBox(height: AppBottomBanner.gap),
                  Divider(height: 1, thickness: 1, color: context.colors.outlineVariant),
                ],
                // Align with heightFactor 1: Center would expand to fill.
                Align(heightFactor: 1, child: SizedBox(key: const ValueKey('app-bottom-banner-ad'), height: ad.height, child: ad.widget)),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}
