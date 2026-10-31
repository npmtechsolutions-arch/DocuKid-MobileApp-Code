import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/device_auth.dart';
import '../../../core/platform/system_flow.dart';
import '../../../core/providers.dart';
import '../../../data/settings/app_settings.dart';

/// §4.8 states. `unlocking` = the system prompt is up.
enum LockStatus { disabled, locked, unlocking, unlocked }

/// FR-LCK-03 (ADR-057): the routes the lock covers. `/lock` and onboarding
/// never are.
bool isLockScoped(String location, LockScope scope) {
  final path = Uri.parse(location).path;
  if (path == '/lock' || path == '/onboarding') return false;
  if (scope == LockScope.app) return true;
  return path == '/library' || path.startsWith('/library/') || path == '/settings/library';
}

/// S45's `next`: only an in-app path (no scheme, host or `//`), never `/lock`.
String safeNext(String? next) {
  if (next == null || next.isEmpty) return '/';
  final u = Uri.tryParse(next);
  if (u == null || u.hasScheme || u.hasAuthority || !next.startsWith('/') || next.startsWith('//')) return '/';
  if (u.path == '/lock') return '/';
  return next;
}

/// The device-auth wrapper (a fake in tests).
final deviceAuthProvider = Provider<DeviceAuth>((ref) => LocalDeviceAuth());

/// §4.8 app-lock state machine (FR-LCK-01–07). Locked on a cold start when
/// the lock is on; locks again after being away for the chosen time (or at
/// once); trips into system UI started by DocuKit don't count as leaving.
class AppLockController extends Notifier<LockStatus> {
  DateTime? _backgroundAt;

  DateTime _now() => ref.read(clockProvider)();
  AppSettings get _s => ref.read(settingsProvider);
  DeviceAuth get _auth => ref.read(deviceAuthProvider);

  @override
  LockStatus build() {
    ref.listen(settingsProvider.select((s) => s.lockEnabled), (_, on) {
      if (!on) state = LockStatus.disabled;
    });
    return _s.lockEnabled ? LockStatus.locked : LockStatus.disabled;
  }

  bool get locked => state == LockStatus.locked || state == LockStatus.unlocking;

  /// The router guard: [location] must go through S45 first.
  bool needsUnlock(String location) => locked && isLockScoped(location, _s.lockScope);

  void background() {
    if (state == LockStatus.disabled || SystemFlow.busy) return;
    _backgroundAt = _now();
    if (_s.lockTimeout == LockTimeout.immediate && state == LockStatus.unlocked) state = LockStatus.locked;
  }

  void foreground() {
    final at = _backgroundAt;
    _backgroundAt = null;
    if (at == null || SystemFlow.busy || state != LockStatus.unlocked) return;
    if (_now().difference(at) >= _s.lockTimeout.duration) state = LockStatus.locked;
  }

  /// S45 [Unlock] (and its one automatic prompt). No retry loop.
  Future<AuthOutcome> unlock(String reason) async {
    if (state != LockStatus.locked) return AuthOutcome.success;
    state = LockStatus.unlocking;
    final r = await _auth.authenticate(reason);
    state = r == AuthOutcome.success ? LockStatus.unlocked : LockStatus.locked;
    return r;
  }

  /// FR-LCK-01: turning the lock on takes one successful check; impossible
  /// without a screen lock (FR-LCK-02).
  Future<AuthOutcome> enable(String reason) async {
    if (!await _auth.available()) return AuthOutcome.noCredential;
    final r = await _auth.authenticate(reason);
    if (r != AuthOutcome.success) return r;
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(lockEnabled: true));
    state = LockStatus.unlocked;
    return r;
  }

  /// Turning it off also takes one check.
  Future<AuthOutcome> disable(String reason) async {
    final r = await _auth.authenticate(reason);
    if (r == AuthOutcome.success) await _off();
    return r;
  }

  /// FR-LCK-07: the phone's screen lock was removed, so nothing can be
  /// checked; the lock is turned off after one confirmation in the UI.
  /// Refused while a screen lock exists.
  Future<bool> turnOffWithoutScreenLock() async {
    if (await _auth.available()) return false;
    await _off();
    return true;
  }

  Future<void> _off() async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(lockEnabled: false));
    state = LockStatus.disabled;
  }
}

final appLockProvider = NotifierProvider<AppLockController, LockStatus>(AppLockController.new);

/// FR-LCK-02: the phone has a screen lock (S46 disables the switch without
/// one). Invalidated on resume (the user may have just set one up).
final screenLockAvailableProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(deviceAuthProvider).available());
