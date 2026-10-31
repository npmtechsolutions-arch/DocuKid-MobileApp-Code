// T12.0 spike (RELEASE_V1_5 §4.1, §9): answers for ADR-054…058 on a device.
// 1) SQLite as shipped (drift_flutter → sqlite3): version, FTS5, unicode61
//    tokenizer with Hindi, snippet(), bm25 order; 2) pdfrx page text for a
//    text-layer PDF; 3) flutter_local_notifications 22.3.3: initialize, channel,
//    show, zonedSchedule (inexactAllowWhileIdle), pending, launch details,
//    cancel; 4) local_auth 3.0.2 with FlutterFragmentActivity; 5) the device
//    time zone via docukit_native + timezone 0.11.2. Spike code: records answers.
//
//   flutter test integration_test/library_spike_test.dart -d <android device>
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _Db extends GeneratedDatabase {
  _Db() : super(NativeDatabase.memory());
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  int get schemaVersion => 1;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLite + FTS5 as shipped', (_) async {
    final db = _Db();
    final v = await db.customSelect('select sqlite_version() as v').getSingle();
    final opts = [for (final r in await db.customSelect('pragma compile_options').get()) r.read<String>('compile_options')];
    // ignore: avoid_print
    print('SPIKE sqlite ${v.read<String>('v')} fts5=${opts.any((o) => o.contains('FTS5'))} '
        'options: ${opts.where((o) => o.contains('FTS') || o.contains('THREADSAFE') || o.contains('ICU')).join(', ')}');
    await db.customStatement(
        "create virtual table docs_fts using fts5(name, notes, body, tokenize = 'unicode61 remove_diacritics 2')");
    for (final (name, body) in [
      ('Passport.pdf', 'Republic of India passport. Date of expiry 12 Mar 2031. पासपोर्ट संख्या'),
      ('Payslip Oct.pdf', 'Salary slip for October. Net pay 1,250.00'),
      ('Insurance.pdf', 'Motor insurance policy, expiry 2027'),
    ]) {
      await db.customInsert('insert into docs_fts(name, notes, body) values (?, ?, ?)',
          variables: [Variable.withString(name), Variable.withString(''), Variable.withString(body)]);
    }
    Future<List<String>> q(String m) async => [
          for (final r in await db
              .customSelect("select name, snippet(docs_fts, 2, '[', ']', '…', 6) as s from docs_fts where docs_fts match ? order by bm25(docs_fts)",
                  variables: [Variable.withString(m)])
              .get())
            '${r.read<String>('name')} :: ${r.read<String>('s')}',
        ];
    final expiry = await q('expiry'), hindi = await q('पासपो*'), prefix = await q('sal*'), accent = await q('passport');
    // ignore: avoid_print
    print('SPIKE fts expiry=$expiry\nSPIKE fts hindi=$hindi\nSPIKE fts prefix=$prefix\nSPIKE fts passport=$accent');
    expect(expiry.length, 2);
    expect(hindi.single, startsWith('Passport.pdf'));
    expect(prefix.single, startsWith('Payslip'));
    await db.close();
  });

  testWidgets('FTS5 tokenizers for Devanagari: which one keeps "पासपोर्ट" whole?', (_) async {
    final db = _Db();
    const body = 'Republic of India passport. पासपोर्ट संख्या Z1234567. समाप्ति तिथि 2031';
    for (final (name, tok) in [
      ('u61_rd2', "unicode61 remove_diacritics 2"),
      ('u61_rd0', "unicode61 remove_diacritics 0"),
      ('u61_cat', "unicode61 remove_diacritics 0 categories 'L* N* Co M*'"),
      ('trigram', 'trigram'),
    ]) {
      String r;
      try {
        await db.customStatement('create virtual table $name using fts5(body, tokenize = "$tok")');
        await db.customInsert('insert into $name(body) values (?)', variables: [Variable.withString(body)]);
        Future<int> n(String m) async =>
            (await db.customSelect('select count(*) as c from $name where $name match ?', variables: [Variable.withString(m)]).getSingle()).read<int>('c');
        r = 'word=${await n('पासपोर्ट')} prefix=${await n('पासपो*')} other=${await n('समाप्ति')} latin=${await n('passport')} '
            'quoted=${await n('"पासपोर्ट"')}';
      } catch (e) {
        r = 'error ${e.runtimeType}: ${e.toString().split('\n').first}';
      }
      // ignore: avoid_print
      print('SPIKE tokenizer $name: $r');
    }
    await db.close();
  });

  testWidgets('pdfrx page text from a text-layer PDF', (_) async {
    await pdfrxFlutterInitialize();
    final doc = pw.Document()
      ..addPage(pw.Page(build: (_) => pw.Text('Certificate of insurance — policy 4471 valid until 2027')))
      ..addPage(pw.Page(build: (_) => pw.Text('Second page text')));
    final d = await PdfDocument.openData(await doc.save());
    final sw = Stopwatch()..start();
    final texts = [for (final p in d.pages) (await p.loadText())?.fullText ?? ''];
    // ignore: avoid_print
    print('SPIKE pdfrx loadText ${sw.elapsedMilliseconds} ms: ${texts.map((t) => t.replaceAll('\n', ' ')).toList()}');
    await d.dispose();
    expect(texts.first, contains('policy 4471'));
  });

  testWidgets('flutter_local_notifications 22.3.3 + timezone 0.11.2 + docukit_native.deviceTimeZone', (_) async {
    final zone = await DocukitNative().deviceTimeZone();
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(zone!));
    final n = FlutterLocalNotificationsPlugin();
    final ok = await n.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    final android = n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
    await android.createNotificationChannel(const AndroidNotificationChannel('reminders', 'Reminders',
        description: 'Expiry reminders', importance: Importance.defaultImportance));
    final enabled = await android.areNotificationsEnabled();
    const details = NotificationDetails(android: AndroidNotificationDetails('reminders', 'Reminders'));
    await n.show(id: 1, title: 'Spike', body: 'Shown now', notificationDetails: details);
    await Future<void>.delayed(const Duration(seconds: 2));
    final active = await android.getActiveNotifications();
    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 20));
    await n.zonedSchedule(
        id: 2,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Spike',
        body: 'Scheduled',
        payload: '/library/doc/spike');
    final pending = await n.pendingNotificationRequests();
    final launch = await n.getNotificationAppLaunchDetails();
    // Inexact alarms may come late; wait up to 3 minutes and record when it shows.
    final sw = Stopwatch()..start();
    var delivered = false;
    while (sw.elapsed < const Duration(minutes: 3)) {
      if ((await android.getActiveNotifications()).any((a) => a.id == 2)) {
        delivered = true;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    // ignore: avoid_print
    print('SPIKE notif zone=$zone tz.local=${tz.local.name} init=$ok enabled=$enabled '
        'active(show)=${active.map((a) => a.id).toList()} pending=${pending.map((p) => '${p.id}:${p.payload}').toList()} '
        'launchedByNotif=${launch?.didNotificationLaunchApp} scheduled(20 s, inexact) delivered=$delivered after ${sw.elapsed.inSeconds}s');
    expect(zone, isNotEmpty);
    expect(pending.map((p) => p.id), contains(2));
    await n.cancel(id: 2);
    await n.cancelAll();
    expect(await n.pendingNotificationRequests(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('local_auth 3.0.2 with FlutterFragmentActivity: no crash; answers on this emulator', (_) async {
    final a = LocalAuthentication();
    final supported = await a.isDeviceSupported();
    final canBio = await a.canCheckBiometrics;
    final types = await a.getAvailableBiometrics();
    // ignore: avoid_print
    print('SPIKE local_auth isDeviceSupported=$supported canCheckBiometrics=$canBio available=$types');
  });
}
