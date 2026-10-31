import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../platform/system_flow.dart';

/// A notification DocuKit has scheduled (only ours carry a payload).
class PendingNotification {
  const PendingNotification(this.id, this.payload);
  final int id;
  final String? payload;
}

/// One local notification at a wall-clock time in the device's zone.
class NotificationRequest {
  const NotificationRequest({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    this.snoozeLabel,
  });
  final int id;

  /// Local date and time (year…minute); interpreted in the device's zone.
  final DateTime at;
  final String title, body, payload;

  /// FR-REM-09: the "Remind me tomorrow" action, when offered.
  final String? snoozeLabel;
}

/// A tap on a notification (or its snooze action).
class NotificationTap {
  const NotificationTap(this.payload, {this.snooze = false});
  final String payload;
  final bool snooze;
}

/// Local notifications for 1.5 reminders (RELEASE_V1_5 §4.7) behind an
/// interface (ARCHITECTURE rule: plugins sit behind `core/`). Fakes in tests.
abstract interface class NotificationService {
  /// Channel, zone, categories; [onTap] gets taps while the app runs.
  Future<void> init({required String channelName, required String channelDescription, required String snoozeLabel,
      required void Function(NotificationTap tap) onTap});

  /// The tap that launched the app (cold start), once.
  Future<NotificationTap?> takeLaunchTap();

  /// Sets the zone scheduled times are in (IANA id, e.g. Asia/Kolkata).
  void setZone(String zone);

  Future<bool> enabled();

  /// Android 13+ / iOS: asks once (FR-REM-03). True when allowed.
  Future<bool> requestPermission();

  Future<List<PendingNotification>> pending();
  Future<void> schedule(NotificationRequest r);
  Future<void> cancel(int id);
}

/// FR-REM-09's action id.
const snoozeActionId = 'rmd_snooze';
const reminderChannelId = 'doc_reminders';
const _iosCategory = 'doc_reminder';

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _zonesLoaded = false;
  String? _channelName, _channelDescription;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  static NotificationTap? _tapOf(NotificationResponse r) {
    final p = r.payload;
    return p == null ? null : NotificationTap(p, snooze: r.actionId == snoozeActionId);
  }

  @override
  Future<void> init({required String channelName, required String channelDescription, required String snoozeLabel,
      required void Function(NotificationTap tap) onTap}) async {
    _channelName = channelName;
    _channelDescription = channelDescription;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Never ask at launch: only on the first save with reminders (FR-REM-03).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          notificationCategories: [
            DarwinNotificationCategory(_iosCategory, actions: [
              DarwinNotificationAction.plain(snoozeActionId, snoozeLabel,
                  options: const {DarwinNotificationActionOption.foreground}),
            ]),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final t = _tapOf(r);
        if (t != null) onTap(t);
      },
    );
    await _android?.createNotificationChannel(AndroidNotificationChannel(reminderChannelId, channelName,
        description: channelDescription, importance: Importance.defaultImportance));
  }

  @override
  Future<NotificationTap?> takeLaunchTap() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d?.didNotificationLaunchApp != true || r == null) return null;
    return _tapOf(r);
  }

  @override
  void setZone(String zone) {
    if (!_zonesLoaded) {
      tzdata.initializeTimeZones();
      _zonesLoaded = true;
    }
    try {
      tz.setLocalLocation(tz.getLocation(zone));
    } on Exception {
      tz.setLocalLocation(tz.UTC); // unknown id: never crash the scheduler
    }
  }

  @override
  Future<bool> enabled() async {
    if (Platform.isAndroid) return await _android?.areNotificationsEnabled() ?? false;
    final p = await _ios?.checkPermissions();
    return p?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() => SystemFlow.run(() async {
        if (Platform.isAndroid) return await _android?.requestNotificationsPermission() ?? false;
        return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
      });

  @override
  Future<List<PendingNotification>> pending() async =>
      [for (final p in await _plugin.pendingNotificationRequests()) PendingNotification(p.id, p.payload)];

  @override
  Future<void> schedule(NotificationRequest r) async {
    final when = tz.TZDateTime(tz.local, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute);
    await _plugin.zonedSchedule(
      id: r.id,
      scheduledDate: when,
      title: r.title,
      body: r.body,
      payload: r.payload,
      // Day-level reminders: inexact is fine and needs no exact-alarm permission (§4.7).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          reminderChannelId,
          _channelName ?? reminderChannelId,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          actions: [
            if (r.snoozeLabel != null) AndroidNotificationAction(snoozeActionId, r.snoozeLabel!, showsUserInterface: true),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: r.snoozeLabel == null ? null : _iosCategory),
      ),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
