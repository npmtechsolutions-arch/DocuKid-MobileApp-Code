/// Organizer edit model (FEATURE_SPECS §4.3). List order = output order.
library;

class PageEdit {
  const PageEdit(this.sourceIndex, [this.rotationQuarterTurns = 0]);

  final int sourceIndex;

  /// Extra clockwise quarter turns, always 0–3.
  final int rotationQuarterTurns;

  PageEdit rotated(int delta) => PageEdit(sourceIndex, (rotationQuarterTurns + delta) % 4);

  Map<String, int> toJson() => {'s': sourceIndex, 'r': rotationQuarterTurns};
  static PageEdit fromJson(Map<String, dynamic> j) => PageEdit(j['s'] as int, j['r'] as int);

  @override
  bool operator ==(Object other) =>
      other is PageEdit && other.sourceIndex == sourceIndex && other.rotationQuarterTurns == rotationQuarterTurns;

  @override
  int get hashCode => Object.hash(sourceIndex, rotationQuarterTurns);

  @override
  String toString() => 'PageEdit($sourceIndex, r$rotationQuarterTurns)';
}

class EmptyDocumentException implements Exception {
  const EmptyDocumentException();
}

List<PageEdit> identityEdits(int pageCount) => [for (var i = 0; i < pageCount; i++) PageEdit(i)];

bool isIdentity(List<PageEdit> list, int pageCount) {
  if (list.length != pageCount) return false;
  for (var i = 0; i < list.length; i++) {
    if (list[i].sourceIndex != i || list[i].rotationQuarterTurns != 0) return false;
  }
  return true;
}

/// Moves the pages at [fromPositions] (any order) so that the block starts at
/// [toIndex] of the list *after* removing them. Their relative order is kept.
List<PageEdit> movePages(List<PageEdit> list, Iterable<int> fromPositions, int toIndex) {
  final from = fromPositions.toSet().where((p) => p >= 0 && p < list.length).toList()..sort();
  if (from.isEmpty) return List.of(list);
  final moving = [for (final p in from) list[p]];
  final rest = [
    for (var i = 0; i < list.length; i++)
      if (!from.contains(i)) list[i],
  ];
  final at = toIndex.clamp(0, rest.length);
  return [...rest.sublist(0, at), ...moving, ...rest.sublist(at)];
}

/// Single drag-and-drop move (ReorderableList semantics are resolved by the caller).
List<PageEdit> moveOne(List<PageEdit> list, int from, int to) {
  final out = List.of(list);
  final item = out.removeAt(from);
  out.insert(to.clamp(0, out.length), item);
  return out;
}

List<PageEdit> rotatePages(List<PageEdit> list, Iterable<int> positions, int delta) {
  final set = positions.toSet();
  return [
    // Dart's % is non-negative for a positive divisor, so -1 % 4 == 3.
    for (var i = 0; i < list.length; i++) set.contains(i) ? list[i].rotated(delta % 4) : list[i],
  ];
}

/// Throws [EmptyDocumentException] if nothing would remain.
List<PageEdit> deletePages(List<PageEdit> list, Iterable<int> positions) {
  final set = positions.toSet();
  final out = [
    for (var i = 0; i < list.length; i++)
      if (!set.contains(i)) list[i],
  ];
  if (out.isEmpty) throw const EmptyDocumentException();
  return out;
}

/// Undo/redo history of snapshots, capped at [cap] steps (FR-ORG-06).
class EditHistory {
  EditHistory(List<PageEdit> initial, {this.cap = 50}) : _current = List.unmodifiable(initial);

  final int cap;
  List<PageEdit> _current;
  final List<List<PageEdit>> _undo = [];
  final List<List<PageEdit>> _redo = [];

  List<PageEdit> get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;

  void push(List<PageEdit> next) {
    _undo.add(_current);
    if (_undo.length > cap) _undo.removeAt(0);
    _redo.clear();
    _current = List.unmodifiable(next);
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _redo.add(_current);
    _current = _undo.removeLast();
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    _undo.add(_current);
    _current = _redo.removeLast();
    return true;
  }
}
