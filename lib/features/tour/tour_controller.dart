import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/consent_state.dart';
import '../../core/providers.dart';
import '../incoming/incoming_controller.dart';
import 'tour_overlay.dart';

/// Bump when a release adds tour steps (FR-TOUR-10; TOUR.md §2.1: 1.1 = 2, 1.2 = 3).
const currentTourVersion = 3;

class TourState {
  const TourState({this.active = false, this.index = 0, this.total = 0, this.replayPending = false});
  final bool active;

  /// Settings asked for a replay; Home starts it once it's visible again.
  final bool replayPending;
  final int index, total;
  bool get isLast => index >= total - 1;
}

/// TOUR.md §4 controller: next/back/skip/finish. While [TourState.active],
/// ad slots stay hidden (FR-TOUR-08).
class TourController extends Notifier<TourState> {
  @override
  TourState build() => const TourState();

  bool _autoScheduled = false;

  void begin({required int total}) => state = TourState(active: true, index: 0, total: total);

  void next() {
    if (!state.active) return;
    if (state.isLast) {
      finish();
    } else {
      state = TourState(active: true, index: state.index + 1, total: state.total);
    }
  }

  void back() {
    if (!state.active || state.index == 0) return;
    state = TourState(active: true, index: state.index - 1, total: state.total);
  }

  void skip() => _end();
  void finish() => _end();

  void _end() {
    state = const TourState();
    unawaited(
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(tourDone: true, tourVersion: currentTourVersion)),
    );
  }

  /// Starts (or replays) the tour over the current screen (FR-TOUR-05).
  /// Settings → "Take the tour" (FR-TOUR-05): Home starts it once it's visible.
  void requestReplay() {
    if (!state.active) state = const TourState(replayPending: true);
  }

  /// The full tour, or with [whatsNewSince] only the steps added after it.
  void start(BuildContext context, {int? whatsNewSince}) {
    if (state.active) return;
    if (state.replayPending) state = const TourState();
    Navigator.of(context, rootNavigator: true).push(TourRoute(whatsNewSince: whatsNewSince));
  }

  /// FR-TOUR-01: once, 600 ms after Home's first frame, only after onboarding
  /// and any consent form have closed, and never over a dialog/sheet.
  void maybeAutoStart(BuildContext context) {
    if (state.replayPending) {
      start(context);
      return;
    }
    final s = ref.read(settingsProvider);
    // New user → the full tour; a user who finished an older tour → only
    // what's new since (FR-TOUR-10); otherwise nothing.
    final upToDate = s.tourDone && s.tourVersion >= currentTourVersion;
    if (_autoScheduled || upToDate || !s.onboardingDone) return;
    _autoScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 600), () async {
      if (!context.mounted) return;
      await ref.read(consentStateProvider.notifier).settled;
      final now = ref.read(settingsProvider);
      if (!context.mounted || (now.tourDone && now.tourVersion >= currentTourVersion)) return;
      final route = ModalRoute.of(context);
      // Home sits in the shell's navigator, so its route stays "current" while
      // a root route (a tool, S19) is on top: check the app's location too.
      final onHome = GoRouter.of(context).state.matchedLocation == '/';
      if ((route != null && !route.isCurrent) || !onHome || ref.read(incomingProvider) != null) {
        _autoScheduled = false; // try again on the next Home build
        return;
      }
      start(context, whatsNewSince: now.tourDone ? now.tourVersion : null);
    });
  }
}

final tourControllerProvider = NotifierProvider<TourController, TourState>(TourController.new);
