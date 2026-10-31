// T12.2 — My Documents S39/S40/S41/S43 (RELEASE_V1_5 §3, §8 "Screens"/"Ads";
// FR-LIB-01, 02, 06–10) on the real LibraryRepository (in-memory DB, temp
// files): intro → empty → content, folders (create, depth, delete modes,
// move with disabled targets), documents (grid/list, sort, starred, selection,
// delete with Undo), the banner and the native-card rule, unknown folder ids.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/ad_slots.dart';
import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/library/application/library_controller.dart';
import 'package:docukit/features/library/presentation/library_home_screen.dart';
import 'package:docukit/features/library/presentation/library_intro_screen.dart';
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

  setUp(() => src = Directory.systemTemp.createTempSync('lib_ui'));
  tearDown(() => src.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  Future<void> act(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester);
  }

  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen, skipOffstage: false)));
  LibraryRepository repo(WidgetTester tester) => c(tester).read(libraryRepositoryProvider);

  Future<void> open(WidgetTester tester, {bool introSeen = true, String route = '/library'}) async {
    tester.view.physicalSize = const Size(420, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: {if (introSeen) 'lib_intro_seen': true})))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    if (route.isNotEmpty) unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push(route));
    await settle(tester);
  }

  Future<LibraryDoc> addDoc(WidgetTester tester, String name, {String? folderId, String? content}) async {
    final f = File(p.join(src.path, '${DateTime.now().microsecondsSinceEpoch}_$name'))..writeAsStringSync(content ?? 'doc $name');
    final r = (await tester.runAsync(() => repo(tester).addFile(f.path,
        displayName: name, folderId: folderId, source: DocSource.import, mime: 'image/jpeg')))!;
    // Let the screen's live queries finish (see [write]).
    await settle(tester, 2);
    return (r as Added).doc;
  }

  /// A repository write on the real clock, then a pump: the screen's live
  /// queries run on the fake clock and hold drift's lock until pumped, so
  /// back-to-back real-clock writes would otherwise deadlock.
  Future<T> write<T>(WidgetTester tester, Future<T> Function() f) async {
    final r = (await tester.runAsync(f)) as T;
    await settle(tester, 2);
    return r;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('FR-LIB-01/02: Home 📁 → S39 intro with the banner; Get started → empty state; not shown again', (tester) async {
    await open(tester, introSeen: false, route: '');
    await tester.tap(find.byTooltip('My Documents'));
    await settle(tester);
    expect(find.byType(LibraryIntroScreen), findsOneWidget);
    expect(find.byType(AppBottomBanner), findsOneWidget);
    expect(find.text('Not included in cloud backups. You can export a backup anytime.'), findsOneWidget);
    expect(find.text('Deleted if you uninstall DocuKit'), findsOneWidget);
    await act(tester, find.byKey(const ValueKey('lib-intro-start')));
    expect(h.store.get('lib_intro_seen'), true);
    expect(find.text('No documents yet'), findsOneWidget);
    expect(find.text('Tip: tap "Save to My Documents" on any result.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('New folder: created; a taken name shows inline; folder tile shows its count', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('lib-fab')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('lib-add-folder')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('folder-name')), 'IDs');
    await act(tester, find.text('Create'));
    expect(find.text('IDs'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lib-fab')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('lib-add-folder')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('folder-name')), 'ids');
    await act(tester, find.text('Create'));
    expect(find.text('A folder with this name already exists here'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Empty'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('§3.2 ads: banner always; the native card after the 5th document only with ≥ 6', (tester) async {
    await open(tester);
    for (var i = 1; i <= 5; i++) {
      await addDoc(tester, 'doc$i.jpg');
    }
    await settle(tester);
    expect(find.byType(AppBottomBanner), findsOneWidget);
    // Without an ads service the card has no height, so the finder must
    // include "offstage" (zero-size) widgets.
    expect(find.byType(HistoryAdCard, skipOffstage: false), findsNothing, reason: '5 documents');
    await addDoc(tester, 'doc6.jpg');
    await settle(tester);
    expect(find.byType(HistoryAdCard, skipOffstage: false), findsOneWidget);
    await finish(tester);
  });

  testWidgets('grid/list and sort are remembered; Starred chip filters across folders', (tester) async {
    await open(tester);
    final f = await write(tester, () => repo(tester).createFolder('Bills'));
    final a = await addDoc(tester, 'beta.jpg');
    await addDoc(tester, 'Alpha.jpg', folderId: f.id);
    await settle(tester);
    await tester.tap(find.byTooltip('More options').first);
    await settle(tester);
    await tester.tap(find.text('Name (A–Z)'));
    await settle(tester);
    expect((h.store.get('lib_view'), h.store.get('lib_sort')), ('grid', 'name'));
    await tester.tap(find.byTooltip('More options').first);
    await settle(tester);
    await tester.tap(find.text('List view'));
    await settle(tester);
    expect(h.store.get('lib_view'), 'list');
    expect(c(tester).read(libraryViewProvider).view, LibraryView.list);
    await write(tester, () => repo(tester).setStarred([a.id], true));
    await tester.tap(find.text('Starred'));
    await settle(tester);
    expect(find.text('beta.jpg'), findsOneWidget);
    expect(find.text('Bills'), findsNothing, reason: 'starred view lists documents only');
    await finish(tester);
  });

  testWidgets('selection: long-press, tap more, Star and Delete (confirmed) act on all selected', (tester) async {
    await open(tester);
    final a = await addDoc(tester, 'a.jpg'), b = await addDoc(tester, 'b.jpg');
    await addDoc(tester, 'c.jpg');
    await settle(tester);
    await tester.longPress(find.byKey(ValueKey('doc-${a.id}')));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('lib-fab')), findsNothing, reason: 'the FAB hides');
    await tester.tap(find.byKey(ValueKey('doc-${b.id}')));
    await settle(tester);
    expect(find.text('2 selected'), findsOneWidget);
    await act(tester, find.byTooltip('Star'));
    expect((await tester.runAsync(() => repo(tester).get(a.id)))!.starred, isTrue);
    await tester.longPress(find.byKey(ValueKey('doc-${a.id}')));
    await tester.tap(find.byKey(ValueKey('doc-${b.id}')));
    await settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await settle(tester);
    expect(find.text('Delete 2 documents?'), findsOneWidget);
    await act(tester, find.text('Delete').last);
    expect((await tester.runAsync(() => repo(tester).stats()))!.docCount, 1);
    await finish(tester);
  });

  testWidgets('single delete: hidden at once with Undo; Undo restores; otherwise deleted after 5 s', (tester) async {
    await open(tester);
    final a = await addDoc(tester, 'keep.jpg'), b = await addDoc(tester, 'gone.jpg');
    await settle(tester);
    Future<void> deleteViaMenu(LibraryDoc d) async {
      await tester.tap(find.descendant(of: find.byKey(ValueKey('doc-${d.id}')), matching: find.byTooltip('Document options')));
      await settle(tester);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(find.text('Delete "${d.name}"?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
    }

    await deleteViaMenu(a);
    expect(find.byKey(ValueKey('doc-${a.id}')), findsNothing);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.byKey(ValueKey('doc-${a.id}')), findsOneWidget);
    await deleteViaMenu(b);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    expect((await tester.runAsync(() => repo(tester).get(b.id))), isNull);
    expect((await tester.runAsync(() => repo(tester).get(a.id))), isNotNull);
    await finish(tester);
  });

  testWidgets('S41: breadcrumb; at level 3 "New folder" explains the limit; delete asks with counts (move up)', (tester) async {
    await open(tester);
    final r = repo(tester);
    final a = await write(tester, () => r.createFolder('IDs'));
    final b = await write(tester, () => r.createFolder('Travel', parentId: a.id));
    final x = await write(tester, () => r.createFolder('Visas', parentId: b.id));
    await addDoc(tester, 'visa.jpg', folderId: x.id);
    unawaited(GoRouter.of(tester.element(find.byType(LibraryScreen).last)).push('/library/folder/${x.id}'));
    await settle(tester);
    expect(find.text('IDs'), findsOneWidget);
    expect(find.text('Visas'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lib-fab')));
    await settle(tester);
    expect(find.text('Folders can be 3 levels deep'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('lib-add-folder'))).enabled, isFalse);
    await tester.tapAt(const Offset(200, 100));
    await settle(tester);
    // Delete "Travel" from its parent's view: 1 document, 1 folder → move up.
    unawaited(GoRouter.of(tester.element(find.byType(LibraryScreen).last)).push('/library/folder/${a.id}'));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byKey(ValueKey('folder-${b.id}')), matching: find.byTooltip('Folder options')));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(find.text('It contains 1 document and 1 folder.'), findsOneWidget);
    await act(tester, find.text('Move contents up'));
    final moved = (await tester.runAsync(() => r.folder(x.id)))!;
    expect((moved.parentId, moved.depth), (a.id, 2));
    await finish(tester);
  });

  testWidgets('S43 moving a folder: itself and its subfolders disabled, the root allowed; Move here moves it', (tester) async {
    await open(tester);
    final r = repo(tester);
    final a = await write(tester, () => r.createFolder('A'));
    final b = await write(tester, () => r.createFolder('B', parentId: a.id));
    final other = await write(tester, () => r.createFolder('Other'));
    await settle(tester);
    // Move A (which contains B) from its tile menu on the root level.
    await tester.tap(find.descendant(of: find.byKey(ValueKey('folder-${a.id}')), matching: find.byTooltip('Folder options')));
    await settle(tester);
    await tester.tap(find.text('Move'));
    await settle(tester, 20);
    ListTile tile(String id) => tester.widget<ListTile>(find.byKey(ValueKey('pick-$id')));
    expect(tile(a.id).enabled, isFalse);
    expect(tile(b.id).enabled, isFalse);
    expect(tile('root').enabled, isFalse, reason: 'A is already at the root (its current place)');
    expect(tile(other.id).enabled, isTrue);
    await tester.tap(find.byKey(ValueKey('pick-${other.id}')));
    await settle(tester);
    await act(tester, find.text('Move here'));
    final moved = (await tester.runAsync(() => r.folder(a.id)))!;
    expect((moved.parentId, moved.depth), (other.id, 2));
    expect((await tester.runAsync(() => r.folder(b.id)))!.depth, 3);
    await finish(tester);
  });

  testWidgets('an unknown folder id → back to My Documents with "no longer in My Documents"', (tester) async {
    await open(tester, route: '/library/folder/does-not-exist');
    await settle(tester, 20);
    expect(find.text('That document is no longer in My Documents.'), findsOneWidget);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-LIB-01 on tablets: the navigation rail has My Documents, and it opens the library', (tester) async {
    tester.view.physicalSize = const Size(1280, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    h = (await tester.runAsync(() => TestHarness.create(store: {SettingsRepository.kLibIntroSeen: true})))!;
    await tester.pumpWidget(h.app());
    await settle(tester);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.length, 4);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('My Documents')));
    await settle(tester);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await finish(tester);
  });
}
