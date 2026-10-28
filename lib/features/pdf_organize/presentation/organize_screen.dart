import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/pdf/page_edit.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/pdf_thumbnail.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/organize_controller.dart';

/// S07 · PDF Page Organizer.
class OrganizeScreen extends ConsumerWidget {
  const OrganizeScreen({super.key});
  static const tool = ToolId.pdfOrganize;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final c = ref.read(organizeProvider.notifier);
    final s = ref.read(organizeProvider);
    final count = s.selected.length;
    if (count == s.pages.length) {
      showAppSnack(context, l.orgMinOnePage);
      return;
    }
    if (count > 1 && ref.read(settingsProvider).confirmDestructive) {
      final (ok, _) = await confirmDestructive(
        context,
        title: l.orgDeleteConfirmTitle(count),
        body: l.orgDeleteConfirmBody,
        confirmLabel: l.orgDelete,
      );
      if (!ok) return;
    }
    if (c.deleteSelected() == EditResult.wouldEmpty) {
      if (context.mounted) showAppSnack(context, l.orgMinOnePage);
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    if (count == 1 && context.mounted) {
      showAppSnack(context, l.orgDeletedUndo, actionLabel: l.actionUndo, onAction: c.undo);
    }
  }

  Future<void> _moveSheet(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final s = ref.read(organizeProvider);
    final rest = s.pages.length - s.selected.length;
    final afterCtrl = TextEditingController();
    final target = await showAppSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x6 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.orgMoveTo, style: ctx.text.titleLarge),
          const SizedBox(height: Space.x4),
          ListTile(leading: const Icon(Icons.vertical_align_top_rounded), title: Text(l.orgMoveStart), onTap: () => Navigator.pop(ctx, 0)),
          ListTile(leading: const Icon(Icons.vertical_align_bottom_rounded), title: Text(l.orgMoveEnd), onTap: () => Navigator.pop(ctx, rest)),
          const SizedBox(height: Space.x2),
          Row(children: [
            Expanded(
              child: TextField(
                controller: afterCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l.orgMoveAfter, helperText: '1–$rest'),
              ),
            ),
            const SizedBox(width: Space.x3),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
              onPressed: () {
                final v = int.tryParse(afterCtrl.text);
                if (v != null && v >= 1 && v <= rest) Navigator.pop(ctx, v);
              },
              child: Text(l.orgMove),
            ),
          ]),
        ]),
      ),
    );
    afterCtrl.dispose();
    if (target != null) ref.read(organizeProvider.notifier).moveSelectedTo(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final file = inputs.single;
    final valid = file?.status.isValid == true;
    final s = ref.watch(organizeProvider);
    final c = ref.read(organizeProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= Breakpoints.expanded ? 6 : (width >= Breakpoints.medium ? 4 : 3);

    final menu = valid
        ? [
            IconButton(tooltip: l.orgUndo, onPressed: s.canUndo ? c.undo : null, icon: const Icon(Icons.undo_rounded)),
            IconButton(tooltip: l.orgRedo, onPressed: s.canRedo ? c.redo : null, icon: const Icon(Icons.redo_rounded)),
            PopupMenuButton<String>(
              tooltip: l.orgMore,
              onSelected: (v) => switch (v) {
                'all' => c.selectAll(),
                'none' => c.selectNone(),
                'invert' => c.invert(),
                'reset' => c.reset(),
                'change' => pick.pick(replace: true),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'all', child: Text(l.orgSelectAll)),
                PopupMenuItem(value: 'none', child: Text(l.orgSelectNone)),
                PopupMenuItem(value: 'invert', child: Text(l.orgInvert)),
                PopupMenuItem(value: 'reset', enabled: s.dirty, child: Text(l.orgReset)),
                PopupMenuItem(value: 'change', child: Text(l.chooseAnother)),
              ],
            ),
          ]
        : <Widget>[];

    return ToolScaffold(
      title: valid ? file!.displayName : l.toolPdfOrganizeTitle,
      info: valid ? null : l.infoPdfOrganize,
      hasWork: file != null,
      organizer: s.dirty,
      actions: menu,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.orgRun,
        icon: Icons.save_alt_rounded,
        helper: file == null ? l.pickPdf : (!valid ? l.chooseAnother : null),
        onPressed: valid && s.dirty && !inputs.picking
            ? () => runTool(context, ref, ref.read(organizeOperationProvider), [file!], OrganizeOptions(s.pages))
            : null,
      ),
      primary: [
        if (file == null) ...[
          SectionHeader(l.inputsFileHeader),
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: Icons.grid_view_rounded,
            accent: context.docu.pdfAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          ),
        ] else if (!valid) ...[
          SectionHeader(l.inputsFileHeader),
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
        ],
      ],
      slivers: !valid
          ? null
          : [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: Space.x3, bottom: Space.x3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(l.orgStatus(s.pages.length, s.selected.length), style: context.text.titleSmall),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(l.orgHint, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                  ]),
                ),
              ),
              ReorderableSliverGrid(
                itemCount: s.pages.length,
                crossAxisCount: cols,
                childAspectRatio: 0.72,
                spacing: Space.x3,
                keyOf: (i) => 'p${s.pages[i].sourceIndex}',
                onReorder: (from, to) => c.moveOnePage(from, to),
                itemBuilder: (context, i) => _PageTile(
                  path: file!.path,
                  edit: s.pages[i],
                  position: i,
                  total: s.pages.length,
                  selected: s.selected.contains(i),
                  aspect: _aspect(file.pdf!.pageSizes, s.pages[i].sourceIndex),
                  onTap: () => c.toggle(i),
                  onDoubleTap: () => context.push('/tool/pdf-organize/preview/$i'),
                ),
              ),
            ],
      bottomAccessory: valid && s.selected.isNotEmpty
          ? _SelectionBar(
              onLeft: () => c.rotateSelected(-1),
              onRight: () => c.rotateSelected(1),
              onDelete: () => _delete(context, ref),
              onMove: () => _moveSheet(context, ref),
              // FR-EXT-01/02: a separate job; the Organizer keeps its edits.
              onExtract: () => runTool(context, ref, ref.read(organizeOperationProvider), [file!],
                  OrganizeOptions(c.selectedEdits(), extract: true)),
            )
          : null,
    );
  }

  double? _aspect(List<(double, double)> sizes, int i) => i < sizes.length ? sizes[i].$1 / sizes[i].$2 : null;
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.onLeft,
    required this.onRight,
    required this.onDelete,
    required this.onMove,
    required this.onExtract,
  });
  final VoidCallback onLeft, onRight, onDelete, onMove, onExtract;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget b(IconData icon, String label, VoidCallback onTap, {Color? color}) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.x2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color),
                const SizedBox(height: 2),
                Text(label, style: context.text.labelMedium?.copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        );
    return Material(
      color: context.colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.all(Space.x1),
        child: Row(children: [
          b(Icons.rotate_left_rounded, l.orgRotateLeft, onLeft),
          b(Icons.rotate_right_rounded, l.orgRotateRight, onRight),
          b(Icons.delete_outline_rounded, l.orgDelete, onDelete, color: context.colors.error),
          b(Icons.swap_vert_rounded, l.orgMove, onMove),
          b(Icons.file_copy_outlined, l.orgExtract, onExtract),
        ]),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.path,
    required this.edit,
    required this.position,
    required this.total,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    this.aspect,
  });
  final String path;
  final PageEdit edit;
  final int position, total;
  final bool selected;
  final double? aspect;
  final VoidCallback onTap, onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final moved = edit.sourceIndex != position;
    final deg = edit.rotationQuarterTurns * 90;
    final label = [
      l.orgA11yPage(position + 1, total),
      if (moved) l.orgPageMovedFrom(position + 1, edit.sourceIndex + 1),
      if (deg != 0) l.orgA11yRotated(deg),
      if (selected) l.orgA11ySelected,
    ].join(', ');
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      customSemanticsActions: {CustomSemanticsAction(label: l.actionDetails): onDoubleTap},
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Column(children: [
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth - Space.x2;
              return AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: selected ? context.colors.primary : Colors.transparent, width: 3),
                  color: selected ? context.colors.primaryContainer.withValues(alpha: 0.5) : null,
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Center(
                    child: PdfThumbnail(
                      path: path,
                      pageIndex: edit.sourceIndex,
                      width: w - 6,
                      quarterTurns: edit.rotationQuarterTurns,
                      aspect: aspect,
                    ),
                  ),
                  if (selected)
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: context.colors.primary,
                        child: Icon(Icons.check_rounded, size: 15, color: context.colors.onPrimary),
                      ),
                    ),
                  if (deg != 0)
                    PositionedDirectional(
                      bottom: 2,
                      start: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.full)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.rotate_right_rounded, size: 12, color: Colors.white),
                          Text('$deg°', style: context.text.labelSmall?.copyWith(color: Colors.white)),
                        ]),
                      ),
                    ),
                ]),
              );
            }),
          ),
          const SizedBox(height: Space.x1),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${position + 1}', style: context.text.labelMedium),
            if (moved) ...[
              const SizedBox(width: Space.x1),
              Text(l.orgOrigPage(edit.sourceIndex + 1), style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ]),
        ]),
      ),
    );
  }
}
