// T12.6 — expiry and reminders in the UI (RELEASE_V1_5 S44, S42 rows, S40
// "Expiring soon", the Home card, S46 Reminders; FR-REM-01–06, 09; FR-LIB-23)
// on the real LibraryRepository and ReminderScheduler with the harness's fake
// notification service.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/notifications/notification_service.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/library/presentation/document_screen.dart';
import 'package:docukit/features/library/presentation/library_home_screen.dart';
import 'package:docukit/features/library/presentation/library_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late Directory src;
  final today = DateTime.now();
  DateTime day(int offset) => DateTime(today.year, today.month, today.day + offset);
  String fmt(DateTime d) => DateFormat('d MMM yyyy').format(d);

  setUp(() => src = Directory.systemTemp.createTempSync('lib_expiry'));
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
  GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Navigator, skipOffstage: false).first));

  Future<T> write<T>(WidgetTester tester, Future<T> Function() f) async {
    final r = (await tester.runAsync(f)) as T;
    await settle(tester, 2);
    return r;
  }

  Future<void> open(WidgetTester tester, {bool allowed = true}) async {
    tester.view.physicalSize = const Size(420, 1800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: {'lib_intro_seen': true})))!;
    h.notifications.allowed = allowed;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    // The reminders runtime starts after the first frame.
    await waitFor(tester, () => h.notifications.inits > 0);
  }

  Future<LibraryDoc> addDoc(WidgetTester tester, String name, {String? folderId}) async {
    final f = File(p.join(src.path, name))..writeAsStringSync('doc $name');
    final r = await write(tester,
        () => repo(tester).addFile(f.path, displayName: name, folderId: folderId, source: DocSource.import, mime: 'application/pdf'));
    return (r as Added).doc;
  }

  Future<void> push(WidgetTester tester, String route) async {
    unawaited(router(tester).push(route));
    await settle(tester);
  }

  /// Library changes reconcile after a 500 ms debounce on the app's (fake) clock.
  Future<void> reconciled(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester, 6);
  }

  Future<LibraryDoc> get(WidgetTester tester, String id) async => (await tester.runAsync(() => repo(tester).get(id)))!;

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('FR-REM-01/02/03 S42 → S44: "1 year", default 30 / 7 / on the day, permission asked on save, 3 reminders, generic text',
      (tester) async {
    await open(tester, allowed: false);
    h.notifications.grant = true;
    final d = await addDoc(tester, 'Passport.pdf');
    await push(tester, '/library/doc/${d.id}');
    expect(find.descendant(of: find.byKey(const ValueKey('doc-expiry')), matching: find.text('No expiry')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('doc-expiry')), matching: find.text('Change ›')));
    await settle(tester);
    expect(find.text('Expiry date'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rmd-1y')));
    await settle(tester, 2);
    final exp = day(365 + (DateTime(today.year + 1, today.month, today.day).difference(day(365)).inDays));
    expect(find.text(fmt(exp)), findsOneWidget);
    for (final (o, on) in [(30, true), (7, true), (1, false), (0, true)]) {
      expect(tester.widget<FilterChip>(find.byKey(ValueKey('rmd-off-$o'))).selected, on, reason: '$o');
    }
    expect(find.textContaining('Next reminder: '), findsOneWidget);
    expect(h.notifications.requests, 0, reason: 'not before saving');
    await tester.tap(find.byKey(const ValueKey('rmd-save')));
    await waitFor(tester, () => find.text('Expiry date').evaluate().isEmpty);
    expect(h.notifications.requests, 1);
    final saved = await get(tester, d.id);
    expect(saved.expiryDate, exp);
    expect(saved.reminderOffsets, [30, 7, 0]);
    expect(h.notifications.scheduled.values.map((r) => r.body).toSet(),
        {'A document expires in 30 days.', 'A document expires in 7 days.', 'A document expires today.'});
    expect(find.descendant(of: find.byKey(const ValueKey('doc-expiry')), matching: find.text(fmt(exp))), findsOneWidget);
    expect(find.text('30 days before, 7 days before, On the day'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-REM-03 denied: the expiry still saves; the sheet explains with Open Settings; S42 says reminders are off', (tester) async {
    await open(tester, allowed: false);
    h.notifications.grant = false;
    final d = await addDoc(tester, 'Passport.pdf');
    await push(tester, '/library/doc/${d.id}');
    await tester.tap(find.text('Change ›'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('rmd-5y')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('rmd-save')));
    await waitFor(tester, () => find.byKey(const ValueKey('rmd-blocked')).evaluate().isNotEmpty);
    expect(find.text("Notifications are blocked, so reminders won't appear."), findsOneWidget);
    expect((await get(tester, d.id)).expiryDate, isNotNull);
    expect(h.notifications.scheduled, isEmpty);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('rmd-blocked')), matching: find.text('Open Settings')));
    await settle(tester, 2);
    expect(h.device.settingsOpened, 1);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Off — notifications are blocked'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('S44 Remove expiry: date and reminders gone', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'Visa.pdf');
    await write(tester, () => repo(tester).setExpiry(d.id, day(40), [30, 0], null));
    await reconciled(tester);
    expect(h.notifications.scheduled, hasLength(2));
    await push(tester, '/library/doc/${d.id}');
    await tester.tap(find.text('Change ›'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('rmd-remove')));
    await waitFor(tester, () => find.text('Expiry date').evaluate().isEmpty);
    expect((await get(tester, d.id)).expiryDate, isNull);
    expect(h.notifications.scheduled, isEmpty);
    expect(find.descendant(of: find.byKey(const ValueKey('doc-expiry')), matching: find.text('No expiry')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-REM-04 S40 "Expiring soon": expired in red first, then within 60 days; not later ones; tile badges', (tester) async {
    await open(tester);
    final ids = await write(tester, () => repo(tester).createFolder('IDs'));
    final old = await addDoc(tester, 'Old permit.pdf', folderId: ids.id);
    final soon = await addDoc(tester, 'Passport.pdf');
    final later = await addDoc(tester, 'Licence.pdf');
    await write(tester, () => repo(tester).setExpiry(old.id, day(-3), [0], null));
    await write(tester, () => repo(tester).setExpiry(soon.id, day(12), [7], null));
    await write(tester, () => repo(tester).setExpiry(later.id, day(90), [30], null));
    await push(tester, '/library');
    expect(find.text('Expiring soon'), findsOneWidget);
    final section = find.byKey(const ValueKey('lib-expiring'));
    expect(find.descendant(of: section, matching: find.byKey(ValueKey('expiring-${old.id}'))), findsOneWidget);
    expect(find.descendant(of: section, matching: find.byKey(ValueKey('expiring-${later.id}'))), findsNothing);
    final expired = tester.widget<Text>(find.descendant(of: section, matching: find.text('Expired 3 days ago')));
    expect(expired.style?.color, Theme.of(tester.element(section)).colorScheme.error);
    expect(find.descendant(of: section, matching: find.text('Expires in 12 days')), findsOneWidget);
    final top = tester.getTopLeft(find.byKey(ValueKey('expiring-${old.id}'))).dy;
    expect(top, lessThan(tester.getTopLeft(find.byKey(ValueKey('expiring-${soon.id}'))).dy), reason: 'soonest first');
    // The tile's badge replaces size and date.
    expect(find.descendant(of: find.byKey(ValueKey('doc-${soon.id}')), matching: find.text('Expires in 12 days')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('expiring-${old.id}')));
    await waitFor(tester, () => find.byType(DocumentScreen).evaluate().isNotEmpty);
    expect(find.text('Expired 3 days ago'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-LIB-23 Home card: hidden while empty; 3 latest, the nearest expiry within 30 days, Open library', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('home-library-card')), findsNothing);
    final a = await addDoc(tester, 'a.pdf');
    await addDoc(tester, 'b.pdf');
    await addDoc(tester, 'c.pdf');
    await addDoc(tester, 'd.pdf');
    await write(tester, () => repo(tester).setExpiry(a.id, day(9), [0], null));
    await settle(tester);
    final card = find.byKey(const ValueKey('home-library-card'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.byKey(const ValueKey('home-library-expiring'))), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Expires in 9 days')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byKey(ValueKey('home-library-${a.id}'))), findsNothing,
        reason: 'only the 3 latest (a is the oldest)');
    await tester.ensureVisible(find.byKey(const ValueKey('home-library-open')));
    await tester.tap(find.byKey(const ValueKey('home-library-open')));
    await settle(tester);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('FR-REM-06 tap: opens the document; a deleted one → My Documents with a note; FR-REM-09 snooze', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'Passport.pdf');
    await write(tester, () => repo(tester).setExpiry(d.id, day(20), [7], null));
    h.notifications.onTap!(NotificationTap('rem:${d.id}:7:x:UTC:1'));
    await waitFor(tester, () => find.byType(DocumentScreen).evaluate().isNotEmpty);
    expect(find.byType(DocumentScreen), findsOneWidget);
    expect(find.text('Passport.pdf'), findsOneWidget);

    h.notifications.onTap!(NotificationTap('rem:${d.id}:7:x:UTC:1', snooze: true));
    await waitFor(tester, () => h.notifications.scheduled.values.any((r) => r.payload.startsWith('rem:${d.id}:s:')));
    final tomorrow = day(1);
    final snoozed = h.notifications.scheduled.values.firstWhere((r) => r.payload.startsWith('rem:${d.id}:s:'));
    expect((snoozed.at.year, snoozed.at.month, snoozed.at.day, snoozed.at.hour), (tomorrow.year, tomorrow.month, tomorrow.day, 9));

    await write(tester, () => repo(tester).delete([d.id]));
    await settle(tester);
    h.notifications.onTap!(NotificationTap('rem:${d.id}:7:x:UTC:1'));
    await waitFor(tester, () => shows('That document is no longer in My Documents.') && find.byType(LibraryScreen).evaluate().isNotEmpty);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('That document is no longer in My Documents.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('S46 Reminders: names on → rescheduled with the name; time saved; blocked → Open Settings', (tester) async {
    await open(tester);
    final d = await addDoc(tester, 'Passport.pdf');
    await write(tester, () => repo(tester).setExpiry(d.id, day(20), [7], null));
    await reconciled(tester);
    expect(h.notifications.scheduled.values.single.body, 'A document expires in 7 days.');
    await push(tester, '/settings/library');
    expect(find.byType(LibrarySettingsScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-names')), 200);
    await tester.tap(find.byKey(const ValueKey('set-lib-names')));
    await waitFor(tester, () => h.notifications.scheduled.values.single.body.startsWith('Passport'));
    expect(h.notifications.scheduled.values.single.body, 'Passport.pdf expires in 7 days.');
    expect(h.store.get(SettingsRepository.kRemShowNames), true);
    expect(find.text('Allowed'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('S46 with notifications blocked: "Blocked" and Open Settings', (tester) async {
    await open(tester, allowed: false);
    await push(tester, '/settings/library');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('set-lib-notifications')), 200);
    expect(find.text('Blocked'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('set-lib-notifications')), matching: find.text('Open Settings')));
    await settle(tester, 2);
    expect(h.device.settingsOpened, 1);
    await finish(tester);
  });

  testWidgets('Home is reached without a library card when nothing is saved (no regression)', (tester) async {
    await open(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('home-library-card')), findsNothing);
    await finish(tester);
  });
}
