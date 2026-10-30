import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/pdf/page_ranges.dart';
import '../../../core/pdf/text_stamp_renderer.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/pdf_thumbnail.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/range_text.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/placement.dart';
import '../application/sign_operation.dart';
import '../application/sign_session.dart';


/// S35 · Placement editor (RELEASE_V1_4 §3; FR-SIG-05…09): full screen,
/// **no ads**. Drag to move, corner handle to resize (aspect kept), ⟳ to
/// rotate (snaps at 0/±90), ✕ to remove; the ⋯ sheet is the accessible
/// alternative. Save runs the Sign job.
class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

/// Half a handle's 48 dp target.
const _handleRoom = 24.0;

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  final _pageKey = GlobalKey();
  var _started = false;

  // Handle gestures: the placement as it was when the gesture began.
  Rect? _startRect;
  double _startRotation = 0;
  Offset _startVector = Offset.zero;
  Offset? _lastGlobal;

  static const tool = ToolId.pdfSign;

  void _startIfReady(List<Size> sizes) {
    if (_started) return;
    final chosen = ref.read(signSessionProvider).chosen;
    if (chosen == null) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(placementEditorProvider.notifier).start(sizes, chosen);
    });
  }

  Directory get _workDir {
    final draft = ref.read(toolInputsProvider(tool)).draftId;
    return Directory(p.join(ref.read(appPathsProvider).jobDir(draft).path, 'sig'));
  }

  Future<String?> _askText(String title, {String initial = ''}) async {
    final r = await showAdaptiveDialog<String>(
      context: context,
      builder: (_) => _TextPrompt(title: title, initial: initial),
    );
    return r == null || r.isEmpty ? null : r;
  }

  /// FR-SIG-07: date / text / initials as images (any script, §4.3).
  Future<void> _addText(PlacementKind kind) async {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final text = switch (kind) {
      PlacementKind.date =>
        await _askText(l.sigAddDate, initial: DateFormat.yMMMd(locale).format(ref.read(clockProvider)())),
      PlacementKind.initials => await _askText(l.sigAddInitials),
      _ => await _askText(l.sigAddText),
    };
    if (text == null || !mounted) return;
    final dir = _workDir;
    await dir.create(recursive: true);
    final r = await renderTextPng(text,
        outPath: p.join(dir.path, 'text_${const Uuid().v4()}.png'), colour: const Color(0xFF111111), heightPt: 18);
    ref.read(placementEditorProvider.notifier).add(r.pngPath, r.widthPx / r.heightPx, kind);
  }

  Future<void> _pagesSheet(String id, int pageCount) async {
    final pages = await showModalBottomSheet<List<int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _PagesSheet(pageCount: pageCount),
    );
    if (pages != null && pages.isNotEmpty) ref.read(placementEditorProvider.notifier).copyTo(id, pages);
  }

  Future<void> _moreSheet(String id) async {
    final l = context.l10n;
    final ctrl = ref.read(placementEditorProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x4),
            child: Text(l.sigMoveTo, style: ctx.text.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.x3),
            child: Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
              for (final (a, label) in [
                (PlacementAnchor.topLeft, l.wmkPosTl),
                (PlacementAnchor.topRight, l.wmkPosTr),
                (PlacementAnchor.centre, l.wmkPosCentre),
                (PlacementAnchor.bottomLeft, l.wmkPosBl),
                (PlacementAnchor.bottomRight, l.wmkPosBr),
              ])
                ActionChip(
                  label: Text(label),
                  onPressed: () {
                    ctrl.moveToAnchor(id, a);
                    Navigator.pop(ctx);
                  },
                ),
            ]),
          ),
          ListTile(
              leading: const Icon(Icons.zoom_in_rounded),
              title: Text(l.sigBigger),
              onTap: () {
                ctrl.scale(id, 1.2);
                Navigator.pop(ctx);
              }),
          ListTile(
              leading: const Icon(Icons.zoom_out_rounded),
              title: Text(l.sigSmaller),
              onTap: () {
                ctrl.scale(id, 1 / 1.2);
                Navigator.pop(ctx);
              }),
          ListTile(
              leading: const Icon(Icons.rotate_90_degrees_cw_rounded),
              title: Text(l.sigRotate),
              onTap: () {
                ctrl.rotateQuarter(id);
                Navigator.pop(ctx);
              }),
          ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l.actionRemove),
              onTap: () {
                ctrl.delete(id);
                Navigator.pop(ctx);
              }),
        ]),
      ),
    );
  }

  Offset _toPagePoints(Offset global, double scale) {
    final box = _pageKey.currentContext!.findRenderObject()! as RenderBox;
    return box.globalToLocal(global) / scale;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final inputs = ref.watch(toolInputsProvider(tool));
    ref.watch(signSessionProvider);
    final file = inputs.single;
    final view = ref.watch(placementEditorProvider);
    final ctrl = ref.read(placementEditorProvider.notifier);
    final sizes = file == null ? null : visualPageSizes(ref, file);
    if (file == null || sizes == null || sizes.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    _startIfReady(sizes);
    final page = view.page.clamp(0, sizes.length - 1);
    final size = sizes[page];
    final selected = view.selected;
    final chosen = ref.read(signSessionProvider).chosen;

    return PopScope(
      canPop: view.placements.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmLeave(context) && context.mounted) {
          ref.read(placementEditorProvider.notifier).select(null);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.actionClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(l.sigPlaceTitle),
          actions: [
            IconButton(tooltip: l.orgUndo, icon: const Icon(Icons.undo_rounded), onPressed: view.canUndo ? ctrl.undo : null),
            IconButton(tooltip: l.orgRedo, icon: const Icon(Icons.redo_rounded), onPressed: view.canRedo ? ctrl.redo : null),
          ],
        ),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Container(
              color: context.colors.surfaceContainer,
              padding: const EdgeInsets.all(Space.x4),
              child: LayoutBuilder(builder: (context, c) {
                // A [_handleRoom] border around the page, so handles of a
                // placement at the edge can still be tapped (hit tests stop
                // at a widget's bounds).
                final scale = math.min((c.maxWidth - 2 * _handleRoom) / size.width, (c.maxHeight - 2 * _handleRoom) / size.height);
                final w = size.width * scale, h = size.height * scale;
                return Center(
                  child: SizedBox(
                    width: w + 2 * _handleRoom,
                    height: h + 2 * _handleRoom,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned(
                        key: _pageKey,
                        left: _handleRoom,
                        top: _handleRoom,
                        width: w,
                        height: h,
                        child: GestureDetector(
                          onTap: () => ctrl.select(null),
                          child: PdfThumbnail(
                              key: ValueKey('page-$page'), path: file.path, pageIndex: page, width: w, aspect: size.width / size.height),
                        ),
                      ),
                      for (final pl in view.onPage(page)) _placement(pl, scale, pl.id == view.selectedId, size),
                    ]),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x2),
            child: Wrap(spacing: Space.x2, runSpacing: Space.x1, children: [
              ActionChip(
                avatar: const Icon(Icons.draw_rounded, size: 18),
                label: Text(l.sigAddSignature),
                onPressed: chosen == null ? null : () => ctrl.add(chosen.pngPath, chosen.aspect, PlacementKind.signature),
              ),
              ActionChip(
                  avatar: const Icon(Icons.event_rounded, size: 18),
                  label: Text(l.sigAddDate),
                  onPressed: () => _addText(PlacementKind.date)),
              ActionChip(
                  avatar: const Icon(Icons.text_fields_rounded, size: 18),
                  label: Text(l.sigAddText),
                  onPressed: () => _addText(PlacementKind.text)),
              ActionChip(
                  avatar: const Icon(Icons.short_text_rounded, size: 18),
                  label: Text(l.sigAddInitials),
                  onPressed: () => _addText(PlacementKind.initials)),
              ActionChip(
                avatar: const Icon(Icons.copy_all_rounded, size: 18),
                label: Text(l.sigPagesButton),
                onPressed: selected == null ? null : () => _pagesSheet(selected.id, sizes.length),
              ),
            ]),
          ),
          // A 40 pt-wide A4 thumbnail (57) + border + the page number, with room for 200% text.
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x1),
              itemCount: sizes.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
              itemBuilder: (context, i) => Semantics(
                selected: i == page,
                button: true,
                label: l.sigPageN(i + 1),
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey('strip-$i'),
                  onTap: () => ctrl.setPage(i),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: i == page ? context.colors.primary : Colors.transparent, width: 2),
                      ),
                      child: PdfThumbnail(path: file.path, pageIndex: i, width: 40, aspect: sizes[i].width / sizes[i].height),
                    ),
                    const SizedBox(height: 2),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${i + 1}', style: context.text.labelSmall),
                      if (view.stampedPages.contains(i)) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.circle, size: 6, color: context.colors.primary),
                      ],
                    ]),
                  ]),
                ),
              ),
            ),
          ),
          PrimaryActionBar(
            label: l.sigRun,
            icon: Icons.save_alt_rounded,
            helper: view.placements.isEmpty ? l.sigNeedOne : null,
            onPressed: view.placements.isEmpty
                ? null
                : () => runTool(context, ref, ref.read(signOperationProvider), [file], SignOptions(view.placements)),
          ),
        ]),
      ),
    );
  }

  Widget _handle(String tooltip, IconData icon, {VoidCallback? onTap, GestureDragStartCallback? onStart, GestureDragUpdateCallback? onUpdate, VoidCallback? onEnd}) =>
      Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onPanStart: onStart,
          onPanUpdate: onUpdate,
          onPanEnd: onEnd == null ? null : (_) => onEnd(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: context.colors.onPrimary),
              ),
            ),
          ),
        ),
      );

  Widget _placement(Placement pl, double scale, bool selected, Size page) {
    final l = context.l10n;
    final ctrl = ref.read(placementEditorProvider.notifier);
    final r = pl.rect;
    Offset centreGlobal() {
      final box = _pageKey.currentContext!.findRenderObject()! as RenderBox;
      return box.localToGlobal(r.center * scale);
    }

    return Positioned(
      key: ValueKey('placement-${pl.id}'),
      // The page starts _handleRoom in; the box starts _handleRoom before the image.
      left: r.left * scale,
      top: r.top * scale,
      width: r.width * scale + 2 * _handleRoom,
      height: r.height * scale + 2 * _handleRoom,
      child: Transform.rotate(
        angle: pl.rotation * math.pi / 180,
        child: Stack(children: [
          Positioned(
            left: _handleRoom,
            top: _handleRoom,
            right: _handleRoom,
            bottom: _handleRoom,
            child: Semantics(
              selected: selected,
              button: true,
              label: switch (pl.kind) {
                PlacementKind.signature => l.sigAddSignature,
                PlacementKind.date => l.sigAddDate,
                PlacementKind.text => l.sigAddText,
                PlacementKind.initials => l.sigAddInitials,
              },
              child: GestureDetector(
                key: ValueKey('body-${pl.id}'),
                onTap: () => ctrl.select(pl.id),
                onPanStart: (d) {
                  _lastGlobal = d.globalPosition;
                  ctrl.begin(pl.id);
                },
                onPanUpdate: (d) {
                  final last = _lastGlobal ?? d.globalPosition;
                  _lastGlobal = d.globalPosition;
                  ctrl.liveMove(pl.id, (d.globalPosition - last) / scale);
                },
                onPanEnd: (_) => ctrl.end(),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: selected ? context.colors.primary : Colors.transparent, width: 1.5),
                  ),
                  child: Image.file(File(pl.pngPath), fit: BoxFit.fill, gaplessPlayback: true),
                ),
              ),
            ),
          ),
          if (selected) ...[
            Positioned(left: 0, top: 0, child: _handle(l.actionRemove, Icons.close_rounded, onTap: () => ctrl.delete(pl.id))),
            Positioned(
              right: 0,
              top: 0,
              child: _handle(l.sigRotateHandle, Icons.rotate_right_rounded,
                  onStart: (d) {
                    _startRotation = pl.rotation;
                    _startVector = d.globalPosition - centreGlobal();
                    ctrl.begin(pl.id);
                  },
                  onUpdate: (d) {
                    final v = d.globalPosition - centreGlobal();
                    final deg = (v.direction - _startVector.direction) * 180 / math.pi;
                    ctrl.liveSet(pl.id, rotation: snapRotation(_startRotation + deg));
                  },
                  onEnd: ctrl.end),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _handle(l.sigResizeHandle, Icons.open_in_full_rounded,
                  onStart: (d) {
                    _startRect = pl.rect;
                    _startVector = _toPagePoints(d.globalPosition, scale) - pl.rect.center;
                    ctrl.begin(pl.id);
                  },
                  onUpdate: (d) {
                    final start = _startRect;
                    if (start == null || _startVector.distance == 0) return;
                    final v = _toPagePoints(d.globalPosition, scale) - start.center;
                    ctrl.liveSet(pl.id, rect: resizeAboutCentre(start, v.distance / _startVector.distance, page));
                  },
                  onEnd: ctrl.end),
            ),
            Positioned(left: 0, bottom: 0, child: _handle(l.sigMore, Icons.more_horiz_rounded, onTap: () => _moreSheet(pl.id))),
          ],
        ]),
      ),
    );
  }
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.title, required this.initial});
  final String title, initial;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog.adaptive(
      title: Text(widget.title),
      content: Material(
        type: MaterialType.transparency,
        child: TextField(key: const ValueKey('stamp-text'), controller: _c, autofocus: true, maxLength: 60),
      ),
      actions: [
        adaptiveAction(context, label: l.actionCancel, onPressed: () => Navigator.pop(context)),
        adaptiveAction(context, label: l.inputsAdd, primary: true, onPressed: () => Navigator.pop(context, _c.text.trim())),
      ],
    );
  }
}

/// "Pages…" (S35): All pages / Pages [range] / Only this page → 0-based pages.
class _PagesSheet extends StatefulWidget {
  const _PagesSheet({required this.pageCount});
  final int pageCount;

  @override
  State<_PagesSheet> createState() => _PagesSheetState();
}

class _PagesSheetState extends State<_PagesSheet> {
  final _range = TextEditingController();
  var _choice = 0; // 0 all, 1 range, 2 this page only

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = widget.pageCount;
    final parsed = _choice == 1 ? parsePageRanges(_range.text, n, endWords: {'end', l.rangeEndWord}) : null;
    final error = parsed?.error == null || _range.text.isEmpty ? null : rangeErrorText(l, parsed!.error!, n);
    Widget option(int v, String label) => ListTile(
          leading: Icon(_choice == v ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
          title: Text(label),
          selected: _choice == v,
          onTap: () => setState(() => _choice = v),
        );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x4),
            child: Text(l.sigPagesSheet, style: context.text.titleLarge),
          ),
          option(0, l.sigPagesAll),
          option(1, l.sigPagesRange),
          if (_choice == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: TextField(
                key: const ValueKey('sig-range'),
                controller: _range,
                decoration: InputDecoration(hintText: l.wmkRangeHint, errorText: error, border: const OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
          option(2, l.sigPagesThis),
          Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _choice == 1 && parsed?.parts == null
                  ? null
                  : () => Navigator.pop(context, switch (_choice) {
                        0 => [for (var i = 0; i < n; i++) i],
                        1 => {for (final r in parsed!.parts!) ...r.pages}.map((p) => p - 1).toList(),
                        _ => const <int>[],
                      }),
              child: Text(l.actionDone),
            ),
          ),
        ]),
      ),
    );
  }
}
