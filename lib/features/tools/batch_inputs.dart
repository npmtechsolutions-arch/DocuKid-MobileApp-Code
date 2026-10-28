import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/files/picked_file.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../search/tool_catalog.dart';
import 'tool_inputs.dart';

/// S21 · Batch inputs (RELEASE_V1_1 §3), shown inside an image tool screen
/// once 2+ images are picked: header with Add / Clear all, a 4-column grid of
/// thumbnails (order doesn't matter, so no numbers), the total and how many
/// can't be used. Invalid images stay listed; the run skips them.
class BatchInputs extends ConsumerWidget {
  const BatchInputs({super.key, required this.tool});
  final ToolId tool;

  /// More than this → "Show all n" opens the full list.
  static const gridLimit = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final inputs = ref.watch(toolInputsProvider(tool));
    final ctrl = ref.read(toolInputsProvider(tool).notifier);
    final files = inputs.files;
    final shown = files.length > gridLimit ? files.sublist(0, gridLimit) : files;
    final invalid = inputs.invalidCount;
    final cols = MediaQuery.sizeOf(context).width >= Breakpoints.medium ? 6 : 4;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(
        l.batchHeader(files.length),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (files.length < toolById(tool).maxInputs)
            TextButton.icon(
              onPressed: inputs.picking ? null : () => ctrl.pick(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.inputsAdd),
            ),
          PopupMenuButton<void>(
            tooltip: l.orgMore,
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (_) => [PopupMenuItem(onTap: ctrl.clear, child: Text(l.batchClearAll))],
          ),
        ]),
      ),
      GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Space.x2,
        crossAxisSpacing: Space.x2,
        children: [
          for (var i = 0; i < shown.length; i++)
            _BatchTile(key: ValueKey(shown[i].path), file: shown[i], onRemove: () => ctrl.remove(i)),
        ],
      ),
      if (files.length > gridLimit)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => context.push('${toolById(tool).route}/review'),
            child: Text(l.batchShowAll(files.length)),
          ),
        ),
      const SizedBox(height: Space.x2),
      Row(children: [
        Expanded(
          child: Text(
            [l.batchTotal(formatBytes(inputs.totalBytes)), if (invalid > 0) l.batchInvalid(invalid)].join(' · '),
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        if (invalid > 0) TextButton(onPressed: ctrl.removeInvalid, child: Text(l.batchRemoveInvalid)),
      ]),
    ]);
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({super.key, required this.file, required this.onRemove});
  final PickedFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final badge = badgeText(l, file);
    final invalid = file.status.level == ValidationLevel.invalid;
    return Semantics(
      label: badge == null ? file.displayName : '${file.displayName}, $badge',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Stack(fit: StackFit.expand, children: [
          ExcludeSemantics(
            child: invalid
                ? ColoredBox(
                    color: context.colors.surfaceContainerHigh,
                    child: Icon(Icons.broken_image_outlined, color: context.colors.onSurfaceVariant),
                  )
                : LayoutBuilder(builder: (context, c) => LocalImageThumb(path: file.path, size: c.maxWidth)),
          ),
          if (badge != null)
            PositionedDirectional(
              start: Space.x1,
              bottom: Space.x1,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: invalid ? context.colors.errorContainer : context.docu.warningContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(invalid ? Icons.block_rounded : Icons.warning_rounded,
                      size: 16, color: invalid ? context.colors.onErrorContainer : context.docu.warning),
                ),
              ),
            ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              tooltip: l.actionRemove,
              onPressed: onRemove,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
