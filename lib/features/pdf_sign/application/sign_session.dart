import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'placement.dart';
import 'signature_models.dart';

/// The signature S33 will place: a new one (maybe unsaved) or a saved one.
class SignatureChoice {
  const SignatureChoice({required this.pngPath, required this.aspect, this.savedId});
  final String pngPath;

  /// width / height of the PNG.
  final double aspect;
  final String? savedId;
}

/// (width, height) from a PNG's IHDR, without decoding it; null if it isn't one.
(int, int)? pngSize(String path) {
  try {
    final raf = File(path).openSync();
    try {
      final b = raf.readSync(24);
      if (b.length < 24 || b[1] != 0x50 || b[2] != 0x4E || b[3] != 0x47) return null;
      final d = ByteData.sublistView(b);
      return (d.getUint32(16), d.getUint32(20));
    } finally {
      raf.closeSync();
    }
  } on FileSystemException {
    return null;
  }
}

class SignSession {
  const SignSession({this.created, this.chosen});

  /// Made in S34 during this visit (shown as a tile even if not saved).
  final CreatedSignature? created;
  final SignatureChoice? chosen;
}

/// S33's state; alive while S33 is (S34/S35 sit on top of it).
class SignSessionController extends Notifier<SignSession> {
  @override
  SignSession build() => const SignSession();

  void created(CreatedSignature s) => state = SignSession(
        created: s,
        chosen: SignatureChoice(pngPath: s.pngPath, aspect: s.aspect, savedId: s.savedId),
      );

  void choose(SignatureChoice c) => state = SignSession(created: state.created, chosen: c);

  /// A saved signature was deleted (S33 long-press / Settings).
  void forgetSaved(String id) => state = SignSession(
        created: state.created?.savedId == id ? null : state.created,
        chosen: state.chosen?.savedId == id ? null : state.chosen,
      );
}

final signSessionProvider = NotifierProvider.autoDispose<SignSessionController, SignSession>(SignSessionController.new);

/// S35's view of the placements.
class EditorView {
  const EditorView({
    this.placements = const [],
    this.selectedId,
    this.page = 0,
    this.canUndo = false,
    this.canRedo = false,
  });
  final List<Placement> placements;
  final String? selectedId;
  final int page;
  final bool canUndo, canRedo;

  Placement? get selected => placements.where((p) => p.id == selectedId).firstOrNull;
  List<Placement> onPage(int i) => placements.where((p) => p.pageIndex == i).toList();
  Set<int> get stampedPages => {for (final p in placements) p.pageIndex};
}

/// S35 placement editor (FR-SIG-05/06/08). [sizes] are the pages' visual
/// sizes in points.
class PlacementEditorController extends Notifier<EditorView> {
  final _h = PlacementHistory();
  List<Size> _sizes = const [];

  @override
  EditorView build() => const EditorView();

  List<Size> get sizes => _sizes;
  Size get pageSize => _sizes.isEmpty ? const Size(595, 842) : _sizes[state.page];

  /// First entry: one placement of [c] on the first page (S35).
  void start(List<Size> sizes, SignatureChoice c) {
    _sizes = sizes;
    if (_h.current.isEmpty && !_h.canUndo) add(c.pngPath, c.aspect, PlacementKind.signature);
  }

  void _emit({String? selected, bool keepSelection = true, int? page}) {
    final placements = _h.current;
    var sel = keepSelection ? (selected ?? state.selectedId) : selected;
    if (sel != null && !placements.any((p) => p.id == sel)) sel = null;
    state = EditorView(
      placements: placements,
      selectedId: sel,
      page: page ?? state.page,
      canUndo: _h.canUndo,
      canRedo: _h.canRedo,
    );
  }

  void add(String pngPath, double aspect, PlacementKind kind) {
    final p = Placement(
      id: const Uuid().v4(),
      pageIndex: state.page,
      pngPath: pngPath,
      rect: kind == PlacementKind.signature
          ? defaultPlacementRect(pageSize, aspect)
          : defaultPlacementRect(pageSize, aspect, widthShare: 0.18),
      kind: kind,
    );
    _h.apply([..._h.current, p]);
    _emit(selected: p.id);
  }

  void select(String? id) => _emit(selected: id, keepSelection: false);
  void setPage(int i) => _emit(page: i, selected: null, keepSelection: false);

  List<Placement> _replace(String id, Placement Function(Placement) f) =>
      [for (final p in _h.current) p.id == id ? f(p) : p];

  // A drag, resize or rotate is one undo step.
  void begin(String id) {
    _h.begin();
    _emit(selected: id);
  }

  void liveMove(String id, Offset delta) {
    _h.live(_replace(id, (p) => p.copyWith(rect: clampToPage(p.rect.shift(delta), _sizes[p.pageIndex]))));
    _emit();
  }

  void liveSet(String id, {Rect? rect, double? rotation}) {
    _h.live(_replace(id, (p) => p.copyWith(rect: rect == null ? null : clampToPage(rect, _sizes[p.pageIndex]), rotation: rotation)));
    _emit();
  }

  void end() {
    _h.end();
    _emit();
  }

  // The accessible alternatives (S35 overflow sheet): one step each.
  void _commit(String id, Placement Function(Placement) f) {
    _h.apply(_replace(id, f));
    _emit();
  }

  void moveToAnchor(String id, PlacementAnchor a) => _commit(id, (p) => p.copyWith(rect: moveTo(p.rect, _sizes[p.pageIndex], a)));
  void scale(String id, double factor) =>
      _commit(id, (p) => p.copyWith(rect: clampToPage(resizeAboutCentre(p.rect, factor, _sizes[p.pageIndex]), _sizes[p.pageIndex])));
  void rotateQuarter(String id) => _commit(id, (p) => p.copyWith(rotation: rotate90(p.rotation)));

  void delete(String id) {
    _h.apply(_h.current.where((p) => p.id != id).toList());
    _emit();
  }

  /// "Pages…" (FR-SIG-06): copies of [id] on [pages] (0-based).
  void copyTo(String id, Iterable<int> pages) {
    final p = _h.current.firstWhere((x) => x.id == id);
    final copies = copyToPages(p, pages, _sizes, newId: (_) => const Uuid().v4());
    if (copies.isEmpty) return;
    _h.apply([..._h.current, ...copies]);
    _emit();
  }

  void undo() {
    _h.undo();
    _emit();
  }

  void redo() {
    _h.redo();
    _emit();
  }
}

final placementEditorProvider =
    NotifierProvider.autoDispose<PlacementEditorController, EditorView>(PlacementEditorController.new);
