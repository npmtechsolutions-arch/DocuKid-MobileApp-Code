// T12.7 — the app-lock state machine (RELEASE_V1_5 §4.8, FR-LCK-01–07):
// cold start, enable / disable with one check, re-lock timing, system flows
// that don't count as leaving, unlock outcomes, scopes, the S45 `next`
// check, and turning off a lock whose screen lock was removed.
import 'package:docukit/core/auth/device_auth.dart';
import 'package:docukit/core/platform/system_flow.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/library/application/app_lock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late MemoryStore store;
  late FakeDeviceAuth auth;
  late DateTime now;

  setUp(() {
    SystemFlow.reset();
    store = MemoryStore();
    auth = FakeDeviceAuth();
    now = DateTime(2026, 10, 31, 12);
  });

  ProviderContainer container({Map<String, Object> settings = const {}}) {
    store = MemoryStore({...settings});
    final c = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(store)),
      clockProvider.overrideWithValue(() => now),
      deviceAuthProvider.overrideWithValue(auth),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  const on = {SettingsRepository.kLockEnabled: true};

  test('cold start: locked when on (it survives process death), disabled when off', () {
    expect(container(settings: on).read(appLockProvider), LockStatus.locked);
    expect(container().read(appLockProvider), LockStatus.disabled);
  });

  test('FR-LCK-01/02: turning on takes one successful check; refused without a screen lock; a failed check changes nothing', () async {
    final c = container();
    final lock = c.read(appLockProvider.notifier);
    auth.next = AuthOutcome.failed;
    expect(await lock.enable('r'), AuthOutcome.failed);
    expect((c.read(appLockProvider), c.read(settingsProvider).lockEnabled), (LockStatus.disabled, false));
    auth.hasScreenLock = false;
    expect(await lock.enable('r'), AuthOutcome.noCredential);
    expect(auth.prompts, 1, reason: 'no prompt without a screen lock');
    auth
      ..hasScreenLock = true
      ..next = AuthOutcome.success;
    expect(await lock.enable('r'), AuthOutcome.success);
    expect((c.read(appLockProvider), c.read(settingsProvider).lockEnabled), (LockStatus.unlocked, true));
    expect(store.get(SettingsRepository.kLockEnabled), true);
  });

  test('turning off takes one check too', () async {
    final c = container(settings: on);
    final lock = c.read(appLockProvider.notifier);
    auth.next = AuthOutcome.cancelled;
    expect(await lock.disable('r'), AuthOutcome.cancelled);
    expect(c.read(settingsProvider).lockEnabled, isTrue);
    auth.next = AuthOutcome.success;
    await lock.disable('r');
    expect((c.read(appLockProvider), c.read(settingsProvider).lockEnabled), (LockStatus.disabled, false));
  });

  test('FR-LCK-06 unlock: success → unlocked; fail or cancel → stays locked, no automatic retry', () async {
    final c = container(settings: on);
    final lock = c.read(appLockProvider.notifier);
    auth.next = AuthOutcome.failed;
    expect(await lock.unlock('r'), AuthOutcome.failed);
    expect(c.read(appLockProvider), LockStatus.locked);
    auth.next = AuthOutcome.cancelled;
    await lock.unlock('r');
    expect((c.read(appLockProvider), auth.prompts), (LockStatus.locked, 2));
    auth.next = AuthOutcome.success;
    await lock.unlock('r');
    expect(c.read(appLockProvider), LockStatus.unlocked);
    expect(await lock.unlock('r'), AuthOutcome.success);
    expect(auth.prompts, 3, reason: 'already unlocked: no prompt');
  });

  for (final (timeout, away, locks) in [
    (LockTimeout.m1, const Duration(seconds: 59), false),
    (LockTimeout.m1, const Duration(minutes: 1), true),
    (LockTimeout.m5, const Duration(minutes: 4), false),
    (LockTimeout.m5, const Duration(minutes: 6), true),
    (LockTimeout.immediate, const Duration(seconds: 1), true),
  ]) {
    test('FR-LCK-04 ${timeout.name}: away ${away.inSeconds} s → ${locks ? 'locked' : 'still unlocked'}', () async {
      final c = container(settings: {...on, SettingsRepository.kLockTimeout: timeout.name});
      final lock = c.read(appLockProvider.notifier);
      await lock.unlock('r');
      lock.background();
      if (timeout == LockTimeout.immediate) expect(c.read(appLockProvider), LockStatus.locked, reason: 'at once');
      now = now.add(away);
      lock.foreground();
      expect(c.read(appLockProvider), locks ? LockStatus.locked : LockStatus.unlocked);
    });
  }

  test('§4.8: a picker / share / unlock prompt started by DocuKit doesn\'t count as leaving, even with "Immediately"', () async {
    final c = container(settings: {...on, SettingsRepository.kLockTimeout: LockTimeout.immediate.name});
    final lock = c.read(appLockProvider.notifier);
    await lock.unlock('r');
    await SystemFlow.run(() async {
      lock.background();
      now = now.add(const Duration(minutes: 10));
      lock.foreground();
    });
    expect(c.read(appLockProvider), LockStatus.unlocked);
    // Just after the flow ends the app's own resume may still arrive.
    lock.background();
    expect(c.read(appLockProvider), LockStatus.unlocked);
    SystemFlow.reset();
    lock.background();
    expect(c.read(appLockProvider), LockStatus.locked, reason: 'a real departure');
  });

  test('turning the lock off in Settings disables it at once', () async {
    final c = container(settings: on);
    await c.read(settingsProvider.notifier).update((s) => s.copyWith(lockEnabled: false));
    expect(c.read(appLockProvider), LockStatus.disabled);
    c.read(appLockProvider.notifier)
      ..background()
      ..foreground();
    expect(c.read(appLockProvider), LockStatus.disabled);
  });

  test('FR-LCK-07: with the screen lock removed it can be turned off without a check; refused while one exists', () async {
    final c = container(settings: on);
    final lock = c.read(appLockProvider.notifier);
    expect(await lock.turnOffWithoutScreenLock(), isFalse);
    expect(c.read(settingsProvider).lockEnabled, isTrue);
    auth.hasScreenLock = false;
    expect(await lock.turnOffWithoutScreenLock(), isTrue);
    expect((c.read(appLockProvider), c.read(settingsProvider).lockEnabled), (LockStatus.disabled, false));
    expect(auth.prompts, 0);
  });

  test('FR-LCK-03 scopes: My Documents only vs whole app; /lock and onboarding never', () {
    for (final r in ['/library', '/library/folder/x', '/library/doc/y/view', '/settings/library']) {
      expect(isLockScoped(r, LockScope.library), isTrue, reason: r);
    }
    for (final r in ['/', '/history', '/settings', '/tool/pdf-merge', '/job/1', '/librarything', '/lock', '/onboarding']) {
      expect(isLockScoped(r, LockScope.library), isFalse, reason: r);
    }
    for (final r in ['/', '/history', '/tool/pdf-merge', '/settings']) {
      expect(isLockScoped(r, LockScope.app), isTrue, reason: r);
    }
    expect(isLockScoped('/lock?next=/', LockScope.app), isFalse);
    expect(isLockScoped('/onboarding', LockScope.app), isFalse);
  });

  test('needsUnlock: only while locked and only for scoped routes', () async {
    final c = container(settings: on);
    final lock = c.read(appLockProvider.notifier);
    expect(lock.needsUnlock('/library/doc/a'), isTrue);
    expect(lock.needsUnlock('/tool/pdf-merge'), isFalse);
    await lock.unlock('r');
    expect(lock.needsUnlock('/library/doc/a'), isFalse);
  });

  test('S45 next: in-app paths only (no open redirect)', () {
    expect(safeNext('/library/doc/a'), '/library/doc/a');
    expect(safeNext('/library?x=1'), '/library?x=1');
    for (final bad in [null, '', 'https://evil.example/', '//evil.example/x', 'library', '/lock?next=/library', 'javascript:alert(1)']) {
      expect(safeNext(bad), '/', reason: '$bad');
    }
  });
}
