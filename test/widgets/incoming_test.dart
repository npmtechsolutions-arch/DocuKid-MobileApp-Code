// T8.12 — Share to DocuKit, Dart side (RELEASE_V1_1 FR-SHR-03…07, S19,
// §8.2: S19 sections and filtered tools, no banner).
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/incoming/incoming_controller.dart';
import 'package:docukit/features/incoming/incoming_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tools/tool_inputs.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

const batch = IncomingBatch(dir: '/nonexistent/incoming/x', files: [(path: '/x/a', name: 'a')]);

PickedFile unknownFile(String name) => PickedFile(
      path: '/nonexistent/$name',
      displayName: name,
      type: SniffedType.unknown,
      sizeBytes: 10,
      status: const ValidationStatus.invalid(AppErrorCode.unsupportedFormat),
    );

class SeededJobs extends JobsController {
  SeededJobs(this.seed);
  final Map<String, LiveJob> seed;
  @override
  Map<String, LiveJob> build() => seed;

  /// The job finished and its result was dismissed.
  void end() => state = const {};
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> open(WidgetTester tester, {bool onboarded = true, bool tourDone = true, Map<String, LiveJob>? jobs}) async {
    tester.view.physicalSize = const Size(400, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create(onboarded: onboarded, tourDone: tourDone)))!;
    await tester.pumpWidget(h.app(overrides: [if (jobs != null) jobsProvider.overrideWith(() => SeededJobs(jobs))]));
    // A running job shows a spinner on Home, which never settles.
    jobs == null ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 500));
    return h;
  }

  Future<void> deliver(WidgetTester tester, TestHarness h, List<PickedFile> files, {bool settle = true}) async {
    h.gateway.nextIncoming = files;
    h.native.send(batch);
    await tester.pump();
    settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('3 photos → S19 with the image tools only; no banner (FR-SHR-05)', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, [fakeImage('a.jpg'), fakeImage('b.jpg'), fakeImage('c.jpg')]);
    expect(find.byType(IncomingScreen), findsOneWidget);
    expect(find.text('Received 3 files'), findsOneWidget);
    expect(find.text('3 images'), findsOneWidget);
    for (final t in ['Image Compressor', 'Image Resizer', 'Convert Image', 'Images to PDF']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Merge PDFs'), findsNothing);
    expect(find.byType(AppBottomBanner), findsNothing);
    await finish(tester);
  });

  testWidgets('1 PDF → the PDF tools, Merge says it needs one more', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, [fakePdf('doc.pdf')]);
    expect(find.text('1 PDF'), findsOneWidget);
    for (final t in ['Organize Pages', 'Split PDF', 'PDF to Images', 'Reduce PDF Size', 'Merge PDFs']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Needs one more PDF. You can add it next.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a second share while S19 waits joins the session: two sections (FR-SHR-07, R36)', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, [fakeImage('a.jpg'), fakeImage('b.jpg'), fakeImage('c.jpg')]);
    await deliver(tester, h, [fakePdf('doc.pdf')]);
    expect(find.text('Received 4 files'), findsOneWidget);
    expect(find.text('3 images'), findsOneWidget);
    expect(find.text('1 PDF'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('nothing usable → "DocuKit can\'t work with this file type."', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, [unknownFile('song.mp3')]);
    expect(find.text("DocuKit can't work with this file type."), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Cancel deletes the temp copies and goes Home (R36)', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, [fakePdf('doc.pdf')]);
    final draft = ProviderScope.containerOf(tester.element(find.byType(IncomingScreen))).read(incomingProvider)!.draftId;
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(h.gateway.discarded, contains(draft));
    expect(find.byType(IncomingScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('choosing a tool opens it with the files already in (FR-SHR-04)', (tester) async {
    final h = await open(tester);
    // Real files: they are moved into the tool's own draft folder.
    final files = (await tester.runAsync(() async {
      final dir = h.paths.jobIn('incoming_t')..createSync(recursive: true);
      return [
        for (final n in ['a.jpg', 'b.jpg'])
          PickedFile(
            path: (File('${dir.path}/$n')..writeAsBytesSync([1, 2, 3])).path,
            displayName: n,
            type: SniffedType.jpeg,
            sizeBytes: 3,
            image: const ImageMeta(format: SniffedType.jpeg, width: 10, height: 10),
          ),
      ];
    }))!;
    await deliver(tester, h, files);
    await tester.tap(find.text('Convert Image'));
    // Each real file operation needs real time, then a pump.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    final moved = ProviderScope.containerOf(tester.element(find.byType(Scaffold).last)).read(toolInputsProvider(ToolId.imageConvert));
    expect(moved.files.every((f) => f.path.contains(moved.draftId)), isTrue, reason: 'moved into the tool draft');
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));
    final inputs = container.read(toolInputsProvider(ToolId.imageConvert));
    expect(inputs.files.map((f) => f.displayName), ['a.jpg', 'b.jpg']);
    expect(container.read(incomingProvider), isNull);
    await finish(tester);
  });

  testWidgets('during a running job the files wait with a banner; S19 opens once the job ends (FR-SHR-03)', (tester) async {
    final jobs = {
      'run': LiveJob(
        id: 'run',
        tool: ToolId.pdfCompress,
        state: const JobProcessing(Determinate(1, 3, 'stepOptimizing')),
        cancel: CancelToken(),
        restart: () => 'run',
        inputBytes: 10,
      ),
    };
    final h = await open(tester, jobs: jobs);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await deliver(tester, h, [fakePdf('doc.pdf')], settle: false);
    expect(find.byType(IncomingScreen), findsNothing, reason: 'never over a running job');
    expect(container.read(incomingProvider), isNotNull);
    // The job screen shows the waiting banner.
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/job/run'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.descendant(of: find.byType(InlineBanner), matching: find.text('1 file received. Open when this job finishes.')),
        findsOneWidget);
    // The job ends; the user taps Done, which goes Home and then dismisses
    // the job (the result screen's order) → S19 opens.
    GoRouter.of(tester.element(find.byType(Scaffold).last)).go('/');
    await tester.pump();
    (container.read(jobsProvider.notifier) as SeededJobs).end();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(IncomingScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('not before onboarding is done', (tester) async {
    final h = await open(tester, onboarded: false);
    await deliver(tester, h, [fakePdf('doc.pdf')]);
    expect(find.byType(IncomingScreen), findsNothing);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(IncomingScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('caps: the first 50 images are kept, with the truncation note (FR-SHR-06)', (tester) async {
    final h = await open(tester);
    await deliver(tester, h, [for (var i = 0; i < 53; i++) fakeImage('p$i.jpg')]);
    expect(find.text('Received 50 files'), findsOneWidget);
    expect(find.text('Only the first 50 files were added.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the Quick tour never starts over S19 (found on the emulator, R36)', (tester) async {
    // As on the emulator: files arrive during onboarding, then Get started.
    final h = await open(tester, onboarded: false, tourDone: false);
    await deliver(tester, h, [fakePdf('doc.pdf')], settle: false);
    await tester.tap(find.text('Get started'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(IncomingScreen), findsOneWidget);
    expect(find.text('Quick tour'), findsNothing);
    await finish(tester);
  });

  testWidgets('files that arrive while a result is showing wait until the user leaves it (FR-SHR-03, R36)', (tester) async {
    final jobs = {
      'done': LiveJob(
        id: 'done',
        tool: ToolId.pdfMerge,
        state: const JobFailed(AppError(AppErrorCode.processingFailed)),
        cancel: CancelToken(),
        restart: () => 'done',
        inputBytes: 10,
      ),
    };
    final h = await open(tester, jobs: jobs);
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/job/done'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await deliver(tester, h, [fakePdf('doc.pdf')], settle: false);
    expect(find.byType(IncomingScreen), findsNothing, reason: 'never over a finished job\'s screen');
    GoRouter.of(tester.element(find.byType(Scaffold).last)).go('/');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(IncomingScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a share whose files couldn\'t be read still opens S19 with the error card', (tester) async {
    final h = await open(tester);
    h.gateway.nextIncoming = const [];
    h.native.send(const IncomingBatch(dir: '/nonexistent/incoming/y', files: [], failed: 1));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(IncomingScreen), findsOneWidget);
    expect(find.text("DocuKit can't work with this file type."), findsOneWidget);
    await finish(tester);
  });
}
