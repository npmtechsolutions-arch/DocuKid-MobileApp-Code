import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/ocr/ocr_labels.dart';
import '../../../core/ocr/text_recognizer.dart';
import '../../../core/scan/scan_options.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';

/// What S29 can do to one page (FR-SCN-11, 21).
enum ScanPageAction { details, rescan, rotateLeft, rotateRight, moveTo, delete }

/// S29 page grid: numbered thumbnails, ✕ top-right, ⟳ bottom-left, ⋮ bottom-right,
/// long-press drag, tap → full-screen preview (RELEASE_V1_2 §3).
class ScanPageGrid extends StatelessWidget {
  const ScanPageGrid({
    super.key,
    required this.pages,
    required this.rotations,
    required this.onReorder,
    required this.onAction,
    required this.onOpen,
    required this.canRescan,
  });

  final List<PickedFile> pages;
  final List<int> rotations;
  final void Function(int from, int to) onReorder;
  final void Function(int index, ScanPageAction action) onAction;
  final ValueChanged<int> onOpen;
  final bool canRescan;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= Breakpoints.medium ? 4 : 3;
    return ReorderableGrid(
      itemCount: pages.length,
      crossAxisCount: cols,
      childAspectRatio: 0.75,
      keyOf: (i) => pages[i].path,
      onReorder: onReorder,
      itemBuilder: (context, i, dragging) => _ScanPageTile(
        file: pages[i],
        index: i,
        total: pages.length,
        quarterTurns: rotations[i],
        canRescan: canRescan,
        onAction: (a) => onAction(i, a),
        onOpen: () => onOpen(i),
      ),
    );
  }
}

class _ScanPageTile extends StatelessWidget {
  const _ScanPageTile({
    required this.file,
    required this.index,
    required this.total,
    required this.quarterTurns,
    required this.canRescan,
    required this.onAction,
    required this.onOpen,
  });
  final PickedFile file;
  final int index, total, quarterTurns;
  final bool canRescan;
  final ValueChanged<ScanPageAction> onAction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      label: l.orgA11yPage(index + 1, total),
      customSemanticsActions: {
        if (total > 1) CustomSemanticsAction(label: l.moveToTitle): () => onAction(ScanPageAction.moveTo),
        CustomSemanticsAction(label: l.scnRotateRight): () => onAction(ScanPageAction.rotateRight),
        CustomSemanticsAction(label: l.scnRotateLeft): () => onAction(ScanPageAction.rotateLeft),
        CustomSemanticsAction(label: l.actionRemove): () => onAction(ScanPageAction.delete),
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Stack(fit: StackFit.expand, children: [
          Container(color: context.colors.surfaceContainerHigh),
          InkWell(
            onTap: onOpen,
            child: LayoutBuilder(
              builder: (context, c) =>
                  LocalImageThumb(path: file.path, size: c.maxWidth, quarterTurns: quarterTurns, fit: BoxFit.contain),
            ),
          ),
          PositionedDirectional(
            top: Space.x1,
            start: Space.x1,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.full)),
                child: Text('${index + 1}', style: context.text.labelMedium?.copyWith(color: Colors.white)),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: _OverlayButton(
                icon: Icons.close_rounded, tooltip: l.actionRemove, onPressed: () => onAction(ScanPageAction.delete)),
          ),
          PositionedDirectional(
            bottom: 0,
            start: 0,
            child: _OverlayButton(
              icon: Icons.rotate_right_rounded,
              tooltip: l.scnRotateRight,
              onPressed: () => onAction(ScanPageAction.rotateRight),
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: PopupMenuButton<ScanPageAction>(
              tooltip: l.scnPageMenu,
              icon: const _OverlayIcon(icon: Icons.more_vert_rounded),
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(value: ScanPageAction.details, child: Text(l.actionDetails)),
                if (canRescan) PopupMenuItem(value: ScanPageAction.rescan, child: Text(l.scnRescanPage)),
                PopupMenuItem(value: ScanPageAction.rotateLeft, child: Text(l.scnRotateLeft)),
                PopupMenuItem(value: ScanPageAction.rotateRight, child: Text(l.scnRotateRight)),
                if (total > 1) PopupMenuItem(value: ScanPageAction.moveTo, child: Text(l.moveToTitle)),
                PopupMenuItem(value: ScanPageAction.delete, child: Text(l.orgDelete)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _OverlayIcon extends StatelessWidget {
  const _OverlayIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: Colors.white),
      );
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: tooltip, onPressed: onPressed, icon: _OverlayIcon(icon: icon));
}

/// S29 options: Save as, Page size (PDF only), Quality, Name (FR-SCN-13…16).
class ScanOptionsCards extends StatelessWidget {
  const ScanOptionsCards({
    super.key,
    required this.options,
    required this.name,
    required this.onChanged,
    required this.onRename,
    this.scripts = const [OcrScript.latin],
  });
  final ScanOptions options;
  final String name;
  final ValueChanged<ScanOptions> onChanged;
  final VoidCallback onRename;

  /// Shipped text-recognition scripts (ADR-045) for "Make searchable".
  final List<OcrScript> scripts;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final o = options;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OptionsCard(icon: Icons.save_alt_rounded, title: l.scnSaveAs, children: [
        ChoiceSegments<ScanOutputFormat>(
          value: o.format,
          options: [(ScanOutputFormat.pdf, l.scnFormatPdf), (ScanOutputFormat.jpg, l.scnFormatJpg)],
          onChanged: (v) => onChanged(o.copyWith(format: v)),
        ),
      ]),
      if (o.format == ScanOutputFormat.pdf)
        OptionsCard(icon: Icons.description_outlined, title: l.i2pPageSize, children: [
          ChoiceSegments<ScanPageSize>(
            value: o.pageSize,
            options: [
              (ScanPageSize.a4, l.i2pSizeA4),
              (ScanPageSize.letter, l.i2pSizeLetter),
              (ScanPageSize.fitToScan, l.scnPageFit),
            ],
            onChanged: (v) => onChanged(o.copyWith(pageSize: v)),
          ),
        ]),
      // FR-OCR-13 (1.3): PDF only; the language appears when it's on.
      if (o.format == ScanOutputFormat.pdf)
        OptionsCard(icon: Icons.text_fields_rounded, title: l.toolOcrTitle, children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.scanMakeSearchable),
            value: o.makeSearchable,
            onChanged: (v) => onChanged(o.copyWith(makeSearchable: v)),
          ),
          if (o.makeSearchable)
            LayoutBuilder(
              builder: (context, c) => DropdownMenu<OcrScript>(
                width: c.maxWidth,
                initialSelection: scripts.contains(o.ocrScript) ? o.ocrScript : OcrScript.latin,
                label: Text(l.ocrLanguage),
                onSelected: (s) {
                  if (s != null) onChanged(o.copyWith(ocrScript: s));
                },
                dropdownMenuEntries: [for (final s in scripts) DropdownMenuEntry(value: s, label: ocrScriptLabel(l, s))],
              ),
            ),
        ]),
      OptionsCard(icon: Icons.high_quality_outlined, title: l.i2pSectionQuality, children: [
        ChoiceSegments<ScanQuality>(
          value: o.quality,
          options: [(ScanQuality.high, l.scnQualityHigh), (ScanQuality.compact, l.scnQualityCompact)],
          onChanged: (v) => onChanged(o.copyWith(quality: v)),
        ),
      ]),
      SectionHeader(l.i2pOutputName),
      Card(
        child: ListTile(
          leading: const Icon(Icons.description_outlined),
          title: MiddleEllipsisText(name),
          trailing: Icon(Icons.edit_outlined, semanticLabel: l.actionRename),
          onTap: onRename,
        ),
      ),
    ]);
  }
}

/// Full-screen page preview: pinch-zoom, swipe; no ads (like the Organizer's).
class ScanPagePreview extends StatefulWidget {
  const ScanPagePreview({super.key, required this.pages, required this.rotations, required this.initial});
  final List<PickedFile> pages;
  final List<int> rotations;
  final int initial;

  @override
  State<ScanPagePreview> createState() => _ScanPagePreviewState();
}

class _ScanPagePreviewState extends State<ScanPagePreview> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _at = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.orgPreviewTitle(_at + 1, widget.pages.length)),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.pages.length,
        onPageChanged: (i) => setState(() => _at = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: RotatedBox(
              quarterTurns: widget.rotations[i],
              child: Image.file(
                File(widget.pages[i].path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Move to…" for one page; returns the new index.
Future<int?> pickMoveTarget(BuildContext context, int index, int total) async {
  final t = await showMoveToSheet(context, canUp: index > 0, canDown: index < total - 1);
  return t == null ? null : moveTargetIndex(t, index, total);
}
