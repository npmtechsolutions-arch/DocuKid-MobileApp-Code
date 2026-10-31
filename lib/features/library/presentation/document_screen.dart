import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/ads/bottom_banner.dart';
import '../../../core/formatting/bytes_format.dart';
import '../../../core/formatting/date_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../data/library/library_repository.dart';
import '../../job/job_visuals.dart';
import '../../job/save_flow.dart';
import '../application/index_queue.dart';
import '../application/library_controller.dart';
import '../application/open_in_tool.dart';
import 'folder_picker_sheet.dart';
import 'widgets/library_tiles.dart';

/// How long notes wait after the last keystroke before saving (S42).
const notesSaveDelay = Duration(milliseconds: 600);

/// S42 Document detail (RELEASE_V1_5 §3, FR-LIB-11–13). Expiry and reminders
/// join in T12.6, "Make searchable now" in T12.5.
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({super.key, required this.docId});
  final String docId;

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  final _notes = TextEditingController();
  bool _notesLoaded = false, _leaving = false;
  Timer? _notesTimer;

  // `ref` can't be used in dispose, so the pending notes save keeps its own.
  late final LibraryRepository _repo = ref.read(libraryRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_repo.markOpened(widget.docId).catchError((_) {}));
  }

  @override
  void dispose() {
    if (_notesTimer?.isActive ?? false) {
      _notesTimer!.cancel();
      unawaited(_saveNotes());
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    try {
      await _repo.setNotes(widget.docId, _notes.text);
    } on Exception {
      // Gone meanwhile, or over the limit (the field already stops at 2,000).
    }
  }

  void _notesChanged(String _) {
    _notesTimer?.cancel();
    _notesTimer = Timer(notesSaveDelay, _saveNotes);
  }

  // ---------------------------------------------------------------- actions

  Future<void> _rename(LibraryDoc d) async {
    final name = await renameDialog(context, currentName: d.name);
    if (name == null || name == d.name) return;
    try {
      await _repo.rename(d.id, name);
    } on LibraryException {
      if (mounted) showAppSnack(context, context.l10n.libNameTaken);
    }
  }

  Future<void> _move(LibraryDoc d) async {
    final l = context.l10n;
    final pick = await showFolderPicker(context,
        title: l.libMoveTitle(1), actionLabel: l.libMoveHere, currentFolderId: d.folderId, disableCurrent: true);
    if (pick != null) await _repo.move([d.id], pick.folderId);
  }

  Future<void> _delete(LibraryDoc d) async {
    final l = context.l10n;
    final ok = await askAdaptive(context, title: l.libDeleteDocTitle(d.name), body: l.libDeleteDocBody, no: l.actionCancel, yes: l.libDelete);
    if (!ok || !mounted) return;
    _leaving = true;
    _notesTimer?.cancel();
    await _repo.delete([d.id]);
    if (!mounted) return;
    showAppSnack(context, l.libDeletedSnack(d.name));
    _close();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/library');

  Future<void> _menu(LibraryDoc d, bool missing) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!missing) ...[
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.actionRename), onTap: () => Navigator.pop(ctx, 'rename')),
            ListTile(leading: const Icon(Icons.drive_file_move_outline), title: Text(l.libMove), onTap: () => Navigator.pop(ctx, 'move')),
            if (_canMakeSearchable(d))
              ListTile(
                  leading: const Icon(Icons.manage_search_rounded),
                  title: Text(l.libSearchableNow),
                  onTap: () => Navigator.pop(ctx, 'index')),
          ],
          ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l.libDelete), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await _rename(d);
      case 'move':
        await _move(d);
      case 'delete':
        await _delete(d);
      case 'index':
        await ref.read(indexQueueProvider).makeSearchableNow(d.id);
    }
  }

  /// FR-LIB-15: any document not already searchable or on its way.
  bool _canMakeSearchable(LibraryDoc d) =>
      d.indexState == IndexState.none || d.indexState == IndexState.failed || d.indexState == IndexState.notNeeded;

  Future<void> _addTag(LibraryDoc d) async {
    final all = ref.read(libraryTagsProvider).value ?? const <String>[];
    final have = d.tags.map((t) => t.toLowerCase()).toSet();
    final tag = await showDialog<String>(
      context: context,
      builder: (_) => _TagDialog(suggestions: [for (final t in all) if (!have.contains(t.toLowerCase())) t]),
    );
    if (tag == null || tag.trim().isEmpty) return;
    await _repo.setTags(d.id, [...d.tags, tag.trim()]);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final detail = ref.watch(libraryDocProvider(widget.docId));
    // Kept alive while S42 is open: the Add tag suggestions.
    ref.watch(libraryTagsProvider);
    final d = detail.value?.doc;
    if (detail.hasValue && d == null && !_leaving) {
      // Deleted elsewhere (or a stale link): say so and leave.
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppSnack(context, l.libGone);
        _close();
      });
    }
    if (d == null) return Scaffold(appBar: AppBar());
    final missing = detail.value!.missing;
    if (!_notesLoaded) {
      _notesLoaded = true;
      _notes.text = d.notes;
    }
    final path = _repo.absolutePath(d);
    final folderPath = detail.value!.folderPath;
    final info = [
      d.isPdf ? l.libTypePdf : l.libTypeImage,
      if (d.pageCount != null) l.metaPages(d.pageCount!),
      if (d.width != null && d.height != null) l.metaDims(d.width!, d.height!),
      formatBytes(d.sizeBytes),
      l.libAddedOn(formatDate(d.addedAt)),
    ].join(' · ');
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);

    Widget action(String key, IconData icon, String label, Future<void> Function(BuildContext anchor) run) => Builder(
          builder: (anchor) => ResultActionButton(
            key: ValueKey(key),
            icon: icon,
            label: label,
            onPressed: missing ? null : () => run(anchor),
          ),
        );

    return AppBottomBanner(
      unit: AdUnit.bannerMain,
      child: Scaffold(
        appBar: AppBar(actions: [
          IconButton(
            tooltip: d.starred ? l.libUnstar : l.libStar,
            icon: Icon(d.starred ? Icons.star_rounded : Icons.star_outline_rounded),
            onPressed: () => _repo.setStarred([d.id], !d.starred),
          ),
          IconButton(tooltip: l.libDocMore, icon: const Icon(Icons.more_vert_rounded), onPressed: () => _menu(d, missing)),
        ]),
        body: ContentWidth(
          child: ListView(padding: const EdgeInsets.fromLTRB(0, Space.x2, 0, Space.x6), children: [
            // Preview: tap → full viewer (no ads there).
            Semantics(
              button: !missing,
              label: missing ? l.libFileMissing : l.libOpenFull,
              excludeSemantics: true,
              child: Material(
                color: context.colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Radii.lg),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('doc-preview'),
                  onTap: missing ? null : () => context.push('/library/doc/${d.id}/view'),
                  child: SizedBox(
                    height: 240,
                    child: Center(
                      child: missing
                          ? Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.broken_image_outlined, size: 40, color: context.colors.onSurfaceVariant),
                              const SizedBox(height: Space.x2),
                              Text(l.libFileMissing, style: muted),
                            ])
                          : DocThumb(doc: d, path: path, size: 200),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.x4),
            Row(children: [
              Expanded(child: MiddleEllipsisText(d.name, style: context.text.titleLarge)),
              if (!missing) IconButton(tooltip: l.actionRename, icon: const Icon(Icons.edit_outlined), onPressed: () => _rename(d)),
            ]),
            Text(info, style: muted),
            const SizedBox(height: Space.x2),
            Row(children: [
              Expanded(
                child: Text(l.libFolderLine(folderPath.isEmpty ? l.libRoot : folderPath.join(' › ')),
                    style: context.text.bodyMedium),
              ),
              if (!missing)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => _move(d),
                  child: Text(l.libMoveLink),
                ),
            ]),
            const Divider(height: Space.x6),
            Text(l.libNotes, style: context.text.titleSmall),
            const SizedBox(height: Space.x2),
            TextField(
              key: const ValueKey('doc-notes'),
              controller: _notes,
              onChanged: _notesChanged,
              minLines: 2,
              maxLines: 6,
              maxLength: maxNotesChars,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l.libNotesHint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: Space.x2),
            Text(l.libTags, style: context.text.titleSmall),
            const SizedBox(height: Space.x2),
            Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
              for (final t in d.tags)
                InputChip(
                  label: Text(t),
                  onDeleted: () => _repo.setTags(d.id, [...d.tags]..remove(t)),
                  deleteButtonTooltipMessage: l.libTagRemove(t),
                ),
              Tooltip(
                message: d.tags.length >= maxTags ? l.libTagsFull : l.libTagAdd,
                child: ActionChip(
                  key: const ValueKey('doc-add-tag'),
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.libTagAdd),
                  onPressed: d.tags.length >= maxTags ? null : () => _addTag(d),
                ),
              ),
            ]),
            const SizedBox(height: Space.x4),
            Row(children: [
              Icon(
                  switch (d.indexState) {
                    IndexState.done => Icons.check_circle_outline_rounded,
                    IndexState.queued || IndexState.indexing => Icons.hourglass_top_rounded,
                    _ => Icons.text_snippet_outlined,
                  },
                  size: 20,
                  color: context.colors.onSurfaceVariant),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  key: const ValueKey('doc-searchable'),
                  switch (d.indexState) {
                    IndexState.done => l.libSearchableYes,
                    IndexState.queued || IndexState.indexing => l.libSearchablePending,
                    IndexState.failed => l.libSearchableFailed,
                    _ => l.libSearchableNo,
                  },
                  style: muted,
                ),
              ),
              if (!missing && _canMakeSearchable(d))
                TextButton(
                  key: const ValueKey('doc-make-searchable'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => ref.read(indexQueueProvider).makeSearchableNow(d.id),
                  child: Text(l.libSearchableNow),
                ),
            ]),
            const Divider(height: Space.x6),
            Row(children: [
              Expanded(
                  child: action('doc-share', Icons.share_outlined, l.actionShare,
                      (a) => shareResult(a, ref, path: path, mime: d.mime))),
              const SizedBox(width: Space.x3),
              Expanded(
                  child: action('doc-save', Icons.download_rounded, l.libSaveToDevice,
                      (_) => saveResult(context, ref, path: path, name: d.name, mime: d.mime, opId: null))),
            ]),
            const SizedBox(height: Space.x3),
            Row(children: [
              Expanded(
                  child: action('doc-open-with', Icons.open_in_new_rounded, l.actionOpenWith,
                      (a) => openWithResult(a, ref, path: path, mime: d.mime))),
              const SizedBox(width: Space.x3),
              Expanded(
                  child: action('doc-open-in-tool', Icons.handyman_outlined, l.libOpenInTool, (_) => openInTool(context, ref, [d]))),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// "Add tag": free text (≤ 30 characters) with the tags already in use as
/// suggestions (FR-LIB-13).
class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.suggestions});
  final List<String> suggestions;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _c.text.trim().toLowerCase();
    final shown = [for (final t in widget.suggestions) if (q.isEmpty || t.toLowerCase().contains(q)) t].take(8);
    return AlertDialog(
      title: Text(l.libTagAdd),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          key: const ValueKey('tag-name'),
          controller: _c,
          autofocus: true,
          maxLength: maxTagChars,
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        if (shown.isNotEmpty)
          Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
            for (final t in shown) ActionChip(label: Text(t), onPressed: () => Navigator.pop(context, t)),
          ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        TextButton(onPressed: _c.text.trim().isEmpty ? null : () => Navigator.pop(context, _c.text), child: Text(l.libAdd)),
      ],
    );
  }
}
