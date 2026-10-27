// UI-REF-01: goldens for Home, a tool screen, Processing and Result in
// light/dark at compact and expanded widths.
//
// Tagged `golden`: pixels differ between macOS and Linux font rendering, so CI
// runs `flutter test --exclude-tags golden`; run these locally on macOS with
// `flutter test --tags golden` (add `--update-goldens` after an intended change).
@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

/// Seeds the jobs map so Processing and Result render without running a tool.
class _SeededJobs extends JobsController {
  _SeededJobs(this.seed);
  final Map<String, LiveJob> seed;
  @override
  Map<String, LiveJob> build() => seed;
}

LiveJob _job(String id, ToolId tool, JobState state) =>
    LiveJob(id: id, tool: tool, state: state, cancel: CancelToken(), restart: () => id, inputBytes: 3355443);

final _jobs = {
  'processing': _job('processing', ToolId.pdfMerge, const JobProcessing(Determinate(2, 5, 'stepMerging', unit: ProgressUnit.files))),
  'result': _job(
    'result',
    ToolId.pdfCompress,
    const JobCompleted(JobResult(
      jobId: 'result',
      tool: ToolId.pdfCompress,
      outputPath: '/nonexistent/Report_reduced.pdf',
      outputName: 'Report_reduced.pdf',
      mime: 'application/pdf',
      meta: OutputMeta(bytes: 419840, pages: 12),
      inputBytes: 3355443,
      inputCount: 1,
      duration: Duration(seconds: 3),
    )),
  ),
};

/// Real glyphs instead of the test font's boxes: Roboto + Material Icons from
/// the Flutter SDK, Plus Jakarta Sans from the app's assets.
Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'];
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  if (sdk != null) {
    final dir = '$sdk/bin/cache/artifacts/material_fonts';
    await load('Roboto', ['$dir/Roboto-Regular.ttf', '$dir/Roboto-Medium.ttf', '$dir/Roboto-Bold.ttf']);
    await load('MaterialIcons', ['$dir/MaterialIcons-Regular.otf']);
  }
  await load('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-SemiBold.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await _loadFonts();
  });

  const sizes = {'compact': Size(390, 844), 'expanded': Size(1280, 800)};
  const screens = {'home': null, 'tool': '/tool/image-compress', 'processing': '/job/processing', 'result': '/job/result'};

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in sizes.entries) {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} · ${theme.name} · ${size.key}', (tester) async {
          tester.view.physicalSize = size.value * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

          final h = await tester.runAsync(() => TestHarness.create(store: {
                SettingsRepository.kTheme: theme.name,
                SettingsRepository.kSavedBytes: 50541363,
              }));
          await tester.pumpWidget(h!.app(overrides: [
            if (screen.value?.startsWith('/job/') ?? false) jobsProvider.overrideWith(() => _SeededJobs(_jobs)),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 27, 19, 30)),
          ]));
          await tester.pump(const Duration(milliseconds: 500));
          if (screen.value != null) {
            unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push(screen.value!));
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/${screen.key}_${theme.name}_${size.key}.png'),
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
