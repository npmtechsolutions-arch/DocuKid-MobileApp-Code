import 'dart:math' as math;
import 'dart:ui';

import '../../../core/pdf/page_ranges.dart';
import '../../../core/pdf/stamp_check.dart';

/// FR-WMK-04.
enum WatermarkPosition { diagonal, centre, tile, topLeft, topRight, bottomLeft, bottomRight }

/// FR-WMK-06.
enum PageMode { all, range, odd, even }

/// FR-WMK-05 defaults and limits (percentages).
int defaultSizePct({required bool image}) => image ? 30 : 60;
const defaultOpacityPct = 25;
const minSizePct = 10, maxSizePct = 100, minOpacityPct = 10, maxOpacityPct = 80;
const maxWatermarkChars = 60;

/// Diagonal presets lean up to the right (−35°, counter-clockwise).
double defaultRotation(WatermarkPosition p) =>
    p == WatermarkPosition.diagonal || p == WatermarkPosition.tile ? -35 : 0;

class WatermarkStamp {
  const WatermarkStamp(this.rect, this.rotation);

  /// Visual space, before [rotation] (clockwise degrees about the centre).
  final Rect rect;
  final double rotation;
}

const _margin = 0.05;

/// Where the watermark goes on a page of visual [page] size (points). The
/// stamp's long side is [sizePct] % of the page's short side; [aspect] is the
/// image's width / height. Tile: a 3×4 grid (4×3 on landscape pages), each
/// stamp shrunk to fit its cell when rotated.
List<WatermarkStamp> watermarkLayout(Size page, double aspect,
    {required WatermarkPosition position, required num sizePct, required double rotation}) {
  final short = math.min(page.width, page.height);
  final long = short * sizePct.clamp(minSizePct, maxSizePct) / 100;
  final (w, h) = aspect >= 1 ? (long, long / aspect) : (long * aspect, long);
  Rect centred(Offset c, double w, double h) => Rect.fromCenter(center: c, width: w, height: h);

  switch (position) {
    case WatermarkPosition.diagonal || WatermarkPosition.centre:
      return [WatermarkStamp(centred(page.center(Offset.zero), w, h), rotation)];
    case WatermarkPosition.tile:
      final landscape = page.width > page.height;
      final cols = landscape ? 4 : 3, rows = landscape ? 3 : 4;
      final cw = page.width / cols, ch = page.height / rows;
      final box = rotatedBounds(Rect.fromLTWH(0, 0, w, h), rotation);
      final k = math.min(1.0, math.min(0.9 * cw / box.width, 0.9 * ch / box.height));
      return [
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++)
            WatermarkStamp(centred(Offset((c + 0.5) * cw, (r + 0.5) * ch), w * k, h * k), rotation),
      ];
    case WatermarkPosition.topLeft || WatermarkPosition.topRight || WatermarkPosition.bottomLeft || WatermarkPosition.bottomRight:
      // The rotated box sits in the margin, so a turned stamp stays on the page.
      final m = short * _margin;
      final box = rotatedBounds(Rect.fromLTWH(0, 0, w, h), rotation);
      final left = position == WatermarkPosition.topLeft || position == WatermarkPosition.bottomLeft;
      final top = position == WatermarkPosition.topLeft || position == WatermarkPosition.topRight;
      final cx = left ? m + box.width / 2 : page.width - m - box.width / 2;
      final cy = top ? m + box.height / 2 : page.height - m - box.height / 2;
      return [WatermarkStamp(centred(Offset(cx, cy), w, h), rotation)];
  }
}

/// 0-based pages for [mode]; null when [range] isn't valid for [count] pages
/// ("Use page numbers like 1-3, 5").
List<int>? selectPages(PageMode mode, String range, int count, {Set<String> endWords = const {'end'}}) {
  switch (mode) {
    case PageMode.all:
      return [for (var i = 0; i < count; i++) i];
    case PageMode.odd:
      return [for (var i = 0; i < count; i += 2) i];
    case PageMode.even:
      return [for (var i = 1; i < count; i += 2) i];
    case PageMode.range:
      final r = parsePageRanges(range, count, endWords: endWords);
      if (r.parts == null) return null;
      return ({for (final part in r.parts!) ...part.pages}.map((p) => p - 1).toList()..sort());
  }
}
