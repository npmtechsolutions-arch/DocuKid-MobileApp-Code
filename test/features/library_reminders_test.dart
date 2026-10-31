// T12.6 — reminder planning and the scheduler (RELEASE_V1_5 §4.7, FR-REM-02,
// 05, 07, 08, 09, 10) on the real LibraryRepository with a fake notification
// service: local wall-clock times, past offsets skipped, per-document time,
// generic vs named text, the iOS nearest-60 limit, stable unique ids, and
// reconcile (schedule, keep, replace, cancel on delete / permission off /
// zone change), snooze, the debug "minutes" mode.
import 'dart:io';

import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/library/application/reminder_scheduler.dart';
import 'package:docukit/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

LibraryDoc doc(String id, DateTime? expiry, {List<int> offsets = defaultReminderOffsets, int? minute, String? name}) => LibraryDoc(
      id: id,
      folderId: null,
      name: name ?? '$id.pdf',
      relPath: 'library/$id/x',
      mime: 'application/pdf',
      sizeBytes: 1,
      sha256: id,
      source: DocSource.import,
      addedAt: DateTime(2026),
      expiryDate: expiry,
      reminderOffsets: offsets,
      reminderMinuteOfDay: minute,
    );

void main() {
  final l = AppLocalizationsEn();
  final now = DateTime(2026, 10, 31, 12);

  List<PlannedReminder> plan(List<LibraryDoc> docs, {bool names = false, int limit = 500, DateTime? at}) =>
      planReminders(docs: docs, now: at ?? now, defaultMinute: 540, showNames: names, l: l, limit: limit);

  group('planReminders', () {
    test('FR-REM-02: 30 / 7 days before and on the day at 09:00 local; generic text (FR-REM-05)', () {
      final r = plan([doc('a', DateTime(2031, 3, 15))]);
      expect([for (final x in r) x.at], [DateTime(2031, 2, 13, 9), DateTime(2031, 3, 8, 9), DateTime(2031, 3, 15, 9)]);
      expect([for (final x in r) x.body],
          ['A document expires in 30 days.', 'A document expires in 7 days.', 'A document expires today.']);
      expect(r.first.title, 'Document expiring');
    });

    test('"1 day before" says tomorrow; names only when the setting is on', () {
      final r = plan([doc('a', DateTime(2027, 1, 2), offsets: [1], name: 'Passport.pdf')], names: true);
      expect(r.single.body, 'Passport.pdf expires tomorrow.');
    });

    test('FR-REM-07: past offsets and anything due within a minute are skipped (no backlog); a past expiry has none', () {
      expect([for (final x in plan([doc('a', DateTime(2026, 11, 7))])) x.key], ['a:0'], reason: '30 and 7 days before are past');
      final atNine = DateTime(2026, 11, 7, 8, 59, 30);
      expect(plan([doc('a', DateTime(2026, 11, 7))], at: atNine), isEmpty, reason: 'due in 30 s');
      expect(plan([doc('a', DateTime(2026, 10, 1))]), isEmpty);
      expect(plan([doc('a', null)]), isEmpty);
    });

    test('a document\'s own time wins over the default (S44 "At …")', () {
      expect(plan([doc('a', DateTime(2027, 1, 2), offsets: [0], minute: 20 * 60 + 30)]).single.at, DateTime(2027, 1, 2, 20, 30));
    });

    test('month and leap-year arithmetic: 30 days before 1 Mar 2028 is 31 Jan 2028', () {
      expect(plan([doc('a', DateTime(2028, 3, 1), offsets: [30])]).single.at, DateTime(2028, 1, 31, 9));
    });

    test('FR-REM-08: only the nearest [limit], soonest first', () {
      final docs = [for (var i = 0; i < 30; i++) doc('d$i', DateTime(2027, 1, 1).add(Duration(days: i * 3)))];
      final r = plan(docs, limit: iosReminderLimit);
      expect(r, hasLength(60));
      final all = plan(docs);
      expect(all.length, 90);
      expect([for (final x in r) x.key], [for (final x in all.take(60)) x.key]);
      expect(r.map((x) => x.at).toList(), [...r.map((x) => x.at)]..sort());
    });

    test('ids: stable per key, unique, 31-bit', () {
      final docs = [for (var i = 0; i < 200; i++) doc('doc-$i', DateTime(2028, 1, 1))];
      final r = plan(docs);
      expect(r.map((x) => x.id).toSet(), hasLength(r.length));
      expect(r.every((x) => x.id >= 0 && x.id < 1 << 31), isTrue);
      expect(plan([doc('doc-7', DateTime(2028, 1, 1))]).first.id, reminderId('doc-7:30'));
    });

    test('docIdOfPayload / nextReminder', () {
      expect(docIdOfPayload('rem:abc-1:30:203102130900:UTC:42'), 'abc-1');
      expect(docIdOfPayload('other'), isNull);
      expect(nextReminder(DateTime(2031, 3, 15), [30, 7, 0], 540, now), DateTime(2031, 2, 13, 9));
      expect(nextReminder(DateTime(2026, 11, 1), [30, 7], 540, now), isNull);
    });

    test('debug "minutes" mode (R64): a day lasts [debugUnit] from the anchor', () {
      final anchor = DateTime(2026, 10, 31, 12);
      final r = planReminders(
          docs: [doc('a', DateTime(2026, 11, 2), offsets: [1])],
          now: anchor,
          defaultMinute: 540,
          showNames: false,
          l: l,
          limit: 500,
          debugUnit: const Duration(minutes: 1),
          debugAnchors: {'a': anchor});
      expect(r.single.at, anchor.add(const Duration(minutes: 1)));
      expect(r.single.body, 'A document expires tomorrow.');
    });
  });

  group('ReminderScheduler (§4.7)', () {
    late AppDatabase db;
    late Directory tmp;
    late LibraryRepositoryImpl repo;
    late SettingsRepository store;
    late FakeNotifications n;
    var settings = const AppSettings();
    var zone = 'Asia/Kolkata';
    var clock = now;

    setUp(() {
      db = memoryDb();
      tmp = Directory.systemTemp.createTempSync('lib_rem');
      repo = LibraryRepositoryImpl(db, Directory(p.join(tmp.path, 'support'))..createSync());
      store = SettingsRepository(MemoryStore());
      n = FakeNotifications();
      settings = const AppSettings();
      zone = 'Asia/Kolkata';
      clock = now;
    });
    tearDown(() async {
      await repo.dispose();
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    ReminderScheduler scheduler({int limit = androidReminderLimit}) => ReminderScheduler(
          repo: repo,
          notifications: n,
          store: store,
          settings: () => settings,
          l10n: () => l,
          deviceZone: () async => zone,
          clock: () => clock,
          limit: limit,
        );

    Future<LibraryDoc> add(String name) async {
      final f = File(p.join(tmp.path, name))..writeAsStringSync(name);
      return ((await repo.addFile(f.path, displayName: name, source: DocSource.import, mime: 'application/pdf')) as Added).doc;
    }

    test('schedules the plan once; a second reconcile changes nothing; the zone is set and remembered', () async {
      final a = await add('a.pdf');
      await repo.setExpiry(a.id, DateTime(2031, 3, 15), [30, 7, 0], null);
      final s = scheduler();
      await s.reconcile();
      expect(n.list.map((x) => x.$1), [DateTime(2031, 2, 13, 9), DateTime(2031, 3, 8, 9), DateTime(2031, 3, 15, 9)]);
      expect((n.zone, store.readRemLastTz()), ('Asia/Kolkata', 'Asia/Kolkata'));
      final calls = n.scheduleCalls;
      await s.reconcile();
      expect((n.scheduleCalls, n.cancelCalls), (calls, 0));
      expect(n.others, hasLength(1), reason: 'never touches notifications that aren\'t ours');
    });

    test('FR-REM-07: changing the expiry replaces them; removing it or deleting the document cancels them', () async {
      final a = await add('a.pdf'), b = await add('b.pdf');
      await repo.setExpiry(a.id, DateTime(2031, 3, 15), [30], null);
      await repo.setExpiry(b.id, DateTime(2031, 3, 15), [0], null);
      final s = scheduler();
      await s.reconcile();
      await repo.setExpiry(a.id, DateTime(2032, 3, 15), [7], 600);
      await s.reconcile();
      expect(n.list.map((x) => x.$1), [DateTime(2031, 3, 15, 9), DateTime(2032, 3, 8, 10)]);
      await repo.setExpiry(a.id, null, const [], null);
      await repo.delete([b.id]);
      await s.reconcile();
      expect(n.scheduled, isEmpty);
    });

    test('FR-REM-05: turning "Show document names" on reschedules with the name', () async {
      final a = await add('Passport.pdf');
      await repo.setExpiry(a.id, DateTime(2031, 3, 15), [7], null);
      final s = scheduler();
      await s.reconcile();
      expect(n.list.single.$2, 'A document expires in 7 days.');
      settings = settings.copyWith(remShowNames: true);
      await s.reconcile();
      expect(n.list.single.$2, 'Passport.pdf expires in 7 days.');
    });

    test('FR-REM-07: a time-zone change reschedules everything at local 09:00 in the new zone', () async {
      final a = await add('a.pdf');
      await repo.setExpiry(a.id, DateTime(2031, 3, 15), [0], null);
      final s = scheduler();
      await s.reconcile();
      final before = n.scheduled.values.single.payload;
      zone = 'Europe/London';
      await s.reconcile();
      expect(n.zone, 'Europe/London');
      expect(store.readRemLastTz(), 'Europe/London');
      expect(n.scheduled.values.single.payload, isNot(before));
      expect(n.list.single.$1, DateTime(2031, 3, 15, 9));
    });

    test('FR-REM-03: notifications blocked → ours are cancelled (the expiry stays); allowed again → back', () async {
      final a = await add('a.pdf');
      await repo.setExpiry(a.id, DateTime(2031, 3, 15), [0], null);
      final s = scheduler();
      await s.reconcile();
      n.allowed = false;
      await s.reconcile();
      expect(n.scheduled, isEmpty);
      expect(n.others, hasLength(1));
      expect((await repo.get(a.id))!.expiryDate, DateTime(2031, 3, 15));
      n.allowed = true;
      await s.reconcile();
      expect(n.scheduled, hasLength(1));
    });

    test('FR-REM-08 on iOS: the nearest 60; later ones join as earlier ones pass', () async {
      for (var i = 0; i < 25; i++) {
        final d = await add('d$i.pdf');
        await repo.setExpiry(d.id, DateTime(2027, 1, 1).add(Duration(days: i * 10)), [30, 7, 0], null);
      }
      final s = scheduler(limit: iosReminderLimit);
      await s.reconcile();
      expect(n.scheduled, hasLength(60));
      final latest = n.list.last.$1;
      clock = DateTime(2027, 2, 1);
      await s.reconcile();
      expect(n.scheduled, hasLength(60));
      expect(n.list.last.$1.isAfter(latest), isTrue, reason: 'topped up');
      expect(n.list.first.$1.isAfter(clock), isTrue);
    });

    test('FR-REM-09 snooze: once more tomorrow at the reminder time; gone after it passes', () async {
      final a = await add('a.pdf');
      await repo.setExpiry(a.id, DateTime(2026, 11, 7), [0], null);
      final s = scheduler();
      await s.snooze(a.id);
      expect(n.list.map((x) => x.$1), [DateTime(2026, 11, 1, 9), DateTime(2026, 11, 7, 9)]);
      expect(n.list.first.$2, 'A document expires in 6 days.');
      clock = DateTime(2026, 11, 1, 10);
      await s.reconcile();
      expect(n.list.map((x) => x.$1), [DateTime(2026, 11, 7, 9)]);
    });
  });
}
