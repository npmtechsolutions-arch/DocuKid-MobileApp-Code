// T12.6 on a device (RELEASE_V1_5 R64, R65): the real ReminderScheduler with
// flutter_local_notifications, the device zone from docukit_native and SQLite.
//
// R64 uses the debug "minutes" unit (a reminder "day" = 1 minute). The host
// grants POST_NOTIFICATIONS once the app is installed and taps the
// notification when the test prints "R64 delivered":
//   adb shell pm grant com.npmtechsolutions.docukit android.permission.POST_NOTIFICATIONS
//   adb shell cmd statusbar expand-notifications ; uiautomator dump ; input tap …
// R65 changes the zone: the host runs `adb shell cmd alarm set-timezone
// Europe/London` when the test prints "R65 change zone now".
// The reboot half of R65 is a phone check (flutter test uninstalls the app).
import 'dart:io';

import 'package:docukit/core/notifications/notification_service.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/library/application/reminder_scheduler.dart';
import 'package:docukit/l10n/gen/app_localizations_en.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  final native = DocukitNative();
  final n = LocalNotificationService();
  final taps = <NotificationTap>[];
  late Directory dir;
  late AppDatabase db;
  late LibraryRepositoryImpl repo;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('it_reminders');
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(db, Directory(p.join(dir.path, 'support'))..createSync());
    await n.init(channelName: l.rmdChannelName, channelDescription: l.rmdChannelDesc, snoozeLabel: l.rmdSnooze, onTap: taps.add);
  });
  tearDownAll(() async {
    for (final x in await n.pending()) {
      await n.cancel(x.id);
    }
    await repo.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  ReminderScheduler scheduler({Duration? unit}) => ReminderScheduler(
        repo: repo,
        notifications: n,
        store: SettingsRepository(MemoryStore()),
        settings: () => const AppSettings(),
        l10n: () => l,
        deviceZone: native.deviceTimeZone,
        clock: DateTime.now,
        limit: androidReminderLimit,
        debugUnit: unit,
      );

  Future<void> waitUntil(Future<bool> Function() ok, Duration max) async {
    final end = DateTime.now().add(max);
    while (!await ok() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<LibraryDoc> addDoc(String name) async {
    final f = File(p.join(dir.path, name))..writeAsStringSync('%PDF $name');
    return ((await repo.addFile(f.path, displayName: name, source: DocSource.import, mime: 'application/pdf')) as Added).doc;
  }

  testWidgets('R64: expiry today + 2 with "1 day before" (debug minutes) → delivered with the generic text; the tap names the document',
      (_) async {
    // ignore: avoid_print
    print('R64 waiting for notification permission');
    await waitUntil(n.enabled, const Duration(seconds: 90));
    expect(await n.enabled(), isTrue, reason: 'the host grants POST_NOTIFICATIONS');
    final d = await addDoc('Passport.pdf');
    final now = DateTime.now();
    await repo.setExpiry(d.id, DateTime(now.year, now.month, now.day + 2), [1], null);
    final s = scheduler(unit: const Duration(minutes: 1));
    await s.expirySaved(d.id);
    await s.reconcile();
    final pending = await n.pending();
    // ignore: avoid_print
    print('R64 pending: ${pending.map((x) => x.payload).toList()}');
    expect(pending.where((x) => docIdOfPayload(x.payload ?? '') == d.id), hasLength(1));

    final android = FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
    final sw = Stopwatch()..start();
    ActiveNotification? shown;
    await waitUntil(() async {
      final a = await android.getActiveNotifications();
      shown = a.where((x) => x.id == pending.single.id).firstOrNull;
      return shown != null;
    }, const Duration(minutes: 4));
    // ignore: avoid_print
    print('R64 delivered after ${sw.elapsed.inSeconds}s: "${shown?.title}" / "${shown?.body}"');
    expect(shown?.title, 'Document expiring');
    expect(shown?.body, 'A document expires tomorrow.');

    await waitUntil(() async => taps.isNotEmpty, const Duration(seconds: 90));
    // ignore: avoid_print
    print('R64 tap: ${taps.map((t) => t.payload).toList()}');
    expect(docIdOfPayload(taps.first.payload), d.id);
    expect(taps.first.snooze, isFalse);
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('R65: a time-zone change reschedules every reminder at local 09:00 in the new zone', (_) async {
    final d = await addDoc('Visa.pdf');
    await repo.setExpiry(d.id, DateTime(2031, 3, 15), [30, 7, 0], null);
    final s = scheduler();
    await s.reconcile();
    final zone1 = await native.deviceTimeZone();
    final before = [for (final x in await n.pending()) if (docIdOfPayload(x.payload ?? '') == d.id) x.payload!]..sort();
    // ignore: avoid_print
    print('R65 zone=$zone1 pending=$before');
    expect(before, hasLength(3));
    expect(before.every((x) => x.contains(':$zone1:') && RegExp(r':\d{8}0900:').hasMatch(x)), isTrue);

    // ignore: avoid_print
    print('R65 change zone now');
    await waitUntil(() async => await native.deviceTimeZone() != zone1, const Duration(seconds: 90));
    final zone2 = await native.deviceTimeZone();
    await s.reconcile(); // what resume does
    final after = [for (final x in await n.pending()) if (docIdOfPayload(x.payload ?? '') == d.id) x.payload!]..sort();
    // ignore: avoid_print
    print('R65 zone=$zone2 pending=$after');
    expect(zone2, isNot(zone1));
    expect(after, hasLength(3));
    expect(after.every((x) => x.contains(':$zone2:') && RegExp(r':\d{8}0900:').hasMatch(x)), isTrue,
        reason: 'still 09:00 local, now in the new zone');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
