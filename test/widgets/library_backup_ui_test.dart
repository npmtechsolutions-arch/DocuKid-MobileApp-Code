// T12.8 — storage and backup in the UI (RELEASE_V1_5 S46, S41, S16;
// FR-LIB-17–20): "My Documents uses …", the backup note, Export library →
// progress → system Save dialog → "Library exported", Export folder as ZIP,
// Import backup → summary, not-a-backup, Settings → Storage used split, and
// the launch housekeeping (iOS backup exclusion call, orphan sweep).
import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/library/presentation/library_settings_screen.dart';
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

  setUp(() => src = Directory.systemTemp.createTempSync('lib_backup_ui'));
  tearDown(() => src.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await settle(tester, 1);
    }
    await settle(tester, 2);
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator, skipOffstage: false).first));
  LibraryRepository repo(WidgetTester tester) => c(tester).read(libraryRepositoryProvider);
  GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(HomeScreen, skipOffstage: false)));

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: {'lib_intro_seen': true})))!;
    await tester.pumpWidget(h.app());
    await settle(tester);
  }

  Future<LibraryDoc> addDoc(WidgetTester tester, String name, String content, {String? folderId}) async {
    final f = File(p.join(src.path, name))..writeAsStringSync(content);
    final r = (await tester.runAsync(() =>
        repo(tester).addFile(f.path, displayName: name, folderId: folderId, source: DocSource.import, mime: 'application/pdf')))!;
    await settle(tester, 2);
    return (r as Added).doc;
  }

  Future<void> push(WidgetTester tester, String route) async {
    unawaited(router(tester).push(route));
    await settle(tester);
  }

  List<String> entries(String zip) {
    final input = InputFileStream(zip);
    try {
      return [for (final f in ZipDecoder().decodeStream(input).files) if (f.isFile) f.name]..sort();
    } finally {
      input.closeSync();
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('FR-LIB-17/20 S46: "My Documents uses …" and the backup note; Settings shows Recent and My Documents', (tester) async {
    await open(tester);
    await addDoc(tester, 'a.pdf', '%PDF aaaa');
    await addDoc(tester, 'b.pdf', '%PDF bbbb');
    await push(tester, '/settings/library');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-uses')), 300);
    await waitFor(tester, () => shows('My Documents uses 18 B · 2 documents'));
    expect(find.text('My Documents uses 18 B · 2 documents'), findsOneWidget);
    expect(find.textContaining("My Documents isn't included in iCloud or Google backups."), findsOneWidget);
    router(tester).pop();
    await push(tester, '/settings');
    await tester.scrollUntilVisible(find.textContaining('Recent '), 300);
    expect(find.textContaining(' · My Documents 18 B'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-LIB-18 Export library: progress, then the Save dialog with DocuKit-Backup-<date>.zip; "Library exported"', (tester) async {
    await open(tester);
    final ids = (await tester.runAsync(() => repo(tester).createFolder('IDs')))!;
    await addDoc(tester, 'Passport.pdf', '%PDF passport', folderId: ids.id);
    await addDoc(tester, 'Lease.pdf', '%PDF lease');
    await push(tester, '/settings/library');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-export')), 300);
    await tester.tap(find.byKey(const ValueKey('set-lib-export')));
    await waitFor(tester, () => shows('Library exported'));
    expect(find.text('Library exported'), findsOneWidget);
    final saved = h.gateway.savedAs.single;
    expect(saved.name, matches(RegExp(r'^DocuKit-Backup-\d{8}\.zip$')));
    expect(saved.mime, 'application/zip');
    final base = saved.name.replaceAll('.zip', '');
    expect(entries(saved.copy!), ['$base/docukit-library.json', '$base/files/IDs/Passport.pdf', '$base/files/Lease.pdf']);
    expect(find.byKey(const ValueKey('export-progress')), findsNothing);
    final jobs = c(tester).read(appPathsProvider).jobsRoot;
    expect(jobs.existsSync() ? jobs.listSync().where((e) => p.basename(e.path).startsWith('lib-export-')) : const [], isEmpty,
        reason: 'the temporary ZIP is removed');
    await finish(tester);
  });

  testWidgets('S41 ⋮ Export folder as ZIP: only that folder', (tester) async {
    await open(tester);
    final ids = (await tester.runAsync(() => repo(tester).createFolder('IDs')))!;
    await addDoc(tester, 'Passport.pdf', '%PDF passport', folderId: ids.id);
    await addDoc(tester, 'Lease.pdf', '%PDF lease');
    await push(tester, '/library/folder/${ids.id}');
    await tester.tap(find.byTooltip('More options'));
    await settle(tester);
    await tester.tap(find.text('Export folder as ZIP'));
    await waitFor(tester, () => h.gateway.savedAs.isNotEmpty);
    final base = h.gateway.savedAs.single.name.replaceAll('.zip', '');
    expect(entries(h.gateway.savedAs.single.copy!), ['$base/docukit-library.json', '$base/files/IDs/Passport.pdf']);
    await finish(tester);
  });

  testWidgets('FR-LIB-19 Import backup: picks a ZIP, merges it, shows the summary; a second import only skips', (tester) async {
    await open(tester);
    await addDoc(tester, 'Passport.pdf', '%PDF passport');
    await addDoc(tester, 'Lease.pdf', '%PDF lease');
    await push(tester, '/settings/library');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-export')), 300);
    await tester.tap(find.byKey(const ValueKey('set-lib-export')));
    await waitFor(tester, () => h.gateway.savedAs.isNotEmpty);
    // A "new phone": the library emptied, then the backup imported.
    final docs = (await tester.runAsync(() => repo(tester).watchDocs().first))!;
    await tester.runAsync(() => repo(tester).delete([for (final d in docs) d.id]));
    await settle(tester);
    h.gateway.nextZip = h.gateway.savedAs.single.copy;
    await tester.tap(find.byKey(const ValueKey('set-lib-import')));
    await waitFor(tester, () => find.byKey(const ValueKey('import-summary')).evaluate().isNotEmpty);
    expect(find.text('Imported 2 · Skipped 0 duplicates'), findsOneWidget);
    expect([for (final d in (await tester.runAsync(() => repo(tester).watchDocs(sort: LibrarySort.name).first))!) d.name],
        ['Lease.pdf', 'Passport.pdf']);
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('set-lib-import')));
    await waitFor(tester, () => find.byKey(const ValueKey('import-summary')).evaluate().isNotEmpty);
    expect(find.text('Imported 0 · Skipped 2 duplicates'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(h.gateway.discarded.where((d) => d.startsWith('lib-import-zip-')), hasLength(2));
    await finish(tester);
  });

  testWidgets('Import backup: not a DocuKit backup → explained; cancelled picker → nothing', (tester) async {
    await open(tester);
    await push(tester, '/settings/library');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-import')), 300);
    await tester.tap(find.byKey(const ValueKey('set-lib-import')));
    await settle(tester);
    expect(find.byKey(const ValueKey('import-progress')), findsNothing);
    h.gateway.nextZip = (File(p.join(src.path, 'photos.zip'))..writeAsStringSync('not a zip')).path;
    await tester.tap(find.byKey(const ValueKey('set-lib-import')));
    await waitFor(tester, () => shows("This isn't a DocuKit backup."));
    expect(find.text("This isn't a DocuKit backup."), findsOneWidget);
    await finish(tester);
  });

  testWidgets('launch housekeeping: library/ is kept out of iCloud backup; a folder with no row is swept', (tester) async {
    tester.view.physicalSize = const Size(420, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    h = (await tester.runAsync(() => TestHarness.create(store: {'lib_intro_seen': true})))!;
    final orphan = Directory(p.join(h.paths.supportRoot.path, 'library', 'no-such-doc'))..createSync(recursive: true);
    File(p.join(orphan.path, 'x.pdf')).writeAsStringSync('left over');
    await tester.pumpWidget(h.app());
    await waitFor(tester, () => !orphan.existsSync());
    expect(orphan.existsSync(), isFalse);
    expect(h.device.protectedPaths, contains(p.join(h.paths.supportRoot.path, 'library')));
    expect(find.byType(LibrarySettingsScreen), findsNothing);
    await finish(tester);
  });
}
