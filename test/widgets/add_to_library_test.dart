// T12.3 — Adding documents to My Documents (RELEASE_V1_5 FR-LIB-03/04/05/21,
// §4.5) on the real LibraryRepository: the Result button, the multi-result
// row menu, scans default to "Scans" (or the folder the scan started from),
// Import files (progress, skipped files), the duplicate dialog both ways,
// the S19 "Save to My Documents" row, and the + sheet.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/incoming/incoming_controller.dart';
import 'package:docukit/features/library/application/add_to_library.dart';
import 'package:docukit/features/library/presentation/library_home_screen.dart';
import 'package:docukit/features/library/presentation/widgets/library_tiles.dart';
import 'package:docukit/features/scan/presentation/scan_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

class SeededJobs extends JobsController {
  SeededJobs(this.seed);
  final Map<String, LiveJob> seed;
  @override
  Map<String, LiveJob> build() => seed;
}

LiveJob resultJob(String path, {ToolId tool = ToolId.pdfCompress, String name = 'out.pdf'}) => LiveJob(
      id: 'result',
      tool: tool,
      state: JobCompleted(JobResult(
        jobId: 'result',
        tool: tool,
        outputPath: path,
        outputName: name,
        mime: 'application/pdf',
        meta: const OutputMeta(bytes: 4, pages: 3),
        inputBytes: 3000000,
        inputCount: 1,
        duration: const Duration(seconds: 1),
      )),
      cancel: CancelToken(),
      restart: () => 'result',
      inputBytes: 3000000,
    );

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late Directory src;

  setUp(() => src = Directory.systemTemp.createTempSync('lib_add'));
  tearDown(() => src.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  /// Taps, then waits (real time) until [until] holds: copies and hashing run
  /// on the real clock.
  Future<void> act(WidgetTester tester, Finder f, {bool Function()? until}) async {
    await tester.tap(f);
    for (var i = 0; i < 60; i++) {
      await settle(tester, 1);
      if (until == null ? i >= 10 : until()) break;
    }
    await settle(tester, 2);
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  /// Tiles shorten long names ("Pass….pdf"), so match the tile's document.
  Finder docTile(String name) => find.byWidgetPredicate((w) => w is DocTile && w.doc.name == name);

  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator, skipOffstage: false).first));
  LibraryRepository repo(WidgetTester tester) => c(tester).read(libraryRepositoryProvider);
  GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(HomeScreen, skipOffstage: false)));

  Future<List<LibraryDoc>> allDocs(WidgetTester tester, {String? folderId}) async =>
      (await tester.runAsync(() => repo(tester).watchDocs(folderId: folderId).first))!;

  Future<void> open(WidgetTester tester, {Map<String, LiveJob>? jobs, String route = ''}) async {
    tester.view.physicalSize = const Size(420, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: {'lib_intro_seen': true})))!;
    await tester.pumpWidget(h.app(overrides: [if (jobs != null) jobsProvider.overrideWith(() => SeededJobs(jobs))]));
    await tester.pump(const Duration(milliseconds: 100));
    if (route.isNotEmpty) unawaited(router(tester).push(route));
    await settle(tester);
  }

  String file(WidgetTester tester, String name, String content) =>
      (File(p.join(src.path, '${DateTime.now().microsecondsSinceEpoch}_$name'))..writeAsStringSync(content)).path;

  PickedFile picked(String path, String name, {bool pdf = true, ValidationStatus status = const ValidationStatus.ok()}) => PickedFile(
        path: path,
        displayName: name,
        type: pdf ? SniffedType.pdf : SniffedType.jpeg,
        sizeBytes: File(path).existsSync() ? File(path).lengthSync() : 10,
        pdf: pdf ? const PdfMeta(pageCount: 2) : null,
        image: pdf ? null : const ImageMeta(format: SniffedType.jpeg, width: 40, height: 30, hasAlpha: false),
        status: status,
      );

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  Future<void> tapSaveButton(WidgetTester tester) async {
    final b = find.byKey(const ValueKey('save-to-library'));
    await tester.ensureVisible(b);
    await settle(tester, 2);
    await act(tester, b, until: () => shows('Save to…'));
  }

  testWidgets('FR-LIB-03 Result: Save to My Documents → S43 "Save to…" → saved with the tool, pages and View', (tester) async {
    late String out;
    await tester.runAsync(() async => out = file(tester, 'out.pdf', '%PDF result'));
    await open(tester, jobs: {'result': resultJob(out)}, route: '/job/result');
    await tapSaveButton(tester);
    expect(find.text('Save to…'), findsOneWidget);
    await act(tester, find.text('Save here'), until: () => shows('Saved to My Documents'));
    expect(find.text('Saved to My Documents'), findsOneWidget);
    final d = (await allDocs(tester)).single;
    expect((d.name, d.source, d.sourceTool, d.pageCount, d.folderId), ('out.pdf', DocSource.result, ToolId.pdfCompress, 3, null));
    expect(File(out).existsSync(), isTrue, reason: 'the result stays where it was (copied in)');
    await act(tester, find.text('View'), until: () => find.byType(LibraryScreen).evaluate().isNotEmpty);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-LIB-21 duplicate: Add copy keeps both; Open existing goes to its folder', (tester) async {
    late String out;
    await tester.runAsync(() async => out = file(tester, 'out.pdf', '%PDF same'));
    await open(tester, jobs: {'result': resultJob(out)}, route: '/job/result');
    final ids = (await tester.runAsync(() => repo(tester).createFolder('IDs')))!;
    await tester.runAsync(() => repo(tester).addFile(file(tester, 'x.pdf', '%PDF same'),
        displayName: 'Passport.pdf', folderId: ids.id, source: DocSource.import, mime: 'application/pdf'));
    await settle(tester, 2);

    await tapSaveButton(tester);
    await act(tester, find.text('Save here'), until: () => shows('Already in My Documents'));
    expect(find.text('This file is already saved as Passport.pdf in IDs. Add another copy?'), findsOneWidget);
    await act(tester, find.text('Add copy'), until: () => shows('Saved to My Documents'));
    expect((await allDocs(tester)).single.name, 'out.pdf');
    expect((await allDocs(tester, folderId: ids.id)).single.name, 'Passport.pdf');

    await tester.pump(const Duration(seconds: 5)); // the snack goes
    await tapSaveButton(tester);
    await act(tester, find.text('Save here'), until: () => shows('Already in My Documents'));
    await act(tester, find.text('Open existing'), until: () => docTile('Passport.pdf').evaluate().isNotEmpty);
    expect(router(tester).state.uri.toString(), '/library/folder/${ids.id}');
    expect(docTile('Passport.pdf'), findsOneWidget, reason: 'the folder that holds the existing copy');
    expect((await allDocs(tester)).length, 1, reason: 'nothing more added');
    await finish(tester);
  });

  testWidgets('FR-LIB-05 scan: "Scans" is preselected (created on demand, removed again on cancel)', (tester) async {
    late String out;
    await tester.runAsync(() async => out = file(tester, 'scan.pdf', '%PDF scan'));
    await open(tester, jobs: {'result': resultJob(out, tool: ToolId.scanDocument, name: 'Scan 2026-10-31.pdf')}, route: '/job/result');
    await tapSaveButton(tester);
    expect(find.text('Scans'), findsOneWidget);
    await tester.tapAt(const Offset(200, 60));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    expect(await tester.runAsync(() => repo(tester).allFolders()), isEmpty, reason: 'no empty "Scans" left behind');

    await tapSaveButton(tester);
    await act(tester, find.text('Save here'), until: () => shows('Saved to My Documents'));
    final scans = (await tester.runAsync(() => repo(tester).allFolders()))!.single;
    expect(scans.name, 'Scans');
    final d = (await allDocs(tester, folderId: scans.id)).single;
    expect((d.source, d.sourceTool), (DocSource.scan, ToolId.scanDocument));
    await finish(tester);
  });

  testWidgets('S41 + → Scan a document: opens the scanner; that scan\'s save preselects the folder, once', (tester) async {
    await open(tester);
    final travel = (await tester.runAsync(() => repo(tester).createFolder('Travel')))!;
    unawaited(router(tester).push('/library/folder/${travel.id}'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('lib-fab')));
    await settle(tester);
    expect(find.text('Import files'), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lib-add-scan')));
    await settle(tester);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(c(tester).read(scanTargetFolderProvider), travel.id);
    expect(c(tester).read(scanTargetFolderProvider.notifier).take(), travel.id);
    expect(c(tester).read(scanTargetFolderProvider), isNull);
    await finish(tester);
  });

  testWidgets('a scan started from a folder saves there by default, not to "Scans"', (tester) async {
    late String out;
    await tester.runAsync(() async => out = file(tester, 'scan.pdf', '%PDF scan2'));
    await open(tester, jobs: {'result': resultJob(out, tool: ToolId.scanDocument)}, route: '/job/result');
    final travel = (await tester.runAsync(() => repo(tester).createFolder('Travel')))!;
    c(tester).read(scanTargetFolderProvider.notifier).set(travel.id);
    await tapSaveButton(tester);
    await act(tester, find.text('Save here'), until: () => shows('Saved to My Documents'));
    expect((await allDocs(tester, folderId: travel.id)).length, 1);
    expect((await tester.runAsync(() => repo(tester).allFolders()))!.map((f) => f.name), ['Travel']);
    await finish(tester);
  });

  testWidgets('S22 row menu: Save to My Documents saves that output', (tester) async {
    late String out;
    await tester.runAsync(() async => out = file(tester, 'part_1.pdf', '%PDF part'));
    final job = LiveJob(
      id: 'multi',
      tool: ToolId.pdfSplit,
      state: JobCompletedMulti(MultiJobResult(
        jobId: 'multi',
        tool: ToolId.pdfSplit,
        output: MultiOutput([
          OutputOk(0, 'in.pdf', path: out, relPath: 'multi/part_1.pdf', name: 'part_1.pdf', mime: 'application/pdf',
              meta: const OutputMeta(bytes: 9)),
        ]),
        inputBytes: 9,
        inputCount: 1,
        duration: const Duration(seconds: 1),
      )),
      cancel: CancelToken(),
      restart: () => 'multi',
      inputBytes: 9,
      multi: true,
    );
    await open(tester, jobs: {'multi': job}, route: '/job/multi');
    await tester.tap(find.byTooltip('More').first);
    await settle(tester);
    await act(tester, find.text('Save to My Documents').last, until: () => shows('Save to…'));
    await act(tester, find.text('Save here'), until: () => shows('Saved to My Documents'));
    final d = (await allDocs(tester)).single;
    expect((d.name, d.sourceTool), ('part_1.pdf', ToolId.pdfSplit));
    await finish(tester);
  });

  testWidgets('FR-LIB-04 empty state → Import files → PDF files: adds the valid ones, counts the rest, discards the draft', (tester) async {
    await open(tester, route: '/library');
    expect(find.byKey(const ValueKey('lib-empty-import')), findsOneWidget);
    expect(find.byKey(const ValueKey('lib-empty-scan')), findsOneWidget);
    await tester.runAsync(() async => h.gateway.nextPdfs = [
          picked(file(tester, 'a.pdf', '%PDF a'), 'a.pdf'),
          picked(file(tester, 'b.pdf', '%PDF b'), 'b.pdf'),
          picked(file(tester, 'locked.pdf', '%PDF locked'), 'locked.pdf',
              status: const ValidationStatus.invalid(AppErrorCode.encryptedDocument)),
          picked('/nonexistent/x.docx', 'x.docx', status: const ValidationStatus.invalid(AppErrorCode.unsupportedFormat)),
        ]);
    await tester.tap(find.byKey(const ValueKey('lib-empty-import')));
    await settle(tester);
    var sawProgress = false;
    await act(tester, find.text('PDF files'), until: () {
      sawProgress |= find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
      return shows('3 documents added · 1 file couldn\'t be added');
    });
    expect(find.text('3 documents added · 1 file couldn\'t be added'), findsOneWidget);
    expect(sawProgress, isTrue, reason: '"Adding n of 3…" while copying');
    expect((await allDocs(tester)).map((d) => (d.name, d.source)).toSet(),
        {('a.pdf', DocSource.import), ('b.pdf', DocSource.import), ('locked.pdf', DocSource.import)});
    expect(h.gateway.discarded.where((d) => d.startsWith('lib-import-')), hasLength(1));
    await finish(tester);
  });

  testWidgets('FR-LIB-05 S19: Save to My Documents keeps all received files, then shows My Documents', (tester) async {
    await open(tester);
    await tester.runAsync(() async => h.gateway.nextIncoming = [
          picked(file(tester, 'a.jpg', 'jpg a'), 'a.jpg', pdf: false),
          picked(file(tester, 'b.pdf', '%PDF in'), 'b.pdf'),
        ]);
    h.native.send(const IncomingBatch(dir: '/nonexistent/incoming/x', files: [(path: '/x/a', name: 'a')]));
    await settle(tester);
    await act(tester, find.byKey(const ValueKey('incoming-save-to-library')), until: () => shows('Save to…'));
    await act(tester, find.text('Save here'), until: () => find.byType(LibraryScreen).evaluate().isNotEmpty);
    await settle(tester);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect((await allDocs(tester)).map((d) => (d.name, d.source)).toSet(),
        {('a.jpg', DocSource.incoming), ('b.pdf', DocSource.incoming)});
    expect(c(tester).read(incomingProvider), isNull, reason: 'the incoming batch is finished');
    await finish(tester);
  });
}
