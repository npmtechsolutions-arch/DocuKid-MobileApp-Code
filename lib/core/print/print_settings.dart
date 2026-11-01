/// S48 print options (RELEASE_PRINT §4.3, §5). The page range is the only
/// option that isn't remembered (FR-PRN-15).
library;

import 'dart:ui';

const _mm = 72 / 25.4;

/// FR-PRN-04. Portrait sizes in points; [sameAsDocument] takes each sheet's
/// first page size.
enum PaperSize {
  a4(Size(595.28, 841.89)),
  letter(Size(612, 792)),
  legal(Size(612, 1008)),
  a5(Size(419.53, 595.28)),
  in4x6(Size(288, 432)),
  in5x7(Size(360, 504)),
  sameAsDocument(null);

  const PaperSize(this.sizePt);
  final Size? sizePt;
}

/// FR-PRN-05.
enum PrintOrientation { auto, portrait, landscape }

/// FR-PRN-07. Fit never crops; Fill crops to the cell.
enum PrintScaling { fit, actual, fill }

/// FR-PRN-08.
enum PrintMargins {
  none(0),
  narrow(6 * _mm),
  normal(12 * _mm);

  const PrintMargins(this.pt);
  final double pt;
}

/// FR-PRN-10. [perSheet] is null for the passport sheet, which has its own grid.
enum ImageLayout {
  fullPage(1),
  twoUp(2),
  fourUp(4),
  passportSheet(null);

  const ImageLayout(this.perSheet);
  final int? perSheet;
}

/// FR-PRN-09.
const perSheetOptions = [1, 2, 4, 6];

enum PageSelectionMode { all, range, odd, even }

/// FR-PRN-06. [range] is the text as typed ("1-3, 5"), for [PageSelectionMode.range].
class PageSelection {
  const PageSelection._(this.mode, [this.range = '']);
  const PageSelection.range(String text) : this._(PageSelectionMode.range, text);

  static const all = PageSelection._(PageSelectionMode.all);
  static const odd = PageSelection._(PageSelectionMode.odd);
  static const even = PageSelection._(PageSelectionMode.even);

  final PageSelectionMode mode;
  final String range;

  @override
  bool operator ==(Object other) => other is PageSelection && other.mode == mode && other.range == range;
  @override
  int get hashCode => Object.hash(mode, range);
  @override
  String toString() => mode == PageSelectionMode.range ? 'range("$range")' : mode.name;
}

class PrintSettings {
  const PrintSettings({
    this.paper = PaperSize.a4,
    this.orientation = PrintOrientation.auto,
    this.pages = PageSelection.all,
    this.perSheet = 1,
    this.imageLayout = ImageLayout.fullPage,
    this.scaling = PrintScaling.fit,
    this.margins = PrintMargins.narrow,
  });

  final PaperSize paper;
  final PrintOrientation orientation;
  final PageSelection pages;

  /// PDF input: one of [perSheetOptions].
  final int perSheet;

  /// Image input.
  final ImageLayout imageLayout;
  final PrintScaling scaling;
  final PrintMargins margins;

  PrintSettings copyWith({
    PaperSize? paper,
    PrintOrientation? orientation,
    PageSelection? pages,
    int? perSheet,
    ImageLayout? imageLayout,
    PrintScaling? scaling,
    PrintMargins? margins,
  }) => PrintSettings(
    paper: paper ?? this.paper,
    orientation: orientation ?? this.orientation,
    pages: pages ?? this.pages,
    perSheet: perSheet ?? this.perSheet,
    imageLayout: imageLayout ?? this.imageLayout,
    scaling: scaling ?? this.scaling,
    margins: margins ?? this.margins,
  );

  @override
  bool operator ==(Object other) =>
      other is PrintSettings &&
      other.paper == paper &&
      other.orientation == orientation &&
      other.pages == pages &&
      other.perSheet == perSheet &&
      other.imageLayout == imageLayout &&
      other.scaling == scaling &&
      other.margins == margins;
  @override
  int get hashCode => Object.hash(paper, orientation, pages, perSheet, imageLayout, scaling, margins);
}
