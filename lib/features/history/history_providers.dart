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
import '../search/tool_catalog.dart';

final recentProvider = StreamProvider.autoDispose<List<OperationRecord>>(
  (ref) => ref.watch(historyRepositoryProvider).watchRecent(5),
);

/// Availability is checked on display (FR-HIS-02): row + file on disk.
final outputAvailableProvider = FutureProvider.autoDispose.family<bool, String?>((ref, relPath) async {
  if (relPath == null) return false;
  return ref.watch(outputsRepositoryProvider).exists(relPath);
});

bool recordAvailable(WidgetRef ref, OperationRecord r) {
  if (!r.outputRecorded) return false;
  return ref.watch(outputAvailableProvider(r.row.outputRelPath)).value ?? true;
}

String statusLabel(AppLocalizations l, OperationRecord r) => switch (r.status) {
      OpStatus.success => l.detStatusCompleted,
      OpStatus.failed => l.detStatusFailed,
      OpStatus.cancelled => l.detStatusCancelled,
      OpStatus.interrupted => l.detStatusInterrupted,
      _ => l.detStatusRunning,
    };

/// "3.2 MB → 410 KB · 14:05" / "3 files · 47 pages · 5.3 MB" / "Failed — …".
String historySubtitle(AppLocalizations l, OperationRecord r, DateTime now) {
  final when = formatWhen(r.createdAt, now);
  switch (r.status) {
    case OpStatus.success:
      final out = r.row.outputBytes ?? 0;
      final tool = r.tool;
      if (tool == ToolId.pdfMerge || tool == ToolId.imageToPdf) {
        final pages = (r.outputMeta['pages'] as int?) ?? r.inputPages;
        return '${l.histFilesPages(r.row.inputCount, pages, formatBytes(out))} · $when';
      }
      return '${l.histSizes(formatBytes(r.row.inputTotalBytes), formatBytes(out))} · $when';
    case OpStatus.failed:
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
  const StatusIcon(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, color, label) = switch (status) {
      OpStatus.success => (Icons.check_circle_rounded, context.docu.success, l.detStatusCompleted),
      OpStatus.failed => (Icons.cancel_rounded, context.colors.error, l.detStatusFailed),
      OpStatus.interrupted => (Icons.pause_circle_rounded, context.docu.warning, l.detStatusInterrupted),
      OpStatus.cancelled => (Icons.remove_circle_outline_rounded, context.colors.onSurfaceVariant, l.detStatusCancelled),
      _ => (Icons.timelapse_rounded, context.colors.primary, l.detStatusRunning),
    };
    return Icon(icon, color: color, semanticLabel: label, size: 22);
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
    final available = record.status == OpStatus.success && recordAvailable(ref, record);
    final unavailable = record.status == OpStatus.success && !available;
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
            StatusIcon(record.status),
          ]),
        ),
      ),
    );
  }
}
