// T12.4 — S42 Document detail and "Open in tool…" (RELEASE_V1_5 §3 S42,
// FR-LIB-10–13) on the real LibraryRepository: tap → S42 with its info and
// banner, the full viewer (no ads), notes autosave, tags with suggestions and
// the S40 tag filter, rename / move / delete, a missing file, Open in tool
// (a copy, never the library file) from S42 and from a selection.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/library/presentation/doc_viewer_screen.dart';
import 'package:docukit/features/library/presentation/document_screen.dart';
import 'package:docukit/features/library/presentation/widgets/library_tiles.dart';
import 'package:docukit/features/pdf_compress/presentation/reduce_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tools/tool_inputs.dart';
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

  setUp(() => src = Directory.systemTemp.createTempSync('lib_doc'));
  tearDown(() => src.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  /// Taps, then waits (real time) until [until] holds.
  Future<void> act(WidgetTester tester, Finder f, {required bool Function() until}) async {
    await tester.tap(f);
    for (var i = 0; i < 60 && !until(); i++) {
      await settle(tester, 1);
    }
    await settle(tester, 2);
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;
  Finder docTile(String name) => find.byWidgetPredicate((w) => w is DocTile && w.doc.name == name);

  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator, skipOffstage: false).first));
  LibraryRepository repo(WidgetTester tester) => c(tester).read(libraryRepositoryProvider);
  GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(HomeScreen, skipOffstage: false)));

  Future<T> write<T>(WidgetTester tester, Future<T> Function() f) async {
    final r = (await tester.runAsync(f)) as T;
    await settle(tester, 2);
    return r;
  }

  Future<LibraryDoc> get(WidgetTester tester, String id) async => (await tester.runAsync(() => repo(tester).get(id)))!;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: {'lib_intro_seen': true})))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<LibraryDoc> addDoc(WidgetTester tester, String name,
      {String? folderId, String mime = 'application/pdf', int? pages = 3, String? content}) async {
    final f = File(p.join(src.path, '${DateTime.now().microsecondsSinceEpoch}_$name'))..writeAsStringSync(content ?? 'doc $name');
    final r = await write(
        tester,
        () => repo(tester).addFile(f.path,
            displayName: name, folderId: folderId, source: DocSource.import, mime: mime, pageCount: pages));
    return (r as Added).doc;
  }

  Future<void> openDoc(WidgetTester tester, LibraryDoc d) async {
    unawaited(router(tester).push('/library/doc/${d.id}'));
    for (var i = 0; i < 40 && find.byType(DocumentScreen).evaluate().isEmpty; i++) {
      await settle(tester, 1);
    }
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('FR-LIB-12: tap in S40 → S42 with name, info, folder, banner; opened is recorded', (tester) async {
    await open(tester);
    final ids = await write(tester, () => repo(tester).createFolder('IDs'));
    final d = await addDoc(tester, 'Passport.pdf', folderId: ids.id, pages: 2);
    unawaited(router(tester).push('/library/folder/${ids.id}'));
    await settle(tester);
    await act(tester, docTile('Passport.pdf'), until: () => find.byType(DocumentScreen).evaluate().isNotEmpty);
    await settle(tester);
    expect(find.byType(DocumentScreen), findsOneWidget);
    expect(find.text('Passport.pdf'), findsOneWidget);
    expect(find.textContaining('PDF · 2 pages · '), findsOneWidget);
    expect(find.textContaining(' · Added '), findsOneWidget);
    expect(find.text('Folder: IDs'), findsOneWidget);
    expect(find.text('Not searchable'), findsOneWidget);
    expect(find.descendant(of: find.byType(DocumentScreen), matching: find.byType(AppBottomBanner)), findsOneWidget);
    expect((await get(tester, d.id)).openedAt, isNotNull);
    await finish(tester);
  });

  testWidgets('preview → full viewer without a banner; "Page 1 of 3"', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'a.pdf');
    await openDoc(tester, d);
    await tester.tap(find.byKey(const ValueKey('doc-preview')));
    await settle(tester);
    expect(find.byType(DocViewerScreen), findsOneWidget);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(find.descendant(of: find.byType(DocViewerScreen), matching: find.byType(AppBottomBanner)), findsNothing);
    await finish(tester);
  });

  testWidgets('notes save 600 ms after the last keystroke, and when leaving', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'a.pdf');
    await openDoc(tester, d);
    await tester.enterText(find.byKey(const ValueKey('doc-notes')), 'Passport number on page 2');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect((await get(tester, d.id)).notes, '', reason: 'not yet');
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester, 4);
    expect((await get(tester, d.id)).notes, 'Passport number on page 2');

    await tester.enterText(find.byKey(const ValueKey('doc-notes')), 'Renew in 2031');
    router(tester).pop(); // leave before the delay
    await settle(tester, 6);
    expect((await get(tester, d.id)).notes, 'Renew in 2031');
    await finish(tester);
  });

  testWidgets('FR-LIB-13 tags: add (suggestions from other documents), remove; S40 filters by tag across folders', (tester) async {
    await open(tester);
    final f = await write(tester, () => repo(tester).createFolder('Travel'));
    final a = await addDoc(tester, 'visa.pdf', folderId: f.id);
    await addDoc(tester, 'bill.pdf', content: 'bill');
    await write(tester, () => repo(tester).setTags(a.id, ['travel']));
    final d = await addDoc(tester, 'passport.pdf', content: 'pp');
    await openDoc(tester, d);
    await tester.tap(find.byKey(const ValueKey('doc-add-tag')));
    await settle(tester);
    expect(find.widgetWithText(ActionChip, 'travel'), findsOneWidget, reason: 'a suggestion');
    await act(tester, find.widgetWithText(ActionChip, 'travel'), until: () => find.widgetWithText(InputChip, 'travel').evaluate().isNotEmpty);
    await tester.tap(find.byKey(const ValueKey('doc-add-tag')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('tag-name')), 'id');
    await tester.pump();
    await act(tester, find.widgetWithText(TextButton, 'Add'), until: () => find.widgetWithText(InputChip, 'id').evaluate().isNotEmpty);
    expect((await get(tester, d.id)).tags, ['id', 'travel']);
    await act(tester, find.byTooltip('Remove tag id'), until: () => find.widgetWithText(InputChip, 'id').evaluate().isEmpty);
    expect((await get(tester, d.id)).tags, ['travel']);

    router(tester).pop();
    unawaited(router(tester).push('/library'));
    await settle(tester);
    await act(tester, find.byKey(const ValueKey('lib-tag-travel')), until: () => docTile('bill.pdf').evaluate().isEmpty);
    expect(docTile('visa.pdf'), findsOneWidget, reason: 'from the Travel folder');
    expect(docTile('passport.pdf'), findsOneWidget);
    expect(find.text('Travel'), findsNothing, reason: 'folders hide while filtering');
    await act(tester, find.text('All'), until: () => docTile('bill.pdf').evaluate().isNotEmpty);
    await finish(tester);
  });

  testWidgets('10 tags: Add is disabled with "Up to 10 tags"', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'a.pdf');
    await write(tester, () => repo(tester).setTags(d.id, [for (var i = 0; i < 10; i++) 't$i']));
    await openDoc(tester, d);
    expect(tester.widget<ActionChip>(find.byKey(const ValueKey('doc-add-tag'))).onPressed, isNull);
    expect(find.byTooltip('Up to 10 tags'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('rename (taken name explained), move, delete → back to the list', (tester) async {
    await open(tester);
    final ids = await write(tester, () => repo(tester).createFolder('IDs'));
    await addDoc(tester, 'b.pdf', content: 'b');
    final d = await addDoc(tester, 'a.pdf');
    await openDoc(tester, d);
    await tester.tap(find.byTooltip('Rename'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'b');
    await tester.pump();
    await act(tester, find.widgetWithText(FilledButton, 'Rename'), until: () => shows('A document with this name is already in this folder'));
    expect(find.text('A document with this name is already in this folder'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text('Move ›'));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('pick-${ids.id}')));
    await settle(tester, 2);
    await act(tester, find.text('Move here'), until: () => shows('Folder: IDs'));
    expect(find.text('Folder: IDs'), findsOneWidget);

    await tester.tap(find.byTooltip('Document options'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await act(tester, find.text('Delete').last, until: () => find.byType(DocumentScreen).evaluate().isEmpty);
    expect(find.byType(DocumentScreen), findsNothing);
    expect(find.text('Deleted "a.pdf"'), findsOneWidget);
    expect(await tester.runAsync(() => repo(tester).get(d.id)), isNull);
    await finish(tester);
  });

  testWidgets('file missing: "File missing", actions off except Delete', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'a.pdf');
    await tester.runAsync(() => File(repo(tester).absolutePath(d)).delete());
    await openDoc(tester, d);
    expect(find.text('File missing'), findsOneWidget);
    for (final k in ['doc-share', 'doc-save', 'doc-open-with', 'doc-open-in-tool']) {
      expect(tester.widget<TextButton>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(TextButton))).onPressed,
          isNull, reason: k);
    }
    await tester.tap(find.byTooltip('Document options'));
    await settle(tester);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Share hands the library file to the share sheet', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'a.pdf');
    await openDoc(tester, d);
    await act(tester, find.byKey(const ValueKey('doc-share')), until: () => h.gateway.sharedFiles.isNotEmpty);
    expect(h.gateway.sharedFiles.single, [repo(tester).absolutePath(d)]);
    await finish(tester);
  });

  testWidgets('FR-LIB-11 Open in tool from S42: compatible tools only; the tool gets a copy, the library file stays', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'statement.pdf');
    final lib = repo(tester).absolutePath(d);
    await openDoc(tester, d);
    await tester.ensureVisible(find.byKey(const ValueKey('doc-open-in-tool')));
    await tester.tap(find.byKey(const ValueKey('doc-open-in-tool')));
    await settle(tester);
    expect(find.byKey(const ValueKey('open-in-pdfCompress')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-in-imageResize')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-in-pdfCompress')));
    ProviderContainer cc() => c(tester);
    for (var i = 0; i < 60; i++) {
      await settle(tester, 1);
      if (find.byType(ReduceScreen).evaluate().isNotEmpty && cc().read(toolInputsProvider(ToolId.pdfCompress)).single != null) break;
    }
    expect(find.byType(ReduceScreen), findsOneWidget);
    final f = cc().read(toolInputsProvider(ToolId.pdfCompress)).single!;
    expect(f.displayName, 'statement.pdf');
    expect(f.path, isNot(lib));
    expect(p.isWithin(c(tester).read(appPathsProvider).jobsRoot.path, f.path), isTrue, reason: "in the tool's job draft");
    expect(File(f.path).readAsStringSync(), 'doc statement.pdf');
    expect(File(lib).existsSync(), isTrue, reason: 'copied, never moved');
    await finish(tester);
  });

  testWidgets('FR-LIB-10 selection: 2 PDFs → only Merge; PDFs + an image → explained, nothing opens', (tester) async {
    await open(tester);
    await addDoc(tester, 'a.pdf', content: 'a');
    await addDoc(tester, 'b.pdf', content: 'b');
    await addDoc(tester, 'c.jpg', mime: 'image/jpeg', pages: null, content: 'c');
    unawaited(router(tester).push('/library'));
    await settle(tester);
    await tester.longPress(docTile('a.pdf'));
    await settle(tester, 2);
    await tester.tap(docTile('b.pdf'));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('lib-selection-more')));
    await settle(tester);
    await tester.tap(find.text('Open in tool…'));
    await settle(tester);
    expect(find.byKey(const ValueKey('open-in-pdfMerge')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-in-pdfCompress')), findsNothing);
    await tester.tapAt(const Offset(200, 60));
    await settle(tester);

    await tester.longPress(docTile('a.pdf'));
    await settle(tester, 2);
    await tester.tap(docTile('c.jpg'));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('lib-selection-more')));
    await settle(tester);
    await tester.tap(find.text('Open in tool…'));
    await settle(tester);
    expect(find.text("These can't go to the same tool. Select only PDFs or only images."), findsOneWidget);
    await finish(tester);
  });

  testWidgets('deleted elsewhere: S42 says so and closes', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'a.pdf');
    await openDoc(tester, d);
    await write(tester, () => repo(tester).delete([d.id]));
    await settle(tester);
    expect(find.byType(DocumentScreen), findsNothing);
    expect(find.text('That document is no longer in My Documents.'), findsOneWidget);
    await finish(tester);
  });
}
