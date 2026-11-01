/// Print layout maths (RELEASE_PRINT §4.3), pure Dart. Rects are in points,
/// top-down (y down) like the preview; [Placement.pdfMatrix] converts to PDF
/// space for the composer. Page sizes are visual: /Rotate and the crop box
/// applied, which is how PDFium's page XObjects come (ADR-070).
library;

import 'dart:math' as math;
import 'dart:ui';

import '../pdf/page_ranges.dart';
import 'print_settings.dart';

const _mm = 72 / 25.4;

/// FR-PRN-09: the gap between cells.
const cellGapPt = 4 * _mm;

const passportPhotoPt = Size(35 * _mm, 45 * _mm);
const passportGapPt = 2 * _mm;

/// 0-based pages in print order, or the range error (then [pages] is empty).
typedef ResolvedPages = ({List<int> pages, PageRangeError? error});

/// FR-PRN-06. Ranges keep the order written and any repeats (like Split);
/// odd / even are 1-based page numbers. An empty result isn't an error: S48
/// says "No pages to print with these settings".
ResolvedPages resolvePages(int pageCount, PageSelection s, {Set<String> endWords = const {'end'}}) {
  switch (s.mode) {
    case PageSelectionMode.all:
      return (pages: [for (var i = 0; i < pageCount; i++) i], error: null);
    case PageSelectionMode.odd:
      return (pages: [for (var i = 0; i < pageCount; i += 2) i], error: null);
    case PageSelectionMode.even:
      return (pages: [for (var i = 1; i < pageCount; i += 2) i], error: null);
    case PageSelectionMode.range:
      final r = parsePageRanges(s.range, pageCount, endWords: endWords);
      if (r.error != null) return (pages: const [], error: r.error);
      return (
        pages: [
          for (final part in r.parts!)
            for (final p in part.pages) p - 1,
        ],
        error: null,
      );
  }
}

int sheetCount(int pages, int perSheet) => (pages + perSheet - 1) ~/ perSheet;

/// The paper in points, portrait as listed; [PaperSize.sameAsDocument] is
/// [document] (the sheet's first page), or A4 when there isn't one.
Size paperSizePt(PaperSize paper, {Size? document}) => paper.sizePt ?? document ?? PaperSize.a4.sizePt!;

/// [paper] turned so its long side runs across ([landscape]) or down.
Size sheetSize(Size paper, {required bool landscape}) {
  final long = math.max(paper.width, paper.height), short = math.min(paper.width, paper.height);
  return landscape ? Size(long, short) : Size(short, long);
}

typedef Grid = ({int cols, int rows});

/// §4.3: the grid's long side follows the sheet's — 2 per sheet are stacked
/// on portrait paper and side by side on landscape; 6 is 2 × 3 or 3 × 2.
Grid gridFor(int perSheet, {required bool landscape}) {
  final (short, long) = switch (perSheet) {
    1 => (1, 1),
    2 => (1, 2),
    4 => (2, 2),
    6 => (2, 3),
    _ => throw ArgumentError.value(perSheet, 'perSheet'),
  };
  return landscape ? (cols: long, rows: short) : (cols: short, rows: long);
}

/// The cells of a sheet in reading order (left → right, top → bottom),
/// filling the area inside [margins] with [cellGapPt] between them.
List<Rect> cellRects(Size sheet, Grid g, PrintMargins margins) {
  final m = margins.pt;
  final cw = (sheet.width - 2 * m - (g.cols - 1) * cellGapPt) / g.cols;
  final ch = (sheet.height - 2 * m - (g.rows - 1) * cellGapPt) / g.rows;
  return [
    for (var r = 0; r < g.rows; r++)
      for (var c = 0; c < g.cols; c++) Rect.fromLTWH(m + c * (cw + cellGapPt), m + r * (ch + cellGapPt), cw, ch),
  ];
}

double _fit(Size content, Rect cell) => math.min(cell.width / content.width, cell.height / content.height);

/// FR-PRN-05 Auto: the orientation that prints this sheet's [pages] bigger
/// (the larger total area at Fit). A tie stays portrait.
bool autoLandscape(List<Size> pages, {required Size paper, required int perSheet, required PrintMargins margins}) {
  if (pages.isEmpty) return false;
  double area(bool landscape) {
    final cells = cellRects(sheetSize(paper, landscape: landscape), gridFor(perSheet, landscape: landscape), margins);
    var sum = 0.0;
    for (final (i, p) in pages.indexed) {
      final s = _fit(p, cells[i % cells.length]);
      sum += s * s * p.width * p.height;
    }
    return sum;
  }

  return area(true) > area(false) * (1 + 1e-9);
}

/// Where one page goes in its cell.
class Placement {
  const Placement({required this.rect, required this.scale, required this.quarterTurn, required this.overflows});

  /// The page as placed (top-down); may extend past the cell for Fill / Actual size.
  final Rect rect;
  final double scale;

  /// 1 = turned a quarter anticlockwise (its top edge on the left).
  final int quarterTurn;

  /// Bigger than the cell: the composer clips, and Actual size warns (FR-PRN-07).
  final bool overflows;

  /// [a b c d e f] taking the page XObject's box (0,0)–(w,h) onto [rect] on a
  /// sheet [sheetHeight] tall, in PDF space (y up).
  (double, double, double, double, double, double) pdfMatrix(double sheetHeight) {
    final f = sheetHeight - rect.bottom;
    return quarterTurn == 0 ? (scale, 0, 0, scale, rect.left, f) : (0, scale, -scale, 0, rect.right, f);
  }
}

/// Scales a page of visual [size] into [cell], centred. With [allowRotate]
/// it's turned a quarter when that prints it bigger (§4.3: not used for one
/// page per sheet with Auto orientation, where the sheet turns instead).
Placement placeInCell(Rect cell, Size size, PrintScaling scaling, {bool allowRotate = false}) {
  final turned = Size(size.height, size.width);
  final rotate = allowRotate && _fit(turned, cell) > _fit(size, cell) * (1 + 1e-9);
  final v = rotate ? turned : size;
  final s = switch (scaling) {
    PrintScaling.fit => _fit(v, cell),
    PrintScaling.fill => math.max(cell.width / v.width, cell.height / v.height),
    PrintScaling.actual => 1.0,
  };
  final w = v.width * s, h = v.height * s;
  return Placement(
    rect: Rect.fromLTWH(cell.left + (cell.width - w) / 2, cell.top + (cell.height - h) / 2, w, h),
    scale: s,
    quarterTurn: rotate ? 1 : 0,
    overflows: w > cell.width + 1e-6 || h > cell.height + 1e-6,
  );
}

/// FR-PRN-10 passport sheet: 35 × 45 mm photos, 2 mm apart, centred, in the
/// orientation that fits more (a tie stays portrait).
class PassportSheet {
  const PassportSheet({
    required this.sheet,
    required this.landscape,
    required this.cols,
    required this.rows,
    required this.cells,
  });
  final Size sheet;
  final bool landscape;
  final int cols, rows;

  /// Top-down, reading order.
  final List<Rect> cells;
  int get count => cols * rows;
}

PassportSheet passportSheet(Size paper, PrintMargins margins) {
  (int, int) grid(Size sheet) {
    final aw = sheet.width - 2 * margins.pt, ah = sheet.height - 2 * margins.pt;
    // Small slack so mm-exact sizes (e.g. A4's 210 mm in points) don't round down.
    int n(double a, double cell) => a < cell ? 0 : ((a + passportGapPt) / (cell + passportGapPt) + 1e-6).floor();
    return (n(aw, passportPhotoPt.width), n(ah, passportPhotoPt.height));
  }

  final portrait = sheetSize(paper, landscape: false), land = sheetSize(paper, landscape: true);
  final (pc, pr) = grid(portrait);
  final (lc, lr) = grid(land);
  final landscape = lc * lr > pc * pr;
  final sheet = landscape ? land : portrait;
  final (cols, rows) = landscape ? (lc, lr) : (pc, pr);
  final gw = cols * passportPhotoPt.width + math.max(0, cols - 1) * passportGapPt;
  final gh = rows * passportPhotoPt.height + math.max(0, rows - 1) * passportGapPt;
  final x0 = (sheet.width - gw) / 2, y0 = (sheet.height - gh) / 2;
  return PassportSheet(
    sheet: sheet,
    landscape: landscape,
    cols: cols,
    rows: rows,
    cells: [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          Rect.fromLTWH(
            x0 + c * (passportPhotoPt.width + passportGapPt),
            y0 + r * (passportPhotoPt.height + passportGapPt),
            passportPhotoPt.width,
            passportPhotoPt.height,
          ),
    ],
  );
}
