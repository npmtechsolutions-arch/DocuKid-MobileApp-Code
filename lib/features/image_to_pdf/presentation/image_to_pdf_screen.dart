import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/pdf/image_to_pdf_layout.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/image_to_pdf_controller.dart';
import '../application/image_to_pdf_operation.dart';

/// S05 · Images to PDF.
class ImageToPdfScreen extends ConsumerStatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  ConsumerState<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends ConsumerState<ImageToPdfScreen> {
  static const tool = ToolId.imageToPdf;
  final _now = DateTime.now();

  void _run() {
    final inputs = ref.read(toolInputsProvider(tool));
    final current = ref.read(imageToPdfOptionsProvider);
    final o = current.copyWith(
      rotations: inputs.rotations,
      outputName: () => current.outputName ?? defaultOutputName(NamingTool.imageToPdf, now: _now),
    );
    runTool(context, ref, ref.read(imageToPdfOperationProvider), inputs.files, o);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    ref.listen(imageToPdfAutoRunProvider, (_, run) {
      if (run && ref.read(imageToPdfAutoRunProvider.notifier).take()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(toolInputsProvider(tool)).valid.isNotEmpty) _run();
        });
      }
    });
    final inputs = ref.watch(toolInputsProvider(tool));
    final ctrl = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(imageToPdfOptionsProvider);
    final set = ref.read(imageToPdfOptionsProvider.notifier).set;
    final n = inputs.files.length;
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= Breakpoints.expanded ? 4 : (width >= Breakpoints.medium ? 4 : 3);
    final accent = context.docu.imageAccent;
    final defaultName = defaultOutputName(NamingTool.imageToPdf, now: _now);
    final name = o.outputName ?? defaultName;
    final canRun = n > 0 && inputs.invalidCount == 0 && !inputs.picking;

    String? helper;
    if (n == 0) {
      helper = l.i2pEmptyHint;
    } else if (inputs.invalidCount > 0) {
      helper = l.mrgRemoveInvalid(inputs.invalidCount);
    }

    return ToolScaffold(
      title: l.toolImageToPdfTitle,
      info: l.infoImageToPdf,
      hasWork: n > 0,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: n == 0 ? l.i2pRunEmpty : l.i2pRun(n),
        icon: Icons.picture_as_pdf_rounded,
        helper: helper,
        onPressed: canRun ? _run : null,
      ),
      primary: [
        SectionHeader(
          l.i2pHeader(n),
          trailing: n == 0 || n >= 100
              ? null
              : TextButton.icon(onPressed: inputs.picking ? null : () => ctrl.pick(), icon: const Icon(Icons.add_rounded), label: Text(l.inputsAdd)),
        ),
        if (n == 0)
          PickerDropCard(
            label: l.pickImages,
            formats: l.pickFormatsImages,
            hint: l.i2pEmptyHint,
            icon: Icons.collections_rounded,
            accent: accent,
            loading: inputs.picking,
            onTap: () => ctrl.pick(),
          )
        else ...[
          ReorderableGrid(
            itemCount: n,
            crossAxisCount: cols,
            keyOf: (i) => inputs.files[i].path,
            onReorder: ctrl.move,
            itemBuilder: (context, i, dragging) => _ImageThumbTile(
              file: inputs.files[i],
              index: i,
              total: n,
              quarterTurns: inputs.rotations[i],
              onRotate: () => ctrl.rotate(i),
              onRemove: () => ctrl.remove(i),
              onMove: (t) => ctrl.move(i, moveTargetIndex(t, i, n)),
            ),
          ),
          if (n > 6)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.push('${toolById(tool).route}/review'),
                child: Text('${l.inputsManageAll} ›'),
              ),
            ),
          if (inputs.picking) const Padding(padding: EdgeInsets.all(Space.x4), child: Center(child: CircularProgressIndicator.adaptive())),
        ],
        LargeFileHint(bytes: inputs.totalBytes),
      ],
      secondary: [
        OptionsCard(icon: Icons.description_outlined, title: l.i2pSectionPage, children: [
          OptionGroup(
            title: l.i2pPageSize,
            child: DropdownMenu<PdfPageSize>(
              expandedInsets: EdgeInsets.zero,
              initialSelection: o.size,
              dropdownMenuEntries: [
                DropdownMenuEntry(value: PdfPageSize.a4, label: l.i2pSizeA4),
                DropdownMenuEntry(value: PdfPageSize.letter, label: l.i2pSizeLetter),
                DropdownMenuEntry(value: PdfPageSize.legal, label: l.i2pSizeLegal),
                DropdownMenuEntry(value: PdfPageSize.image, label: l.i2pSizeImage),
              ],
              onSelected: (v) => set(o.copyWith(size: v)),
            ),
          ),
          if (o.size != PdfPageSize.image) ...[
            OptionGroup(
              title: l.i2pOrientation,
              child: ChoiceSegments<PdfOrientation>(
                value: o.orientation,
                options: [
                  (PdfOrientation.auto, l.i2pOrientAuto),
                  (PdfOrientation.portrait, l.i2pOrientPortrait),
                  (PdfOrientation.landscape, l.i2pOrientLandscape),
                ],
                onChanged: (v) => set(o.copyWith(orientation: v)),
              ),
            ),
            OptionGroup(
              title: l.i2pFit,
              child: ChoiceSegments<PdfFit>(
                value: o.fit,
                options: [(PdfFit.fit, l.i2pFitFit), (PdfFit.fill, l.i2pFitFill)],
                onChanged: (v) => set(o.copyWith(fit: v)),
              ),
            ),
            OptionGroup(
              title: l.i2pMargins,
              child: ChoiceSegments<PdfMargin>(
                value: o.margin,
                options: [
                  (PdfMargin.none, l.i2pMarginNone),
                  (PdfMargin.small, l.i2pMarginSmall),
                  (PdfMargin.large, l.i2pMarginLarge),
                ],
                onChanged: (v) => set(o.copyWith(margin: v)),
              ),
            ),
          ],
        ]),
        OptionsCard(icon: Icons.high_quality_outlined, title: l.i2pSectionQuality, children: [
          ChoiceSegments<PdfImageQuality>(
            value: o.quality,
            options: [
              (PdfImageQuality.original, l.i2pQOriginal),
              (PdfImageQuality.high, l.i2pQHigh),
              (PdfImageQuality.compact, l.i2pQCompact),
            ],
            onChanged: (v) => set(o.copyWith(quality: v)),
          ),
        ]),
        if (n > 0) ...[
          SectionHeader(l.i2pPreview),
          _LayoutPreviewStrip(files: inputs.files, rotations: inputs.rotations, options: o),
        ],
        SectionHeader(l.i2pOutputName),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: MiddleEllipsisText(name),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final r = await renameDialog(context, currentName: name);
              if (r != null) set(o.copyWith(outputName: () => r));
            },
          ),
        ),
      ],
    );
  }
}

class _ImageThumbTile extends StatelessWidget {
  const _ImageThumbTile({
    required this.file,
    required this.index,
    required this.total,
    required this.quarterTurns,
    required this.onRotate,
    required this.onRemove,
    required this.onMove,
  });
  final PickedFile file;
  final int index, total, quarterTurns;
  final VoidCallback onRotate, onRemove;
  final ValueChanged<MoveTarget> onMove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invalid = !file.status.isValid;
    return Semantics(
      label: '${l.i2pImageA11y(index + 1, total)}. ${file.displayName}',
      customSemanticsActions: {
        if (index > 0) CustomSemanticsAction(label: l.moveUp): () => onMove(MoveTarget.up),
        if (index < total - 1) CustomSemanticsAction(label: l.moveDown): () => onMove(MoveTarget.down),
        CustomSemanticsAction(label: l.i2pRotate): onRotate,
        CustomSemanticsAction(label: l.actionRemove): onRemove,
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Stack(fit: StackFit.expand, children: [
          Container(color: context.colors.surfaceContainerHigh),
          if (!invalid)
            LayoutBuilder(builder: (context, c) => LocalImageThumb(path: file.path, size: c.maxWidth, quarterTurns: quarterTurns))
          else
            Center(child: Padding(padding: const EdgeInsets.all(Space.x2), child: StatusBadge(file: file))),
          PositionedDirectional(
            top: Space.x1,
            start: Space.x1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.full)),
              child: Text('${index + 1}', style: context.text.labelMedium?.copyWith(color: Colors.white)),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: _OverlayButton(icon: Icons.close_rounded, tooltip: l.actionRemove, onPressed: onRemove),
          ),
          if (!invalid)
            PositionedDirectional(
              bottom: 0,
              start: 0,
              child: _OverlayButton(icon: Icons.rotate_right_rounded, tooltip: l.i2pRotate, onPressed: onRotate),
            ),
        ]),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

/// First 3 pages as miniature layouts (layout only — no encoding).
class _LayoutPreviewStrip extends StatelessWidget {
  const _LayoutPreviewStrip({required this.files, required this.rotations, required this.options});
  final List<PickedFile> files;
  final List<int> rotations;
  final ImageToPdfOptions options;

  @override
  Widget build(BuildContext context) {
    final shown = files.take(3).toList();
    return SizedBox(
      height: 150,
      child: Row(children: [
        for (var i = 0; i < shown.length; i++)
          if (shown[i].image != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.x3),
              child: _MiniPage(file: shown[i], turns: rotations[i], options: options),
            ),
      ]),
    );
  }
}

class _MiniPage extends StatelessWidget {
  const _MiniPage({required this.file, required this.turns, required this.options});
  final PickedFile file;
  final int turns;
  final ImageToPdfOptions options;

  @override
  Widget build(BuildContext context) {
    final m = file.image!;
    final (w, h) = rotatedSize(m.width, m.height, turns);
    final lay = layoutImagePage(
      imageWidth: w,
      imageHeight: h,
      size: options.size,
      orientation: options.orientation,
      fit: options.fit,
      margin: options.margin,
      dpiCap: 72,
    );
    const maxH = 140.0, maxW = 120.0;
    final s = math.min(maxH / lay.pageHeight, maxW / lay.pageWidth);
    return ExcludeSemantics(
      child: Container(
        width: lay.pageWidth * s,
        height: lay.pageHeight * s,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(children: [
          Positioned(
            left: lay.boxLeft * s,
            top: lay.boxTop * s,
            width: lay.boxWidth * s,
            height: lay.boxHeight * s,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: lay.drawWidth * s,
                  height: lay.drawHeight * s,
                  child: RotatedBox(
                    quarterTurns: turns,
                    child: Image.file(File(file.path), fit: BoxFit.fill, cacheWidth: 240, errorBuilder: (_, _, _) => const SizedBox()),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
