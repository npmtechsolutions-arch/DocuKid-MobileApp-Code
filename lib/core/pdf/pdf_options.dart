/// PDF option enums shared by engines, tools and settings.
library;

enum PdfPageSize {
  a4(595.28, 841.89),
  letter(612, 792),
  legal(612, 1008),
  image(0, 0);

  const PdfPageSize(this.widthPt, this.heightPt);
  final double widthPt, heightPt;
}

enum PdfOrientation { auto, portrait, landscape }

enum PdfFit { fit, fill }

enum PdfMargin {
  none(0),
  small(18),
  large(36);

  const PdfMargin(this.pt);
  final double pt;
}

/// FR-I2P-06: JPEG quality and dpi cap.
enum PdfImageQuality {
  original(95, 300),
  high(85, 200),
  compact(65, 150);

  const PdfImageQuality(this.jpegQuality, this.dpiCap);
  final int jpegQuality;
  final int dpiCap;
}

enum ReduceLevel { basic, balanced, strong }

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
