import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/operation/jobs_controller.dart';
import '../core/providers.dart';
import '../core/widgets/pdf_thumbnail.dart';
import '../features/incoming/incoming_controller.dart';
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
  late final GoRouter _router = buildRouter(onboarded: ref.read(settingsProvider).onboardingDone);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerFontLicence();
    _router.routerDelegate.addListener(_maybeOpenIncoming);
    _router.routerDelegate.addListener(_maybeOpenShortcut);
    // FR-SHR-03: files from a share or "Open with", cold (now) or warm (stream).
    // FR-SCN-22: the launcher shortcut's route, the same way.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(incomingProvider.notifier).start());
      unawaited(ref.read(shortcutRouteProvider.notifier).start());
    });
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
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_maybeOpenIncoming);
    _router.routerDelegate.removeListener(_maybeOpenShortcut);
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
    ref.listen(jobsProvider, (_, _) => _maybeOpenIncoming());
    ref.listen(settingsProvider.select((s) => s.onboardingDone), (_, _) {
      _maybeOpenIncoming();
      _maybeOpenShortcut();
    });
    ref.listen(shortcutRouteProvider, (_, _) => _maybeOpenShortcut());
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
