import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/rendering.dart' show Matrix4;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pp;

import '../errors/app_error.dart';
import '../operation/tool_operation.dart';
import '../pdf/pdf_engine.dart';
import 'ocr_layout.dart';
import 'text_recognizer.dart';

/// One page of the searchable PDF (RELEASE_V1_3 §4.7).
sealed class SearchablePage {
  const SearchablePage();
}

/// An oriented JPEG plus its OCR result on disk, drawn into [imageBox] on a
/// [pageWidth]×[pageHeight] pt page with an invisible text layer.
final class RecognisedPage extends SearchablePage {
  const RecognisedPage({
    required this.jpegPath,
    required this.ocrPath,
    required this.pageWidth,
    required this.pageHeight,
    required this.imageBox,
  });

  final String jpegPath;

  /// `OcrPage.toJson` in the job's work dir (ADR-047).
  final String ocrPath;
  final double pageWidth, pageHeight;
  final PdfBox imageBox;
}

/// A source page that already has text: copied unchanged (FR-OCR-07).
final class KeptPage extends SearchablePage {
  const KeptPage(this.sourcePath, this.pageIndex);
  final String sourcePath;
  final int pageIndex;
}

/// A run of output pages written in one step; [pages] index the build's list.
sealed class BuildSegment {
  const BuildSegment(this.pages);
  final List<int> pages;
}

final class BuiltSegment extends BuildSegment {
  const BuiltSegment(super.pages);
}

final class KeptSegment extends BuildSegment {
  const KeptSegment(super.pages, this.source, this.sourcePages);
  final String source;
  final List<int> sourcePages;
}

/// Recognised pages in chunks of [chunk] (ADR-012's rule), kept pages in runs
/// per source, in page order.
List<BuildSegment> planSegments(List<SearchablePage> pages, {int chunk = SearchablePdfBuilder.chunkPages}) {
  final out = <BuildSegment>[];
  for (var i = 0; i < pages.length; i++) {
    final page = pages[i];
    final last = out.isEmpty ? null : out.last;
    switch (page) {
      case RecognisedPage():
        if (last is BuiltSegment && last.pages.length < chunk && last.pages.last == i - 1) {
          last.pages.add(i);
        } else {
          out.add(BuiltSegment([i]));
        }
      case KeptPage(:final sourcePath, :final pageIndex):
        if (last is KeptSegment && last.source == sourcePath && last.pages.last == i - 1) {
          last.pages.add(i);
          last.sourcePages.add(pageIndex);
        } else {
          out.add(KeptSegment([i], sourcePath, [pageIndex]));
        }
    }
  }
  return out;
}

/// Where and how one OCR line is written (PDF points; [baseline] is above
/// [origin] along the line's up direction).
class LinePlacement {
  const LinePlacement({
    required this.origin,
    required this.angle,
    required this.size,
    required this.scale,
    required this.baseline,
  });

  /// The line's bottom-left corner.
  final Offset origin;

  /// Radians, counter-clockwise (PDF space); 0 unless skewed > 2°.
  final double angle;
  final double size, scale, baseline;
}

/// §4.7: the font's em box (ascent − descent) fills the line's height, and
/// horizontal scaling (Tz, clamped 0.5–2) fits the line's width, so selection
/// highlights match the words on the image. Skewed lines follow their
/// corners. [naturalWidthEm] is the text's advance width at size 1.
LinePlacement placeLine(
  OcrLine line, {
  required int imageWidth,
  required int imageHeight,
  required PdfBox imageBox,
  required double naturalWidthEm,
  required double ascent,
  required double descent,
}) {
  Offset map(Offset o) => toPdfPoint(o, imageWidth: imageWidth, imageHeight: imageHeight, page: imageBox);
  final Offset origin;
  final double width, height;
  var angle = 0.0;
  final c = line.corners;
  if (c.length == 4 && isSkewed(imageAngle(c))) {
    final tl = map(c[0]), tr = map(c[1]), bl = map(c[3]);
    origin = bl;
    width = (tr - tl).distance;
    height = (tl - bl).distance;
    angle = math.atan2(tr.dy - tl.dy, tr.dx - tl.dx);
  } else {
    final b = toPdfBox(line.box, imageWidth: imageWidth, imageHeight: imageHeight, page: imageBox);
    origin = Offset(b.left, b.bottom);
    width = b.width;
    height = b.height;
  }
  final em = ascent - descent;
  final size = (em > 0 ? height / em : height).clamp(4.0, 200.0);
  final natural = naturalWidthEm * size;
  final scale = natural > 0 ? (width / natural).clamp(0.5, 2.0) : 1.0;
  return LinePlacement(origin: origin, angle: angle, size: size, scale: scale, baseline: -descent * size);
}

/// §4.7 (P1): place each word on its own box when the line is long (> 12
/// words) or its spacing is uneven (a gap > 2× the median gap, e.g. columns
/// or a label and its value). Per-line scaling lets the words drift from
/// their positions when the embedded font's proportions differ from the
/// printed one (T10.4 measured on OCR-01: 25% of words on their box per line,
/// see TASKS).
bool placeWordsSeparately(OcrLine line) {
  final w = line.words;
  if (w.length > 12) return true;
  if (w.length < 3) return false;
  final gaps = [for (var i = 1; i < w.length; i++) w[i].box.left - w[i - 1].box.right]..sort();
  final median = gaps[gaps.length ~/ 2];
  return gaps.last > 2 * math.max(median, 1.0);
}

/// Word boxes from ML Kit can touch or overlap ("planning" 856–1047 px,
/// "session." 1045–1224 px on OCR-01). Then no space fits between them and
/// PDFium's text extraction joins the words, which breaks search. Boxes
/// closer than [minGap] are pulled apart around their midpoint.
List<Rect> separateWords(List<Rect> boxes, {required double minGap}) {
  final out = [...boxes];
  for (var i = 1; i < out.length; i++) {
    final a = out[i - 1], b = out[i];
    if (b.left - a.right >= minGap) continue;
    final mid = (a.right + b.left) / 2;
    out[i - 1] = Rect.fromLTRB(a.left, a.top, math.max(a.left + 1, mid - minGap / 2), a.bottom);
    out[i] = Rect.fromLTRB(math.min(b.right - 1, mid + minGap / 2), b.top, b.right, b.bottom);
  }
  return out;
}

/// Splits [text] into runs for the first font that has each character
/// ([supports] in priority order). A character no font has becomes
/// [replacement] in the primary font (§4.8: U+FFFD, or `?` when the font
/// lacks that too): the `pdf` package's subsetter fails on a character
/// without a glyph (found in T10.4). Those are counted in [missing] for the
/// code-only `ocr_glyph_missing` log event.
({List<(int, String)> runs, int missing}) splitRuns(String text, List<bool Function(int rune)> supports,
    {int replacement = 0xFFFD}) {
  final runs = <(int, String)>[];
  final cur = StringBuffer();
  int? curFont;
  var missing = 0;
  for (final rune in text.runes) {
    var f = supports.indexWhere((s) => s(rune));
    var out = rune;
    if (f < 0) {
      missing++;
      f = 0;
      out = replacement;
    }
    if (f != curFont && cur.isNotEmpty) {
      runs.add((curFont!, cur.toString()));
      cur.clear();
    }
    curFont = f;
    cur.writeCharCode(out);
  }
  if (cur.isNotEmpty) runs.add((curFont!, cur.toString()));
  return (runs: runs, missing: missing);
}

/// The embedded fonts per script, primary first (§4.8, ADR-045).
List<String> ocrFontAssets(OcrScript script) => switch (script) {
      OcrScript.devanagari => const ['assets/fonts/NotoSansDevanagari-Regular.ttf', 'assets/fonts/NotoSans-Regular.ttf'],
      _ => const ['assets/fonts/NotoSans-Regular.ttf'],
    };

class SearchablePdfResult {
  const SearchablePdfResult(this.path, this.missingGlyphs);
  final String path;
  final int missingGlyphs;
}

/// ADR-046: image + invisible text (render mode 3) with the `pdf` package,
/// written in chunks of [chunkPages] inside an isolate that reads one page
/// image at a time from disk; pages that already have text are imported
/// unchanged; PDFium merges the parts in order.
class SearchablePdfBuilder {
  SearchablePdfBuilder(this._pdf, this._loadFont);

  final PdfEngine _pdf;

  /// Asset bytes (`rootBundle` in the app; files in host tests).
  final Future<Uint8List> Function(String asset) _loadFont;

  static const chunkPages = 20;

  Future<SearchablePdfResult> build(List<SearchablePage> pages, OcrScript script, String out, JobContext ctx) async {
    if (pages.isEmpty) throw const AppError(AppErrorCode.invalidInput);
    final fonts = [for (final a in ocrFontAssets(script)) await _loadFont(a)];
    final parts = <String>[];
    final extractors = <String, PdfPageExtractor>{};
    var missing = 0;
    try {
      for (final (i, seg) in planSegments(pages).indexed) {
        ctx.cancel.throwIfCancelled();
        final path = p.join(ctx.workDir.path, 'searchable_part_$i.pdf');
        switch (seg) {
          case BuiltSegment(pages: final indices):
            final chunk = [for (final k in indices) pages[k] as RecognisedPage];
            missing += await Isolate.run(() => _writeChunk(chunk, fonts, path));
          case KeptSegment(:final source, :final sourcePages):
            final ex = extractors[source] ??= await _pdf.openExtractor(source);
            await ex.extract(sourcePages, path);
        }
        parts.add(path);
      }
    } finally {
      for (final e in extractors.values) {
        await e.close();
      }
    }
    ctx.cancel.throwIfCancelled();
    if (parts.length == 1) {
      await File(parts.single).rename(out);
    } else {
      await _pdf.combineFiles(parts, out);
      for (final part in parts) {
        File(part).deleteSync();
      }
    }
    return SearchablePdfResult(out, missing);
  }
}

/// Runs in an isolate: one page image in memory at a time.
Future<int> _writeChunk(List<RecognisedPage> pages, List<Uint8List> fontBytes, String out) async {
  final doc = pp.PdfDocument(compress: true);
  final fonts = [for (final b in fontBytes) pp.PdfTtfFont(doc, ByteData.sublistView(b))];
  final supports = [for (final f in fonts) f.isRuneSupported];
  final replacement = fonts.first.isRuneSupported(0xFFFD) ? 0xFFFD : 0x3F;
  var missing = 0;
  for (final page in pages) {
    final pdfPage = pp.PdfPage(doc, pageFormat: pp.PdfPageFormat(page.pageWidth, page.pageHeight));
    final g = pdfPage.getGraphics();
    final box = page.imageBox;
    g.drawImage(pp.PdfImage.jpeg(doc, image: File(page.jpegPath).readAsBytesSync()), box.left, box.bottom, box.width,
        box.height);
    final ocr = sortedPage(OcrPage.fromJson((jsonDecode(File(page.ocrPath).readAsStringSync()) as Map).cast()));
    /// [spaceAfter] (PDF points) writes a space after the text, scaled to
    /// exactly that gap, so it neither overlaps the next word (PDFium then
    /// drops it) nor counts in the word's own fit.
    void place(OcrLine piece, {double? spaceAfter}) {
      final split = splitRuns(piece.text, supports, replacement: replacement);
      missing += split.missing;
      final natural = split.runs.fold(0.0, (w, r) => w + fonts[r.$1].stringMetrics(r.$2).advanceWidth);
      final runs = split.runs;
      final at = placeLine(piece,
          imageWidth: ocr.imageWidth,
          imageHeight: ocr.imageHeight,
          imageBox: box,
          naturalWidthEm: natural,
          ascent: fonts.first.ascent,
          descent: fonts.first.descent);
      g
        ..saveContext()
        ..setTransform(Matrix4.translationValues(at.origin.dx, at.origin.dy, 0)..multiply(Matrix4.rotationZ(at.angle)));
      var x = 0.0;
      for (final (f, text) in runs) {
        g.drawString(fonts[f], at.size, text, x, at.baseline, mode: pp.PdfTextRenderingMode.invisible, scale: at.scale);
        x += fonts[f].stringMetrics(text).advanceWidth * at.size * at.scale;
      }
      if (spaceAfter != null) {
        final spaceEm = fonts.first.stringMetrics(' ').advanceWidth;
        final scale = spaceEm > 0 ? (math.max(spaceAfter, 0.1) / (spaceEm * at.size)).clamp(0.01, 10.0) : 1.0;
        g.drawString(fonts.first, at.size, ' ', x, at.baseline, mode: pp.PdfTextRenderingMode.invisible, scale: scale);
      }
      g.restoreContext();
    }

    for (final line in ocr.lines) {
      // A skewed line (> 2°) is placed whole along its corners; per-word
      // placement is for straight lines.
      if (!placeWordsSeparately(line) || isSkewed(imageAngle(line.corners))) {
        place(line);
        continue;
      }
      // Each word on its own box, at the line's height so the words share a
      // baseline (word boxes vary with ascenders and descenders). The space is
      // written explicitly: PDFium's gap heuristic sometimes joins two words
      // ("planningsession" on OCR-01), which breaks phrase search.
      final ptPerPx = box.width / ocr.imageWidth;
      final boxes = separateWords([for (final w in line.words) w.box], minGap: 0.2 * line.box.height);
      for (final (i, w) in line.words.indexed) {
        final b = boxes[i];
        place(
          OcrLine(
            text: w.text,
            box: Rect.fromLTRB(b.left, line.box.top, b.right, line.box.bottom),
            corners: const [], // straight line: axis-aligned words
            words: [w],
          ),
          spaceAfter: i + 1 < boxes.length ? (boxes[i + 1].left - b.right) * ptPerPx : null,
        );
      }
    }
  }
  await File(out).writeAsBytes(await doc.save(), flush: true);
  return missing;
}
