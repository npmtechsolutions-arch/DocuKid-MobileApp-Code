// T12.7 on a device (RELEASE_V1_5 R66, FR-LCK-01/02/04/05/06): the real
// local_auth prompt (device PIN, no DocuKit PIN), the lock state machine with
// it, and FLAG_SECURE from docukit_native. The host drives the system UI:
//   R66 set pin    → adb shell locksettings set-pin 1234
//   R66 enter pin  → adb shell input text 1234 ; adb shell input keyevent 66
// Cancelling the system prompt with Back couldn't be driven over adb on the
// API 34 emulator (the call never returned); it's a phone check (TASKS T12.7).
//   R66 secure on / off → adb shell dumpsys window | grep FLAG_SECURE
//   afterwards     → adb shell locksettings clear --old 1234
import 'package:docukit/core/auth/device_auth.dart';
import 'package:docukit/core/platform/system_flow.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/library/application/app_lock.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> say(String s) async {
    // ignore: avoid_print
    print(s);
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  testWidgets('R66: no screen lock → can\'t enable; with a PIN: enable, re-lock after the timeout, unlock with the PIN; FLAG_SECURE',
      (_) async {
    final auth = LocalDeviceAuth();
    var now = DateTime.now();
    final c = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(MemoryStore())),
      clockProvider.overrideWithValue(() => now),
      deviceAuthProvider.overrideWithValue(auth),
    ]);
    addTearDown(c.dispose);
    final lock = c.read(appLockProvider.notifier);

    final before = await auth.available();
    await say('R66 screen lock before: $before');
    expect(before, isFalse, reason: 'the emulator starts without a screen lock');
    expect(await lock.enable('Unlock My Documents'), AuthOutcome.noCredential, reason: 'FR-LCK-02');

    await say('R66 set pin');
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (!await auth.available() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(await auth.available(), isTrue);

    await say('R66 enter pin');
    final enabled = await lock.enable('Unlock My Documents');
    await say('R66 enable → $enabled');
    expect(enabled, AuthOutcome.success);
    expect(c.read(appLockProvider), LockStatus.unlocked);
    expect(c.read(settingsProvider).lockScope, LockScope.library);

    // Leave for 2 minutes (the default timeout is 1 minute) — a real
    // departure, after the PIN prompt's grace period (SystemFlow.grace).
    await Future<void>.delayed(SystemFlow.grace + const Duration(seconds: 1));
    expect(SystemFlow.busy, isFalse);
    lock.background();
    now = now.add(const Duration(minutes: 2));
    lock.foreground();
    expect(c.read(appLockProvider), LockStatus.locked);
    expect(lock.needsUnlock('/library'), isTrue);
    expect(lock.needsUnlock('/tool/pdf-merge'), isFalse, reason: 'tools stay usable');

    await say('R66 enter pin');
    final unlocked = await lock.unlock('Unlock My Documents');
    await say('R66 unlock → $unlocked');
    expect(unlocked, AuthOutcome.success);
    expect(c.read(appLockProvider), LockStatus.unlocked);

    final native = DocukitNative();
    await native.setSecure(true);
    await say('R66 secure on');
    await Future<void>.delayed(const Duration(seconds: 4));
    await native.setSecure(false);
    await say('R66 secure off');
    await Future<void>.delayed(const Duration(seconds: 4));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
