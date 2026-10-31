import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/formatting/date_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../data/library/library_repository.dart';
import '../application/expiry.dart';
import '../application/reminder_scheduler.dart';

/// S44 · Expiry & reminders (RELEASE_V1_5 §3, FR-REM-01–03). No ads (a sheet).
Future<void> showExpirySheet(BuildContext context, LibraryDoc doc) => showAppSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ExpirySheet(doc),
    );

class _ExpirySheet extends ConsumerStatefulWidget {
  const _ExpirySheet(this.doc);
  final LibraryDoc doc;

  @override
  ConsumerState<_ExpirySheet> createState() => _ExpirySheetState();
}

class _ExpirySheetState extends ConsumerState<_ExpirySheet> {
  late DateTime? _date = widget.doc.expiryDate;
  late final Set<int> _offsets = {...(widget.doc.expiryDate == null ? defaultReminderOffsets : widget.doc.reminderOffsets)};

  /// null = the Settings reminder time.
  late int? _minute = widget.doc.reminderMinuteOfDay;
  bool _blocked = false, _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(notificationServiceProvider).enabled().then((ok) {
      if (mounted) setState(() => _blocked = !ok);
    }).catchError((Object _) {}));
  }

  DateTime get _now => ref.read(clockProvider)();
  int get _effectiveMinute => _minute ?? ref.read(settingsProvider).remMinuteOfDay;

  void _years(int y) {
    final n = _now;
    setState(() => _date = DateTime(n.year + y, n.month, n.day));
  }

  Future<void> _pickDate() async {
    final n = _now;
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(n.year + 1, n.month, n.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final m = _effectiveMinute;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (t != null && mounted) setState(() => _minute = t.hour * 60 + t.minute);
  }

  Future<void> _save({bool remove = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(libraryRepositoryProvider);
    final scheduler = ref.read(reminderSchedulerProvider);
    final n = ref.read(notificationServiceProvider);
    final date = remove ? null : _date;
    final offsets = date == null ? const <int>[] : (reminderOffsets.where(_offsets.contains).toList());
    // FR-REM-03: asked only now, on the first save that sets reminders.
    var blocked = false;
    if (date != null && offsets.isNotEmpty && !await n.enabled()) blocked = !await n.requestPermission();
    await repo.setExpiry(widget.doc.id, date, offsets, date == null ? null : _minute);
    await scheduler.expirySaved(widget.doc.id);
    await scheduler.reconcile();
    ref.invalidate(notificationsEnabledProvider);
    if (!mounted) return;
    if (blocked) {
      // The expiry is saved either way; say why no reminders will come.
      setState(() {
        _blocked = true;
        _saving = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final date = _date;
    final m = _effectiveMinute;
    final time = TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);
    final next = date == null ? null : nextReminder(date, _offsets.toList(), m, _now);
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(l.rmdTitle, style: context.text.titleLarge)),
          IconButton(tooltip: l.actionClose, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        ]),
        OutlinedButton.icon(
          key: const ValueKey('rmd-date'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), alignment: Alignment.centerLeft),
          onPressed: _pickDate,
          icon: const Icon(Icons.event_rounded),
          label: Text(date == null ? l.rmdPickDate : formatDate(date)),
        ),
        if (date != null && daysUntil(date, _now) < 0) ...[
          const SizedBox(height: Space.x1),
          Text(expiryLabel(l, date, _now), style: context.text.bodyMedium?.copyWith(color: context.colors.error)),
        ],
        const SizedBox(height: Space.x2),
        Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
          ActionChip(key: const ValueKey('rmd-1y'), label: Text(l.rmdQuick1y), onPressed: () => _years(1)),
          ActionChip(key: const ValueKey('rmd-5y'), label: Text(l.rmdQuick5y), onPressed: () => _years(5)),
          ActionChip(key: const ValueKey('rmd-10y'), label: Text(l.rmdQuick10y), onPressed: () => _years(10)),
          ActionChip(key: const ValueKey('rmd-none'), label: Text(l.rmdNone), onPressed: () => setState(() => _date = null)),
        ]),
        if (date != null) ...[
          const SizedBox(height: Space.x4),
          Text(l.rmdRemindMe, style: context.text.titleSmall),
          const SizedBox(height: Space.x2),
          Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
            for (final o in reminderOffsets)
              FilterChip(
                key: ValueKey('rmd-off-$o'),
                label: Text(offsetLabel(l, o)),
                selected: _offsets.contains(o),
                onSelected: (on) => setState(() => on ? _offsets.add(o) : _offsets.remove(o)),
              ),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('rmd-time'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _pickTime,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded),
              label: Text(l.rmdAtTime(time)),
            ),
          ),
          if (_offsets.isNotEmpty) Text(next == null ? l.rmdNoNext : l.rmdNext(formatDateTime(next)), style: muted),
        ],
        if (_blocked && date != null && _offsets.isNotEmpty) ...[
          const SizedBox(height: Space.x3),
          Container(
            key: const ValueKey('rmd-blocked'),
            padding: const EdgeInsets.all(Space.x3),
            decoration: BoxDecoration(color: context.colors.errorContainer, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(children: [
              Expanded(child: Text(l.rmdBlocked, style: TextStyle(color: context.colors.onErrorContainer))),
              TextButton(
                onPressed: () => ref.read(deviceServicesProvider).openAppSettings(),
                child: Text(l.openSettings),
              ),
            ]),
          ),
        ],
        const SizedBox(height: Space.x4),
        Row(children: [
          if (widget.doc.expiryDate != null)
            TextButton(
              key: const ValueKey('rmd-remove'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _saving ? null : () => _save(remove: true),
              child: Text(l.rmdRemove),
            ),
          const Spacer(),
          FilledButton(
            key: const ValueKey('rmd-save'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: _saving ? null : _save,
            child: Text(l.actionSave),
          ),
        ]),
      ]),
    );
  }
}
