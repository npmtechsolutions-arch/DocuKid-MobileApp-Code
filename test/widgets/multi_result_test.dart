// T8.4 — S22 multi-result, multi jobs in History/Details, ads (RELEASE_V1_1
// §3 S22, §8.2; ADS §3.1; ADR-040).
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/ad_slots.dart';
import 'package:docukit/core/ads/ads_config.dart';
import 'package:docukit/core/ads/ads_controller.dart';
import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/errors/error_copy.dart';
import 'package:docukit/core/files/file_gateway.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

class SeededJobs extends JobsController {
  SeededJobs(this.seed);
  final Map<String, LiveJob> seed;
  @override
  Map<String, LiveJob> build() => seed;
}

OutputOk ok(int i, {int bytes = 1000, int? before = 4000, String mime = 'image/jpeg', Map<String, Object?> flags = const {}}) =>
    OutputOk(i, 'IMG_$i.jpg',
        path: '/nonexistent/out_$i',
        relPath: 'multi/out_$i',
        name: mime == 'application/pdf' ? 'part_$i.pdf' : 'IMG_${i}_compressed.jpg',
        mime: mime,
        meta: OutputMeta(bytes: bytes, flags: flags),
        beforeBytes: before);

LiveJob multiJob(List<OutputItem> items, {ToolId tool = ToolId.imageCompress}) => LiveJob(
      id: 'multi',
      tool: tool,
      state: JobCompletedMulti(MultiJobResult(
        jobId: 'multi',
        tool: tool,
        output: MultiOutput(items),
        inputBytes: 12000,
        inputCount: items.length,
        duration: const Duration(seconds: 2),
      )),
      cancel: CancelToken(),
      restart: () => 'multi',
      inputBytes: 12000,
      multi: true,
    );

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late AppLocalizations l;
  setUpAll(() async => l = await AppLocalizations.delegate.load(const Locale('en')));

  Future<TestHarness> open(WidgetTester tester, Map<String, LiveJob> jobs, {String route = '/job/multi'}) async {
    tester.view.physicalSize = const Size(400, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app(overrides: [jobsProvider.overrideWith(() => SeededJobs(jobs))]));
    await tester.pump(const Duration(milliseconds: 300));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push(route));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('all done: header, batch totals, one row per file with its saving', (tester) async {
    await open(tester, {'multi': multiJob([ok(0), ok(1), ok(2)])});
    expect(find.text('All done'), findsOneWidget);
    expect(find.text('Before 12 KB → After 2.9 KB'), findsOneWidget);
    // Names may be middle-ellipsized (the test font is wide), so match the full text.
    expect(find.byWidgetPredicate((w) => w is MiddleEllipsisText && w.text == 'IMG_0_compressed.jpg'), findsOneWidget);
    expect(find.textContaining('75% smaller'), findsNWidgets(3));
    for (final label in ['Save all…', 'Save as ZIP', 'Share all']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Original not changed.'), findsNothing);
    await finish(tester);
  });

  testWidgets('partial: "2 of 3 done", the failed row names the error and keeps the original', (tester) async {
    await open(tester, {
      'multi': multiJob([ok(0), const OutputFailed(1, 'scan.webp', AppErrorCode.corruptFile), ok(2)]),
    });
    expect(find.text('2 of 3 done'), findsOneWidget);
    expect(find.text('scan.webp'), findsOneWidget);
    final title = errorCopy(l, const AppError(AppErrorCode.corruptFile)).title;
    expect(find.text(l.multiItemFailed(title)), findsOneWidget);
    await finish(tester);
  });

  testWidgets('target missed: "Closest to …" on that row (FR-BAT-11)', (tester) async {
    await open(tester, {
      'multi': multiJob([ok(0, flags: {'targetMissed': true, 'targetBytes': 102400})]),
    });
    expect(find.textContaining('Closest to 100 KB'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('split / PDF to images: count + total instead of before → after', (tester) async {
    await open(tester, {
      'multi': multiJob([for (var i = 0; i < 3; i++) ok(i, before: null, mime: 'application/pdf')], tool: ToolId.pdfSplit),
    });
    expect(find.text('3 PDFs · 2.9 KB'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Save all: one folder, snack names the folder', (tester) async {
    final h = await open(tester, {'multi': multiJob([ok(0), ok(1)])});
    await tester.tap(find.text('Save all…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.gateway.savedMany.single.map((i) => i.name), ['IMG_0_compressed.jpg', 'IMG_1_compressed.jpg']);
    expect(find.text('Saved 2 files to DocuKit'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Save all partial: "Saved 1 of 2…", Try again re-sends only the failed file', (tester) async {
    final h = await open(tester, {'multi': multiJob([ok(0), ok(1)])});
    h.gateway.nextSaveMany = const SavedMany(saved: 1, failed: 1, failedIndexes: [1], folderName: 'DocuKit');
    await tester.tap(find.text('Save all…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Saved 1 of 2. 1 couldn't be written."), findsOneWidget);
    h.gateway.nextSaveMany = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.gateway.savedMany.last.map((i) => i.name), ['IMG_1_compressed.jpg']);
    await finish(tester);
  });

  testWidgets('Save all cancelled: no message', (tester) async {
    final h = await open(tester, {'multi': multiJob([ok(0), ok(1)])});
    h.gateway.nextSaveMany = const SaveManyCancelled();
    await tester.tap(find.text('Save all…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsNothing);
    await finish(tester);
  });

  testWidgets('Share all with more than 50 files offers one ZIP instead (FR-BAT-04)', (tester) async {
    await open(tester, {'multi': multiJob([for (var i = 0; i < 51; i++) ok(i)])});
    await tester.tap(find.text('Share all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l.multiShareTooMany), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    await finish(tester);
  });

  testWidgets('ads: ADMOB_BANNER_MAIN slot and the AD-2 slot (ADS §3.1)', (tester) async {
    await open(tester, {'multi': multiJob([ok(0), ok(1)])});
    expect(tester.widgetList<AppBottomBanner>(find.byType(AppBottomBanner)).map((b) => b.unit), [AdUnit.bannerMain]);
    expect(find.byType(ResultAdSlot, skipOffstage: false), findsOneWidget);
    await finish(tester);
  });

  testWidgets('every item failed → S18 with "None of the files could be processed"', (tester) async {
    await open(tester, {
      'multi': LiveJob(
        id: 'multi',
        tool: ToolId.imageCompress,
        state: const JobFailed(AppError(AppErrorCode.corruptFile)),
        cancel: CancelToken(),
        restart: () => 'multi',
        inputBytes: 1,
        multi: true,
      ),
    });
    expect(find.text(l.multiAllFailed), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a batch counts as ONE completed job for AD-3, and its savings are added up', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final inputs = await tester.runAsync(() async {
      final dir = h.paths.jobIn('draft')..createSync(recursive: true);
      return [
        for (var i = 0; i < 3; i++)
          fakeInput((File(p.join(dir.path, '$i.jpg'))..writeAsBytesSync(List.filled(100, 1))).path),
      ];
    });
    final id = container.read(jobsProvider.notifier).startMulti(FakeMultiTool(3), inputs!, const FakeOptions());
    for (var i = 0; i < 50 && !(container.read(jobsProvider)[id]?.state.isCompleted ?? false); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(container.read(jobsProvider)[id]!.state, isA<JobCompletedMulti>());
    expect(h.store.get(AdsController.kLifetimeJobs), 1);
    // FakeMultiTool writes 1, 2, 3 bytes for 100-byte inputs.
    expect(container.read(settingsProvider).statsTotalSavedBytes, 300 - 6);
    await finish(tester);
  });

  testWidgets('History + Details: a PARTIAL batch shows "2 of 3 done" and lists its files', (tester) async {
    tester.view.physicalSize = const Size(400, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() async {
      final h = await TestHarness.create();
      final dir = h.paths.jobIn('draft')..createSync(recursive: true);
      final inputs = [
        for (var i = 0; i < 3; i++)
          fakeInput((File(p.join(dir.path, '$i.jpg'))..writeAsBytesSync(List.filled(100, 1))).path),
      ];
      await JobRunner(
        paths: h.paths,
        history: HistoryRepository(h.db),
        outputs: OutputsRepository(h.paths),
        device: h.device,
      ).runMulti(
        jobId: 'op-multi',
        op: FakeMultiTool(3, fail: {1: const AppError(AppErrorCode.corruptFile)}),
        inputs: inputs,
        options: const FakeOptions(),
        cancel: CancelToken(),
        emit: (_) {},
      );
      return h;
    }))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    unawaited(router.push('/history'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('2 of 3 done'), findsWidgets);

    unawaited(router.push('/history/op-multi'));
    await tester.pump();
    // The file list is read from the database (real async).
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('out_0.jpg'), findsOneWidget);
    expect(find.text('out_2.jpg'), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget, reason: 'the failed item keeps its source name');
    expect(find.text('Save all…'), findsOneWidget);
    expect(find.text('Save as ZIP'), findsOneWidget);
    await finish(tester);
  });
}
