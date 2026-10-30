// T11.7 — S35 placement maths and undo/redo (RELEASE_V1_4 §3 S35, FR-SIG-05,
// 06, 08), written before the implementation.
import 'dart:ui';

import 'package:docukit/features/pdf_sign/application/placement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a4 = Size(595, 842);
  Placement pl(String id, {int page = 0, Rect rect = const Rect.fromLTWH(100, 100, 120, 40), double rot = 0}) =>
      Placement(id: id, pageIndex: page, pngPath: '/sig.png', rect: rect, rotation: rot, kind: PlacementKind.signature);

  group('geometry', () {
    test('first placement: bottom-right, 30% of the page width, the image\'s aspect, inside a 5% margin', () {
      final r = defaultPlacementRect(a4, 3);
      expect(r.width, closeTo(178.5, 0.01));
      expect(r.height, closeTo(59.5, 0.01));
      expect(r.right, closeTo(595 - 29.75, 0.01));
      expect(r.bottom, closeTo(842 - 29.75, 0.01));
    });

    test('a tall image is limited by height so it stays on the page', () {
      final r = defaultPlacementRect(const Size(300, 200), 0.2);
      expect(r.height, lessThanOrEqualTo(200 * 0.5 + 0.01));
      expect(r.width / r.height, closeTo(0.2, 0.001));
    });

    test('clamp: at most 50% outside the page on each axis; size kept', () {
      final r = clampToPage(const Rect.fromLTWH(-200, 900, 100, 40), a4);
      expect((r.left, r.top, r.width, r.height), (-50.0, 842 - 20.0, 100.0, 40.0));
      expect(clampToPage(const Rect.fromLTWH(10, 10, 100, 40), a4), const Rect.fromLTWH(10, 10, 100, 40));
    });

    test('resize keeps the aspect, about the centre, between 12 pt and the page width', () {
      const r = Rect.fromLTWH(100, 100, 120, 40);
      final big = resizeAboutCentre(r, 1.2, a4);
      expect(big.center, r.center);
      expect((big.width, big.height), (144.0, 48.0));
      expect(resizeAboutCentre(r, 0.01, a4).width, 12);
      expect(resizeAboutCentre(r, 100, a4).width, 595);
    });

    test('rotation snaps at 0 and ±90 (within 5°); normalised to (-180, 180]', () {
      expect(snapRotation(3), 0);
      expect(snapRotation(-4), 0);
      expect(snapRotation(87), 90);
      expect(snapRotation(-93), -90);
      expect(snapRotation(45), 45);
      expect(snapRotation(362), 0);
      expect(snapRotation(370), 10);
      expect(snapRotation(200), -160);
      expect(rotate90(80), 170);
      expect(rotate90(90), 180);
    });

    test('Move to: corners and centre with a 5% margin', () {
      const r = Rect.fromLTWH(0, 0, 100, 40);
      expect(moveTo(r, a4, PlacementAnchor.topLeft).topLeft, const Offset(29.75, 29.75));
      expect(moveTo(r, a4, PlacementAnchor.bottomRight).bottomRight, const Offset(595 - 29.75, 842 - 29.75));
      expect(moveTo(r, a4, PlacementAnchor.centre).center, const Offset(297.5, 421));
      expect(moveTo(r, a4, PlacementAnchor.topRight).topRight, const Offset(595 - 29.75, 29.75));
      expect(moveTo(r, a4, PlacementAnchor.bottomLeft).bottomLeft, const Offset(29.75, 842 - 29.75));
    });

    test('same relative position on another page size (FR-SIG-06): x/width scale with the width, aspect kept', () {
      const r = Rect.fromLTWH(59.5, 84.2, 119, 39.667);
      final on = sameRelativePosition(r, a4, const Size(842, 595));
      expect(on.left, closeTo(84.2, 0.01));
      expect(on.width, closeTo(168.4, 0.01));
      expect(on.width / on.height, closeTo(r.width / r.height, 0.001));
      expect(on.top, closeTo(59.5, 0.01));
    });
  });

  group('history (FR-SIG-08)', () {
    test('add / update / delete with undo and redo; a new action clears redo', () {
      final h = PlacementHistory();
      h.apply([pl('a')]);
      h.apply([pl('a'), pl('b')]);
      h.apply([pl('b')]);
      expect(h.current.map((p) => p.id), ['b']);
      h.undo();
      expect(h.current.map((p) => p.id), ['a', 'b']);
      h.undo();
      h.redo();
      expect(h.current.map((p) => p.id), ['a', 'b']);
      h.apply([pl('c')]);
      expect(h.canRedo, isFalse);
    });

    test('a drag is ONE step: live updates between begin and end aren\'t recorded separately', () {
      final h = PlacementHistory()..apply([pl('a')]);
      h.begin();
      for (var i = 1; i <= 10; i++) {
        h.live([pl('a', rect: Rect.fromLTWH(100.0 + i, 100, 120, 40))]);
      }
      h.end();
      expect(h.current.single.rect.left, 110);
      h.undo();
      expect(h.current.single.rect.left, 100);
      h.undo();
      expect(h.current, isEmpty);
    });

    test('at least 30 steps of undo', () {
      final h = PlacementHistory();
      for (var i = 0; i < 40; i++) {
        h.apply([pl('a', rect: Rect.fromLTWH(i.toDouble(), 0, 50, 20))]);
      }
      var n = 0;
      while (h.canUndo) {
        h.undo();
        n++;
      }
      expect(n, greaterThanOrEqualTo(30));
    });

    test('copy to pages: duplicates at the same relative position on each page, skipping the source page', () {
      final sizes = [a4, a4, const Size(842, 595), a4];
      final out = copyToPages(pl('a', page: 1), [0, 1, 2, 3], sizes, newId: (i) => 'a$i');
      expect(out.map((p) => p.pageIndex), [0, 2, 3]);
      expect(out.map((p) => p.id), ['a0', 'a2', 'a3']);
      expect(out[1].rect.left, closeTo(100 / 595 * 842, 0.01));
    });
  });
}
