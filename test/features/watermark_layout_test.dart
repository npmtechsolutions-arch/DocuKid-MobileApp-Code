// T11.8 — watermark layout and page selection (RELEASE_V1_4 §8.1, FR-WMK-04
// …06), written before the implementation: each preset's rects on A4
// portrait and landscape; tile = 12 stamps inside the page; the page modes and
// range validation ("1-999" on 12 pages is invalid).
import 'dart:ui';

import 'package:docukit/core/pdf/stamp_check.dart';
import 'package:docukit/features/pdf_watermark/application/watermark_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const portrait = Size(595, 842), landscape = Size(842, 595);
  const page = Rect.fromLTWH(0, 0, 595, 842);

  group('presets (FR-WMK-04/05)', () {
    test('defaults: text 60% / image 30% of the short side, opacity 25%, rotation by preset', () {
      expect(defaultSizePct(image: false), 60);
      expect(defaultSizePct(image: true), 30);
      expect(defaultOpacityPct, 25);
      expect(defaultRotation(WatermarkPosition.diagonal), -35);
      expect(defaultRotation(WatermarkPosition.tile), -35);
      for (final p in [WatermarkPosition.centre, WatermarkPosition.topLeft, WatermarkPosition.bottomRight]) {
        expect(defaultRotation(p), 0);
      }
    });

    test('centre diagonal on A4 portrait: centred, 60% of 595 wide, −35°', () {
      final l = watermarkLayout(portrait, 4, position: WatermarkPosition.diagonal, sizePct: 60, rotation: -35).single;
      expect(l.rect.center, const Offset(297.5, 421));
      expect(l.rect.width, closeTo(357, 0.01));
      expect(l.rect.height, closeTo(89.25, 0.01));
      expect(l.rotation, -35);
    });

    test('landscape uses its short side (595) too', () {
      final l = watermarkLayout(landscape, 4, position: WatermarkPosition.centre, sizePct: 50, rotation: 0).single;
      expect(l.rect.width, closeTo(297.5, 0.01));
      expect(l.rect.center, const Offset(421, 297.5));
    });

    test('a tall image: its height is the size', () {
      final l = watermarkLayout(portrait, 0.5, position: WatermarkPosition.centre, sizePct: 30, rotation: 0).single;
      expect((l.rect.width, l.rect.height), (89.25, 178.5));
    });

    test('corners sit in a 5% margin (29.75 pt), the rotated box included', () {
      Rect at(WatermarkPosition p, {double rot = 0}) =>
          watermarkLayout(portrait, 2, position: p, sizePct: 30, rotation: rot).single.rect;
      expect(at(WatermarkPosition.topLeft).topLeft, const Offset(29.75, 29.75));
      expect(at(WatermarkPosition.topRight).topRight, const Offset(595 - 29.75, 29.75));
      expect(at(WatermarkPosition.bottomLeft).bottomLeft, const Offset(29.75, 842 - 29.75));
      expect(at(WatermarkPosition.bottomRight).bottomRight, const Offset(595 - 29.75, 842 - 29.75));
      final turned = watermarkLayout(portrait, 2, position: WatermarkPosition.bottomRight, sizePct: 30, rotation: 30).single;
      final box = rotatedBounds(turned.rect, 30);
      expect(box.right, closeTo(595 - 29.75, 0.01));
      expect(box.bottom, closeTo(842 - 29.75, 0.01));
    });

    for (final (name, size, cols, rows) in [('portrait', portrait, 3, 4), ('landscape', landscape, 4, 3)]) {
      test('tile on A4 $name: 12 stamps, $cols×$rows, each rotated box inside the page and its cell', () {
        final l = watermarkLayout(size, 4, position: WatermarkPosition.tile, sizePct: 60, rotation: -35);
        expect(l.length, 12);
        final area = Offset.zero & size;
        final cw = size.width / cols, ch = size.height / rows;
        for (final (i, s) in l.indexed) {
          final box = rotatedBounds(s.rect, s.rotation);
          expect(area.inflate(0.01).contains(box.topLeft) && area.inflate(0.01).contains(box.bottomRight), isTrue);
          final cell = Rect.fromLTWH((i % cols) * cw, (i ~/ cols) * ch, cw, ch);
          expect(cell.inflate(0.01).contains(box.topLeft) && cell.inflate(0.01).contains(box.bottomRight), isTrue,
              reason: 'stamp $i in its cell');
          expect((s.rect.center - cell.center).distance, lessThan(1e-6));
        }
      });
    }

    test('size is clamped to 10–100%', () {
      final small = watermarkLayout(portrait, 1, position: WatermarkPosition.centre, sizePct: 2, rotation: 0).single;
      expect(small.rect.width, closeTo(59.5, 0.01));
      final big = watermarkLayout(portrait, 1, position: WatermarkPosition.centre, sizePct: 300, rotation: 0).single;
      expect(big.rect.width, closeTo(595, 0.01));
      expect(page.width, 595);
    });
  });

  group('pages (FR-WMK-06)', () {
    test('all / odd / even (1-based odd = indexes 0, 2, …)', () {
      expect(selectPages(PageMode.all, '', 5), [0, 1, 2, 3, 4]);
      expect(selectPages(PageMode.odd, '', 5), [0, 2, 4]);
      expect(selectPages(PageMode.even, '', 5), [1, 3]);
    });

    test('range: "1-3, 5" → 0,1,2,4; whitespace and duplicates are fine; sorted', () {
      expect(selectPages(PageMode.range, '1-3, 5', 12), [0, 1, 2, 4]);
      expect(selectPages(PageMode.range, ' 5 , 1-3,3 ', 12), [0, 1, 2, 4]);
    });

    test('invalid ranges → null: "5-3", "0", "1-999" on 12 pages, empty, letters', () {
      for (final bad in ['5-3', '0', '1-999', '', 'abc']) {
        expect(selectPages(PageMode.range, bad, 12), isNull, reason: bad);
      }
    });
  });
}
