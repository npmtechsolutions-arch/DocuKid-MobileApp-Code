// RELEASE_PRINT §4.3 sheet planning for PDF input (T13.2), written before the
// implementation: which pages go on which sheet, each sheet's paper and
// orientation, and where each page lands.
import 'dart:ui';

import 'package:docukit/core/print/print_geometry.dart';
import 'package:docukit/core/print/print_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const a4 = Size(595.28, 841.89);
const a4Land = Size(841.89, 595.28);

void main() {
  List<List<int>> sources(List<SheetPlan> plan) => [for (final s in plan) [for (final p in s.pages) p.source]];

  test('R69: 10 A4 pages, A4, Auto, Fit, 1 per sheet → 10 portrait A4 sheets, each page centred and whole', () {
    final plan = planPdfSheets(List.filled(10, a4), List.generate(10, (i) => i), const PrintSettings());
    expect(plan, hasLength(10));
    for (final (i, s) in plan.indexed) {
      expect(s.size, sheetSize(PaperSize.a4.sizePt!, landscape: false));
      expect(s.pages.single.source, i);
      final pl = s.pages.single.placement;
      expect(pl.overflows, isFalse);
      expect(pl.quarterTurn, 0);
      expect(pl.rect.center.dx, closeTo(s.size.width / 2, 1e-9));
      expect(pl.rect.center.dy, closeTo(s.size.height / 2, 1e-9));
    }
  });

  test('R70: range "2-4, 7", 2 per sheet, Landscape → 2 sheets: [2, 3] and [4, 7], side by side', () {
    final r = resolvePages(10, const PageSelection.range('2-4, 7'));
    final plan = planPdfSheets(
      List.filled(10, a4),
      r.pages,
      const PrintSettings(perSheet: 2, orientation: PrintOrientation.landscape),
    );
    expect(sources(plan), [
      [1, 2],
      [3, 6],
    ]);
    for (final s in plan) {
      expect(s.size.width, greaterThan(s.size.height), reason: 'landscape');
      expect(s.pages[0].cell.left, lessThan(s.pages[1].cell.left), reason: 'left → right');
      for (final p in s.pages) {
        expect(p.placement.quarterTurn, 0, reason: 'portrait pages fit the portrait cells as they are');
      }
    }
  });

  test('a part-filled last sheet: 5 pages at 4 per sheet → [0..3], [4]', () {
    final plan = planPdfSheets(List.filled(5, a4), List.generate(5, (i) => i), const PrintSettings(perSheet: 4));
    expect(sources(plan), [
      [0, 1, 2, 3],
      [4],
    ]);
    expect(plan[1].pages.single.cell.topLeft, plan[0].pages.first.cell.topLeft, reason: 'the first cell, top-left');
  });

  test('Auto is decided per sheet: a landscape page gets a landscape sheet among portrait ones', () {
    final plan = planPdfSheets([a4, a4Land, a4], [0, 1, 2], const PrintSettings());
    expect([for (final s in plan) s.size.width > s.size.height], [false, true, false]);
  });

  test('fixed Portrait with 1 per sheet turns a landscape page a quarter to print it bigger', () {
    final plan = planPdfSheets([a4Land], [0], const PrintSettings(orientation: PrintOrientation.portrait));
    expect(plan.single.size.height, greaterThan(plan.single.size.width));
    expect(plan.single.pages.single.placement.quarterTurn, 1);
  });

  test('Auto with 1 per sheet never turns the page (the sheet turns instead)', () {
    final plan = planPdfSheets([a4Land], [0], const PrintSettings());
    expect(plan.single.pages.single.placement.quarterTurn, 0);
  });

  test('Same as document: each sheet takes its first page size (in that page orientation with Auto)', () {
    const odd = Size(400, 300);
    final plan = planPdfSheets([odd, a4], [0, 1], const PrintSettings(paper: PaperSize.sameAsDocument));
    expect(plan[0].size, odd);
    expect(plan[1].size, a4);
    expect(plan[0].pages.single.placement.scale, closeTo(1 - 2 * PrintMargins.narrow.pt / 300, 1e-9),
        reason: 'fit inside the narrow margins');
  });

  test('Same as document with no margins and Fit → scale 1, the page exactly covers the sheet', () {
    final plan = planPdfSheets(
      [a4],
      [0],
      const PrintSettings(paper: PaperSize.sameAsDocument, margins: PrintMargins.none),
    );
    expect(plan.single.pages.single.placement.scale, closeTo(1, 1e-9));
    expect(plan.single.pages.single.placement.rect, Offset.zero & a4);
  });

  test('Fill and an oversized Actual size are clipped to their cell; Fit never is', () {
    final pages = List.filled(2, a4);
    expect(
      planPdfSheets(pages, [0, 1], const PrintSettings(perSheet: 2)).expand((s) => s.pages).any((p) => p.clip),
      isFalse,
    );
    final fill = planPdfSheets(pages, [0, 1], const PrintSettings(perSheet: 2, scaling: PrintScaling.fill));
    expect(fill.expand((s) => s.pages).every((p) => p.clip), isTrue);
    final actual = planPdfSheets(pages, [0, 1], const PrintSettings(perSheet: 2, scaling: PrintScaling.actual));
    expect(actual.expand((s) => s.pages).every((p) => p.clip), isTrue, reason: 'A4 at 100 % in half an A4 sheet');
    final small = planPdfSheets([const Size(200, 100)], [0], const PrintSettings(scaling: PrintScaling.actual));
    expect(small.single.pages.single.clip, isFalse);
  });

  test('repeated pages are placed again; nothing selected → no sheets', () {
    expect(sources(planPdfSheets(List.filled(3, a4), [2, 0, 2], const PrintSettings())), [
      [2],
      [0],
      [2],
    ]);
    expect(planPdfSheets(List.filled(3, a4), const [], const PrintSettings()), isEmpty);
  });

  test('imageLayout is ignored for PDF input (perSheet drives the grid)', () {
    final plan = planPdfSheets(
      List.filled(4, a4),
      [0, 1, 2, 3],
      const PrintSettings(perSheet: 2, imageLayout: ImageLayout.fourUp),
    );
    expect(plan, hasLength(2));
  });

  group('images (T13.3, FR-PRN-10)', () {
    const photo = Size(288, 216); // 4:3 landscape at 150 dpi = 600 × 450 px
    test('imageSizePt: pixels at 150 dpi, like Images to PDF', () {
      expect(imageSizePt(600, 450), photo);
    });
    test('Full page: one image per sheet, Auto per image', () {
      final plan = planImageSheets([photo, const Size(216, 288)], const PrintSettings());
      expect(sources(plan), [
        [0],
        [1],
      ]);
      expect([for (final s in plan) s.size.width > s.size.height], [true, false]);
    });
    test('2 and 4 per sheet use the PDF grid; perSheet is ignored for images', () {
      final five = List.filled(5, photo);
      expect(planImageSheets(five, const PrintSettings(imageLayout: ImageLayout.twoUp, perSheet: 6)), hasLength(3));
      expect(planImageSheets(five, const PrintSettings(imageLayout: ImageLayout.fourUp)), hasLength(2));
    });
    test('passport 4×6 in, no margins: one landscape sheet, 8 cells of the first image, covered and clipped', () {
      const portrait = Size(198.24, 254.88); // 413 × 531 px
      final plan = planImageSheets(
        [portrait, photo],
        const PrintSettings(imageLayout: ImageLayout.passportSheet, paper: PaperSize.in4x6, margins: PrintMargins.none),
      );
      expect(plan, hasLength(1));
      expect(plan.single.size, const Size(432, 288));
      expect(plan.single.pages, hasLength(8));
      for (final pg in plan.single.pages) {
        expect(pg.source, 0, reason: 'the first image only');
        expect(pg.cell.width, closeTo(passportPhotoPt.width, 1e-9));
        expect(pg.placement.quarterTurn, 0, reason: 'a face is never turned');
        // Cover: fills the cell in both directions.
        expect(pg.placement.rect.width, greaterThanOrEqualTo(pg.cell.width - 1e-9));
        expect(pg.placement.rect.height, greaterThanOrEqualTo(pg.cell.height - 1e-9));
      }
      expect(passportCount(plan), 8);
    });
    test('passport on paper too small for one photo (Same as document, a tiny image) → no sheets', () {
      expect(
        planImageSheets(
          [imageSizePt(100, 100)],
          const PrintSettings(imageLayout: ImageLayout.passportSheet, paper: PaperSize.sameAsDocument),
        ),
        isEmpty,
      );
    });
    test('no images → no sheets', () => expect(planImageSheets(const [], const PrintSettings()), isEmpty));
  });
}
