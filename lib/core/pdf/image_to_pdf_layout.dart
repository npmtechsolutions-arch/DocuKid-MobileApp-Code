import 'dart:math' as math;

import 'pdf_options.dart';

/// Page layout for one image (FEATURE_SPECS §3.6). All values in points,
/// measured from the page's top-left corner. Pure; unit-tested.
class PageLayout {
  const PageLayout({
    required this.pageWidth,
    required this.pageHeight,
    required this.boxLeft,
    required this.boxTop,
    required this.boxWidth,
    required this.boxHeight,
    required this.drawLeft,
    required this.drawTop,
    required this.drawWidth,
    required this.drawHeight,
    required this.maxLongEdgePx,
  });

  final double pageWidth, pageHeight;

  /// Content box (page minus margins).
  final double boxLeft, boxTop, boxWidth, boxHeight;

  /// Where the whole image is drawn (may overflow the box for Fill).
  final double drawLeft, drawTop, drawWidth, drawHeight;

  /// Longest edge the embedded JPEG needs at the dpi cap.
  final int maxLongEdgePx;

  bool get fills => drawWidth > boxWidth + 0.01 || drawHeight > boxHeight + 0.01;
}

const _minSameAsImagePt = 216.0; // 3 in
const _maxSameAsImagePt = 14400.0; // 200 in

PageLayout layoutImagePage({
  required int imageWidth,
  required int imageHeight,
  required PdfPageSize size,
  required PdfOrientation orientation,
  required PdfFit fit,
  required PdfMargin margin,
  required int dpiCap,
  // "Same as image" page size: 150 dpi (Images to PDF); Fit to scan: 200 (FR-SCN-14).
  int imageDpi = 150,
}) {
  final w = imageWidth.toDouble(), h = imageHeight.toDouble();
  double pw, ph, m;
  if (size == PdfPageSize.image) {
    pw = (w * 72 / imageDpi).clamp(_minSameAsImagePt, _maxSameAsImagePt);
    ph = (h * 72 / imageDpi).clamp(_minSameAsImagePt, _maxSameAsImagePt);
    m = 0;
  } else {
    pw = size.widthPt;
    ph = size.heightPt;
    final landscape = switch (orientation) {
      PdfOrientation.auto => w > h,
      PdfOrientation.portrait => false,
      PdfOrientation.landscape => true,
    };
    if (landscape) {
      final t = pw;
      pw = ph;
      ph = t;
    }
    m = margin.pt;
  }
  final bw = pw - 2 * m, bh = ph - 2 * m;
  final s = switch (fit) {
    PdfFit.fit => math.min(bw / w, bh / h),
    PdfFit.fill => math.max(bw / w, bh / h),
  };
  final dw = w * s, dh = h * s;
  final maxPx = math.max((dw / 72 * dpiCap).ceil(), (dh / 72 * dpiCap).ceil());
  return PageLayout(
    pageWidth: pw,
    pageHeight: ph,
    boxLeft: m,
    boxTop: m,
    boxWidth: bw,
    boxHeight: bh,
    drawLeft: m + (bw - dw) / 2,
    drawTop: m + (bh - dh) / 2,
    drawWidth: dw,
    drawHeight: dh,
    maxLongEdgePx: math.max(1, maxPx),
  );
}

/// Oriented size after a user rotation of [quarterTurns].
(int, int) rotatedSize(int w, int h, int quarterTurns) => quarterTurns.isOdd ? (h, w) : (w, h);
