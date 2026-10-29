import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/page_image_encoder.dart';
import '../../../core/logging/log.dart';
import '../../../core/ocr/ocr_layout.dart';
import '../../../core/ocr/ocr_text_file.dart';
import '../../../core/ocr/pdf_text_reader.dart';
import '../../../core/ocr/searchable_pdf_builder.dart';
import '../../../core/ocr/text_recognizer.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/image_to_pdf_layout.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_options.dart';
import 'ocr_options.dart';
import 'ocr_review_files.dart';

const ocrStepPreparing = 'stepOcrPreparing';
const ocrStepPage = 'stepOcrPage';
const ocrStepBuilding = 'stepOcrBuilding';

/// What one OCR run produced, inside the work dir.
class OcrPipelineResult {
  const OcrPipelineResult({
    required this.pages,
    required this.words,
    required this.lowTextPages,
    required this.reviewDir,
    this.pdfPath,
    this.txtPath,
    this.firstRecognisedPage,
  });

  final int pages, words, lowTextPages;

  /// Per-page text and thumbnails (only filled when text was asked for).
  final String reviewDir;
  final String? pdfPath, txtPath;

  /// The first recognised page that found ≥ 1 word, for §4.10's check.
  final int? firstRecognisedPage;
}

typedef SearchablePdfBuild = Future<SearchablePdfResult> Function(
    List<SearchablePage> pages, OcrScript script, String out, JobContext ctx);

/// RELEASE_V1_3 §4.3: pages are prepared, recognised and written one at a
/// time (one decoded image alive, FR-OCR-12); OCR results go to small JSON
/// files in the work dir, never into memory for the whole job or into logs
/// (ADR-047). Pages that already have text are kept unchanged.
class OcrPipeline {
  OcrPipeline({
    required ImageEngine images,
    required PageImageEncoder encoder,
    required PdfTextReader textReader,
    required TextRecognizer Function() recognizer,
    required Future<PdfPageExtractor> Function(String path) openPages,
    required SearchablePdfBuild buildPdf,
  })  : _images = images,
        _encoder = encoder,
        _textReader = textReader,
        _recognizer = recognizer,
        _openPages = openPages,
        _buildPdf = buildPdf;

  final ImageEngine _images;
  final PageImageEncoder _encoder;
  final PdfTextReader _textReader;
  final TextRecognizer Function() _recognizer;
  final Future<PdfPageExtractor> Function(String path) _openPages;
  final SearchablePdfBuild _buildPdf;

  /// ML Kit gains nothing above this and it bounds memory (§4.4).
  static const maxLongEdge = 4000;
  static const renderDpi = 300, largePageDpi = 200;

  /// Pages larger than A3 (in area) render at [largePageDpi] (FR-OCR-07).
  static const a3AreaPt = 841.89 * 1190.55;
  static const lowTextWords = 3;

  /// FR-OCR-15 is skipped above this many pages (time budget).
  static const rotateRetryMaxPages = 20;
  static const thumbnailLongEdge = 480;

  /// [baseName] names the `.txt` saved later from Review.
  Future<OcrPipelineResult> run(JobContext ctx, List<PickedFile> inputs, OcrOptions o, {String baseName = 'DocuKit'}) async {
    final work = ctx.workDir.path;
    final review = OcrReviewWriter(p.join(work, 'review'));
    final pdfInput = inputs.length == 1 && inputs.single.isPdf ? inputs.single : null;
    final textFlags = pdfInput == null ? const <bool>[] : await _textReader.textPages(pdfInput.path);
    final n = pdfInput == null ? inputs.length : textFlags.length;
    PdfPageExtractor? extractor;
    TextRecognizer? recognizer;
    final searchPages = <SearchablePage>[];
    var words = 0, low = 0;
    int? firstRecognised;
    try {
      if (pdfInput != null) extractor = await _openPages(pdfInput.path);
      if (textFlags.length < n || textFlags.contains(false)) {
        ctx.report(const Indeterminate(ocrStepPreparing));
        recognizer = _recognizer();
        await recognizer.ensureModel(o.script);
      }
      for (var i = 0; i < n; i++) {
        ctx.cancel.throwIfCancelled();
        ctx.report(Determinate(i, n, ocrStepPage));

        if (pdfInput != null && textFlags[i]) {
          searchPages.add(KeptPage(pdfInput.path, i));
          if (o.wantsText) {
            final text = await _textReader.pageText(pdfInput.path, i);
            final count = RegExp(r'\S+').allMatches(text).length;
            words += count;
            await review.page(i, text, OcrReviewPage(words: count, lowText: false, existingText: true));
          }
          if (o.review) await _renderThumb(extractor!, i, pdfInput.pdf!.pageSizes[i], review.thumbPath(i));
          continue;
        }

        var page = pdfInput == null
            ? await _prepareImage(inputs[i], i, work)
            : await _preparePdfPage(extractor!, i, pdfInput.pdf!.pageSizes[i], work);
        var ocr = await recognizer!.recognize(page.jpeg, o.script);
        if (o.rotateRetry && ocr.wordCount < lowTextWords && n <= rotateRetryMaxPages) {
          final best = await _bestRotation(ctx, recognizer, o.script, page, ocr, i, work);
          (page, ocr) = (best.$1, best.$2);
        }
        ocr = sortedPage(ocr);
        final json = p.join(work, 'ocr_$i.json');
        await File(json).writeAsString(jsonEncode(ocr.toJson()), flush: true);
        searchPages.add(RecognisedPage(
            jpegPath: page.jpeg, ocrPath: json, pageWidth: page.width, pageHeight: page.height, imageBox: page.box));
        words += ocr.wordCount;
        final isLow = ocr.wordCount < lowTextWords;
        if (isLow) low++;
        if (ocr.wordCount > 0) firstRecognised ??= i;
        if (o.wantsText) {
          await review.page(i, ocr.text, OcrReviewPage(words: ocr.wordCount, lowText: isLow, existingText: false));
        }
        if (o.review) {
          await _images.transform(page.jpeg, review.thumbPath(i),
              const ImageTransform(format: ImageFormat.jpeg, quality: 70, maxLongEdge: thumbnailLongEdge));
        }
      }
      ctx.cancel.throwIfCancelled();
      if (o.wantsText) await review.finish(n, baseName: baseName);

      String? pdfPath, txtPath;
      if (o.searchablePdf) {
        ctx.report(const Indeterminate(ocrStepBuilding));
        final r = await _buildPdf(searchPages, o.script, p.join(work, 'searchable.pdf'), ctx);
        if (r.missingGlyphs > 0) Log.job(ctx.jobId, 'ocr_glyph_missing', '${r.missingGlyphs}');
        pdfPath = r.path;
      }
      if (o.txt) {
        txtPath = p.join(work, 'text.txt');
        await writeOcrTxt(txtPath, n, review.readText);
      }
      return OcrPipelineResult(
        pages: n,
        words: words,
        lowTextPages: low,
        reviewDir: review.dir,
        pdfPath: pdfPath,
        txtPath: txtPath,
        firstRecognisedPage: firstRecognised,
      );
    } finally {
      await recognizer?.dispose();
      await extractor?.close();
    }
  }

  /// An oriented JPEG (EXIF applied, ≤ 4000 px), on a "Same as image" page.
  Future<_Page> _prepareImage(PickedFile f, int i, String work) async {
    final meta = f.image;
    if (meta == null) throw const AppError(AppErrorCode.corruptFile);
    final out = await _images.transform(
      f.path,
      p.join(work, 'page_$i.jpg'),
      ImageTransform(format: ImageFormat.jpeg, quality: 85, maxLongEdge: math.min(maxLongEdge, math.max(meta.width, meta.height))),
      meta: meta,
    );
    return _imagePage(out.path, out.width, out.height);
  }

  static _Page _imagePage(String jpeg, int w, int h) {
    final l = layoutImagePage(
      imageWidth: w,
      imageHeight: h,
      size: PdfPageSize.image,
      orientation: PdfOrientation.auto,
      fit: PdfFit.fit,
      margin: PdfMargin.none,
      dpiCap: renderDpi,
    );
    return _Page(
      jpeg,
      w,
      h,
      l.pageWidth,
      l.pageHeight,
      PdfBox(
        left: l.drawLeft,
        bottom: l.pageHeight - l.drawTop - l.drawHeight,
        right: l.drawLeft + l.drawWidth,
        top: l.pageHeight - l.drawTop,
      ),
      isPdfPage: false,
    );
  }

  /// FR-OCR-07: 300 dpi (200 above A3); the page keeps its size in points
  /// (post-/Rotate, so the render is upright) and the image is full-bleed.
  Future<_Page> _preparePdfPage(PdfPageExtractor ex, int i, (double, double) sizePt, String work) async {
    final (wPt, hPt) = sizePt;
    final dpi = wPt * hPt > a3AreaPt ? largePageDpi : renderDpi;
    final w = (wPt / 72 * dpi).round(), h = (hPt / 72 * dpi).round();
    final px = await ex.renderPage(i, width: w, height: h, transparent: false);
    final out = p.join(work, 'page_$i.jpg');
    await _encoder.encode(px, out, format: ImageFormat.jpeg, quality: 85, keepAlpha: false);
    return _Page(out, w, h, wPt, hPt, PdfBox(left: 0, bottom: 0, right: wPt, top: hPt), isPdfPage: true);
  }

  /// FR-OCR-15: the rotation (90/180/270) with the most words, if better.
  Future<(_Page, OcrPage)> _bestRotation(
      JobContext ctx, TextRecognizer r, OcrScript script, _Page page, OcrPage ocr, int i, String work) async {
    var best = (page, ocr);
    for (final angle in const [90, 180, 270]) {
      ctx.cancel.throwIfCancelled();
      final turned = await _images.transform(page.jpeg, p.join(work, 'page_${i}_r$angle.jpg'),
          ImageTransform(format: ImageFormat.jpeg, quality: 85, extraRotation: angle));
      final result = await r.recognize(turned.path, script);
      if (result.wordCount > best.$2.wordCount) best = (page.turned(turned.path, angle), result);
    }
    if (!identical(best.$1, page)) Log.job(ctx.jobId, 'ocr_rotated');
    return best;
  }

  Future<void> _renderThumb(PdfPageExtractor ex, int i, (double, double) sizePt, String out) async {
    final (wPt, hPt) = sizePt;
    final s = thumbnailLongEdge / math.max(wPt, hPt);
    final px = await ex.renderPage(i, width: math.max(1, (wPt * s).round()), height: math.max(1, (hPt * s).round()), transparent: false);
    await _encoder.encode(px, out, format: ImageFormat.jpeg, quality: 70, keepAlpha: false);
  }
}

/// One prepared page: its upright JPEG and where it goes on the output page.
class _Page {
  const _Page(this.jpeg, this.pixelWidth, this.pixelHeight, this.width, this.height, this.box, {required this.isPdfPage});

  final String jpeg;
  final int pixelWidth, pixelHeight;
  final double width, height;
  final PdfBox box;
  final bool isPdfPage;

  /// The same page turned by [angle]: images get a new "Same as image" page;
  /// PDF pages swap their width and height for a quarter turn (§4.4).
  _Page turned(String jpeg, int angle) {
    final quarter = angle % 180 != 0;
    final (pw, ph) = quarter ? (pixelHeight, pixelWidth) : (pixelWidth, pixelHeight);
    if (!isPdfPage) return OcrPipeline._imagePage(jpeg, pw, ph);
    final (w, h) = quarter ? (height, width) : (width, height);
    return _Page(jpeg, pw, ph, w, h, PdfBox(left: 0, bottom: 0, right: w, top: h), isPdfPage: true);
  }
}
