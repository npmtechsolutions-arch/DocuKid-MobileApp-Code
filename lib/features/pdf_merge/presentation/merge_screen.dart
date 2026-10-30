import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../secure/unlock_first.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/merge_operation.dart';

/// S06 · PDF Merger.
class MergeScreen extends ConsumerStatefulWidget {
  const MergeScreen({super.key});

  @override
  ConsumerState<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends ConsumerState<MergeScreen> {
  static const tool = ToolId.pdfMerge;
  final _now = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final ctrl = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(mergeOptionsProvider);
    final n = inputs.files.length;
    final validCount = inputs.valid.length;
    final pages = inputs.totalPages;
    final name = o.outputName ?? defaultOutputName(NamingTool.pdfMerge, now: _now);
    final tooManyPages = pages > Limits.mergeMaxPages;
    final canRun = validCount >= 2 && inputs.invalidCount == 0 && !tooManyPages && !inputs.picking;

    String? helper;
    if (inputs.invalidCount > 0) {
      helper = l.mrgRemoveInvalid(inputs.invalidCount);
    } else if (validCount < 2) {
      helper = l.mrgNeedTwo;
    } else if (tooManyPages) {
      helper = l.mrgTooManyPages;
    }

    return ToolScaffold(
      title: l.toolPdfMergeTitle,
      info: l.infoPdfMerge,
      hasWork: n > 0,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.mrgRun(validCount < 2 ? 2 : validCount),
        icon: Icons.call_merge_rounded,
        helper: helper,
        onPressed: canRun
            ? () => runTool(context, ref, ref.read(mergeOperationProvider), inputs.files, MergeOptions(outputName: name))
            : null,
      ),
      primary: [
        SectionHeader(
          l.mrgHeader(n),
          trailing: n == 0 || n >= Limits.mergeMaxFiles
              ? null
              : TextButton.icon(onPressed: inputs.picking ? null : () => ctrl.pick(), icon: const Icon(Icons.add_rounded), label: Text(l.inputsAdd)),
        ),
        if (n == 0)
          PickerDropCard(
            label: l.pickPdfs,
            formats: l.pickFormatsPdf,
            hint: l.mrgNeedTwo,
            icon: Icons.library_add_rounded,
            accent: context.docu.pdfAccent,
            loading: inputs.picking,
            onTap: () => ctrl.pick(),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Text(l.mrgTotal(n, pages), style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          if (firstLockedPdf(inputs) case final locked?) ...[
            UnlockFirstBanner(tool: tool, file: locked),
            const SizedBox(height: Space.x3),
          ],
          Card(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: n,
              onReorderItem: ctrl.move, // newIndex already adjusted for the removed item
              itemBuilder: (context, i) => Material(
                key: ValueKey(inputs.files[i].path),
                color: Colors.transparent,
                child: Column(children: [
                  if (i > 0) const Divider(indent: 64),
                  FileTile(
                    file: inputs.files[i],
                    index: i,
                    total: n,
                    onRemove: () => ctrl.remove(i),
                    onMove: (t) => ctrl.move(i, moveTargetIndex(t, i, n)),
                    dragHandle: ReorderableDragStartListener(
                      index: i,
                      child: Tooltip(
                        message: l.dragHandle,
                        child: const SizedBox(width: 36, height: 48, child: Icon(Icons.drag_indicator_rounded)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.x2),
            child: Row(children: [
              Icon(Icons.swap_vert_rounded, size: 16, color: context.colors.onSurfaceVariant),
              const SizedBox(width: Space.x2),
              Expanded(child: Text(l.mrgDragHint, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant))),
            ]),
          ),
          if (inputs.picking) const Padding(padding: EdgeInsets.all(Space.x4), child: Center(child: CircularProgressIndicator.adaptive())),
        ],
        LargeFileHint(bytes: inputs.totalBytes),
      ],
      secondary: [
        SectionHeader(l.mrgSectionOutput),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.mrgName, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            subtitle: MiddleEllipsisText(name, style: context.text.bodyLarge),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final r = await renameDialog(context, currentName: name);
              if (r != null) ref.read(mergeOptionsProvider.notifier).rename(r);
            },
          ),
        ),
      ],
    );
  }
}
