import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/library/library_repository.dart';

enum LibraryView { grid, list }

/// S40/S41 view state (RELEASE_V1_5 §3, FR-LIB-08…10). View and sort are
/// remembered (`lib_view`, `lib_sort`); selection and pending deletes aren't.
class LibraryViewState {
  const LibraryViewState({
    this.view = LibraryView.grid,
    this.sort = LibrarySort.added,
    this.starredOnly = false,
    this.selected = const {},
    this.hidden = const {},
  });
  final LibraryView view;
  final LibrarySort sort;
  final bool starredOnly;

  /// Selected document ids; non-empty = selection mode.
  final Set<String> selected;

  /// Deleted with Undo still possible (FR-LIB-07): not shown.
  final Set<String> hidden;

  bool get selecting => selected.isNotEmpty;

  LibraryViewState copyWith({LibraryView? view, LibrarySort? sort, bool? starredOnly, Set<String>? selected, Set<String>? hidden}) =>
      LibraryViewState(
        view: view ?? this.view,
        sort: sort ?? this.sort,
        starredOnly: starredOnly ?? this.starredOnly,
        selected: selected ?? this.selected,
        hidden: hidden ?? this.hidden,
      );
}

/// How long a single delete can be undone (FR-LIB-07).
const libraryUndoWindow = Duration(seconds: 5);

class LibraryViewController extends Notifier<LibraryViewState> {
  final _pending = <String, Timer>{};

  @override
  LibraryViewState build() {
    final (v, s) = ref.read(settingsRepositoryProvider).readLibView();
    ref.onDispose(() {
      // Leaving: deletes still pending go through now.
      final ids = _pending.keys.toList();
      for (final t in _pending.values) {
        t.cancel();
      }
      _pending.clear();
      if (ids.isNotEmpty) unawaited(ref.read(libraryRepositoryProvider).delete(ids));
    });
    return LibraryViewState(
      view: LibraryView.values.firstWhere((x) => x.name == v, orElse: () => LibraryView.grid),
      sort: LibrarySort.values.firstWhere((x) => x.name == s, orElse: () => LibrarySort.added),
    );
  }

  void _persist() => unawaited(ref.read(settingsRepositoryProvider).writeLibView(state.view.name, state.sort.name));

  void setView(LibraryView v) {
    state = state.copyWith(view: v);
    _persist();
  }

  void setSort(LibrarySort s) {
    state = state.copyWith(sort: s);
    _persist();
  }

  void setStarredOnly(bool v) => state = state.copyWith(starredOnly: v, selected: const {});

  void toggle(String id) {
    final next = {...state.selected};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selected: next);
  }

  void clearSelection() => state = state.copyWith(selected: const {});

  /// Hides [id] now and deletes it after [libraryUndoWindow] unless [undo]ne.
  /// A process death in between keeps the document (nothing was deleted).
  void deleteWithUndo(String id) {
    state = state.copyWith(hidden: {...state.hidden, id}, selected: {...state.selected}..remove(id));
    _pending[id]?.cancel();
    _pending[id] = Timer(libraryUndoWindow, () {
      _pending.remove(id);
      unawaited(ref.read(libraryRepositoryProvider).delete([id]).whenComplete(() {
        if (ref.mounted) state = state.copyWith(hidden: {...state.hidden}..remove(id));
      }));
    });
  }

  void undo(String id) {
    _pending.remove(id)?.cancel();
    state = state.copyWith(hidden: {...state.hidden}..remove(id));
  }
}

final libraryViewProvider = NotifierProvider.autoDispose<LibraryViewController, LibraryViewState>(LibraryViewController.new);

/// Folders directly in [parentId] (null = root).
final libraryFoldersProvider = StreamProvider.autoDispose.family<List<LibraryFolder>, String?>(
    (ref, parentId) => ref.watch(libraryRepositoryProvider).watchFolders(parentId: parentId));

class DocsQuery {
  const DocsQuery(this.folderId, this.sort, {this.starredOnly = false});
  final String? folderId;
  final LibrarySort sort;
  final bool starredOnly;

  @override
  bool operator ==(Object other) =>
      other is DocsQuery && other.folderId == folderId && other.sort == sort && other.starredOnly == starredOnly;
  @override
  int get hashCode => Object.hash(folderId, sort, starredOnly);
}

final libraryDocsProvider = StreamProvider.autoDispose.family<List<LibraryDoc>, DocsQuery>((ref, q) =>
    ref.watch(libraryRepositoryProvider).watchDocs(folderId: q.folderId, sort: q.sort, starredOnly: q.starredOnly));

/// A folder and its ancestors, root first (S41 breadcrumb); null if it's gone.
final folderTrailProvider = StreamProvider.autoDispose.family<List<LibraryFolder>?, String>((ref, id) async* {
  final repo = ref.watch(libraryRepositoryProvider);
  await for (final _ in repo.watchFolders()) {
    final trail = <LibraryFolder>[];
    String? at = id;
    while (at != null) {
      final f = await repo.folder(at);
      if (f == null) break;
      trail.insert(0, f);
      at = f.parentId;
    }
    yield trail.isEmpty || trail.last.id != id ? null : trail;
  }
});
