import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/widgets/pdf_thumbnail.dart';
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
  }

  /// Plus Jakarta Sans is bundled, so its OFL must appear on the licences page.
  static bool _licenceAdded = false;
  static void _registerFontLicence() {
    if (_licenceAdded) return;
    _licenceAdded = true;
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], text);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
