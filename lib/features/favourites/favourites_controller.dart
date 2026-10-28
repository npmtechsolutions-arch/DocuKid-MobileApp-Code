import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../search/tool_catalog.dart';

enum PinResult { pinned, unpinned, limit }

/// Favourites (RELEASE_V1_1 §4.9): pinned tools in row order, stored in
/// `favourite_tools`. Home reads catalogue ∩ favourites in this order.
class FavouritesController extends Notifier<List<ToolId>> {
  /// FR-FAV-02.
  static const max = 6;

  @override
  List<ToolId> build() => ref.watch(settingsProvider.select((s) => s.favouriteTools));

  bool isPinned(ToolId id) => state.contains(id);

  /// [PinResult.limit] when 6 are already pinned ("Remove one first").
  PinResult pin(ToolId id) {
    if (state.contains(id)) return PinResult.pinned;
    if (state.length >= max) return PinResult.limit;
    _save([...state, id]);
    return PinResult.pinned;
  }

  void unpin(ToolId id) => _save([...state]..remove(id));

  PinResult toggle(ToolId id) {
    if (!state.contains(id)) return pin(id);
    unpin(id);
    return PinResult.unpinned;
  }

  /// Moves the item at [from] to [to] (indices in the list after removal).
  void reorder(int from, int to) {
    if (from < 0 || from >= state.length) return;
    final list = [...state];
    final item = list.removeAt(from);
    list.insert(to.clamp(0, list.length), item);
    _save(list);
  }

  /// Accessible Move up (-1) / Move down (+1).
  void move(ToolId id, int delta) {
    final i = state.indexOf(id);
    final to = i + delta;
    if (i < 0 || to < 0 || to >= state.length) return;
    reorder(i, to);
  }

  void _save(List<ToolId> list) {
    state = list;
    unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(favouriteTools: list)));
  }
}

final favouritesProvider = NotifierProvider<FavouritesController, List<ToolId>>(FavouritesController.new);
