import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/providers.dart';
import '../../../data/library/library_repository.dart';
import '../../../data/settings/app_settings.dart';
import '../../../data/settings/settings_repository.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Reminders scheduled at most, nearest first: iOS keeps 64 pending per app
/// (FR-REM-08, headroom for snoozes); Android has no such limit.
const iosReminderLimit = 60, androidReminderLimit = 500;

/// Never schedule something due within this (it would fire as a backlog).
const reminderLeadTime = Duration(seconds: 60);

/// The S44 offsets, in days before the expiry date (FR-REM-02).
const reminderOffsets = [30, 7, 1, 0];
const defaultReminderOffsets = [30, 7, 0];

/// A reminder that should be pending.
class PlannedReminder {
  PlannedReminder({required this.key, required this.docId, required this.at, required this.title, required this.body, this.id = 0});

  /// `<docId>:<offset>` or `<docId>:s` (a snooze).
  final String key;
  final String docId;

  /// Local wall-clock time.
  final DateTime at;
  final String title, body;
  int id;

  /// What we compare with the pending list: a change of time, zone or text
  /// reschedules (FR-REM-05: the text is fixed when scheduled).
  String payload(String zone) =>
      'rem:$key:${at.year}${_two(at.month)}${_two(at.day)}${_two(at.hour)}${_two(at.minute)}:$zone:${_hash(title + body)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// 31-bit FNV-1a: stable across runs and platforms (Dart's hashCode isn't).
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in utf8.encode(s)) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// A deterministic id per reminder key (§4.7).
int reminderId(String key) => _hash(key);

/// The document a reminder payload is about (tap routing, FR-REM-06).
String? docIdOfPayload(String payload) {
  if (!payload.startsWith('rem:')) return null;
  final parts = payload.split(':');
  return parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// FR-REM-02/05/07/08 · the reminders that should be pending, nearest first:
/// each offset of each dated document at its time (or [defaultMinute]) in
/// local time, plus snoozes; past ones skipped; at most [limit]; ids unique.
/// [debugUnit] (debug builds only, R64): a "day" lasts this long, counted
/// from the anchor recorded when the expiry was saved.
List<PlannedReminder> planReminders({
  required List<LibraryDoc> docs,
  required DateTime now,
  required int defaultMinute,
  required bool showNames,
  required AppLocalizations l,
  required int limit,
  List<({String docId, DateTime at})> snoozes = const [],
  Duration? debugUnit,
  Map<String, DateTime> debugAnchors = const {},
}) {
  final out = <PlannedReminder>[];
  // Debug "minutes" reminders are close by design; real ones keep the minute.
  final lead = debugUnit == null ? reminderLeadTime : const Duration(seconds: 5);
  String body(LibraryDoc d, int days) => showNames ? l.rmdNotifBodyNamed(d.name, days) : l.rmdNotifBodyGeneric(days);
  final byId = {for (final d in docs) d.id: d};
  for (final d in docs) {
    final exp = d.expiryDate;
    if (exp == null) continue;
    final minute = d.reminderMinuteOfDay ?? defaultMinute;
    for (final off in d.reminderOffsets.toSet()) {
      final DateTime at;
      if (debugUnit != null) {
        final anchor = debugAnchors[d.id];
        if (anchor == null) continue;
        at = anchor.add(debugUnit * (_day(exp).difference(_day(anchor)).inDays - off));
      } else {
        at = DateTime(exp.year, exp.month, exp.day - off, minute ~/ 60, minute % 60);
      }
      if (!at.isAfter(now.add(lead))) continue;
      out.add(PlannedReminder(key: '${d.id}:$off', docId: d.id, at: at, title: l.rmdNotifTitle, body: body(d, off)));
    }
  }
  for (final s in snoozes) {
    final d = byId[s.docId];
    final exp = d?.expiryDate;
    if (d == null || exp == null || !s.at.isAfter(now.add(lead))) continue;
    final days = _day(exp).difference(_day(s.at)).inDays;
    if (days < 0) continue;
    out.add(PlannedReminder(key: '${d.id}:s', docId: d.id, at: s.at, title: l.rmdNotifTitle, body: body(d, days)));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  final kept = out.take(limit).toList();
  final used = <int>{};
  for (final r in kept) {
    var id = reminderId(r.key);
    while (!used.add(id)) {
      id = (id + 1) & 0x7fffffff; // collision: next free (§4.7)
    }
    r.id = id;
  }
  return kept;
}

/// The next reminder S44 shows for these settings, or null.
DateTime? nextReminder(DateTime expiry, List<int> offsets, int minute, DateTime now) {
  final times = [
    for (final off in offsets) DateTime(expiry.year, expiry.month, expiry.day - off, minute ~/ 60, minute % 60),
  ].where((t) => t.isAfter(now.add(reminderLeadTime))).toList()
    ..sort();
  return times.isEmpty ? null : times.first;
}

/// §4.7 ReminderScheduler: makes the pending notifications match the plan.
/// Called on launch, resume, library changes, settings changes and after a
/// snooze; calls are serialised. Never logs names or dates.
class ReminderScheduler {
  ReminderScheduler({
    required LibraryRepository repo,
    required NotificationService notifications,
    required SettingsRepository store,
    required AppSettings Function() settings,
    required AppLocalizations Function() l10n,
    required Future<String?> Function() deviceZone,
    required DateTime Function() clock,
    required this.limit,
    this.debugUnit,
  })  : _repo = repo,
        _n = notifications,
        _store = store,
        _settings = settings,
        _l10n = l10n,
        _deviceZone = deviceZone,
        _now = clock;

  final LibraryRepository _repo;
  final NotificationService _n;
  final SettingsRepository _store;
  final AppSettings Function() _settings;
  final AppLocalizations Function() _l10n;
  final Future<String?> Function() _deviceZone;
  final DateTime Function() _now;
  final int limit;
  final Duration? debugUnit;

  Future<void> _last = Future.value();

  /// Serialised: one reconcile at a time, the latest state wins.
  Future<void> reconcile() => _last = _last.then((_) => _reconcile()).catchError((Object _) {});

  Future<void> _reconcile() async {
    final zone = await _deviceZone() ?? 'UTC';
    _n.setZone(zone);
    if (_store.readRemLastTz() != zone) await _store.writeRemLastTz(zone);
    final ours = [for (final p in await _n.pending()) if (p.payload?.startsWith('rem:') ?? false) p];
    if (!await _n.enabled()) {
      for (final p in ours) {
        await _n.cancel(p.id);
      }
      return;
    }
    final s = _settings();
    final now = _now();
    final snoozes = [for (final x in _readSnoozes()) if (x.at.isAfter(now)) x];
    await _writeSnoozes(snoozes);
    final plan = planReminders(
      docs: await _repo.docsWithExpiry(),
      now: now,
      defaultMinute: s.remMinuteOfDay,
      showNames: s.remShowNames,
      l: _l10n(),
      limit: limit,
      snoozes: snoozes,
      debugUnit: debugUnit,
      debugAnchors: _readAnchors(),
    );
    final wanted = {for (final r in plan) r.id: r.payload(zone)};
    final have = {for (final p in ours) p.id: p.payload};
    for (final p in ours) {
      if (wanted[p.id] != p.payload) await _n.cancel(p.id);
    }
    final snooze = _l10n().rmdSnooze;
    for (final r in plan) {
      if (have[r.id] == wanted[r.id]) continue;
      await _n.schedule(NotificationRequest(
          id: r.id, at: r.at, title: r.title, body: r.body, payload: r.payload(zone), snoozeLabel: snooze));
    }
  }

  /// FR-REM-09: once more tomorrow at the reminder time.
  Future<void> snooze(String docId) async {
    final t = _now().add(const Duration(days: 1));
    final m = (await _repo.get(docId))?.reminderMinuteOfDay ?? _settings().remMinuteOfDay;
    final at = debugUnit != null ? _now().add(debugUnit!) : DateTime(t.year, t.month, t.day, m ~/ 60, m % 60);
    await _writeSnoozes([..._readSnoozes().where((x) => x.docId != docId), (docId: docId, at: at)]);
    await reconcile();
  }

  /// Debug builds (R64): the moment an expiry was saved anchors its "days".
  Future<void> expirySaved(String docId) async {
    if (debugUnit == null) return;
    final a = _readAnchors()..[docId] = _now();
    await _store.writeRaw(SettingsRepository.kRemDebugAnchors,
        jsonEncode({for (final e in a.entries) e.key: e.value.millisecondsSinceEpoch}));
  }

  List<({String docId, DateTime at})> _readSnoozes() {
    try {
      return [
        for (final x in jsonDecode(_store.readRaw(SettingsRepository.kRemSnoozes) ?? '[]') as List)
          (docId: (x as Map)['doc'] as String, at: DateTime.fromMillisecondsSinceEpoch(x['at'] as int)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeSnoozes(List<({String docId, DateTime at})> s) => _store.writeRaw(
      SettingsRepository.kRemSnoozes, jsonEncode([for (final x in s) {'doc': x.docId, 'at': x.at.millisecondsSinceEpoch}]));

  Map<String, DateTime> _readAnchors() {
    try {
      final m = jsonDecode(_store.readRaw(SettingsRepository.kRemDebugAnchors) ?? '{}') as Map;
      return {for (final e in m.entries) e.key as String: DateTime.fromMillisecondsSinceEpoch(e.value as int)};
    } catch (_) {
      return {};
    }
  }
}

/// Debug builds only (R64): `--dart-define=DOCUKIT_REMINDER_MINUTES=true`
/// makes a reminder "day" one minute. Release builds always use days.
const _debugMinutes = kDebugMode && bool.fromEnvironment('DOCUKIT_REMINDER_MINUTES');

/// The app's scheduler (notification texts in the device language).
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => ReminderScheduler(
      repo: ref.watch(libraryRepositoryProvider),
      notifications: ref.watch(notificationServiceProvider),
      store: ref.watch(settingsRepositoryProvider),
      settings: () => ref.read(settingsProvider),
      l10n: () {
        try {
          return lookupAppLocalizations(PlatformDispatcher.instance.locale);
        } on FlutterError {
          return lookupAppLocalizations(const Locale('en'));
        }
      },
      deviceZone: () async {
        try {
          return await ref.read(nativeProvider).deviceTimeZone();
        } on Exception {
          return null;
        }
      },
      clock: ref.watch(clockProvider),
      limit: !kIsWeb && Platform.isIOS ? iosReminderLimit : androidReminderLimit,
      debugUnit: _debugMinutes ? const Duration(minutes: 1) : null,
    ));

/// Keeps the pending reminders right while the app runs (§4.7): starts the
/// service, reconciles on launch, resume, library changes (debounced) and
/// reminder settings changes, and hands taps to [onTap].
class RemindersRuntime {
  RemindersRuntime(this._ref);
  final Ref _ref;
  StreamSubscription<LibraryChange>? _sub;
  Timer? _debounce;
  bool _started = false;

  ReminderScheduler get _scheduler => _ref.read(reminderSchedulerProvider);

  Future<void> start({required void Function(NotificationTap tap) onTap}) async {
    if (_started) return;
    _started = true;
    final l = _ref.read(reminderSchedulerProvider)._l10n();
    final n = _ref.read(notificationServiceProvider);
    await n.init(channelName: l.rmdChannelName, channelDescription: l.rmdChannelDesc, snoozeLabel: l.rmdSnooze, onTap: onTap);
    _sub = _ref.read(libraryRepositoryProvider).changes.listen((c) {
      if (c.kind == LibraryChangeKind.folders) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () => unawaited(_scheduler.reconcile()));
    });
    await _scheduler.reconcile();
    final launch = await n.takeLaunchTap();
    if (launch != null) onTap(launch);
  }

  void _settingsChanged(AppSettings? before, AppSettings now) {
    if (_started && before != null && (before.remMinuteOfDay != now.remMinuteOfDay || before.remShowNames != now.remShowNames)) {
      unawaited(_scheduler.reconcile());
    }
  }

  /// Back in the foreground: permission, zone or date may have changed.
  void resumed() {
    if (_started) unawaited(_scheduler.reconcile());
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_sub?.cancel());
  }
}

final remindersRuntimeProvider = Provider<RemindersRuntime>((ref) {
  final r = RemindersRuntime(ref);
  ref.listen(settingsProvider, r._settingsChanged);
  ref.onDispose(r.dispose);
  return r;
});

/// Whether reminders can show (S42 "Off — notifications are blocked", S46).
/// Invalidated after a permission prompt and on resume.
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await ref.watch(notificationServiceProvider).enabled();
  } on Exception {
    return false;
  }
});
