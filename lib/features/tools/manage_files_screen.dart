import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/bottom_banner.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/inputs.dart';
import '../search/tool_catalog.dart';
import 'tool_inputs.dart';

/// S09 full-screen variant for multi-file tools with more than 6 items.
class ManageFilesScreen extends ConsumerWidget {
  const ManageFilesScreen({super.key, required this.tool});
  final ToolId tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final inputs = ref.watch(toolInputsProvider(tool));
    final ctrl = ref.read(toolInputsProvider(tool).notifier);
    final n = inputs.files.length;
    return AppBottomBanner(unit: AdUnit.bannerTools, child: Scaffold(
      appBar: AppBar(
        title: Text(l.inputsHeader(n)),
        actions: [
          if (n < toolById(tool).maxInputs)
            TextButton.icon(onPressed: () => ctrl.pick(), icon: const Icon(Icons.add_rounded), label: Text(l.inputsAdd)),
        ],
      ),
      body: ContentWidth(
        padded: false,
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: Space.x8),
          buildDefaultDragHandles: false,
          itemCount: n,
          onReorderItem: ctrl.move, // newIndex already adjusted for the removed item
          itemBuilder: (context, i) => Material(
            key: ValueKey(inputs.files[i].path),
            color: Colors.transparent,
            child: FileTile(
              file: inputs.files[i],
              index: i,
              total: n,
              onRemove: () => ctrl.remove(i),
              onMove: (t) => ctrl.move(i, moveTargetIndex(t, i, n)),
              dragHandle: ReorderableDragStartListener(
                index: i,
                child: Tooltip(
                  message: l.dragHandle,
                  child: const SizedBox(width: 40, height: 48, child: Icon(Icons.drag_indicator_rounded)),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
