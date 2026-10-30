import 'dart:math' as math;
import 'dart:ui';

/// What a placement shows (FR-SIG-05, FR-SIG-07).
enum PlacementKind { signature, date, text, initials }

/// One image on one page, in the page's visual space (points, origin top-left)
/// — the same space as `Stamp` (RELEASE_V1_4 §4.4).
class Placement {
  const Placement({
    required this.id,
    required this.pageIndex,
    required this.pngPath,
    required this.rect,
    required this.kind,
    this.rotation = 0,
  });

  final String id;
  final int pageIndex;
  final String pngPath;

  /// Before [rotation], clockwise degrees about the centre.
  final Rect rect;
  final double rotation;
  final PlacementKind kind;

  double get aspect => rect.width / rect.height;

  Placement copyWith({String? id, int? pageIndex, Rect? rect, double? rotation}) => Placement(
        id: id ?? this.id,
        pageIndex: pageIndex ?? this.pageIndex,
        pngPath: pngPath,
        rect: rect ?? this.rect,
        kind: kind,
        rotation: rotation ?? this.rotation,
      );
}

const _margin = 0.05;
const minPlacementWidth = 12.0;

/// S35 "first entry": bottom-right, 30% of the page width, within a 5%
/// margin; a tall image is limited to half the page height.
Rect defaultPlacementRect(Size page, double aspect, {double widthShare = 0.3}) {
  var w = page.width * widthShare, h = w / aspect;
  if (h > page.height * 0.5) {
    h = page.height * 0.5;
    w = h * aspect;
  }
  final m = page.width * _margin;
  return Rect.fromLTWH(page.width - w - m, page.height - h - m, w, h);
}

/// No more than 50% outside the page on either axis (S35 "Bounds").
Rect clampToPage(Rect r, Size page) => Rect.fromLTWH(
      r.left.clamp(-r.width / 2, page.width - r.width / 2).toDouble(),
      r.top.clamp(-r.height / 2, page.height - r.height / 2).toDouble(),
      r.width,
      r.height,
    );

/// Scales about the centre, aspect kept; width between 12 pt and the page width.
Rect resizeAboutCentre(Rect r, double factor, Size page) {
  final w = (r.width * factor).clamp(minPlacementWidth, page.width).toDouble();
  final h = w / (r.width / r.height);
  return Rect.fromCenter(center: r.center, width: w, height: h);
}

/// Normalised to (-180, 180]; within 5° of 0 or ±90 it snaps.
double snapRotation(double degrees) {
  var d = degrees % 360;
  if (d > 180) d -= 360;
  for (final s in const [0.0, 90.0, -90.0]) {
    if ((d - s).abs() <= 5) return s;
  }
  return d;
}

/// The accessible "Rotate 90°" (S35 overflow sheet), clockwise.
double rotate90(double degrees) {
  final d = snapRotation(degrees + 90);
  return d == -180 ? 180 : d;
}

enum PlacementAnchor { topLeft, topRight, centre, bottomLeft, bottomRight }

/// The accessible "Move to" (S35): a corner or the centre, 5% margin.
Rect moveTo(Rect r, Size page, PlacementAnchor a) {
  final m = math.min(page.width, page.height) * _margin;
  final (x, y) = switch (a) {
    PlacementAnchor.topLeft => (m, m),
    PlacementAnchor.topRight => (page.width - r.width - m, m),
    PlacementAnchor.centre => ((page.width - r.width) / 2, (page.height - r.height) / 2),
    PlacementAnchor.bottomLeft => (m, page.height - r.height - m),
    PlacementAnchor.bottomRight => (page.width - r.width - m, page.height - r.height - m),
  };
  return Rect.fromLTWH(x, y, r.width, r.height);
}

/// FR-SIG-06 "same relative position": x and width follow the page width, y
/// the page height; the aspect is kept.
Rect sameRelativePosition(Rect r, Size from, Size to) {
  final w = r.width / from.width * to.width;
  final h = w / (r.width / r.height);
  return clampToPage(Rect.fromLTWH(r.left / from.width * to.width, r.top / from.height * to.height, w, h), to);
}

/// "Add to all pages / Pages…": copies of [p] on [pages] (0-based) except its own.
List<Placement> copyToPages(Placement p, Iterable<int> pages, List<Size> sizes, {required String Function(int page) newId}) => [
      for (final i in pages)
        if (i != p.pageIndex && i >= 0 && i < sizes.length)
          p.copyWith(id: newId(i), pageIndex: i, rect: sameRelativePosition(p.rect, sizes[p.pageIndex], sizes[i])),
    ];

/// Undo/redo of whole placement lists (FR-SIG-08: ≥ 30 steps). A gesture is
/// one step: [begin], any number of [live] updates, then [end].
class PlacementHistory {
  PlacementHistory({this.limit = 50});
  final int limit;
  final _undo = <List<Placement>>[];
  final _redo = <List<Placement>>[];
  List<Placement> _current = const [];
  List<Placement>? _gestureStart;

  List<Placement> get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void apply(List<Placement> next) {
    _push(_current);
    _current = List.unmodifiable(next);
  }

  void begin() => _gestureStart ??= _current;
  void live(List<Placement> next) => _current = List.unmodifiable(next);
  void end() {
    final start = _gestureStart;
    _gestureStart = null;
    if (start != null && !identical(start, _current)) _push(start);
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_current);
    _current = _undo.removeLast();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_current);
    _current = _redo.removeLast();
  }

  void _push(List<Placement> previous) {
    _undo.add(previous);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }
}
