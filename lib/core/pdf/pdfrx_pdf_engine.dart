import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../errors/app_error.dart';
import '../files/mime_sniffer.dart';
import '../files/picked_file.dart';
import '../image/page_image_encoder.dart';
import '../operation/tool_operation.dart';
import 'page_edit.dart';
import 'pdf_engine.dart';
import 'pdf_options.dart';
import 'pdfium_raw_ops.dart';

/// PDFium through pdfrx 2.4.7 (ADR-005). Verified in the pinned sources:
/// `PdfDocument.openFile/createNew/createFromJpegData`, the `pages` setter,
/// `encodePdf()`, and `PdfPage.rotatedBy()` for rotation (resolves the spike
/// T3.0 rotation question without a native fallback — DECISIONS ADR-020).
class PdfrxPdfEngine implements PdfEngine {
  PdfrxPdfEngine();

  /// Documents kept open for thumbnail rendering, least recently used first.
  /// Capped so e.g. 20 merge inputs don't stay open at once.
  final Map<String, Future<PdfDocument>> _open = {};
  static const _maxOpen = 3;

  Future<PdfDocument> _openForRender(String path) {
    final existing = _open.remove(path);
    if (existing != null) {
      _open[path] = existing; // move to most-recently-used
      return existing;
    }
    while (_open.length >= _maxOpen) {
      final oldest = _open.keys.first;
      final f = _open.remove(oldest)!;
      f.then((d) => d.dispose()).ignore();
    }
    return _open[path] = _openFile(path);
  }

  /// Opens [path] with the engine's error mapping (for other PDF readers).
  static Future<PdfDocument> openChecked(String path) => _openFile(path);

  static Future<PdfDocument> _openFile(String path) async {
    try {
      // passwordProvider == null → pdfrx throws PdfPasswordException for a
      // user password. Owner-only (restrictions) PDFs open with the empty
      // password, as documented in TESTING PDF-06. Never bypassed (rule 7).
      return await PdfDocument.openFile(path);
    } on PdfPasswordException {
      throw const AppError(AppErrorCode.encryptedDocument);
    } on FileSystemException {
      throw const AppError(AppErrorCode.permissionLost);
    } on AppError {
      rethrow;
    } catch (_) {
      throw const AppError(AppErrorCode.corruptFile);
    }
  }

  @override
  Future<PdfMeta> inspect(String path) async {
    if (await sniffFile(path) != SniffedType.pdf) throw const AppError(AppErrorCode.unsupportedFormat);
    final doc = await _openFile(path);
    try {
      final pages = doc.pages;
      if (pages.isEmpty) throw const AppError(AppErrorCode.corruptFile);
      return PdfMeta(
        pageCount: pages.length,
        isEncrypted: doc.isEncrypted,
        pageSizes: [for (final pg in pages) (pg.width, pg.height)],
      );
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<PdfAnalysis> analyse(String path, int fileBytes) async {
    final r = await PdfrxEntryFunctions.instance
        .compute(analyseImagesInWorker, AnalyseRequest(path, 20, Pdfrx.pdfiumModulePath));
    final pages = r.pageCount;
    final images = r.sampledPages == 0 ? 0 : (r.imagesInSample * pages / r.sampledPages).round();
    final perPage = pages == 0 ? 0 : images / pages;
    final bytesPerPage = pages == 0 ? 0 : fileBytes / pages;
    return PdfAnalysis(pageCount: pages, imageCount: images, imageHeavy: perPage >= 0.5 || bytesPerPage > 150 * 1024);
  }

  @override
  Future<ui.Image?> renderPage(String path, int index, {required int targetWidthPx}) async {
    final doc = await _openForRender(path);
    if (index < 0 || index >= doc.pages.length) return null;
    final page = doc.pages[index];
    final w = targetWidthPx.toDouble();
    final h = w * page.height / page.width;
    final rendered = await page.render(fullWidth: w, fullHeight: h, backgroundColor: 0xFFFFFFFF);
    if (rendered == null) return null;
    try {
      return await rendered.createImage();
    } finally {
      rendered.dispose();
    }
  }

  @override
  Future<void> close(String path) async {
    final f = _open.remove(path);
    if (f == null) return;
    try {
      await (await f).dispose();
    } catch (_) {
      // Already failed to open; nothing to release.
    }
  }

  Future<void> _write(PdfDocument doc, String out) async {
    final Uint8List bytes = await doc.encodePdf();
    await File(out).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> merge(List<String> inputs, String out, JobContext ctx) async {
    final docs = <PdfDocument>[];
    PdfDocument? merged;
    try {
      final pages = <PdfPage>[];
      for (var i = 0; i < inputs.length; i++) {
        ctx.cancel.throwIfCancelled();
        ctx.report(Determinate(i, inputs.length, 'stepMerging', unit: ProgressUnit.files));
        final d = await _openFile(inputs[i]);
        docs.add(d);
        pages.addAll(d.pages);
      }
      ctx.cancel.throwIfCancelled();
      ctx.report(const Indeterminate('stepSavingPages'));
      merged = await PdfDocument.createNew(sourceName: 'merge-${ctx.jobId}');
      merged.pages = pages;
      await _write(merged, out);
    } finally {
      await merged?.dispose();
      for (final d in docs) {
        await d.dispose();
      }
    }
  }

  @override
  Future<void> combineFiles(List<String> inputs, String out) async {
    final docs = <PdfDocument>[];
    PdfDocument? merged;
    try {
      final pages = <PdfPage>[];
      for (final path in inputs) {
        final d = await _openFile(path);
        docs.add(d);
        pages.addAll(d.pages);
      }
      merged = await PdfDocument.createNew(sourceName: 'combine-${p.basename(out)}');
      merged.pages = pages;
      await _write(merged, out);
    } finally {
      await merged?.dispose();
      for (final d in docs) {
        await d.dispose();
      }
    }
  }

  @override
  Future<PdfPageExtractor> openExtractor(String input) async => _PdfrxExtractor(await _openFile(input));

  @override
  Future<void> organize(String input, List<PageEdit> edits, String out, JobContext ctx) async {
    final src = await _openFile(input);
    PdfDocument? doc;
    try {
      ctx.report(const Indeterminate('stepSavingPages'));
      final pages = <PdfPage>[];
      for (final e in edits) {
        ctx.cancel.throwIfCancelled();
        final page = src.pages[e.sourceIndex];
        pages.add(e.rotationQuarterTurns % 4 == 0 ? page : page.rotatedBy(PdfPageRotation.values[e.rotationQuarterTurns % 4]));
      }
      doc = await PdfDocument.createNew(sourceName: 'organize-${ctx.jobId}');
      doc.pages = pages;
      await _write(doc, out);
    } finally {
      await doc?.dispose();
      await src.dispose();
    }
  }

  @override
  Future<void> reduce(String input, String out, ReduceLevel level, JobContext ctx) async {
    switch (level) {
      case ReduceLevel.basic:
        await _reduceBasic(input, out, ctx);
      case ReduceLevel.balanced:
        await _reduceBalanced(input, out, ctx);
      case ReduceLevel.strong:
        await _reduceStrong(input, out, ctx);
    }
  }

  /// Lossless rewrite: importing the pages into a fresh document drops
  /// unreferenced objects and incremental-update history.
  Future<void> _reduceBasic(String input, String out, JobContext ctx) async {
    ctx.report(const Indeterminate('stepOptimizing'));
    final src = await _openFile(input);
    PdfDocument? doc;
    try {
      ctx.cancel.throwIfCancelled();
      doc = await PdfDocument.createNew(sourceName: 'basic-${ctx.jobId}');
      doc.pages = src.pages;
      await _write(doc, out);
    } finally {
      await doc?.dispose();
      await src.dispose();
    }
  }

  Future<void> _reduceBalanced(String input, String out, JobContext ctx) async {
    final flag = calloc<Uint8>();
    final port = ReceivePort();
    final cancelWatch = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (ctx.cancel.isCancelled) flag.value = 1;
    });
    port.listen((m) {
      if (m is List && m.length == 2) ctx.report(Determinate(m[0] as int, m[1] as int, 'stepOptimizing'));
    });
    try {
      final result = await PdfrxEntryFunctions.instance.compute(
        balancedReduceInWorker,
        BalancedRequest(
          input: input,
          output: out,
          cancelFlagAddress: flag.address,
          progress: port.sendPort,
          modulePath: Pdfrx.pdfiumModulePath,
        ),
      );
      switch (result) {
        case RawResult.ok:
          return;
        case RawResult.cancelled:
          throw const CancelledException();
        case RawResult.encrypted:
          throw const AppError(AppErrorCode.encryptedDocument);
        case RawResult.corrupt:
          throw const AppError(AppErrorCode.corruptFile);
        default:
          throw const AppError(AppErrorCode.processingFailed);
      }
    } finally {
      cancelWatch.cancel();
      port.close();
      calloc.free(flag);
    }
  }

  /// Rasterises each page at 120 dpi → JPEG q60, in chunks of 40 pages.
  Future<void> _reduceStrong(String input, String out, JobContext ctx) async {
    const dpi = 120.0;
    const chunkSize = 40;
    final src = await _openFile(input);
    final chunkPaths = <String>[];
    try {
      final n = src.pages.length;
      for (var start = 0; start < n; start += chunkSize) {
        final pageDocs = <PdfDocument>[];
        PdfDocument? chunk;
        try {
          for (var i = start; i < n && i < start + chunkSize; i++) {
            ctx.cancel.throwIfCancelled();
            ctx.report(Determinate(i, n, 'stepOptimizing'));
            final page = src.pages[i];
            final w = page.width * dpi / 72, h = page.height * dpi / 72;
            final rendered = await page.render(fullWidth: w, fullHeight: h, backgroundColor: 0xFFFFFFFF);
            if (rendered == null) throw const AppError(AppErrorCode.processingFailed);
            final width = rendered.width, height = rendered.height;
            // `pixels` views native memory that dispose() frees: copy first.
            final pixels = Uint8List.fromList(rendered.pixels);
            rendered.dispose();
            final jpeg = await Isolate.run(() => _bgraToJpeg(pixels, width, height, 60));
            pageDocs.add(await PdfDocument.createFromJpegData(
              jpeg,
              width: page.width,
              height: page.height,
              sourceName: 'strong-${ctx.jobId}-$i',
            ));
          }
          chunk = await PdfDocument.createNew(sourceName: 'strong-chunk-${ctx.jobId}-$start');
          chunk.pages = [for (final d in pageDocs) ...d.pages];
          final path = p.join(ctx.workDir.path, 'chunk_$start.pdf');
          await _write(chunk, path);
          chunkPaths.add(path);
        } finally {
          await chunk?.dispose();
          for (final d in pageDocs) {
            await d.dispose();
          }
        }
      }
    } finally {
      await src.dispose();
    }
    ctx.cancel.throwIfCancelled();
    ctx.report(const Indeterminate('stepSavingPages'));
    if (chunkPaths.length == 1) {
      await File(chunkPaths.single).rename(out);
    } else {
      await combineFiles(chunkPaths, out);
    }
  }
}

Uint8List _bgraToJpeg(Uint8List bgra, int width, int height, int quality) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bgra.buffer,
    bytesOffset: bgra.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
  return img.encodeJpg(image.convert(numChannels: 3), quality: quality);
}

/// Keeps the source open across Split items (§4.7); same page copy as
/// Organize (`createNew` + the `pages` setter + `encodePdf`).
class _PdfrxExtractor implements PdfPageExtractor {
  _PdfrxExtractor(this._src);
  final PdfDocument _src;

  @override
  int get pageCount => _src.pages.length;

  @override
  Future<void> extract(List<int> pages, String out) async {
    final doc = await PdfDocument.createNew(sourceName: 'extract-${p.basename(out)}');
    try {
      doc.pages = [for (final i in pages) _src.pages[i]];
      final Uint8List bytes = await doc.encodePdf();
      await File(out).writeAsBytes(bytes, flush: true);
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<PagePixels> renderPage(int index, {required int width, required int height, required bool transparent}) async {
    final rendered = await _src.pages[index].render(
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      backgroundColor: transparent ? 0x00FFFFFF : 0xFFFFFFFF,
    );
    if (rendered == null) throw const AppError(AppErrorCode.processingFailed);
    try {
      // Copy out, then free the native bitmap before the next page (FR-P2I-05).
      return PagePixels(Uint8List.fromList(rendered.pixels), rendered.width, rendered.height);
    } finally {
      rendered.dispose();
    }
  }

  @override
  Future<void> close() => _src.dispose();
}
