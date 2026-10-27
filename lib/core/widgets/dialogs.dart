import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../files/file_naming.dart';
import '../files/picked_file.dart';
import '../formatting/bytes_format.dart';
import 'common.dart';

/// All sheets go through here: drag handle + safe area (incl. the gesture bar).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      useSafeArea: useSafeArea,
      isScrollControlled: isScrollControlled,
      builder: (ctx) => SafeArea(top: false, child: builder(ctx)),
    );

/// D2 — confirm a destructive action. Returns (confirmed, checkboxValue).
Future<(bool, bool)> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? checkboxLabel,
  bool checkboxInitial = true,
}) async {
  var checked = checkboxInitial;
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog.adaptive(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            if (checkboxLabel != null)
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: (v) => setState(() => checked = v ?? false),
                  title: Text(checkboxLabel),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
          ],
        ),
        actions: [
          adaptiveAction(ctx, label: ctx.l10n.actionCancel, onPressed: () => Navigator.pop(ctx, false)),
          adaptiveAction(ctx, label: confirmLabel, destructive: true, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    ),
  );
  return (ok ?? false, checked);
}

Widget adaptiveAction(BuildContext context,
    {required String label, required VoidCallback onPressed, bool destructive = false, bool primary = false}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: destructive,
      isDefaultAction: primary,
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: destructive ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : null,
    child: Text(label),
  );
}

/// A two-button adaptive question (D4 and similar). Returns true for [yes].
Future<bool> askAdaptive(BuildContext context,
    {required String title, String? body, required String no, required String yes, bool destructive = true}) async {
  final r = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        adaptiveAction(ctx, label: no, onPressed: () => Navigator.pop(ctx, false), primary: true),
        adaptiveAction(ctx, label: yes, destructive: destructive, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return r ?? false;
}

/// D4 — unsaved work.
Future<bool> confirmLeave(BuildContext context, {bool organizer = false}) {
  final l = context.l10n;
  return askAdaptive(
    context,
    title: organizer ? l.unsavedOrganizerTitle : l.unsavedTitle,
    body: organizer ? l.unsavedOrganizerBody : l.unsavedBody,
    no: l.actionStay,
    yes: l.actionLeave,
  );
}

/// D3 — rename. The extension is shown separately and can't be edited.
Future<String?> renameDialog(BuildContext context, {required String currentName}) async {
  final dot = currentName.lastIndexOf('.');
  final base = dot > 0 ? currentName.substring(0, dot) : currentName;
  final ext = dot > 0 ? currentName.substring(dot + 1) : '';
  final ctrl = TextEditingController(text: base);
  final result = await showAdaptiveDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final l = ctx.l10n;
      final trimmed = ctrl.text.trim();
      final preview = trimmed.isEmpty ? null : withExtension(trimmed, ext);
      return AlertDialog(
        title: Text(l.renameTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.renameHint,
                suffixText: ext.isEmpty ? null : '.$ext',
                errorText: trimmed.isEmpty ? l.renameEmpty : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (preview != null) Navigator.pop(ctx, preview);
              },
            ),
            if (preview != null) ...[
              const SizedBox(height: Space.x2),
              Text(l.renamePreview(preview), style: ctx.text.bodySmall?.copyWith(color: ctx.colors.onSurfaceVariant)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.actionCancel)),
          FilledButton(
            onPressed: preview == null ? null : () => Navigator.pop(ctx, preview),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: Text(l.actionRename),
          ),
        ],
      );
    }),
  );
  ctrl.dispose();
  return result;
}

/// D1 — file details sheet.
Future<void> showFileDetails(BuildContext context, PickedFile f) {
  final l = context.l10n;
  String yesNo(bool v) => v ? l.fdYes : l.fdNo;
  final rows = <(String, String)>[
    (l.fdName, f.displayName),
    (l.fdType, f.type.ext.toUpperCase()),
    (l.fdSize, formatBytes(f.sizeBytes)),
    if (f.image != null) (l.fdDimensions, l.metaDims(f.image!.width, f.image!.height)),
    if (f.image != null) (l.fdAlpha, yesNo(f.image!.hasAlpha)),
    if (f.image?.hasGps != null) (l.fdLocation, yesNo(f.image!.hasGps!)),
    if (f.pdf != null) (l.fdPages, '${f.pdf!.pageCount}'),
    if (f.isPdf) (l.fdProtected, yesNo(f.status.error?.name == 'encryptedDocument')),
  ];
  return showAppSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.fdTitle, style: ctx.text.titleLarge),
          const SizedBox(height: Space.x4),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 128, child: Text(k, style: ctx.text.bodyMedium?.copyWith(color: ctx.colors.onSurfaceVariant))),
                  Expanded(child: Text(v, style: ctx.text.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

enum MoveTarget { top, up, down, bottom }

/// Accessible non-drag reorder ("Move to…").
Future<MoveTarget?> showMoveToSheet(BuildContext context, {required bool canUp, required bool canDown}) {
  final l = context.l10n;
  return showAppSheet<MoveTarget>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.x2),
          child: Text(l.moveToTitle, style: ctx.text.titleMedium),
        ),
        ListTile(
          enabled: canUp,
          leading: const Icon(Icons.vertical_align_top_rounded),
          title: Text(l.moveTop),
          onTap: () => Navigator.pop(ctx, MoveTarget.top),
        ),
        ListTile(
          enabled: canUp,
          leading: const Icon(Icons.arrow_upward_rounded),
          title: Text(l.moveUp),
          onTap: () => Navigator.pop(ctx, MoveTarget.up),
        ),
        ListTile(
          enabled: canDown,
          leading: const Icon(Icons.arrow_downward_rounded),
          title: Text(l.moveDown),
          onTap: () => Navigator.pop(ctx, MoveTarget.down),
        ),
        ListTile(
          enabled: canDown,
          leading: const Icon(Icons.vertical_align_bottom_rounded),
          title: Text(l.moveBottom),
          onTap: () => Navigator.pop(ctx, MoveTarget.bottom),
        ),
        const SizedBox(height: Space.x4),
      ],
    ),
  );
}

int moveTargetIndex(MoveTarget t, int from, int length) => switch (t) {
      MoveTarget.top => 0,
      MoveTarget.up => (from - 1).clamp(0, length - 1),
      MoveTarget.down => (from + 1).clamp(0, length - 1),
      MoveTarget.bottom => length - 1,
    };

Future<void> showInfoSheet(BuildContext context, {required String title, required String body}) {
  return showAppSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline_rounded, color: ctx.colors.primary),
            const SizedBox(width: Space.x3),
            Expanded(child: Text(title, style: ctx.text.titleLarge)),
          ]),
          const SizedBox(height: Space.x4),
          Text(body, style: ctx.text.bodyLarge),
          const SizedBox(height: Space.x4),
          Row(children: [
            Icon(Icons.lock_rounded, size: 16, color: ctx.docu.success),
            const SizedBox(width: Space.x2),
            Expanded(child: Text(ctx.l10n.privacyPromise, style: ctx.text.bodySmall?.copyWith(color: ctx.colors.onSurfaceVariant))),
          ]),
        ],
      ),
    ),
  );
}
