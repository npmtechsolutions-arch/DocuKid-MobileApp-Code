import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app/app.dart';
import 'app/bootstrap/sweeps.dart';
import 'core/files/paths.dart';
import 'core/providers.dart';
import 'data/db/app_database.dart';
import 'data/settings/settings_repository.dart';

/// Bootstrap: bindings, PDFium, paths, prefs, DB, then the launch sweeps after
/// the first frame (ARCHITECTURE §5.3).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  await pdfrxFlutterInitialize();
  final paths = await AppPaths.resolve();
  final store = await PrefsStore.open();
  final settingsRepo = SettingsRepository(
    store,
    countryCode: WidgetsBinding.instance.platformDispatcher.locale.countryCode,
  );
  final db = AppDatabase.open();

  final container = ProviderContainer(overrides: [
    appPathsProvider.overrideWithValue(paths),
    databaseProvider.overrideWithValue(db),
    settingsRepositoryProvider.overrideWithValue(settingsRepo),
  ]);

  runApp(UncontrolledProviderScope(container: container, child: const DocuKitApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(runLaunchSweeps(
      paths: paths,
      history: container.read(historyRepositoryProvider),
      outputs: container.read(outputsRepositoryProvider),
      settings: settingsRepo,
      retention: container.read(settingsProvider).outputRetention,
      now: DateTime.now(),
    ));
  });
}
