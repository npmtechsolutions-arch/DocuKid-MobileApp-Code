import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../../features/search/tool_catalog.dart';
import '../../l10n/gen/app_localizations.dart';
import '../errors/app_error.dart';
import '../files/picked_file.dart';
import '../formatting/bytes_format.dart';
import 'common.dart';
import 'dialogs.dart';
import 'illustrations.dart';
import 'pdf_thumbnail.dart';
import 'tool_scaffold.dart';

/// Dashed "Choose …" card shown while a tool has no inputs.
class PickerDropCard extends StatelessWidget {
  const PickerDropCard({
    super.key,
    required this.label,
    required this.formats,
    required this.onTap,
    required this.icon,
    required this.accent,
    this.hint,
    this.loading = false,
  });
  final String label, formats;
  final String? hint;
  final VoidCallback? onTap;
  final IconData icon;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tool = CurrentTool.of(context);
    final category = tool == null ? null : toolById(tool).category;
    return Semantics(
      button: true,
      label: '$label. $formats',
      // UI_REFRESH §4: the dashes drift once on first show (static with reduce-motion).
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, const Duration(milliseconds: 1200)),
        curve: Motion.curve,
        builder: (context, t, child) => CustomPaint(
          painter: _DashedBorder(color: accent.withValues(alpha: 0.55), radius: Radii.lg, phase: t * 22),
          child: child,
        ),
        child: Material(
          color: accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(Radii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.lg),
            onTap: loading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.x8, horizontal: Space.x4),
              child: Column(
                children: [
                  if (loading)
                    const SizedBox(width: 56, height: 56, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator.adaptive()))
                  else if (category != null)
                    Illustration(
                      kind: category == ToolCategory.image ? IllustrationKind.pickImages : IllustrationKind.pickPdf,
                      size: 112,
                    )
                  else
                    ToolIconTile(icon: icon, color: accent, size: 56),
                  const SizedBox(height: Space.x3),
                  Text(loading ? context.l10n.pickLoading : label,
                      style: context.text.titleMedium?.copyWith(color: accent), textAlign: TextAlign.center),
                  const SizedBox(height: Space.x1),
                  Text(formats,
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                  if (hint != null) ...[
                    const SizedBox(height: Space.x1),
                    Text(hint!,
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius, this.phase = 0});
  final Color color;
  final double radius, phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = phase % 11 - 11;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(math.max(0, d), d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.phase != phase;
}

String? badgeText(AppLocalizations l, PickedFile f) {
  final s = f.status;
  switch (s.level) {
    case ValidationLevel.ok:
      return null;
    case ValidationLevel.warning:
      if (s.warnings.contains(WarningCode.hasAlpha)) return l.badgeHasAlpha;
      if (s.warnings.contains(WarningCode.largeFile)) return l.largeFileHint;
      return null;
    case ValidationLevel.invalid:
      return switch (s.error) {
        AppErrorCode.encryptedDocument => l.badgeLocked,
        AppErrorCode.corruptFile => l.badgeDamaged,
        AppErrorCode.unsupportedFormat => l.badgeUnsupported,
        AppErrorCode.fileTooLarge => l.badgeTooLarge,
        _ => l.badgeUnreadable,
      };
  }
}

/// Icon + text badge — colour is never the only signal.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.file});
  final PickedFile file;

  @override
  Widget build(BuildContext context) {
    final text = badgeText(context.l10n, file);
    if (text == null) return const SizedBox.shrink();
    final invalid = file.status.level == ValidationLevel.invalid;
    final locked = file.status.error == AppErrorCode.encryptedDocument;
    final bg = invalid ? context.colors.errorContainer : context.docu.warningContainer;
    final fg = invalid ? context.colors.onErrorContainer : context.docu.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.xs)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(locked ? Icons.lock_rounded : (invalid ? Icons.block_rounded : Icons.warning_rounded), size: 14, color: fg),
        const SizedBox(width: Space.x1),
        Flexible(child: Text(text, style: context.text.labelSmall?.copyWith(color: fg), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

String metaLine(AppLocalizations l, PickedFile f) {
  final parts = <String>[
    if (f.image != null) l.metaDims(f.image!.width, f.image!.height),
    if (f.pdf != null) l.metaPages(f.pdf!.pageCount),
    if (f.sizeBytes > 0) formatBytes(f.sizeBytes),
  ];
  return parts.join(' · ');
}

/// Small square image preview from a local copy (memory-bounded decode).
class LocalImageThumb extends StatelessWidget {
  const LocalImageThumb({super.key, required this.path, required this.size, this.quarterTurns = 0, this.fit = BoxFit.cover});
  final String path;
  final double size;
  final int quarterTurns;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: fit,
        cacheWidth: px,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => Container(
          color: context.colors.surfaceContainerHigh,
          child: Icon(Icons.image_not_supported_outlined, color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 72 dp row for multi-file tools.
class FileTile extends StatelessWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.onRemove,
    this.onMove,
    this.dragHandle,
    this.index,
    this.total,
  });
  final PickedFile file;
  final VoidCallback onRemove;
  final ValueChanged<MoveTarget>? onMove;
  final Widget? dragHandle;
  final int? index, total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invalid = file.status.level == ValidationLevel.invalid;
    final canUp = (index ?? 0) > 0;
    final canDown = index != null && total != null && index! < total! - 1;
    return Semantics(
      customSemanticsActions: {
        if (onMove != null && canUp) CustomSemanticsAction(label: l.moveUp): () => onMove!(MoveTarget.up),
        if (onMove != null && canDown) CustomSemanticsAction(label: l.moveDown): () => onMove!(MoveTarget.down),
        CustomSemanticsAction(label: l.actionRemove): onRemove,
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsetsDirectional.only(start: Space.x2, end: Space.x1),
        child: Row(children: [
          ?dragHandle,
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: SizedBox(
              width: 48,
              height: 48,
              child: file.isImage && !invalid
                  ? LocalImageThumb(path: file.path, size: 48)
                  : file.isPdf && !invalid
                      ? PdfThumbnail(path: file.path, pageIndex: 0, width: 48)
                      : Container(
                          color: context.colors.surfaceContainerHigh,
                          child: Icon(file.isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                              color: context.colors.onSurfaceVariant),
                        ),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MiddleEllipsisText(file.displayName, style: context.text.bodyLarge),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: Space.x2,
                    runSpacing: Space.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!invalid)
                        Text(metaLine(l, file),
                            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                      StatusBadge(file: file),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (invalid)
            TextButton(onPressed: onRemove, child: Text(l.actionRemove))
          else
            PopupMenuButton<String>(
              tooltip: l.actionDetails,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) async {
                switch (v) {
                  case 'details':
                    await showFileDetails(context, file);
                  case 'move':
                    final t = await showMoveToSheet(context, canUp: canUp, canDown: canDown);
                    if (t != null) onMove?.call(t);
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'details', child: Text(l.actionDetails)),
                if (onMove != null) PopupMenuItem(value: 'move', child: Text(l.moveToTitle)),
                PopupMenuItem(value: 'remove', child: Text(l.actionRemove)),
              ],
            ),
        ]),
      ),
    );
  }
}

/// Single-input tools show a large preview with a Change button (S09).
class SingleFileCard extends StatelessWidget {
  const SingleFileCard({super.key, required this.file, required this.onChange, this.extra, this.onAdd});
  final PickedFile file;
  final VoidCallback onChange;
  final Widget? extra;

  /// Shows an "Add" icon button next to Change (batch-capable tools).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invalid = file.status.level == ValidationLevel.invalid;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Checkerboard(
              child: invalid
                  ? Center(
                      child: Icon(file.isPdf ? Icons.picture_as_pdf_rounded : Icons.broken_image_outlined,
                          size: 48, color: context.colors.onSurfaceVariant))
                  : file.isPdf
                      ? Center(child: PdfThumbnail(path: file.path, pageIndex: 0, width: 140, elevated: true))
                      : LayoutBuilder(
                          builder: (context, c) => LocalImageThumb(path: file.path, size: c.maxWidth, fit: BoxFit.contain),
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x2, Space.x3),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MiddleEllipsisText(file.displayName, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Wrap(spacing: Space.x2, runSpacing: Space.x1, children: [
                    if (!invalid)
                      Text(metaLine(l, file), style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                    StatusBadge(file: file),
                  ]),
                  ?extra,
                ]),
              ),
              IconButton(
                tooltip: l.actionDetails,
                onPressed: () => showFileDetails(context, file),
                icon: const Icon(Icons.info_outline_rounded),
              ),
              if (onAdd != null)
                IconButton(tooltip: l.inputsAdd, onPressed: onAdd, icon: const Icon(Icons.add_photo_alternate_outlined)),
              OutlinedButton(onPressed: onChange, child: Text(l.actionChange)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Grid reorder without an extra dependency: long-press to lift, drop on a
/// cell to move there. Edge auto-scroll uses the nearest Scrollable.
class ReorderableGrid extends StatefulWidget {
  const ReorderableGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    required this.crossAxisCount,
    this.childAspectRatio = 1,
    this.spacing = Space.x2,
    this.keyOf,
  });
  final int itemCount;
  final Widget Function(BuildContext, int index, bool dragging) itemBuilder;
  final void Function(int from, int to) onReorder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final Object Function(int index)? keyOf;

  @override
  State<ReorderableGrid> createState() => _ReorderableGridState();
}

class _ReorderableGridState extends State<ReorderableGrid> {
  int? _dragging;
  int? _hover;

  void _autoScroll(Offset global) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final box = scrollable.context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    const edge = 72.0;
    final pos = scrollable.position;
    double? delta;
    if (local.dy < edge) delta = -14;
    if (local.dy > box.size.height - edge) delta = 14;
    if (delta != null) {
      pos.jumpTo((pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cell = (c.maxWidth - widget.spacing * (widget.crossAxisCount - 1)) / widget.crossAxisCount;
      final h = cell / widget.childAspectRatio;
      return Wrap(
        spacing: widget.spacing,
        runSpacing: widget.spacing,
        children: [
          for (var i = 0; i < widget.itemCount; i++)
            SizedBox(
              key: widget.keyOf == null ? null : ValueKey(widget.keyOf!(i)),
              width: cell,
              height: h,
              child: DragTarget<int>(
                onWillAcceptWithDetails: (d) {
                  setState(() => _hover = i);
                  return d.data != i;
                },
                onLeave: (_) => setState(() => _hover = null),
                onAcceptWithDetails: (d) {
                  setState(() => _hover = null);
                  HapticFeedback.selectionClick(); // UI_REFRESH §8: reorder drop
                  widget.onReorder(d.data, i);
                },
                builder: (context, candidate, _) {
                  final child = widget.itemBuilder(context, i, _dragging == i);
                  return LongPressDraggable<int>(
                    data: i,
                    hapticFeedbackOnStart: true,
                    onDragStarted: () => setState(() => _dragging = i),
                    onDragUpdate: (d) => _autoScroll(d.globalPosition),
                    onDragEnd: (_) => setState(() => _dragging = null),
                    onDraggableCanceled: (_, _) => setState(() => _dragging = null),
                    feedback: SizedBox(
                      width: cell,
                      height: h,
                      child: Transform.scale(
                        scale: 1.04,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(Radii.sm),
                          clipBehavior: Clip.antiAlias,
                          child: widget.itemBuilder(context, i, false),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: child),
                    child: AnimatedContainer(
                      duration: Motion.of(context, Motion.medium),
                      curve: Motion.curve,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: _hover == i && _dragging != null && _dragging != i
                            ? Border.all(color: context.colors.primary, width: 2)
                            : null,
                      ),
                      child: child,
                    ),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}

/// Lazy (sliver) variant for long grids such as a 2,000-page Organizer: only
/// visible cells are built, so only visible thumbnails render (FR-ORG-01).
class ReorderableSliverGrid extends StatefulWidget {
  const ReorderableSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    required this.crossAxisCount,
    this.childAspectRatio = 1,
    this.spacing = Space.x2,
    this.keyOf,
  });
  final int itemCount;
  final Widget Function(BuildContext, int index) itemBuilder;
  final void Function(int from, int to) onReorder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final Object Function(int index)? keyOf;

  @override
  State<ReorderableSliverGrid> createState() => _ReorderableSliverGridState();
}

class _ReorderableSliverGridState extends State<ReorderableSliverGrid> {
  int? _dragging;
  int? _hover;

  void _autoScroll(BuildContext cellContext, Offset global) {
    final scrollable = Scrollable.maybeOf(cellContext);
    if (scrollable == null) return;
    final box = scrollable.context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    const edge = 80.0;
    final pos = scrollable.position;
    double? delta;
    if (local.dy < edge) delta = -16;
    if (local.dy > box.size.height - edge) delta = 16;
    if (delta != null) pos.jumpTo((pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        mainAxisSpacing: widget.spacing,
        crossAxisSpacing: widget.spacing,
      ),
      itemCount: widget.itemCount,
      itemBuilder: (context, i) => LayoutBuilder(
        key: widget.keyOf == null ? null : ValueKey(widget.keyOf!(i)),
        builder: (cellContext, c) => DragTarget<int>(
          onWillAcceptWithDetails: (d) {
            if (_hover != i) setState(() => _hover = i);
            return d.data != i;
          },
          onLeave: (_) => setState(() => _hover = null),
          onAcceptWithDetails: (d) {
            setState(() => _hover = null);
            HapticFeedback.selectionClick(); // UI_REFRESH §8: reorder drop
            widget.onReorder(d.data, i);
          },
          builder: (context, _, _) {
            final child = widget.itemBuilder(context, i);
            return LongPressDraggable<int>(
              data: i,
              hapticFeedbackOnStart: true,
              onDragStarted: () => setState(() => _dragging = i),
              onDragUpdate: (d) => _autoScroll(cellContext, d.globalPosition),
              onDragEnd: (_) => setState(() => _dragging = null),
              onDraggableCanceled: (_, _) => setState(() => _dragging = null),
              feedback: SizedBox(
                width: c.maxWidth,
                height: c.maxHeight,
                child: Transform.scale(
                  scale: 1.04,
                  child: Material(
                    elevation: 6,
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    clipBehavior: Clip.antiAlias,
                    child: widget.itemBuilder(context, i),
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: child),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: _hover == i && _dragging != null && _dragging != i
                      ? Border.all(color: context.colors.primary, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                ),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
