import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../core/logging/log.dart';
import '../core/notifications/notification_service.dart';
import '../core/operation/jobs_controller.dart';
import '../core/providers.dart';
import '../core/widgets/common.dart';
import '../core/widgets/pdf_thumbnail.dart';
import '../features/incoming/incoming_controller.dart';
import '../features/library/application/app_lock.dart';
import '../features/library/application/index_queue.dart';
import '../features/library/application/reminder_scheduler.dart';
import '../features/shortcuts/shortcut_routes.dart';
import '../features/tour/tour_controller.dart';
import '../l10n/gen/app_localizations.dart';
import 'router.dart';
import 'theme/theme.dart';

class DocuKitApp extends ConsumerStatefulWidget {
  const DocuKitApp({super.key});

  @override
  ConsumerState<DocuKitApp> createState() => _DocuKitAppState();
}

class _DocuKitAppState extends ConsumerState<DocuKitApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(
    onboarded: ref.read(settingsProvider).onboardingDone,
    // §4.8: entering a locked route goes through S45 (cold start included).
    guard: (location) =>
        ref.read(appLockProvider.notifier).needsUnlock(location) ? '/lock?next=${Uri.encodeComponent(location)}' : null,
  );

  /// FR-LCK-04: locked again while a locked-scope screen is showing → S45
  /// covers it (a router refresh only re-checks the base location, not
  /// screens pushed on top); unlocking pops the cover.
  void _coverIfLocked() {
    final here = _router.state.uri.toString();
    if (here.startsWith('/lock') || !ref.read(appLockProvider.notifier).needsUnlock(here)) return;
    unawaited(_router.push('/lock?next=${Uri.encodeComponent(here)}&cover=1'));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerFontLicence();
    _router.routerDelegate.addListener(_maybeOpenIncoming);
    _router.routerDelegate.addListener(_maybeOpenShortcut);
    _router.routerDelegate.addListener(_applyScreenPrivacy);
    // FR-SHR-03: files from a share or "Open with", cold (now) or warm (stream).
    // FR-SCN-22: the launcher shortcut's route, the same way.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_libraryHousekeeping());
      unawaited(ref.read(incomingProvider.notifier).start());
      unawaited(ref.read(shortcutRouteProvider.notifier).start());
      _applyScreenPrivacy();
      // 1.5 §4.7: reminders reconciled now; a tap that launched the app is routed.
      unawaited(ref.read(remindersRuntimeProvider).start(onTap: _openReminder));
      // 1.5 FR-LIB-16: indexing starts a little after launch (§4.6).
      _indexStart = Timer(const Duration(seconds: 5), () {
        if (mounted) unawaited(ref.read(indexQueueProvider).start());
      });
    });
  }

  Timer? _indexStart;

  /// 1.5 launch housekeeping, before anything can be added: My Documents is
  /// kept out of iCloud backup (FR-LIB-20, ADR-054 — re-applied each launch;
  /// Android excludes it in `data_extraction_rules.xml`), and leftovers are
  /// swept (`.part` files, folders with no row, import staging).
  Future<void> _libraryHousekeeping() async {
    try {
      final root = Directory(p.join(ref.read(appPathsProvider).supportRoot.path, 'library'));
      await root.create(recursive: true);
      await ref.read(deviceServicesProvider).protectOutput(root.path);
      await ref.read(libraryRepositoryProvider).sweepOrphans();
    } on Object catch (e) {
      Log.event('lib_housekeeping_failed', e.runtimeType.toString());
    }
  }
  bool? _secure, _cover;

  /// FR-LCK-05: Android blanks locked-scope screens in recents (and blocks
  /// screenshots) when "Hide in recent apps" is on; iOS covers the app while
  /// it isn't active whenever the lock is on.
  void _applyScreenPrivacy() {
    if (!mounted) return;
    final s = ref.read(settingsProvider);
    final secure = s.lockEnabled && s.lockHideRecents && isLockScoped(_router.state.matchedLocation, s.lockScope);
    final native = ref.read(nativeProvider);
    if (secure != _secure) {
      _secure = secure;
      unawaited(native.setSecure(secure).catchError((Object _) {}));
    }
    if (s.lockEnabled != _cover) {
      _cover = s.lockEnabled;
      unawaited(native.setPrivacyCover(s.lockEnabled).catchError((Object _) {}));
    }
  }

  /// FR-REM-06/09: a reminder tap opens its document (My Documents with a
  /// note if it's gone); "Remind me tomorrow" snoozes it.
  Future<void> _openReminder(NotificationTap t) async {
    final id = docIdOfPayload(t.payload);
    if (id == null) return;
    if (t.snooze) return ref.read(reminderSchedulerProvider).snooze(id);
    if (!ref.read(settingsProvider).onboardingDone) return;
    final doc = await ref.read(libraryRepositoryProvider).get(id);
    if (!mounted) return;
    if (doc != null) {
      unawaited(_router.push('/library/doc/$id'));
      return;
    }
    _router.go('/library');
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(ctx.l10n.libGone)));
  }

  /// ADR-058: indexing only while DocuKit is in the foreground. `inactive`
  /// (a system dialog or picker on top) doesn't count as leaving.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    ref.read(indexQueueProvider).setForeground(state == AppLifecycleState.resumed);
    // FR-LCK-04: leaving (incl. screen-off) starts the re-lock clock.
    if (state == AppLifecycleState.paused) ref.read(appLockProvider.notifier).background();
    if (state == AppLifecycleState.resumed) ref.read(appLockProvider.notifier).foreground();
    if (state == AppLifecycleState.resumed) {
      ref.read(remindersRuntimeProvider).resumed();
      ref.invalidate(notificationsEnabledProvider); // back from the system Settings
      ref.invalidate(screenLockAvailableProvider);
    }
  }

  /// Opens S19 once received files can be shown: after onboarding, never over
  /// a running job or its result (the files wait; FR-SHR-03).
  /// Set once S19 is pushed for the current session, so the router listener
  /// (fired by that very push) can't push it again. [_incomingSeen] notes that
  /// S19 was actually on screen: if it then disappears while the session is
  /// still open (the stack was replaced), it may be shown again.
  bool _incomingShown = false, _incomingSeen = false;

  void _maybeOpenIncoming() {
    if (!mounted || ref.read(incomingProvider) == null) return;
    // The top route, pushed ones included (currentConfiguration.uri is only
    // the base location — found on the emulator, R36).
    final here = _router.state.matchedLocation;
    if (here == '/incoming') {
      _incomingSeen = true;
    } else if (_incomingSeen) {
      _incomingShown = _incomingSeen = false;
    }
    if (_incomingShown) return;
    if (!ref.read(settingsProvider).onboardingDone) return;
    if (ref.read(jobsProvider).values.any((j) => j.isRunning)) return;
    final location = here;
    if (location.startsWith('/job/') || location == '/incoming' || location == '/onboarding') return;
    _incomingShown = true;
    _router.push('/incoming');
  }

  /// Opens the launcher shortcut's route (FR-SCN-22, ADR-065) on top of
  /// whatever is shown — pushed, never replacing it. Waits for onboarding and
  /// the tour; dropped when that tool is already open.
  void _maybeOpenShortcut() {
    if (!mounted) return;
    final route = ref.read(shortcutRouteProvider);
    if (route == null) return;
    if (!ref.read(settingsProvider).onboardingDone || ref.read(tourControllerProvider).active) return;
    final here = _router.state.matchedLocation;
    if (here == '/onboarding') return;
    ref.read(shortcutRouteProvider.notifier).take();
    if (here == Uri.parse(route).path) return;
    _router.push(route);
  }

  /// Plus Jakarta Sans and the Noto fonts (OCR text layer, ADR-046) are
  /// bundled, so their OFL must appear on the licences page.
  static bool _licenceAdded = false;
  static void _registerFontLicence() {
    if (_licenceAdded) return;
    _licenceAdded = true;
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], text);
      final noto = await rootBundle.loadString('assets/fonts/OFL-Noto.txt');
      yield LicenseEntryWithLineBreaks(const ['Noto Sans', 'Noto Sans Devanagari'], noto);
      for (final (name, file) in const [
        ('Dancing Script', 'OFL-DancingScript.txt'),
        ('Sacramento', 'OFL-Sacramento.txt'),
        ('Mr Dafoe', 'OFL-MrDafoe.txt'),
      ]) {
        yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/$file'));
      }
      // Protect / Unlock on Android (ADR-049); not in the iOS build.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final notice = await rootBundle.loadString('assets/licenses/PdfBox-Android-NOTICE.txt');
        final licence = await rootBundle.loadString('assets/licenses/PdfBox-Android-LICENSE.txt');
        yield LicenseEntryWithLineBreaks(const ['PdfBox-Android'], '$notice\n\n$licence');
      }
    });
  }

  @override
  void dispose() {
    _indexStart?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_maybeOpenIncoming);
    _router.routerDelegate.removeListener(_maybeOpenShortcut);
    _router.routerDelegate.removeListener(_applyScreenPrivacy);
    _router.dispose();
    super.dispose();
  }

  /// FR-LIFE-04: Android onTrimMemory / iOS memory warning → drop caches.
  @override
  void didHaveMemoryPressure() {
    ref.read(thumbnailCacheProvider).clear();
    PaintingBinding.instance.imageCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(incomingProvider, (_, next) {
      if (next == null) _incomingShown = _incomingSeen = false; // handed to a tool or cancelled
      _maybeOpenIncoming();
    });
    ref.listen(jobsProvider, (_, _) {
      _maybeOpenIncoming();
      ref.read(indexQueueProvider).wake(); // a job that ended frees the indexer
    });
    ref.listen(settingsProvider.select((s) => s.onboardingDone), (_, _) {
      _maybeOpenIncoming();
      _maybeOpenShortcut();
    });
    ref.listen(shortcutRouteProvider, (_, _) => _maybeOpenShortcut());
    ref.listen(appLockProvider, (before, now) {
      if (before == LockStatus.unlocked && now == LockStatus.locked) _coverIfLocked();
    });
    ref.listen(settingsProvider.select((s) => (s.lockScope, s.lockEnabled, s.lockHideRecents)), (_, _) => _applyScreenPrivacy());
    ref.listen(tourControllerProvider.select((t) => t.active), (_, _) => _maybeOpenShortcut());
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
      scaffoldMessengerKey: rootMessengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
