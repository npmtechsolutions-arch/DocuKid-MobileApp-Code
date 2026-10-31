import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ads/ad_slots.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/ads/bottom_banner.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../data/library/library_repository.dart';
import '../../search/tool_catalog.dart';
import '../application/add_to_library.dart';
import '../application/expiry.dart';
import '../application/library_controller.dart';
import '../application/open_in_tool.dart';
import '../application/search_controller.dart';
import 'folder_name_dialog.dart';
import 'folder_picker_sheet.dart';
import 'library_intro_screen.dart';
import 'widgets/library_tiles.dart';
import 'widgets/search_result_tile.dart';

/// Documents before the in-feed native card, and the minimum to show it
/// (RELEASE_V1_5 §3.2: after the 5th item, only when there are ≥ 6).
const libraryAdAfter = 5;

/// S40 Library home ([folderId] null) and S41 Folder view (RELEASE_V1_5 §3;
/// FR-LIB-01, 02, 06–10). Search, Expiring soon, Import/Scan, tags and Open in
/// tool arrive with T12.3–T12.6.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.folderId});
  final String? folderId;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late bool _introSeen = ref.read(settingsRepositoryProvider).readLibIntroSeen();
  var _goneHandled = false;

  // FR-LIB-14: the query searched (150 ms after the last keystroke).
  final _search = TextEditingController();
  Timer? _searchTimer;
  var _query = '';

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String v) {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);
  LibraryViewController get _ctrl => ref.read(libraryViewProvider.notifier);

  // ---------------------------------------------------------------- folders

  Future<void> _newFolder(int depth) async {
    final l = context.l10n;
    if (depth >= maxFolderDepth) {
      showAppSnack(context, l.libFolderDepth);
      return;
    }
    await showFolderNameDialog(context,
        title: l.libNewFolder, action: l.libCreate, submit: (n) => _repo.createFolder(n, parentId: widget.folderId));
  }

  /// S40/S41 + : Import files · Scan a document · New folder (FR-LIB-04/05/06).
  Future<void> _add(int depth) async {
    final l = context.l10n;
    final atLimit = depth >= maxFolderDepth;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              key: const ValueKey('lib-add-import'),
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(l.libImport),
              onTap: () => Navigator.pop(ctx, 'import')),
          ListTile(
              key: const ValueKey('lib-add-scan'),
              leading: const Icon(Icons.document_scanner_outlined),
              title: Text(l.libScan),
              onTap: () => Navigator.pop(ctx, 'scan')),
          ListTile(
            key: const ValueKey('lib-add-folder'),
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l.libNewFolder),
            subtitle: atLimit ? Text(l.libFolderDepth) : null,
            enabled: !atLimit,
            onTap: () => Navigator.pop(ctx, 'folder'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'import':
        await chooseImport(context, ref, folderId: widget.folderId);
      case 'scan':
        _scan();
      case 'folder':
        await _newFolder(depth);
    }
  }

  void _scan() {
    ref.read(scanTargetFolderProvider.notifier).set(widget.folderId);
    context.push(toolById(ToolId.scanDocument).route);
  }

  Future<void> _folderMenu(LibraryFolder f) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(f.name, style: ctx.text.titleMedium)),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.actionRename), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(leading: const Icon(Icons.drive_file_move_outline), title: Text(l.libMove), onTap: () => Navigator.pop(ctx, 'move')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l.libDelete), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await showFolderNameDialog(context,
            title: l.actionRename, action: l.actionSave, initial: f.name, submit: (n) => _repo.renameFolder(f.id, n));
      case 'move':
        final pick = await showFolderPicker(context,
            title: l.libMoveTitle(1), actionLabel: l.libMoveHere, currentFolderId: f.parentId, disableCurrent: true, movingFolderId: f.id);
        if (pick != null) {
          try {
            await _repo.moveFolder(f.id, pick.folderId);
          } on LibraryException catch (e) {
            if (mounted) showAppSnack(context, e.code == LibraryErrorCode.folderNameTaken ? l.libFolderNameTaken : l.libFolderDepth);
          }
        }
      case 'delete':
        await _deleteFolder(f);
    }
  }

  /// FR-LIB-06: a non-empty folder asks, with counts; "Move contents up" is the default.
  Future<bool> _deleteFolder(LibraryFolder f) async {
    final l = context.l10n;
    final c = await _repo.folderContents(f.id);
    if (!mounted) return false;
    FolderDeleteMode? mode;
    if (c.docs == 0 && c.folders == 0) {
      final ok = await askAdaptive(context, title: l.libDeleteFolderTitle(f.name), no: l.actionCancel, yes: l.libDelete);
      if (ok) mode = FolderDeleteMode.moveContentsUp;
    } else {
      mode = await showAdaptiveDialog<FolderDeleteMode>(
        context: context,
        builder: (ctx) => AlertDialog.adaptive(
          title: Text(l.libDeleteFolderTitle(f.name)),
          content: Text(l.libDeleteFolderBody(c.docs, c.folders)),
          actions: [
            adaptiveAction(ctx, label: l.actionCancel, onPressed: () => Navigator.pop(ctx)),
            adaptiveAction(ctx, label: l.libDeleteFolderAll, destructive: true,
                onPressed: () => Navigator.pop(ctx, FolderDeleteMode.deleteEverything)),
            adaptiveAction(ctx, label: l.libDeleteFolderMove, primary: true,
                onPressed: () => Navigator.pop(ctx, FolderDeleteMode.moveContentsUp)),
          ],
        ),
      );
    }
    if (mode == null) return false;
    await _repo.deleteFolder(f.id, mode: mode);
    return true;
  }

  // ---------------------------------------------------------------- documents

  void _open(LibraryDoc d) => context.push('/library/doc/${d.id}');

  Future<void> _move(List<LibraryDoc> docs) async {
    final l = context.l10n;
    final single = docs.length == 1;
    final pick = await showFolderPicker(context,
        title: l.libMoveTitle(docs.length),
        actionLabel: l.libMoveHere,
        currentFolderId: single ? docs.single.folderId : null,
        disableCurrent: single);
    if (pick == null) return;
    await _repo.move(docs.map((d) => d.id).toList(), pick.folderId);
    _ctrl.clearSelection();
  }

  Future<void> _deleteOne(LibraryDoc d) async {
    final l = context.l10n;
    final ok = await askAdaptive(context, title: l.libDeleteDocTitle(d.name), body: l.libDeleteDocBody, no: l.actionCancel, yes: l.libDelete);
    if (!ok || !mounted) return;
    _ctrl.deleteWithUndo(d.id);
    showAppSnack(context, l.libDeletedSnack(d.name), actionLabel: l.actionUndo, onAction: () => _ctrl.undo(d.id));
  }

  Future<void> _deleteSelected(List<LibraryDoc> docs) async {
    final l = context.l10n;
    final ok = await askAdaptive(context, title: l.libDeleteDocsTitle(docs.length), body: l.libDeleteDocBody, no: l.actionCancel, yes: l.libDelete);
    if (!ok) return;
    await _repo.delete(docs.map((d) => d.id).toList());
    _ctrl.clearSelection();
  }

  Future<void> _rename(LibraryDoc d) async {
    final name = await renameDialog(context, currentName: d.name);
    if (name == null || name == d.name) return;
    try {
      await _repo.rename(d.id, name);
    } on LibraryException {
      if (mounted) showAppSnack(context, context.l10n.libNameTaken);
    }
  }

  Future<void> _docMenu(LibraryDoc d) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: MiddleEllipsisText(d.name, style: ctx.text.titleMedium)),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.actionRename), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(leading: const Icon(Icons.drive_file_move_outline), title: Text(l.libMove), onTap: () => Navigator.pop(ctx, 'move')),
          ListTile(
              leading: Icon(d.starred ? Icons.star_rounded : Icons.star_outline_rounded),
              title: Text(d.starred ? l.libUnstar : l.libStar),
              onTap: () => Navigator.pop(ctx, 'star')),
          ListTile(leading: const Icon(Icons.share_outlined), title: Text(l.actionShare), onTap: () => Navigator.pop(ctx, 'share')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l.libDelete), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await _rename(d);
      case 'move':
        await _move([d]);
      case 'star':
        await _repo.setStarred([d.id], !d.starred);
      case 'share':
        await _share([d]);
      case 'delete':
        await _deleteOne(d);
    }
  }

  Future<void> _share(List<LibraryDoc> docs) async {
    final mimes = docs.map((d) => d.mime).toSet();
    await ref.read(fileGatewayProvider).share([for (final d in docs) _repo.absolutePath(d)],
        mime: mimes.length == 1 ? mimes.single : '*/*', origin: originOf(context));
  }

  // ---------------------------------------------------------------- build

  Future<void> _menu(LibraryViewState s, LibraryFolder? here) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(l.libSort, style: ctx.text.titleMedium)),
            for (final (sort, label) in [
              (LibrarySort.name, l.libSortName),
              (LibrarySort.added, l.libSortAdded),
              (LibrarySort.size, l.libSortSize),
              (LibrarySort.expiry, l.libSortExpiry),
            ])
              ListTile(
                leading: Icon(s.sort == sort ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                title: Text(label),
                selected: s.sort == sort,
                onTap: () => Navigator.pop(ctx, 'sort:${sort.name}'),
              ),
            const Divider(),
            ListTile(
              leading: Icon(s.view == LibraryView.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
              title: Text(s.view == LibraryView.grid ? l.libViewList : l.libViewGrid),
              onTap: () => Navigator.pop(ctx, 'view'),
            ),
            if (here == null)
              ListTile(
                  leading: const Icon(Icons.settings_outlined), title: Text(l.setLibTitle), onTap: () => Navigator.pop(ctx, 'settings')),
            if (here != null) ...[
              ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.actionRename), onTap: () => Navigator.pop(ctx, 'rename')),
              ListTile(
                  leading: const Icon(Icons.drive_file_move_outline), title: Text(l.libMove), onTap: () => Navigator.pop(ctx, 'move')),
              ListTile(
                  leading: const Icon(Icons.delete_outline_rounded), title: Text(l.libDelete), onTap: () => Navigator.pop(ctx, 'delete')),
            ],
          ]),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice.startsWith('sort:')) {
      _ctrl.setSort(LibrarySort.values.byName(choice.substring(5)));
    } else if (choice == 'view') {
      _ctrl.setView(s.view == LibraryView.grid ? LibraryView.list : LibraryView.grid);
    } else if (choice == 'settings') {
      unawaited(context.push('/settings/library'));
    } else if (here != null) {
      switch (choice) {
        case 'rename':
          await showFolderNameDialog(context,
              title: l.actionRename, action: l.actionSave, initial: here.name, submit: (n) => _repo.renameFolder(here.id, n));
        case 'move':
          final pick = await showFolderPicker(context,
              title: l.libMoveTitle(1), actionLabel: l.libMoveHere, currentFolderId: here.parentId, disableCurrent: true, movingFolderId: here.id);
          if (pick != null) await _repo.moveFolder(here.id, pick.folderId);
        case 'delete':
          final router = GoRouter.of(context);
          if (await _deleteFolder(here)) router.go(here.parentId == null ? '/library' : '/library/folder/${here.parentId}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (widget.folderId == null && !_introSeen) {
      return LibraryIntroScreen(onStart: () async {
        await ref.read(settingsRepositoryProvider).writeLibIntroSeen();
        if (mounted) setState(() => _introSeen = true);
      });
    }
    final s = ref.watch(libraryViewProvider);
    final trail = widget.folderId == null ? null : ref.watch(folderTrailProvider(widget.folderId!));
    final here = trail?.value?.last;
    if (trail is AsyncData<List<LibraryFolder>?> && trail.value == null && !_goneHandled) {
      // Unknown or deleted folder (§4.10).
      _goneHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppSnack(context, l.libGone);
        context.go('/library');
      });
    }
    final depth = here?.depth ?? 0;
    final folders = s.filtered ? const AsyncData(<LibraryFolder>[]) : ref.watch(libraryFoldersProvider(widget.folderId));
    final docs = ref.watch(libraryDocsProvider(DocsQuery(widget.folderId, s.sort, starredOnly: s.starredOnly, tag: s.tag)));
    final tags = widget.folderId == null ? ref.watch(libraryTagsProvider).value ?? const <String>[] : const <String>[];
    final expiring = widget.folderId == null && !s.filtered
        ? [for (final d in ref.watch(libraryExpiringProvider).value ?? const <LibraryDoc>[]) if (!s.hidden.contains(d.id)) d]
        : const <LibraryDoc>[];
    final visibleDocs = (docs.value ?? const <LibraryDoc>[]).where((d) => !s.hidden.contains(d.id)).toList();
    final selectedDocs = visibleDocs.where((d) => s.selected.contains(d.id)).toList();

    final title = widget.folderId == null
        ? Text(l.libTitle)
        : _Breadcrumb(trail: trail?.value ?? const [], onRoot: () => context.go('/library'),
            onFolder: (id) => context.go('/library/folder/$id'));

    final appBar = s.selecting
        ? AppBar(
            leading: IconButton(tooltip: l.actionClose, icon: const Icon(Icons.close_rounded), onPressed: _ctrl.clearSelection),
            title: Text(l.libSelected(s.selected.length)),
            actions: [
              IconButton(tooltip: l.libMove, icon: const Icon(Icons.drive_file_move_outline), onPressed: () => _move(selectedDocs)),
              IconButton(tooltip: l.actionShare, icon: const Icon(Icons.share_outlined), onPressed: () => _share(selectedDocs)),
              IconButton(
                tooltip: selectedDocs.every((d) => d.starred) ? l.libUnstar : l.libStar,
                icon: Icon(selectedDocs.every((d) => d.starred) ? Icons.star_rounded : Icons.star_outline_rounded),
                onPressed: () async {
                  await _repo.setStarred(s.selected.toList(), !selectedDocs.every((d) => d.starred));
                  _ctrl.clearSelection();
                },
              ),
              IconButton(tooltip: l.libDelete, icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _deleteSelected(selectedDocs)),
              PopupMenuButton<int>(
                key: const ValueKey('lib-selection-more'),
                tooltip: l.libMore,
                onSelected: (_) async {
                  await openInTool(context, ref, selectedDocs);
                  _ctrl.clearSelection();
                },
                itemBuilder: (_) => [PopupMenuItem(value: 0, child: Text(l.libOpenInTool))],
              ),
            ],
          )
        : AppBar(
            title: title,
            actions: [IconButton(tooltip: l.libMore, icon: const Icon(Icons.more_vert_rounded), onPressed: () => _menu(s, here))],
          );

    final loading = folders.isLoading || docs.isLoading;
    final empty = !loading && (folders.value ?? const []).isEmpty && visibleDocs.isEmpty;

    Widget body;
    if (loading) {
      body = const _Skeleton();
    } else if (empty && !s.filtered && widget.folderId == null) {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Illustration(kind: IllustrationKind.recentEmpty, size: 132),
            const SizedBox(height: Space.x4),
            Text(l.libEmptyTitle, style: context.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Space.x2),
            Text(l.libEmptyBody, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: Space.x5),
            Wrap(alignment: WrapAlignment.center, spacing: Space.x3, runSpacing: Space.x3, children: [
              FilledButton.icon(
                key: const ValueKey('lib-empty-import'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => chooseImport(context, ref),
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(l.libImport),
              ),
              OutlinedButton.icon(
                key: const ValueKey('lib-empty-scan'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _scan,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l.libScan),
              ),
            ]),
          ]),
        ),
      );
    } else {
      body = LayoutBuilder(builder: (context, c) {
        final cols = math.max(2, (c.maxWidth / 180).floor());
        final grid = s.view == LibraryView.grid;
        final now = ref.read(clockProvider)();
        ({String text, bool expired})? badge(LibraryDoc d) {
          final e = d.expiryDate;
          if (e == null || daysUntil(e, now) > expiringSoonDays) return null;
          return (text: expiryLabel(l, e, now), expired: daysUntil(e, now) < 0);
        }

        Widget docTile(LibraryDoc d) => Builder(
              builder: (anchor) => DocTile(
                doc: d,
                path: _repo.absolutePath(d),
                grid: grid,
                selected: s.selected.contains(d.id),
                selecting: s.selecting,
                onTap: () => s.selecting ? _ctrl.toggle(d.id) : _open(d),
                onLongPress: () => _ctrl.toggle(d.id),
                onMore: () => _docMenu(d),
                expiry: badge(d),
              ),
            );
        Widget docs(List<LibraryDoc> list) => grid
            ? SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols, childAspectRatio: 0.72, mainAxisSpacing: Space.x2, crossAxisSpacing: Space.x2),
                delegate: SliverChildBuilderDelegate((_, i) => docTile(list[i]), childCount: list.length),
              )
            : SliverList.separated(itemCount: list.length, itemBuilder: (_, i) => docTile(list[i]), separatorBuilder: (_, _) => const Divider(height: 1));
        final showAd = visibleDocs.length > libraryAdAfter;
        final fs = folders.value ?? const <LibraryFolder>[];
        final searchField = SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.x4, Space.x2, Space.x4, 0),
            child: TextField(
              key: const ValueKey('lib-search'),
              controller: _search,
              onChanged: _searchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: widget.folderId == null ? l.libSearchHint : l.libSearchFolderHint,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.full))),
                isDense: true,
                suffixIcon: _search.text.isEmpty && _query.isEmpty
                    ? null
                    : IconButton(tooltip: l.libSearchClear, icon: const Icon(Icons.close_rounded), onPressed: _clearSearch),
              ),
            ),
          ),
        );
        if (_query.isNotEmpty) {
          final hits = ref.watch(librarySearchProvider(LibrarySearchQuery(_query, folderId: widget.folderId)));
          final list = hits.value ?? const <SearchHit>[];
          return CustomScrollView(slivers: [
            searchField,
            if (hits.hasValue && list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyHint(icon: Icons.search_off_rounded, title: l.libSearchNone(_query)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(Space.x4),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  itemBuilder: (_, i) => SearchResultTile(
                    key: ValueKey('hit-${list[i].doc.id}'),
                    hit: list[i],
                    path: _repo.absolutePath(list[i].doc),
                    onTap: () => _open(list[i].doc),
                  ),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                ),
              ),
          ]);
        }
        return CustomScrollView(slivers: [
          searchField,
          if (widget.folderId == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.x4, Space.x2, Space.x4, 0),
                child: Wrap(spacing: Space.x2, children: [
                  ChoiceChip(label: Text(l.libFilterAll), selected: !s.filtered, onSelected: (_) => _ctrl.setStarredOnly(false)),
                  ChoiceChip(
                      avatar: const Icon(Icons.star_rounded, size: 18),
                      label: Text(l.libFilterStarred),
                      selected: s.starredOnly,
                      onSelected: (_) => _ctrl.setStarredOnly(true)),
                  // FR-LIB-13: one chip per tag in use.
                  for (final t in tags)
                    ChoiceChip(
                        key: ValueKey('lib-tag-$t'),
                        avatar: const Icon(Icons.sell_outlined, size: 18),
                        label: Text(t),
                        selected: s.tag?.toLowerCase() == t.toLowerCase(),
                        onSelected: (on) => _ctrl.setTag(on ? t : null)),
                ]),
              ),
            ),
          // FR-REM-04: expired + the next 60 days, soonest first (S40 only).
          if (expiring.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: SectionHeader(l.libSectionExpiring))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              sliver: SliverToBoxAdapter(
                child: Card(
                  key: const ValueKey('lib-expiring'),
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    for (final d in expiring)
                      ListTile(
                        key: ValueKey('expiring-${d.id}'),
                        minTileHeight: 56,
                        leading: Icon(isExpired(d, now) ? Icons.event_busy_rounded : Icons.event_rounded,
                            color: isExpired(d, now) ? context.colors.error : context.docu.warning),
                        title: MiddleEllipsisText(d.name),
                        subtitle: Text(expiryLabel(l, d.expiryDate!, now),
                            style: TextStyle(color: isExpired(d, now) ? context.colors.error : null)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _open(d),
                      ),
                  ]),
                ),
              ),
            ),
          ],
          if (fs.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: SectionHeader(l.libSectionFolders))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              // A list, not a fixed-height grid: tiles grow with the text size
              // (a 64 px grid cell overflowed with larger text).
              sliver: SliverList.separated(
                itemCount: fs.length,
                itemBuilder: (_, i) => FolderTile(
                    folder: fs[i], onTap: () => context.push('/library/folder/${fs[i].id}'), onMore: () => _folderMenu(fs[i])),
                separatorBuilder: (_, _) => const SizedBox(height: Space.x2),
              ),
            ),
          ],
          if (visibleDocs.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: SectionHeader(l.libSectionDocuments))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              sliver: docs(showAd ? visibleDocs.take(libraryAdAfter).toList() : visibleDocs),
            ),
            if (showAd) ...[
              // §3.2: one native card, after the 5th item; never selectable.
              const SliverPadding(padding: EdgeInsets.symmetric(horizontal: Space.x4), sliver: SliverToBoxAdapter(child: HistoryAdCard())),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                sliver: docs(visibleDocs.skip(libraryAdAfter).toList()),
              ),
            ],
          ],
          if (empty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyHint(icon: Icons.folder_open_rounded, title: l.libEmptyTitle),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ]);
      });
    }

    return PopScope(
      canPop: !s.selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _ctrl.clearSelection();
      },
      child: AppBottomBanner(
        unit: AdUnit.bannerMain,
        child: Scaffold(
          appBar: appBar,
          body: ContentWidth(padded: false, child: body),
          floatingActionButton: s.selecting
              ? null
              : FloatingActionButton(
                  key: const ValueKey('lib-fab'),
                  tooltip: l.libAdd,
                  onPressed: () => _add(depth),
                  child: const Icon(Icons.add_rounded),
                ),
        ),
      ),
    );
  }
}

/// "My Documents › IDs › Travel": tap a segment to jump up (S41).
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.trail, required this.onRoot, required this.onFolder});
  final List<LibraryFolder> trail;
  final VoidCallback onRoot;
  final ValueChanged<String> onFolder;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final parts = <Widget>[
      _crumb(context, l.libRoot, onRoot),
      for (final (i, f) in trail.indexed) ...[
        const Icon(Icons.chevron_right_rounded, size: 18),
        i == trail.length - 1
            ? Flexible(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis))
            : _crumb(context, f.name, () => onFolder(f.id)),
      ],
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
  }

  Widget _crumb(BuildContext context, String text, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x1),
              child: Text(text, style: context.text.titleMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
          ),
        ),
      );
}

/// ≤ 300 ms loading placeholder (S40 states).
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(Space.x4),
        mainAxisSpacing: Space.x2,
        crossAxisSpacing: Space.x2,
        childAspectRatio: 0.72,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 6; i++)
            DecoratedBox(
              decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(Radii.md)),
            ),
        ],
      );
}
