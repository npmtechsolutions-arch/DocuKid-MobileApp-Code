import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/ads/bottom_banner.dart';
import '../../../core/auth/device_auth.dart';
import '../../../core/formatting/bytes_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../data/settings/app_settings.dart';
import '../application/app_lock.dart';
import '../application/index_queue.dart';
import '../application/library_controller.dart';
import '../application/reminder_scheduler.dart';
import 'backup_flow.dart';

/// S46 My Documents settings (RELEASE_V1_5 §3). T12.5 adds "Make documents
/// searchable" (FR-LIB-15/16); reminders, lock and storage join in T12.6–T12.8.
class LibrarySettingsScreen extends ConsumerWidget {
  const LibrarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final status = ref.watch(indexStatusProvider).value ?? const IndexStatus();
    final allowed = ref.watch(notificationsEnabledProvider).value ?? true;
    final stats = ref.watch(libraryStatsProvider).value;
    final state = status.waiting == 0
        ? l.libIndexIdle
        : switch (status.paused) {
            IndexPause.user => l.libIndexPausedUser,
            IndexPause.battery => l.libIndexPausedBattery,
            IndexPause.busy => l.libIndexBusy,
            // Not visible while backgrounded; shown as waiting.
            IndexPause.background || null => status.working ? l.libIndexing(status.waiting) : l.libIndexWaiting(status.waiting),
          };
    final detail = status.waiting > 0 && status.paused != null ? '${l.libIndexWaiting(status.waiting)} · $state' : state;

    // A Settings sub-page: the Settings banner (§3.2).
    return AppBottomBanner(
      unit: AdUnit.bannerSettings,
      child: Scaffold(
        appBar: AppBar(title: Text(l.setLibTitle)),
        body: ContentWidth(
          child: ListView(padding: const EdgeInsets.only(bottom: Space.x8), children: [
            SectionHeader(l.setLibSearchable),
            Card(
              child: Column(children: [
                SwitchListTile.adaptive(
                  key: const ValueKey('set-lib-scans'),
                  secondary: const Icon(Icons.document_scanner_outlined),
                  title: Text(l.setLibScans),
                  value: s.libIndexScans,
                  onChanged: (v) => c.update((x) => x.copyWith(libIndexScans: v)),
                ),
                SwitchListTile.adaptive(
                  key: const ValueKey('set-lib-other'),
                  secondary: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l.setLibOther),
                  value: s.libIndexOther,
                  onChanged: (v) => c.update((x) => x.copyWith(libIndexOther: v)),
                ),
                ListTile(
                  key: const ValueKey('set-lib-status'),
                  leading: Icon(status.paused == null ? Icons.manage_search_rounded : Icons.pause_circle_outline_rounded),
                  title: Text(detail),
                  subtitle: Text(l.setLibSearchNote),
                  trailing: TextButton(
                    key: const ValueKey('set-lib-pause'),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => c.update((x) => x.copyWith(libIndexPaused: !x.libIndexPaused)),
                    child: Text(s.libIndexPaused ? l.libIndexResume : l.libIndexPause),
                  ),
                ),
              ]),
            ),
            SectionHeader(l.setLibReminders),
            Card(
              child: Column(children: [
                ListTile(
                  key: const ValueKey('set-lib-time'),
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(l.setLibReminderTime),
                  trailing: Text(TimeOfDay(hour: s.remMinuteOfDay ~/ 60, minute: s.remMinuteOfDay % 60).format(context),
                      style: context.text.bodyLarge),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: TimeOfDay(hour: s.remMinuteOfDay ~/ 60, minute: s.remMinuteOfDay % 60));
                    // FR-REM-02: 08:00–21:00.
                    if (t != null) await c.update((x) => x.copyWith(remMinuteOfDay: (t.hour * 60 + t.minute).clamp(480, 1260)));
                  },
                ),
                SwitchListTile.adaptive(
                  key: const ValueKey('set-lib-names'),
                  secondary: const Icon(Icons.badge_outlined),
                  title: Text(l.setLibShowNames),
                  value: s.remShowNames,
                  onChanged: (v) => c.update((x) => x.copyWith(remShowNames: v)),
                ),
                ListTile(
                  key: const ValueKey('set-lib-notifications'),
                  leading: Icon(allowed ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                  title: Text(l.setLibNotifications),
                  subtitle: Text(allowed ? l.setLibNotifAllowed : l.setLibNotifBlocked),
                  trailing: allowed
                      ? Icon(Icons.check_rounded, color: context.colors.primary)
                      : TextButton(
                          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                          onPressed: () => ref.read(deviceServicesProvider).openAppSettings(),
                          child: Text(l.openSettings),
                        ),
                ),
              ]),
            ),
            SectionHeader(l.setLibLock),
            Card(child: _LockSection(settings: s)),
            SectionHeader(l.setLibStorage),
            Card(
              child: Column(children: [
                ListTile(
                  key: const ValueKey('set-lib-uses'),
                  leading: const Icon(Icons.storage_rounded),
                  title: Text(stats == null ? '…' : l.setLibUses(formatBytes(stats.totalBytes), stats.docCount)),
                ),
                ListTile(
                  key: const ValueKey('set-lib-export'),
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(l.setLibExport),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: (stats?.docCount ?? 0) > 0,
                  onTap: () => exportLibraryFlow(context, ref),
                ),
                ListTile(
                  key: const ValueKey('set-lib-import'),
                  leading: const Icon(Icons.unarchive_outlined),
                  title: Text(l.setLibImport),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => importBackupFlow(context, ref),
                ),
                // FR-LIB-20 (ADR-054).
                ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: context.colors.onSurfaceVariant),
                  title: Text(l.setLibBackupNote, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// S46 Lock (FR-LCK-01–05): on / off with one check each; without a screen
/// lock the switch is off and explains (FR-LCK-02).
class _LockSection extends ConsumerWidget {
  const _LockSection({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = settings;
    final c = ref.read(settingsProvider.notifier);
    final lock = ref.read(appLockProvider.notifier);
    final hasScreenLock = ref.watch(screenLockAvailableProvider).value ?? true;
    final canToggle = s.lockEnabled || hasScreenLock;

    Future<void> toggle(bool on) async {
      final r = on ? await lock.enable(l.lckReason) : await lock.disable(l.lckReason);
      if (r == AuthOutcome.noCredential) ref.invalidate(screenLockAvailableProvider);
    }

    Widget radio<T>(String key, T value, T group, String label, ValueChanged<T> set) => RadioListTile<T>.adaptive(
          key: ValueKey(key),
          value: value,
          // ignore: deprecated_member_use
          groupValue: group,
          // ignore: deprecated_member_use
          onChanged: (v) => set(v as T),
          title: Text(label),
        );

    return Column(children: [
      SwitchListTile.adaptive(
        key: const ValueKey('set-lib-lock'),
        secondary: const Icon(Icons.lock_outline_rounded),
        title: Text(l.setLibLockOn),
        subtitle: canToggle ? null : Text(l.lckNoScreenLock),
        value: s.lockEnabled,
        onChanged: canToggle ? toggle : null,
      ),
      if (!canToggle)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.only(right: Space.x2),
            child: TextButton(
              key: const ValueKey('set-lib-lock-settings'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => ref.read(deviceServicesProvider).openAppSettings(),
              child: Text(l.openSettings),
            ),
          ),
        ),
      if (s.lockEnabled) ...[
        ListTile(title: Text(l.setLibLockScope, style: context.text.titleSmall)),
        radio('lock-scope-library', LockScope.library, s.lockScope, l.setLibLockScopeLibrary,
            (v) => c.update((x) => x.copyWith(lockScope: v))),
        radio('lock-scope-app', LockScope.app, s.lockScope, l.setLibLockScopeApp, (v) => c.update((x) => x.copyWith(lockScope: v))),
        ListTile(title: Text(l.setLibLockAfter, style: context.text.titleSmall)),
        for (final (t, label) in [
          (LockTimeout.immediate, l.setLibLockImmediately),
          (LockTimeout.m1, l.setLibLock1m),
          (LockTimeout.m5, l.setLibLock5m),
        ])
          radio('lock-after-${t.name}', t, s.lockTimeout, label, (v) => c.update((x) => x.copyWith(lockTimeout: v))),
        SwitchListTile.adaptive(
          key: const ValueKey('set-lib-hide-recents'),
          secondary: const Icon(Icons.visibility_off_outlined),
          title: Text(l.setLibHideRecents),
          subtitle: Text(l.setLibHideRecentsNote),
          value: s.lockHideRecents,
          onChanged: (v) => c.update((x) => x.copyWith(lockHideRecents: v)),
        ),
      ],
    ]);
  }
}
