import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/theme/tokens.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_copy.dart';
import '../../core/files/file_gateway.dart';
import '../../core/files/paths.dart';
import '../../core/files/zip_builder.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/operation/multi_output.dart';
import '../../core/operation/tool_operation.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/db/app_database.dart';
import '../search/tool_catalog.dart';
import 'save_flow.dart';

/// One file of a multi-output job, for S22 and the multi Details list. Built
/// from a live [OutputItem] or a stored `operation_outputs` row.
class OutputEntry {
  const OutputEntry({
    required this.index,
    required this.name,
    this.path,
    this.mime = 'application/octet-stream',
    this.bytes,
    this.beforeBytes,
    this.error,
    this.targetBytes,
  });

  final int index;

  /// Output file name, or the source name for a failed item.
  final String name;

  /// Absolute path of the app copy; null when the item failed.
  final String? path;
  final String mime;
  final int? bytes, beforeBytes;
  final AppErrorCode? error;

  /// Set when target-size search missed (FR-BAT-11: "Closest to …").
  final int? targetBytes;

  bool get ok => path != null;

  factory OutputEntry.fromItem(OutputItem item) => switch (item) {
        OutputOk() => OutputEntry(
            index: item.index,
            name: item.name,
            path: item.path,
            mime: item.mime,
            bytes: item.meta.bytes,
            beforeBytes: item.beforeBytes,
            targetBytes: item.meta.flags['targetMissed'] == true ? item.meta.flags['targetBytes'] as int? : null,
          ),
        OutputFailed() => OutputEntry(index: item.index, name: item.sourceName, error: item.code),
      };

  /// Null for a discarded output (no path and no error).
  static OutputEntry? fromRow(OperationOutputRow row, String Function(String relPath) absolute) {
    final meta = row.metaJson == null ? const <String, Object?>{} : (jsonDecode(row.metaJson!) as Map).cast<String, Object?>();
    final error = AppErrorCode.tryParse(row.errorCode);
    if (row.relPath == null && error == null) return null;
    return OutputEntry(
      index: row.position,
      name: row.displayName,
      path: row.relPath == null ? null : absolute(row.relPath!),
      mime: (meta['mime'] as String?) ?? 'application/octet-stream',
      bytes: row.sizeBytes,
      beforeBytes: row.beforeBytes,
      error: error,
      targetBytes: meta['targetMissed'] == true ? meta['targetBytes'] as int? : null,
    );
  }
}

/// S22 totals card text: "Before 46.2 MB → After 9.8 MB" when every output has
/// its own input (batch), else "12 PDFs · 4.1 MB" / "24 images · 18 MB".
String multiTotalsLine(BuildContext context, List<OutputEntry> entries) {
  final l = context.l10n;
  final ok = entries.where((e) => e.ok).toList();
  final after = ok.fold<int>(0, (s, e) => s + (e.bytes ?? 0));
  if (ok.isNotEmpty && ok.every((e) => e.beforeBytes != null)) {
    final before = ok.fold<int>(0, (s, e) => s + e.beforeBytes!);
    return l.multiTotals(formatBytes(before), formatBytes(after));
  }
  final pdfs = ok.isNotEmpty && ok.every((e) => e.mime == 'application/pdf');
  return pdfs ? l.multiCountPdfs(ok.length, formatBytes(after)) : l.multiCountImages(ok.length, formatBytes(after));
}

/// Bytes before/after over the batch items, for the savings ring; null when
/// the outputs have no inputs of their own (Split, PDF to Images).
(int, int)? multiBeforeAfter(List<OutputEntry> entries) {
  final ok = entries.where((e) => e.ok).toList();
  if (ok.isEmpty || ok.any((e) => e.beforeBytes == null)) return null;
  return (ok.fold(0, (s, e) => s + e.beforeBytes!), ok.fold(0, (s, e) => s + (e.bytes ?? 0)));
}

/// One file row: ✓ name · size · −% · ⋮ / ⚠ closest to target / ✕ error.
class OutputRow extends StatelessWidget {
  const OutputRow({super.key, required this.entry, this.onOpen, this.onShare, this.onSave, this.onDiscard});
  final OutputEntry entry;
  final void Function(BuildContext anchor)? onOpen;
  final void Function(BuildContext anchor)? onShare;
  final VoidCallback? onSave, onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = entry;
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final (icon, color) = !e.ok
        ? (Icons.cancel_rounded, context.colors.error)
        : e.targetBytes != null
            ? (Icons.warning_amber_rounded, context.docu.warning)
            : (Icons.check_circle_rounded, context.docu.success);
    final detail = !e.ok
        ? l.multiItemFailed(errorCopy(l, AppError(e.error ?? AppErrorCode.processingFailed)).title)
        : [
            if (e.bytes != null) formatBytes(e.bytes!),
            if (e.beforeBytes != null && e.bytes != null && e.bytes! < e.beforeBytes!)
              l.resultSmaller(percentChange(e.beforeBytes!, e.bytes!).abs()),
            if (e.targetBytes != null) l.multiItemClosest(formatBytes(e.targetBytes!)),
          ].join(' · ');
    return Builder(
      builder: (anchor) => ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 56,
        leading: Icon(icon, color: color, size: 22),
        title: MiddleEllipsisText(e.name, style: context.text.bodyLarge),
        subtitle: Text(detail, style: muted),
        onTap: e.ok && onOpen != null ? () => onOpen!(anchor) : null,
        trailing: !e.ok
            ? null
            : PopupMenuButton<int>(
                tooltip: l.orgMore,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) => switch (v) {
                  0 => onOpen?.call(anchor),
                  1 => onShare?.call(anchor),
                  2 => onSave?.call(),
                  _ => onDiscard?.call(),
                },
                itemBuilder: (_) => [
                  if (onOpen != null) PopupMenuItem(value: 0, child: Text(l.actionOpenWith)),
                  if (onShare != null) PopupMenuItem(value: 1, child: Text(l.actionShare)),
                  if (onSave != null) PopupMenuItem(value: 2, child: Text(l.actionSave)),
                  if (onDiscard != null) PopupMenuItem(value: 3, child: Text(l.actionDiscard)),
                ],
              ),
      ),
    );
  }
}

/// FR-BAT-02 · Save all… → one folder. Cancel is silent; a partial failure
/// offers Retry for the files that weren't written.
Future<void> saveAllOutputs(BuildContext context, WidgetRef ref, {required String opId, required List<OutputEntry> entries}) async {
  final l = context.l10n;
  final ok = entries.where((e) => e.ok).toList();
  if (ok.isEmpty) return;
  final outcome = await ref
      .read(fileGatewayProvider)
      .saveManyToFolder([for (final e in ok) SaveItem(path: e.path!, name: e.name, mime: e.mime)]);
  if (!context.mounted) return;
  switch (outcome) {
    case SavedMany(:final saved, :final failed, :final failedIndexes, :final folderName):
      if (saved > 0) await ref.read(historyRepositoryProvider).markSaved(opId);
      if (!context.mounted) return;
      if (failed == 0) {
        showAppSnack(context, folderName == null ? l.multiSaved(saved) : l.multiSavedFolder(saved, folderName));
      } else {
        final retry = failedIndexes.isEmpty ? ok : [for (final i in failedIndexes) if (i < ok.length) ok[i]];
        showAppSnack(context, l.multiSavedPartial(saved, ok.length, failed),
            actionLabel: l.actionTryAgain, onAction: () => saveAllOutputs(context, ref, opId: opId, entries: retry));
      }
    case SaveManyCancelled():
      break;
    case SaveManyFailed():
      showAppSnack(context, l.saveFailed,
          actionLabel: l.actionTryAgain, onAction: () => saveAllOutputs(context, ref, opId: opId, entries: entries));
  }
}

/// FR-BAT-03 · Save as ZIP: built once on demand into `outputs/<jobId>/`, then
/// saved through the normal save dialog.
Future<void> saveOutputsAsZip(BuildContext context, WidgetRef ref,
    {required String opId, required ToolId tool, required List<OutputEntry> entries}) async {
  final zip = await _ensureZip(context, ref, opId: opId, tool: tool, entries: entries);
  if (zip == null || !context.mounted) return;
  await saveResult(context, ref, path: zip, name: p.basename(zip), mime: 'application/zip', opId: opId);
}

/// FR-BAT-04 · Share all; above the share cap, offer one ZIP instead.
Future<void> shareAllOutputs(BuildContext anchor, WidgetRef ref,
    {required String opId, required ToolId tool, required List<OutputEntry> entries}) async {
  final l = anchor.l10n;
  final ok = entries.where((e) => e.ok).toList();
  if (ok.isEmpty) return;
  final mimes = ok.map((e) => e.mime).toSet();
  final gateway = ref.read(fileGatewayProvider);
  final outcome = await gateway.share([for (final e in ok) e.path!],
      mime: mimes.length == 1 ? mimes.single : '*/*', origin: originOf(anchor));
  if (!anchor.mounted) return;
  if (outcome == ShareOutcome.failed) {
    showAppSnack(anchor, l.saveFailed);
  } else if (outcome == ShareOutcome.tooMany) {
    final yes = await askAdaptive(anchor, title: l.multiShareTooMany, no: l.actionCancel, yes: l.actionContinue, destructive: false);
    if (!yes || !anchor.mounted) return;
    final zip = await _ensureZip(anchor, ref, opId: opId, tool: tool, entries: entries);
    if (zip == null || !anchor.mounted) return;
    await shareResult(anchor, ref, path: zip, mime: 'application/zip');
  }
}

/// Drops a built ZIP (after a discard it would no longer match the list).
Future<void> forgetZip(WidgetRef ref, String opId) async {
  final history = ref.read(historyRepositoryProvider);
  final rel = (await history.get(opId))?.row.zipRelPath;
  if (rel == null) return;
  await deleteQuietly(File(ref.read(outputsRepositoryProvider).absolute(rel)));
  await history.setZip(opId, null);
}

/// The job's ZIP, reusing one already built. Shows "Zipping n of N" with
/// Cancel; returns null when cancelled or failed (failure shows a snack).
Future<String?> _ensureZip(BuildContext context, WidgetRef ref,
    {required String opId, required ToolId tool, required List<OutputEntry> entries}) async {
  final history = ref.read(historyRepositoryProvider);
  final outputs = ref.read(outputsRepositoryProvider);
  final existing = (await history.get(opId))?.row.zipRelPath;
  if (existing != null && await outputs.exists(existing)) return outputs.absolute(existing);
  if (!context.mounted) return null;

  final ok = entries.where((e) => e.ok).toList();
  final rel = p.join(opId, zipFileName(tool, ref.read(clockProvider)()));
  final out = outputs.absolute(rel);
  final cancel = CancelToken();
  final progress = ValueNotifier<int>(0);
  final l = context.l10n;
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog.adaptive(
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, done, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.multiZipping(done, ok.length), textAlign: TextAlign.center),
            const SizedBox(height: Space.x3),
            LinearProgressIndicator(value: ok.isEmpty ? null : done / ok.length),
          ]),
        ),
        actions: [adaptiveAction(ctx, label: l.actionCancel, onPressed: cancel.cancel)],
      ),
    ),
  ));
  try {
    await buildZip([for (final e in ok) ZipItem(e.path!, e.name)], out,
        cancel: cancel, onProgress: (done, _) => progress.value = done);
    await history.setZip(opId, rel);
    return out;
  } on CancelledException {
    return null;
  } on AppError {
    if (context.mounted) showAppSnack(context, l.saveFailed);
    return null;
  } finally {
    navigator.pop();
    progress.dispose();
  }
}
