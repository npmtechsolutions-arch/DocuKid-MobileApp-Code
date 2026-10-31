import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../data/library/library_repository.dart';
import 'folder_name_dialog.dart';

/// The chosen destination; [folderId] null = the root.
class FolderPick {
  const FolderPick(this.folderId);
  final String? folderId;
}

/// S43 · Move / Save to (RELEASE_V1_5 §3): a tree of folders. Disabled: the
/// item's current folder ([currentFolderId], single item), and when moving a
/// folder ([movingFolderId]) itself, its descendants and anything that would
/// go deeper than 3 levels. A sheet: never ads. Null when cancelled.
Future<FolderPick?> showFolderPicker(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? currentFolderId,
  bool disableCurrent = false,
  String? movingFolderId,
  String? initialFolderId,
}) =>
    showModalBottomSheet<FolderPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FolderPicker(
        title: title,
        actionLabel: actionLabel,
        currentFolderId: currentFolderId,
        disableCurrent: disableCurrent,
        movingFolderId: movingFolderId,
        initialFolderId: initialFolderId,
      ),
    );

const _root = '';

class _FolderPicker extends ConsumerStatefulWidget {
  const _FolderPicker({
    required this.title,
    required this.actionLabel,
    required this.currentFolderId,
    required this.disableCurrent,
    required this.movingFolderId,
    this.initialFolderId,
  });
  final String title, actionLabel;
  final String? currentFolderId, movingFolderId;

  /// Preselected (e.g. "Scans" for a scan, FR-LIB-05); else the root.
  final String? initialFolderId;
  final bool disableCurrent;

  @override
  ConsumerState<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<_FolderPicker> {
  List<LibraryFolder>? _folders;
  var _disabled = <String>{};
  String? _selected;
  var _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? select}) async {
    final repo = ref.read(libraryRepositoryProvider);
    final folders = await repo.allFolders();
    final disabled = <String>{};
    if (widget.disableCurrent) disabled.add(widget.currentFolderId ?? _root);
    if (widget.movingFolderId != null) {
      for (final id in [_root, ...folders.map((f) => f.id)]) {
        if (!await repo.canMoveFolder(widget.movingFolderId!, id == _root ? null : id)) disabled.add(id);
      }
    }
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _disabled = disabled;
      final initial = widget.initialFolderId;
      final preselect = initial != null && !disabled.contains(initial) && folders.any((f) => f.id == initial) ? initial : null;
      _selected = select ?? preselect ?? (disabled.contains(_root) ? null : _root);
    });
  }

  /// Depth-first rows (folder, level) under [parent], filtered by [_filter]
  /// (a match keeps its ancestors).
  List<(LibraryFolder, int)> _rows() {
    final all = _folders ?? const [];
    final byParent = <String?, List<LibraryFolder>>{};
    for (final f in all) {
      (byParent[f.parentId] ??= []).add(f);
    }
    final q = _filter.trim().toLowerCase();
    bool matches(LibraryFolder f) =>
        q.isEmpty || f.name.toLowerCase().contains(q) || (byParent[f.id] ?? const []).any(matches);
    final out = <(LibraryFolder, int)>[];
    void walk(String? parent, int level) {
      for (final f in byParent[parent] ?? const <LibraryFolder>[]) {
        if (!matches(f)) continue;
        out.add((f, level));
        walk(f.id, level + 1);
      }
    }

    walk(null, 1);
    return out;
  }

  Future<void> _newFolder() async {
    final l = context.l10n;
    final parent = _selected == null || _selected == _root ? null : _selected;
    final parentDepth = parent == null ? 0 : _folders!.firstWhere((f) => f.id == parent).depth;
    if (parentDepth >= maxFolderDepth) {
      showAppSnack(context, l.libFolderDepth);
      return;
    }
    final created = await showFolderNameDialog(context, title: l.libNewFolder, action: l.libCreate,
        submit: (name) => ref.read(libraryRepositoryProvider).createFolder(name, parentId: parent));
    if (created != null) await _load(select: created.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = _rows();
    Widget row(String id, String name, int level) {
      final disabled = _disabled.contains(id);
      final selected = _selected == id;
      return Semantics(
        selected: selected,
        enabled: !disabled,
        button: true,
        child: ListTile(
          key: ValueKey('pick-${id.isEmpty ? 'root' : id}'),
          enabled: !disabled,
          contentPadding: EdgeInsetsDirectional.only(start: Space.x4 + Space.x5 * level, end: Space.x4),
          leading: Icon(id == _root ? Icons.folder_special_rounded : Icons.folder_rounded),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? context.colors.primary : null),
          onTap: () => setState(() => _selected = id),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: Row(children: [
                Expanded(child: Text(widget.title, style: context.text.titleLarge)),
                IconButton(tooltip: l.actionClose, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x2),
              child: TextField(
                key: const ValueKey('pick-filter'),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded), hintText: l.libFindFolder, border: const OutlineInputBorder()),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Flexible(
              child: _folders == null
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : ListView(shrinkWrap: true, children: [
                      row(_root, l.libRoot, 0),
                      for (final (f, level) in rows) row(f.id, f.name, level),
                    ]),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _folders == null ? null : _newFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l.libNewFolder),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x3),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.actionCancel),
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _selected == null || _disabled.contains(_selected)
                        ? null
                        : () => Navigator.pop(context, FolderPick(_selected == _root ? null : _selected)),
                    child: Text(widget.actionLabel),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
