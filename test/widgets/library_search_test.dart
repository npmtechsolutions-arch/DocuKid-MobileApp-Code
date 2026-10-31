// T12.5 — search and "Make documents searchable" in the UI (RELEASE_V1_5
// FR-LIB-14–16, S40/S41/S42/S46) on the real LibraryRepository and the real
// index queue (its text comes from the harness's QuietTextSource): results
// with folder paths and highlighted snippets, folder scope, no matches,
// "Make searchable now", and S46's switches, status and Pause.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/library/application/index_queue.dart';
import 'package:docukit/features/library/presentation/document_screen.dart';
import 'package:docukit/features/library/presentation/library_settings_screen.dart';
import 'package:docukit/features/library/presentation/widgets/search_result_tile.dart';
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

  setUp(() => src = Directory.systemTemp.createTempSync('lib_search'));
  tearDown(() => src.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 80 && !done(); i++) {
      await settle(tester, 1);
    }
    await settle(tester, 2);
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator, skipOffstage: false).first));
  LibraryRepository repo(WidgetTester tester) => c(tester).read(libraryRepositoryProvider);
  GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(HomeScreen, skipOffstage: false)));

  Future<T> write<T>(WidgetTester tester, Future<T> Function() f) async {
    final r = (await tester.runAsync(f)) as T;
    await settle(tester, 2);
    return r;
  }

  Future<void> open(WidgetTester tester, {Map<String, Object> store = const {}}) async {
    tester.view.physicalSize = const Size(420, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: {'lib_intro_seen': true, ...store})))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<LibraryDoc> addDoc(WidgetTester tester, String name,
      {String? folderId, DocSource source = DocSource.import, String mime = 'application/pdf'}) async {
    final f = File(p.join(src.path, name))..writeAsStringSync('doc $name');
    final r = await write(tester,
        () => repo(tester).addFile(f.path, displayName: name, folderId: folderId, source: source, mime: mime));
    return (r as Added).doc;
  }

  Future<void> push(WidgetTester tester, String route) async {
    unawaited(router(tester).push(route));
    await settle(tester);
  }

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(find.byKey(const ValueKey('lib-search')), q);
    await tester.pump(const Duration(milliseconds: 200)); // the 150 ms debounce
    await settle(tester, 6);
  }

  Finder hit(String name) => find.byWidgetPredicate((w) => w is SearchResultTile && w.hit.doc.name == name);

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('FR-LIB-14 S40: names, notes and recognised text, with the folder path and a highlighted snippet; tap → S42', (tester) async {
    await open(tester);
    final ids = await write(tester, () => repo(tester).createFolder('IDs'));
    final passport = await addDoc(tester, 'Passport.pdf', folderId: ids.id);
    final lease = await addDoc(tester, 'Lease.pdf');
    await write(tester, () => repo(tester).setNotes(lease.id, 'renew the passport photo'));
    final scan = await addDoc(tester, 'Scan 12.pdf', source: DocSource.scan);
    await write(tester, () => repo(tester).setIndexedText(scan.id, 'Republic of India passport number Z1234567', state: IndexState.done));
    await push(tester, '/library');

    await search(tester, 'passport');
    expect(hit('Passport.pdf'), findsOneWidget);
    expect(hit('Lease.pdf'), findsOneWidget, reason: 'its notes');
    expect(hit('Scan 12.pdf'), findsOneWidget, reason: 'its recognised text');
    expect(find.descendant(of: hit('Passport.pdf'), matching: find.text('IDs')), findsOneWidget);
    final snippet = tester.widget<Text>(find.descendant(of: hit('Scan 12.pdf'), matching: find.byType(Text)).last);
    final runs = (snippet.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(runs.where((r) => r.style?.fontWeight == FontWeight.w700).map((r) => r.text), ['passport']);
    expect(runs.map((r) => r.text).join(), isNot(contains('[')), reason: 'no brackets on screen');

    await tester.tap(hit('Passport.pdf'));
    await waitFor(tester, () => find.byType(DocumentScreen).evaluate().isNotEmpty);
    expect(find.byType(DocumentScreen), findsOneWidget);
    expect((await tester.runAsync(() => repo(tester).get(passport.id)))!.openedAt, isNotNull);
    await finish(tester);
  });

  testWidgets('no matches → explained; Clear brings the list back', (tester) async {
    await open(tester);
    await addDoc(tester, 'Lease.pdf');
    await push(tester, '/library');
    await search(tester, 'zebra');
    expect(find.text('Nothing matches “zebra”'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await settle(tester);
    expect(find.text('Nothing matches “zebra”'), findsNothing);
    expect(find.text('Documents'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('S41 searches this folder and its subfolders only', (tester) async {
    await open(tester);
    final travel = await write(tester, () => repo(tester).createFolder('Travel'));
    final visas = await write(tester, () => repo(tester).createFolder('Visas', parentId: travel.id));
    await addDoc(tester, 'ticket.pdf', folderId: travel.id);
    await addDoc(tester, 'ticket visa.pdf', folderId: visas.id);
    await addDoc(tester, 'ticket stub.pdf');
    await push(tester, '/library/folder/${travel.id}');
    expect(find.widgetWithText(TextField, 'Search in this folder'), findsOneWidget);
    await search(tester, 'ticket');
    expect(hit('ticket.pdf'), findsOneWidget);
    expect(hit('ticket visa.pdf'), findsOneWidget);
    expect(hit('ticket stub.pdf'), findsNothing);
    expect(find.descendant(of: hit('ticket visa.pdf'), matching: find.text('Travel › Visas')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-LIB-15 S42 "Make searchable now": an imported photo (Other off) is recognised and becomes findable', (tester) async {
    await open(tester);
    final photo = await addDoc(tester, 'receipt.jpg', mime: 'image/jpeg');
    h.textSource.ocr[p.basename(repo(tester).absolutePath(photo))] = 'Cafe invoice total 42';
    await tester.runAsync(() => c(tester).read(indexQueueProvider).start());
    await push(tester, '/library/doc/${photo.id}');
    expect(find.text('Not searchable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doc-make-searchable')));
    await waitFor(tester, () => shows('Searchable · Text recognised'));
    expect(find.text('Searchable · Text recognised'), findsOneWidget);
    expect(find.byKey(const ValueKey('doc-make-searchable')), findsNothing);

    router(tester).pop();
    await push(tester, '/library');
    await search(tester, 'invoice');
    expect(hit('receipt.jpg'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('S46 from the S40 menu: switches saved; Pause / Resume; low battery explained; settings banner', (tester) async {
    await open(tester);
    await addDoc(tester, 'Scan.pdf', source: DocSource.scan);
    h.device.batteryNow = (level: 12, charging: false);
    await tester.runAsync(() => c(tester).read(indexQueueProvider).start());
    await push(tester, '/library');
    await tester.tap(find.byTooltip('More options'));
    await settle(tester);
    await tester.tap(find.text('My Documents settings'));
    await waitFor(tester, () => shows('1 waiting · Paused while the battery is low'));
    expect(find.byType(LibrarySettingsScreen), findsOneWidget);
    expect(find.descendant(of: find.byType(LibrarySettingsScreen), matching: find.byType(AppBottomBanner)), findsOneWidget);
    expect(find.text('1 waiting · Paused while the battery is low'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('set-lib-other')));
    await settle(tester);
    expect(h.store.get(SettingsRepository.kLibIndexOther), true);
    expect(h.store.get(SettingsRepository.kLibIndexScans), true);

    await tester.tap(find.byKey(const ValueKey('set-lib-pause')));
    await waitFor(tester, () => shows('1 waiting · Paused'));
    expect(find.text('Resume'), findsOneWidget);
    expect(h.store.get(SettingsRepository.kLibIndexPaused), true);

    h.device.batteryNow = (level: 12, charging: true);
    await tester.tap(find.text('Resume'));
    await waitFor(tester, () => shows('Nothing waiting'));
    expect(find.text('Nothing waiting'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Settings → My Documents settings', (tester) async {
    await open(tester);
    await push(tester, '/settings');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-library')), 200);
    await tester.tap(find.byKey(const ValueKey('set-library')));
    await settle(tester);
    expect(find.byType(LibrarySettingsScreen), findsOneWidget);
    await finish(tester);
  });
}
