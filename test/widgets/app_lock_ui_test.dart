// T12.7 — the app lock in the UI (RELEASE_V1_5 S45, S46 Lock, FR-LCK-01–08):
// the router guard per scope, S45's single automatic prompt and its buttons,
// re-locking on resume, the Home card's locked look, reminder taps through
// S45, FLAG_SECURE on locked-scope screens, turning the lock on / off, no
// screen lock, and a screen lock removed later.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/auth/device_auth.dart';
import 'package:docukit/core/notifications/notification_service.dart';
import 'package:docukit/core/platform/system_flow.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/library/presentation/document_screen.dart';
import 'package:docukit/features/library/presentation/library_home_screen.dart';
import 'package:docukit/features/library/presentation/library_settings_screen.dart';
import 'package:docukit/features/library/presentation/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late Directory src;

  setUp(() {
    SystemFlow.reset();
    src = Directory.systemTemp.createTempSync('lib_lock');
  });
  tearDown(() => src.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 80 && !done(); i++) {
      await settle(tester, 1);
    }
    await settle(tester, 2);
  }

  bool on<T>() => find.byType(T).evaluate().isNotEmpty;

  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator, skipOffstage: false).first));
  LibraryRepository repo(WidgetTester tester) => c(tester).read(libraryRepositoryProvider);
  GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Navigator, skipOffstage: false).first));

  const lockOn = {SettingsRepository.kLockEnabled: true};

  Future<void> open(WidgetTester tester, {Map<String, Object> store = const {}, AuthOutcome auth = AuthOutcome.cancelled}) async {
    tester.view.physicalSize = const Size(420, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: {'lib_intro_seen': true, ...store})))!;
    h.auth.next = auth;
    await tester.pumpWidget(h.app());
    await settle(tester);
  }

  Future<LibraryDoc> addDoc(WidgetTester tester, String name) async {
    final f = File(p.join(src.path, name))..writeAsStringSync('doc $name');
    final r = (await tester.runAsync(
        () => repo(tester).addFile(f.path, displayName: name, source: DocSource.import, mime: 'application/pdf')))!;
    await settle(tester, 2);
    return (r as Added).doc;
  }

  Future<void> go(WidgetTester tester, String route) async {
    unawaited(router(tester).push(route));
    await waitFor(tester, () => on<LockScreen>() || !on<HomeScreen>());
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('FR-LCK-03/06 My Documents only: tools and Home open; My Documents → S45, one automatic prompt; Unlock → My Documents',
      (tester) async {
    await open(tester, store: lockOn);
    expect(on<HomeScreen>(), isTrue, reason: 'Home is not locked in this scope');
    await go(tester, '/tool/pdf-merge');
    expect(on<LockScreen>(), isFalse);
    router(tester).pop();
    await settle(tester);
    await go(tester, '/library');
    expect(on<LockScreen>(), isTrue);
    expect(find.text('My Documents is locked'), findsOneWidget);
    expect(h.auth.prompts, 1, reason: 'once, automatically');
    await settle(tester, 6);
    expect(h.auth.prompts, 1, reason: 'cancel: no retry loop');
    h.auth.next = AuthOutcome.success;
    await tester.tap(find.byKey(const ValueKey('lock-unlock')));
    await waitFor(tester, () => on<LibraryScreen>());
    expect(on<LibraryScreen>(), isTrue);
    expect(on<LockScreen>(), isFalse);
    router(tester).pop();
    await settle(tester);
    expect(on<HomeScreen>(), isTrue, reason: 'Home stays underneath');
    await finish(tester);
  });

  testWidgets('S45 Back to Home (Library-only); failed unlock stays locked', (tester) async {
    await open(tester, store: lockOn, auth: AuthOutcome.failed);
    await go(tester, '/library');
    await settle(tester);
    expect(on<LockScreen>(), isTrue);
    await tester.tap(find.byKey(const ValueKey('lock-home')));
    await settle(tester);
    expect(on<HomeScreen>(), isTrue);
    expect(on<LockScreen>(), isFalse);
    await finish(tester);
  });

  testWidgets('FR-LCK-03 Whole app: opens on S45 with no Back to Home; cancel stays; unlock → Home', (tester) async {
    await open(tester, store: {...lockOn, SettingsRepository.kLockScope: 'app'});
    await waitFor(tester, () => on<LockScreen>());
    expect(on<LockScreen>(), isTrue);
    expect(find.text('DocuKit is locked'), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-home')), findsNothing);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(on<LockScreen>(), isTrue, reason: 'nowhere to go back to');
    h.auth.next = AuthOutcome.success;
    await tester.tap(find.byKey(const ValueKey('lock-unlock')));
    await waitFor(tester, () => on<HomeScreen>());
    expect(on<HomeScreen>(), isTrue);
    await finish(tester);
  });

  testWidgets('FR-LCK-04 "Immediately": leaving and coming back while on a document locks it again', (tester) async {
    await open(tester, store: {...lockOn, SettingsRepository.kLockTimeout: 'immediate'}, auth: AuthOutcome.success);
    final d = await addDoc(tester, 'Passport.pdf');
    unawaited(router(tester).push('/library/doc/${d.id}'));
    // S45 prompts at once (success) while its route is still animating in.
    await waitFor(tester, () => find.byType(DocumentScreen).evaluate().isNotEmpty && find.byType(LockScreen).evaluate().isEmpty);
    await settle(tester, 6);
    expect(on<DocumentScreen>(), isTrue, reason: 'unlocked by the automatic prompt');
    h.auth.next = AuthOutcome.cancelled;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitFor(tester, () => on<LockScreen>());
    expect(on<LockScreen>(), isTrue);
    expect(on<DocumentScreen>(), isFalse);
    h.auth.next = AuthOutcome.success;
    await tester.tap(find.byKey(const ValueKey('lock-unlock')));
    await waitFor(tester, () => on<DocumentScreen>());
    expect(on<DocumentScreen>(), isTrue, reason: 'back where it was');
    await finish(tester);
  });

  testWidgets('a system flow (picker, share, unlock prompt) doesn\'t lock, even with "Immediately"', (tester) async {
    await open(tester, store: {...lockOn, SettingsRepository.kLockTimeout: 'immediate'}, auth: AuthOutcome.success);
    await go(tester, '/library');
    await waitFor(tester, () => on<LibraryScreen>());
    await tester.runAsync(() => SystemFlow.run(() async {
          for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
              AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
            tester.binding.handleAppLifecycleStateChanged(st);
          }
        }));
    await settle(tester);
    expect(on<LibraryScreen>(), isTrue);
    expect(on<LockScreen>(), isFalse);
    await finish(tester);
  });

  testWidgets('FR-LIB-23 locked Home card: "Unlock to view", no documents; tap → S45 → My Documents', (tester) async {
    await open(tester, store: lockOn);
    await addDoc(tester, 'Passport.pdf');
    await settle(tester);
    expect(find.byKey(const ValueKey('home-library-locked')), findsOneWidget);
    expect(find.text('Unlock to view'), findsOneWidget);
    expect(find.text('Passport.pdf'), findsNothing, reason: 'nothing shown while locked');
    h.auth.next = AuthOutcome.success;
    await tester.ensureVisible(find.byKey(const ValueKey('home-library-locked')));
    await tester.tap(find.byKey(const ValueKey('home-library-locked')));
    await waitFor(tester, () => on<LibraryScreen>());
    expect(on<LibraryScreen>(), isTrue);
    router(tester).pop();
    await settle(tester);
    expect(find.byKey(const ValueKey('home-library-locked')), findsNothing);
    expect(find.text('Passport.pdf'), findsOneWidget, reason: 'unlocked: the card shows the documents');
    await finish(tester);
  });

  testWidgets('FR-LCK-08: a reminder tap while locked goes to S45 first, then the document', (tester) async {
    await open(tester, store: lockOn);
    final d = await addDoc(tester, 'Passport.pdf');
    await waitFor(tester, () => h.notifications.onTap != null);
    h.notifications.onTap!(NotificationTap('rem:${d.id}:7:x:UTC:1'));
    await waitFor(tester, () => on<LockScreen>());
    expect(on<LockScreen>(), isTrue);
    expect(on<DocumentScreen>(), isFalse);
    h.auth.next = AuthOutcome.success;
    await tester.tap(find.byKey(const ValueKey('lock-unlock')));
    await waitFor(tester, () => on<DocumentScreen>());
    expect(on<DocumentScreen>(), isTrue);
    await finish(tester);
  });

  testWidgets('FR-LCK-05: FLAG_SECURE only on locked-scope screens with "Hide in recent apps" on', (tester) async {
    await open(tester, store: lockOn, auth: AuthOutcome.success);
    await go(tester, '/library');
    await waitFor(tester, () => on<LibraryScreen>());
    expect(h.native.secure.last, isTrue);
    router(tester).pop();
    await settle(tester);
    expect(h.native.secure.last, isFalse, reason: 'Home is not locked in this scope');
    await tester.runAsync(() => c(tester).read(settingsProvider.notifier).update((s) => s.copyWith(lockHideRecents: false)));
    await go(tester, '/library');
    await settle(tester);
    expect(h.native.secure.last, isFalse);
    await finish(tester);
  });

  testWidgets('FR-LCK-01 S46: turning on takes a check; scope, timeout and Hide in recent apps are saved; off takes a check',
      (tester) async {
    await open(tester, auth: AuthOutcome.success);
    await go(tester, '/settings/library');
    expect(on<LibrarySettingsScreen>(), isTrue);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-lock')), 300);
    await tester.tap(find.byKey(const ValueKey('set-lib-lock')));
    await waitFor(tester, () => h.store.get(SettingsRepository.kLockEnabled) == true);
    expect(h.auth.prompts, 1);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-hide-recents')), 300);
    await tester.tap(find.byKey(const ValueKey('lock-scope-app')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('lock-after-m5')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('set-lib-hide-recents')));
    await settle(tester, 2);
    expect((h.store.get(SettingsRepository.kLockScope), h.store.get(SettingsRepository.kLockTimeout),
        h.store.get(SettingsRepository.kLockHideRecents)), ('app', 'm5', false));
    h.auth.next = AuthOutcome.cancelled;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-lock')), -300);
    await tester.tap(find.byKey(const ValueKey('set-lib-lock')));
    await settle(tester);
    expect(h.store.get(SettingsRepository.kLockEnabled), true, reason: 'cancelled: still on');
    h.auth.next = AuthOutcome.success;
    await tester.tap(find.byKey(const ValueKey('set-lib-lock')));
    await waitFor(tester, () => h.store.get(SettingsRepository.kLockEnabled) == false);
    expect(h.store.get(SettingsRepository.kLockEnabled), false);
    await finish(tester);
  });

  testWidgets('FR-LCK-02: no screen lock → the switch is off with "Set up a screen lock…" and Open Settings', (tester) async {
    await open(tester);
    h.auth.hasScreenLock = false;
    await go(tester, '/settings/library');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-lock')), 300);
    await settle(tester);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('set-lib-lock'))).onChanged, isNull);
    expect(find.text('Set up a screen lock on your phone first.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('set-lib-lock-settings')));
    await settle(tester, 2);
    expect(h.device.settingsOpened, 1);
    await finish(tester);
  });

  testWidgets('FR-LCK-07: screen lock removed later → S45 explains; Turn off (one confirmation) → My Documents', (tester) async {
    await open(tester, store: lockOn);
    h.auth.hasScreenLock = false;
    await go(tester, '/library');
    await waitFor(tester, () => find.byKey(const ValueKey('lock-turn-off')).evaluate().isNotEmpty);
    expect(find.textContaining("Your phone's screen lock was removed."), findsOneWidget);
    expect(h.auth.prompts, 0, reason: 'nothing to prompt with');
    await tester.tap(find.byKey(const ValueKey('lock-turn-off')));
    await settle(tester);
    await tester.tap(find.text('Turn off the lock').last);
    await waitFor(tester, () => on<LibraryScreen>());
    expect(on<LibraryScreen>(), isTrue);
    expect(h.store.get(SettingsRepository.kLockEnabled), false);
    await finish(tester);
  });
}
