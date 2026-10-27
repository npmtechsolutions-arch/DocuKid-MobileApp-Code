import 'package:docukit/core/pdf/image_to_pdf_layout.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PageLayout lay(int w, int h,
          {PdfPageSize size = PdfPageSize.a4,
          PdfOrientation o = PdfOrientation.auto,
          PdfFit fit = PdfFit.fit,
          PdfMargin m = PdfMargin.small,
          int dpi = 200}) =>
      layoutImagePage(imageWidth: w, imageHeight: h, size: size, orientation: o, fit: fit, margin: m, dpiCap: dpi);

  test('A4 portrait fit with small margins centres the image', () {
    final l = lay(3000, 4000);
    expect(l.pageWidth, closeTo(595.28, 0.01));
    expect(l.pageHeight, closeTo(841.89, 0.01));
    expect(l.boxWidth, closeTo(595.28 - 36, 0.01));
    // Fit: width-bound for 3:4 on A4.
    expect(l.drawWidth, closeTo(l.boxWidth, 0.01));
    expect(l.drawTop, greaterThan(18));
    expect(l.fills, isFalse);
  });

  test('auto orientation turns landscape images into landscape pages', () {
    final l = lay(4000, 3000);
    expect(l.pageWidth, greaterThan(l.pageHeight));
  });

  test('explicit portrait keeps portrait for a landscape image', () {
    final l = lay(4000, 3000, o: PdfOrientation.portrait);
    expect(l.pageWidth, lessThan(l.pageHeight));
  });

  test('fill covers the box and overflows one side', () {
    final l = lay(1000, 1000, fit: PdfFit.fill, m: PdfMargin.none);
    expect(l.drawWidth, greaterThanOrEqualTo(l.boxWidth - 0.01));
    expect(l.drawHeight, greaterThanOrEqualTo(l.boxHeight - 0.01));
    expect(l.fills, isTrue);
  });

  test('same-as-image uses 150 dpi and no margin, clamped to 3–200 in', () {
    final l = lay(1500, 3000, size: PdfPageSize.image, m: PdfMargin.large);
    expect(l.pageWidth, closeTo(720, 0.01));
    expect(l.pageHeight, closeTo(1440, 0.01));
    expect(l.boxLeft, 0);
    final tiny = lay(10, 10, size: PdfPageSize.image);
    expect(tiny.pageWidth, 216);
  });

  test('pixel cap follows the dpi cap', () {
    final l = lay(6000, 8000, dpi: 150, m: PdfMargin.none);
    // 595.28 pt wide × 150/72 ≈ 1241 px; the long edge is the height ≈ 1654 px.
    expect(l.maxLongEdgePx, closeTo(1654, 2));
  });

  test('rotated size', () {
    expect(rotatedSize(10, 20, 1), (20, 10));
    expect(rotatedSize(10, 20, 2), (10, 20));
  });
}
