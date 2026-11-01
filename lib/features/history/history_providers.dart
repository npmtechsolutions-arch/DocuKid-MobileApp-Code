import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_copy.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/formatting/date_format.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/history_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../job/multi_outputs.dart';
import '../search/tool_catalog.dart';

final recentProvider = StreamProvider.autoDispose<List<OperationRecord>>(
  (ref) => ref.watch(historyRepositoryProvider).watchRecent(5),
);

/// Availability is checked on display (FR-HIS-02): row + file on disk.
final outputAvailableProvider = FutureProvider.autoDispose.family<bool, String?>((ref, relPath) async {
  if (relPath == null) return false;
  return ref.watch(outputsRepositoryProvider).exists(relPath);
});

/// A multi-output job's files live in `outputs/<jobId>/`.
final outputDirAvailableProvider = FutureProvider.autoDispose.family<bool, String>((ref, opId) async {
  return Directory(ref.watch(outputsRepositoryProvider).absolute(opId)).exists();
});

/// The files of a multi-output job for Details (discarded ones left out).
final multiOutputsProvider = FutureProvider.autoDispose.family<List<OutputEntry>, String>((ref, opId) async {
  final rows = await ref.watch(historyRepositoryProvider).outputsOf(opId);
  final outputs = ref.watch(outputsRepositoryProvider);
  return [for (final row in rows) ?OutputEntry.fromRow(row, outputs.absolute)];
});

/// An OCR job that kept only reviewed/copied text: no file was ever made
/// (RELEASE_V1_3 §5), so it's never "no longer available".
bool isTextOnly(OperationRecord r) => r.tool == ToolId.ocr && r.completed && r.row.outputCount == 0;

/// A finished job that never made a file to keep: OCR text only, or a print
/// sent to the printer (FR-PRN-17). Never shown as "no longer available".
bool madeNoFile(OperationRecord r) => isTextOnly(r) || (r.tool == ToolId.print && r.completed);

bool recordAvailable(WidgetRef ref, OperationRecord r) {
  if (!r.outputRecorded) return false;
  if (r.isMulti) return ref.watch(outputDirAvailableProvider(r.id)).value ?? true;
  return ref.watch(outputAvailableProvider(r.row.outputRelPath)).value ?? true;
}

/// "16 of 18 done" for a PARTIAL multi-output job.
String partialLabel(AppLocalizations l, OperationRecord r) =>
    l.multiHeaderSome(r.row.outputCount - r.row.failedCount, r.row.outputCount);

String statusLabel(AppLocalizations l, OperationRecord r) => switch (r.status) {
      OpStatus.success => l.detStatusCompleted,
      OpStatus.partial => partialLabel(l, r),
      OpStatus.failed => l.detStatusFailed,
      OpStatus.cancelled => l.detStatusCancelled,
      OpStatus.interrupted => l.detStatusInterrupted,
      _ => l.detStatusRunning,
    };

/// "3.2 MB → 410 KB · 14:05" / "3 files · 47 pages · 5.3 MB" / "Failed — …".
String historySubtitle(AppLocalizations l, OperationRecord r, DateTime now) {
  final when = formatWhen(r.createdAt, now);
  switch (r.status) {
    case OpStatus.partial:
      final out = r.row.outputBytes ?? 0;
      return '${partialLabel(l, r)} · ${l.histSizes(formatBytes(r.row.inputTotalBytes), formatBytes(out))} · $when';
    case OpStatus.success:
      final out = r.row.outputBytes ?? 0;
      final tool = r.tool;
      if (isTextOnly(r)) return '${l.ocrTextOnlyHistory} · $when';
      if (tool == ToolId.print) return '${l.prnHistLine((r.outputMeta['sheets'] as int?) ?? 0)} · $when';
      if (tool == ToolId.ocr) {
        final pages = (r.outputMeta['pages'] as int?) ?? r.row.inputCount;
        return '${l.metaPages(pages)} · ${formatBytes(out)} · $when';
      }
      if (tool == ToolId.scanDocument && r.row.outputMime == 'application/pdf') {
        // A scan has no input files to count: "4 pages · 1.2 MB".
        final pages = (r.outputMeta['pages'] as int?) ?? r.row.inputCount;
        return '${l.metaPages(pages)} · ${formatBytes(out)} · $when';
      }
      if (tool == ToolId.pdfMerge || tool == ToolId.imageToPdf) {
        final pages = (r.outputMeta['pages'] as int?) ?? r.inputPages;
        return '${l.histFilesPages(r.row.inputCount, pages, formatBytes(out))} · $when';
      }
      return '${l.histSizes(formatBytes(r.row.inputTotalBytes), formatBytes(out))} · $when';
    case OpStatus.failed:
      if (r.tool == ToolId.print) return '${l.prnHistFailed} · $when';
      final code = AppErrorCode.tryParse(r.row.errorCode) ?? AppErrorCode.processingFailed;
      return '${l.histFailedLine(errorCopy(l, AppError(code)).title)} · $when';
    case OpStatus.cancelled:
      return '${l.histCancelled} · $when';
    case OpStatus.interrupted:
      return '${l.histInterrupted} · $when';
    default:
      return '${l.histRunning} · $when';
  }
}

class StatusIcon extends StatelessWidget {
  const StatusIcon(this.status, {super.key, this.label});
  final String status;

  /// Overrides the semantics label (PARTIAL: "16 of 18 done").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, color, fallback) = switch (status) {
      OpStatus.success => (Icons.check_circle_rounded, context.docu.success, l.detStatusCompleted),
      OpStatus.partial => (Icons.error_rounded, context.docu.warning, l.detStatusCompleted),
      OpStatus.failed => (Icons.cancel_rounded, context.colors.error, l.detStatusFailed),
      OpStatus.interrupted => (Icons.pause_circle_rounded, context.docu.warning, l.detStatusInterrupted),
      OpStatus.cancelled => (Icons.remove_circle_outline_rounded, context.colors.onSurfaceVariant, l.detStatusCancelled),
      _ => (Icons.timelapse_rounded, context.colors.primary, l.detStatusRunning),
    };
    return Icon(icon, color: color, semanticLabel: label ?? fallback, size: 22);
  }
}

/// One history/recent row (HistoryTile).
class HistoryTile extends ConsumerWidget {
  const HistoryTile({super.key, required this.record, required this.onTap, this.onLongPress});
  final OperationRecord record;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tool = record.tool;
    final d = tool == null ? null : toolById(tool);
    final available = record.completed && recordAvailable(ref, record);
    final unavailable = record.completed && !available && !madeNoFile(record);
    final title = record.row.outputName ?? (d?.title(l) ?? '');
    final now = ref.watch(clockProvider)();
    return Opacity(
      opacity: unavailable ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x3),
          child: Row(children: [
            ToolIconTile(icon: d?.icon ?? Icons.description_outlined, color: d == null ? context.colors.primary : accentFor(context, d.category)),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MiddleEllipsisText(title, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(historySubtitle(l, record, now),
                    style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant), maxLines: 2),
                if (unavailable) ...[
                  const SizedBox(height: Space.x1),
                  Row(children: [
                    Icon(Icons.link_off_rounded, size: 14, color: context.docu.warning),
                    const SizedBox(width: Space.x1),
                    Flexible(child: Text(l.histUnavailable, style: context.text.labelSmall?.copyWith(color: context.docu.warning))),
                  ]),
                ],
              ]),
            ),
            const SizedBox(width: Space.x2),
            StatusIcon(record.status, label: statusLabel(l, record)),
          ]),
        ),
      ),
    );
  }
}
