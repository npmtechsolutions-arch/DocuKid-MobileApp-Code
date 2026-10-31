import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/auth/device_auth.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../data/settings/app_settings.dart';
import '../application/app_lock.dart';

/// S45 App lock (RELEASE_V1_5 §3, FR-LCK-06/07): prompts once when shown (no
/// retry loop), then continues to [next]. No ads, no banner.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.next, this.cover = false});

  /// Where to go once unlocked (already checked with [safeNext]).
  final String next;

  /// Pushed over the locked screen itself (re-locked while it was showing):
  /// unlocking just removes the cover.
  final bool cover;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  /// FR-LCK-07: no screen lock any more → offer to turn the lock off.
  bool _noScreenLock = false, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      unawaited(SemanticsService.sendAnnouncement(View.of(context), _title(context), Directionality.of(context)));
      if (!await ref.read(deviceAuthProvider).available()) {
        if (mounted) setState(() => _noScreenLock = true);
        return;
      }
      await _unlock(); // once, automatically
    });
  }

  String _title(BuildContext context) =>
      ref.read(settingsProvider).lockScope == LockScope.app ? context.l10n.lckTitleApp : context.l10n.lckTitle;

  void _continue() {
    final next = safeNext(widget.next);
    final router = GoRouter.of(context);
    if (widget.cover && router.canPop()) {
      router.pop();
    } else if (next == '/') {
      router.go('/');
    } else if (router.canPop()) {
      router.pushReplacement(next);
    } else {
      // Locked in place (the stack was replaced): keep Home underneath.
      router.go('/');
      unawaited(router.push(next));
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await ref.read(appLockProvider.notifier).unlock(context.l10n.lckReason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _noScreenLock = r == AuthOutcome.noCredential;
    });
    if (r == AuthOutcome.success) _continue();
  }

  void _home() {
    final router = GoRouter.of(context);
    // A cover sits on locked screens: leave them all.
    !widget.cover && router.canPop() ? router.pop() : router.go('/');
  }

  Future<void> _turnOff() async {
    final l = context.l10n;
    final ok = await askAdaptive(context, title: l.lckTurnOffTitle, body: l.lckTurnOffBody, no: l.actionCancel, yes: l.lckTurnOff);
    if (!ok || !mounted) return;
    if (await ref.read(appLockProvider.notifier).turnOffWithoutScreenLock()) {
      if (mounted) _continue();
    } else if (mounted) {
      setState(() => _noScreenLock = false); // a screen lock is back: unlock as usual
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final libraryOnly = ref.watch(settingsProvider.select((s) => s.lockScope)) == LockScope.library;
    return PopScope(
      // Library-only: back = Back to Home; whole app: nowhere to go back to.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && libraryOnly) _home();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.x6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // The brand mark (gradient) with a lock: decorative.
                  ExcludeSemantics(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: context.docu.brandGradient),
                      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: Space.x5),
                  Semantics(
                    header: true,
                    child: Text(_title(context), style: context.text.headlineSmall, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(_noScreenLock ? l.lckRemoved : l.lckBody,
                      style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
                  const SizedBox(height: Space.x6),
                  if (_noScreenLock)
                    FilledButton(
                      key: const ValueKey('lock-turn-off'),
                      style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                      onPressed: _turnOff,
                      child: Text(l.lckTurnOff),
                    )
                  else
                    FilledButton.icon(
                      key: const ValueKey('lock-unlock'),
                      autofocus: true,
                      style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                      onPressed: _busy ? null : _unlock,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: Text(l.lckUnlock),
                    ),
                  if (libraryOnly) ...[
                    const SizedBox(height: Space.x3),
                    TextButton(
                      key: const ValueKey('lock-home'),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: _home,
                      child: Text(l.lckBackHome),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
