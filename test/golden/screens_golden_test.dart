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

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

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
  // S22 (T8.4): a batch of 4 with one failure and one missed target.
  'multi': LiveJob(
    id: 'multi',
    tool: ToolId.imageCompress,
    state: JobCompletedMulti(MultiJobResult(
      jobId: 'multi',
      tool: ToolId.imageCompress,
      output: MultiOutput([
        _ok(0, 'IMG_2041_compressed.jpg', 419840, 3355443),
        _ok(1, 'IMG_2042_compressed.jpg', 397312, 2516582),
        _ok(2, 'IMG_2043_compressed.jpg', 114688, 1048576, missed: 102400),
        const OutputFailed(3, 'scan.webp', AppErrorCode.corruptFile),
      ]),
      inputBytes: 7340032,
      inputCount: 4,
      duration: const Duration(seconds: 6),
    )),
    cancel: CancelToken(),
    restart: () => 'multi',
    inputBytes: 7340032,
    multi: true,
  ),
};

OutputOk _ok(int i, String name, int bytes, int before, {int? missed}) => OutputOk(i, 'IMG_204${i + 1}.jpg',
    path: '/nonexistent/$name',
    relPath: 'multi/$name',
    name: name,
    mime: 'image/jpeg',
    meta: OutputMeta(bytes: bytes, flags: {if (missed != null) 'targetMissed': true, 'targetBytes': ?missed}),
    beforeBytes: before);

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

/// Two folders and four PDFs (one starred) with fixed dates, for S40.
Future<void> _seedLibrary(TestHarness h) async {
  final repo = LibraryRepositoryImpl(h.db, h.paths.supportRoot, clock: () => DateTime(2026, 10, 20, 10));
  final ids = await repo.createFolder('IDs');
  await repo.createFolder('Bills');
  final src = Directory(p.join(h.paths.cacheRoot.path, 'golden_src'))..createSync(recursive: true);
  for (final (name, folder) in [
    ('Passport.pdf', ids.id),
    ('Lease agreement.pdf', null),
    ('Insurance policy 2026.pdf', null),
    ('Payslip October.pdf', null),
    ('Tax return.pdf', null),
  ]) {
    final f = File(p.join(src.path, name))..writeAsStringSync('%PDF $name');
    final r = await repo.addFile(f.path, displayName: name, folderId: folder, source: DocSource.import, mime: 'application/pdf', pageCount: 2);
    if (name.startsWith('Lease') && r is Added) await repo.setStarred([r.doc.id], true);
  }
  await repo.dispose();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await _loadFonts();
  });

  const sizes = {'compact': Size(390, 844), 'expanded': Size(1280, 800)};
  const screens = {
    'home': null,
    'tool': '/tool/image-compress',
    'processing': '/job/processing',
    'result': '/job/result',
    'multi': '/job/multi',
    // 1.5 My Documents (T12.2): S39 first visit; S40 with folders and documents.
    'library_intro': '/library',
    'library': '/library',
  };

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
                if (screen.key == 'library') SettingsRepository.kLibIntroSeen: true,
              }));
          if (screen.key == 'library') await tester.runAsync(() => _seedLibrary(h!));
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
