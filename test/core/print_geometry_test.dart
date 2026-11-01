// RELEASE_PRINT §4.3 / §8 print maths (T13.1), written before the
// implementation: page selection, paper and margins, grid and cells, auto
// orientation, placement in a cell, and the passport sheet counts.
import 'dart:ui';

import 'package:docukit/core/pdf/page_ranges.dart';
import 'package:docukit/core/print/print_geometry.dart';
import 'package:docukit/core/print/print_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const a4 = Size(595.28, 841.89);
const mm = 72 / 25.4;

void main() {
  group('resolvePages (FR-PRN-06)', () {
    List<int> ok(PageSelection s, int n) {
      final r = resolvePages(n, s);
      expect(r.error, isNull, reason: '$s should resolve');
      return r.pages;
    }

    test('all → every page, 0-based', () => expect(ok(PageSelection.all, 4), [0, 1, 2, 3]));
    test('odd → pages 1, 3, 5', () => expect(ok(PageSelection.odd, 5), [0, 2, 4]));
    test('even → pages 2, 4', () => expect(ok(PageSelection.even, 5), [1, 3]));
    test('even on a 1-page PDF → empty, not an error', () => expect(ok(PageSelection.even, 1), isEmpty));
    test('range "2-4, 7" (R70)', () => expect(ok(const PageSelection.range('2-4, 7'), 10), [1, 2, 3, 6]));
    test('range keeps the order written and duplicates', () {
      expect(ok(const PageSelection.range('3, 1-2, 3'), 5), [2, 0, 1, 2]);
    });
    test('range "end" is the last page', () => expect(ok(const PageSelection.range('4-end'), 6), [3, 4, 5]));
    test('range end words are passed through', () {
      final r = resolvePages(6, const PageSelection.range('5-fin'), endWords: {'end', 'fin'});
      expect(r.pages, [4, 5]);
    });
    test('out-of-range page → pageMissing, no pages', () {
      final r = resolvePages(5, const PageSelection.range('2-9'));
      expect(r.error!.kind, PageRangeErrorKind.pageMissing);
      expect(r.error!.page, 9);
      expect(r.pages, isEmpty);
    });
    for (final (input, kind) in [
      ('', PageRangeErrorKind.empty),
      ('   ', PageRangeErrorKind.empty),
      ('0', PageRangeErrorKind.zero),
      ('5-2', PageRangeErrorKind.reversed),
      ('1;2', PageRangeErrorKind.chars),
      ('abc', PageRangeErrorKind.chars),
    ]) {
      test('invalid "$input" → $kind', () => expect(resolvePages(9, PageSelection.range(input)).error!.kind, kind));
    }
    test('0 pages → nothing for every mode', () {
      for (final s in [PageSelection.all, PageSelection.odd, PageSelection.even]) {
        expect(ok(s, 0), isEmpty);
      }
    });
  });

  group('paper and margins (FR-PRN-04, -08)', () {
    test('paper sizes in points, portrait', () {
      for (final (p, w, h) in [
        (PaperSize.a4, 595.28, 841.89),
        (PaperSize.letter, 612.0, 792.0),
        (PaperSize.legal, 612.0, 1008.0),
        (PaperSize.a5, 419.53, 595.28),
        (PaperSize.in4x6, 288.0, 432.0),
        (PaperSize.in5x7, 360.0, 504.0),
      ]) {
        final s = paperSizePt(p);
        expect(s.width, closeTo(w, 0.01), reason: '$p');
        expect(s.height, closeTo(h, 0.01), reason: '$p');
      }
    });
    test('same as document → the page own (visual) size; falls back to A4 without one', () {
      expect(paperSizePt(PaperSize.sameAsDocument, document: const Size(700, 400)), const Size(700, 400));
      expect(paperSizePt(PaperSize.sameAsDocument), PaperSize.a4.sizePt);
    });
    test('margins: none 0, narrow 6 mm, normal 12 mm; gap 4 mm', () {
      expect(PrintMargins.none.pt, 0);
      expect(PrintMargins.narrow.pt, closeTo(6 * mm, 1e-9));
      expect(PrintMargins.normal.pt, closeTo(12 * mm, 1e-9));
      expect(cellGapPt, closeTo(4 * mm, 1e-9));
    });
    test('sheetSize orients the paper', () {
      expect(sheetSize(const Size(612, 792), landscape: true), const Size(792, 612));
      expect(sheetSize(const Size(792, 612), landscape: false), const Size(612, 792));
      expect(sheetSize(const Size(612, 792), landscape: false), const Size(612, 792));
    });
  });

  group('grid and cells (FR-PRN-09)', () {
    test('gridFor: 1 → 1×1; 2 stacked in portrait, side by side in landscape; 4 → 2×2; 6 → 2×3 / 3×2', () {
      for (final (n, land, cols, rows) in [
        (1, false, 1, 1),
        (1, true, 1, 1),
        (2, false, 1, 2),
        (2, true, 2, 1),
        (4, false, 2, 2),
        (4, true, 2, 2),
        (6, false, 2, 3),
        (6, true, 3, 2),
      ]) {
        final g = gridFor(n, landscape: land);
        expect((g.cols, g.rows), (cols, rows), reason: '$n per sheet, landscape $land');
      }
    });
    test('gridFor rejects other counts', () => expect(() => gridFor(3, landscape: false), throwsArgumentError));

    for (final margins in PrintMargins.values) {
      for (final land in [false, true]) {
        for (final n in [1, 2, 4, 6]) {
          test('cells: $n per sheet, ${land ? 'landscape' : 'portrait'}, margins ${margins.name}', () {
            final sheet = sheetSize(a4, landscape: land);
            final g = gridFor(n, landscape: land);
            final cs = cellRects(sheet, g, margins);
            expect(cs, hasLength(n));
            final m = margins.pt;
            // Inside the printable area, all the same size, gaps exactly 4 mm.
            for (final c in cs) {
              expect(c.left, greaterThanOrEqualTo(m - 1e-9));
              expect(c.top, greaterThanOrEqualTo(m - 1e-9));
              expect(c.right, lessThanOrEqualTo(sheet.width - m + 1e-9));
              expect(c.bottom, lessThanOrEqualTo(sheet.height - m + 1e-9));
              expect(c.width, closeTo(cs.first.width, 1e-9));
              expect(c.height, closeTo(cs.first.height, 1e-9));
            }
            // The cells together span the whole area.
            expect(cs.first.left, closeTo(m, 1e-9));
            expect(cs.first.top, closeTo(m, 1e-9));
            expect(cs.last.right, closeTo(sheet.width - m, 1e-9));
            expect(cs.last.bottom, closeTo(sheet.height - m, 1e-9));
            // Reading order: left → right, then top → bottom.
            for (var i = 1; i < n; i++) {
              final (a, b) = (cs[i - 1], cs[i]);
              if (i % g.cols == 0) {
                expect(b.top, closeTo(a.bottom + cellGapPt, 1e-9), reason: 'next row');
                expect(b.left, closeTo(m, 1e-9));
              } else {
                expect(b.left, closeTo(a.right + cellGapPt, 1e-9), reason: 'next column');
                expect(b.top, closeTo(a.top, 1e-9));
              }
            }
          });
        }
      }
    }
    test('cells are top-down (y down, as the preview draws them)', () {
      final cs = cellRects(a4, gridFor(2, landscape: false), PrintMargins.none);
      expect(cs[0].top, 0);
      expect(cs[1].bottom, closeTo(a4.height, 1e-9));
    });
  });

  group('auto orientation (FR-PRN-05)', () {
    bool auto(List<Size> pages, int perSheet, {PrintMargins m = PrintMargins.narrow, Size paper = a4}) =>
        autoLandscape(pages, paper: paper, perSheet: perSheet, margins: m);

    test('1 per sheet follows the page shape', () {
      expect(auto([a4], 1), isFalse);
      expect(auto([const Size(842, 595)], 1), isTrue);
      expect(auto([const Size(500, 500)], 1), isFalse, reason: 'a tie stays portrait');
    });
    test('2 portrait pages per sheet → landscape (side by side)', () => expect(auto([a4, a4], 2), isTrue));
    test('2 landscape pages per sheet → portrait (stacked)', () {
      expect(auto([const Size(842, 595), const Size(842, 595)], 2), isFalse);
    });
    test('4 portrait pages per sheet → portrait', () => expect(auto([a4, a4, a4, a4], 4), isFalse));
    test('6 portrait pages per sheet → landscape', () => expect(auto(List.filled(6, a4), 6), isTrue));
    test('a part-filled last sheet decides from its own pages', () {
      // 1 portrait page left over at 2 per sheet: portrait fits it better.
      expect(auto([a4], 2), isTrue, reason: 'cells, not the page count, set the shape');
    });
    test('an empty group stays portrait', () => expect(auto([], 2), isFalse));
  });

  group('placeInCell', () {
    const cell = Rect.fromLTWH(100, 50, 200, 300);

    test('fit: whole page inside, centred, never crops', () {
      final p = placeInCell(cell, const Size(400, 400), PrintScaling.fit);
      expect(p.scale, closeTo(0.5, 1e-9));
      expect(p.rect, const Rect.fromLTWH(100, 100, 200, 200));
      expect(p.overflows, isFalse);
      expect(p.quarterTurn, 0);
    });
    test('fill: covers the cell, centred, overflows', () {
      final p = placeInCell(cell, const Size(400, 400), PrintScaling.fill);
      expect(p.scale, closeTo(0.75, 1e-9));
      expect(p.rect, const Rect.fromLTWH(50, 50, 300, 300));
      expect(p.overflows, isTrue);
    });
    test('actual: scale 1, centred; overflows only when bigger than the cell', () {
      final small = placeInCell(cell, const Size(100, 100), PrintScaling.actual);
      expect(small.scale, 1);
      expect(small.rect, const Rect.fromLTWH(150, 150, 100, 100));
      expect(small.overflows, isFalse);
      expect(placeInCell(cell, const Size(250, 100), PrintScaling.actual).overflows, isTrue);
    });
    test('allowRotate turns the page a quarter when it fits better', () {
      // A wide page in a tall cell.
      final p = placeInCell(cell, const Size(300, 200), PrintScaling.fit, allowRotate: true);
      expect(p.quarterTurn, 1);
      expect(p.scale, closeTo(1.0, 1e-9)); // 200 × 300 turned fills 200 × 300
      expect(p.rect.width, closeTo(200, 1e-9));
      expect(p.rect.height, closeTo(300, 1e-9));
      expect(placeInCell(cell, const Size(300, 200), PrintScaling.fit).quarterTurn, 0, reason: 'off by default');
      expect(
        placeInCell(cell, const Size(200, 300), PrintScaling.fit, allowRotate: true).quarterTurn,
        0,
        reason: 'already fits best',
      );
    });
    test('pdfMatrix maps the XObject box (0,0)-(w,h) onto the placed rect in PDF space (y up)', () {
      const sheetH = 800.0;
      for (final (size, rotate) in [(const Size(400, 400), false), (const Size(300, 200), true)]) {
        final p = placeInCell(cell, size, PrintScaling.fit, allowRotate: rotate);
        final m = p.pdfMatrix(sheetH);
        Offset apply(double x, double y) => Offset(m.$1 * x + m.$3 * y + m.$5, m.$2 * x + m.$4 * y + m.$6);
        final corners = [apply(0, 0), apply(size.width, 0), apply(0, size.height), apply(size.width, size.height)];
        final xs = corners.map((o) => o.dx), ys = corners.map((o) => o.dy);
        // The same rect, flipped to y-up.
        expect(xs.reduce((a, b) => a < b ? a : b), closeTo(p.rect.left, 1e-9));
        expect(xs.reduce((a, b) => a > b ? a : b), closeTo(p.rect.right, 1e-9));
        expect(ys.reduce((a, b) => a < b ? a : b), closeTo(sheetH - p.rect.bottom, 1e-9));
        expect(ys.reduce((a, b) => a > b ? a : b), closeTo(sheetH - p.rect.top, 1e-9));
        if (rotate) {
          // A quarter turn anticlockwise: the page's top edge ends on the left.
          final topMid = apply(size.width / 2, size.height);
          expect(topMid.dx, closeTo(p.rect.left, 1e-9));
        }
      }
    });
  });

  group('sheetCount', () {
    test('ceil(pages / perSheet)', () {
      expect(sheetCount(0, 2), 0);
      expect(sheetCount(10, 1), 10);
      expect(sheetCount(4, 2), 2); // R70: "2-4, 7" at 2 per sheet
      expect(sheetCount(5, 4), 2);
      expect(sheetCount(300, 4), 75); // R74
    });
  });

  group('passport sheet (FR-PRN-10, §4.3 counts)', () {
    for (final (paper, counts) in [
      (PaperSize.in4x6, [8, 6, 4]),
      (PaperSize.a4, [32, 30, 28]),
      (PaperSize.letter, [28, 28, 25]),
      (PaperSize.in5x7, [9, 9, 8]),
    ]) {
      for (final (i, margins) in PrintMargins.values.indexed) {
        test('${paper.name}, margins ${margins.name} → ${counts[i]} photos', () {
          final s = passportSheet(paperSizePt(paper), margins);
          expect(s.count, counts[i]);
          expect(s.cells, hasLength(counts[i]));
          // Each cell is exactly 35 × 45 mm, inside the printable area, centred.
          final area = Rect.fromLTRB(margins.pt, margins.pt, s.sheet.width - margins.pt, s.sheet.height - margins.pt);
          for (final c in s.cells) {
            expect(c.width, closeTo(35 * mm, 1e-6));
            expect(c.height, closeTo(45 * mm, 1e-6));
            expect(area.inflate(1e-6).contains(c.topLeft) && area.inflate(1e-6).contains(c.bottomRight), isTrue);
          }
          final left = s.cells.map((c) => c.left).reduce((a, b) => a < b ? a : b);
          final right = s.cells.map((c) => c.right).reduce((a, b) => a > b ? a : b);
          final top = s.cells.map((c) => c.top).reduce((a, b) => a < b ? a : b);
          final bottom = s.cells.map((c) => c.bottom).reduce((a, b) => a > b ? a : b);
          expect(left, closeTo(s.sheet.width - right, 1e-6), reason: 'centred across');
          expect(top, closeTo(s.sheet.height - bottom, 1e-6), reason: 'centred down');
          expect(right - left, closeTo(s.cols * 35 * mm + (s.cols - 1) * 2 * mm, 1e-6), reason: '2 mm gaps');
        });
      }
    }
    test('4×6 in, no margins: landscape 4 × 2 (more photos than portrait 2 × 3)', () {
      final s = passportSheet(paperSizePt(PaperSize.in4x6), PrintMargins.none);
      expect(s.landscape, isTrue);
      expect((s.cols, s.rows), (4, 2));
      expect(s.sheet, const Size(432, 288));
    });
    test('a tie keeps portrait (4×6 in, narrow: 2 × 3 = 6 vs 3 × 1)', () {
      final s = passportSheet(paperSizePt(PaperSize.in4x6), PrintMargins.narrow);
      expect(s.landscape, isFalse);
      expect((s.cols, s.rows), (2, 3));
    });
    test('the paper passed in landscape is treated the same', () {
      expect(passportSheet(const Size(432, 288), PrintMargins.none).count, 8);
    });
    test('paper too small for one photo → 0 photos', () {
      expect(passportSheet(const Size(50, 50), PrintMargins.none).count, 0);
    });
  });
}
