import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_bindings;

/// Raw PDFium work that pdfrx doesn't expose: image-object analysis and the
/// Balanced reducer (ADR-005, ADR-013, DECISIONS ADR-020).
///
/// Everything here runs inside pdfrx's own PDFium worker isolate via
/// `PdfrxEntryFunctions.compute` — never the UI isolate. That worker owns the
/// font-substitution callbacks pdfrx registers with PDFium; calling PDFium from
/// any other isolate crashes with "Cannot invoke native callback from a
/// different isolate" (found by the host tests). It also serialises all
/// PDFium use, which isn't thread-safe.

/// Message protocol for [balancedReduceIsolate].
class BalancedRequest {
  const BalancedRequest({
    required this.input,
    required this.output,
    required this.cancelFlagAddress,
    required this.progress,
    this.modulePath,
    this.targetDpi = 150,
    this.skipBelowDpi = 160,
    this.jpegQuality = 70,
  });
  final String input, output;

  /// Address of a 1-byte native flag set by the main isolate to cancel.
  final int cancelFlagAddress;
  final SendPort progress;

  /// `Pdfrx.pdfiumModulePath` (null on devices: the default loader finds the
  /// library that pdfrx already loaded; set in host tests).
  final String? modulePath;
  final double targetDpi, skipBelowDpi;
  final int jpegQuality;
}

/// Outcome codes sent back on [BalancedRequest.progress] as the last message.
abstract final class RawResult {
  static const ok = 'ok';
  static const cancelled = 'cancelled';
  static const encrypted = 'encrypted';
  static const corrupt = 'corrupt';
  static const failed = 'failed';
}

class AnalyseResult {
  const AnalyseResult(this.pageCount, this.sampledPages, this.imagesInSample);
  final int pageCount, sampledPages, imagesInSample;
}

class AnalyseRequest {
  const AnalyseRequest(this.path, this.maxPages, this.modulePath);
  final String path;
  final int maxPages;
  final String? modulePath;
}

/// Worker entry point: counts image objects on the first pages.
AnalyseResult analyseImagesInWorker(AnalyseRequest r) => analyseImages(r.path, r.maxPages, modulePath: r.modulePath);

/// Counts image objects on the first [maxPages] pages.
AnalyseResult analyseImages(String path, int maxPages, {String? modulePath}) {
  final p = pdfium_bindings.getPdfium(modulePath: modulePath);
  return using((arena) {
    final doc = p.FPDF_LoadDocument(path.toNativeUtf8(allocator: arena).cast(), nullptr);
    if (doc == nullptr) return const AnalyseResult(0, 0, 0);
    try {
      final n = p.FPDF_GetPageCount(doc);
      final sample = math.min(n, maxPages);
      var images = 0;
      for (var i = 0; i < sample; i++) {
        final page = p.FPDF_LoadPage(doc, i);
        if (page == nullptr) continue;
        final count = p.FPDFPage_CountObjects(page);
        for (var k = 0; k < count; k++) {
          if (p.FPDFPageObj_GetType(p.FPDFPage_GetObject(page, k)) == pdfium_bindings.FPDF_PAGEOBJ_IMAGE) images++;
        }
        p.FPDF_ClosePage(page);
      }
      return AnalyseResult(n, sample, images);
    } finally {
      p.FPDF_CloseDocument(doc);
    }
  });
}

class TextPagesRequest {
  const TextPagesRequest(this.path, this.minChars, this.modulePath);
  final String path;
  final int minChars;
  final String? modulePath;
}

/// [code] is a [RawResult] code; [flags] has one entry per page when ok.
class TextPagesResult {
  const TextPagesResult(this.code, [this.flags = const []]);
  final String code;
  final List<bool> flags;
}

/// Worker entry point: which pages already have text (RELEASE_V1_3 §4.6).
TextPagesResult textPagesInWorker(TextPagesRequest r) {
  try {
    return textPages(r.path, r.minChars, modulePath: r.modulePath);
  } catch (_) {
    return const TextPagesResult(RawResult.failed);
  }
}

/// Counts non-space characters per page through PDFium's text API and stops
/// at [minChars]: much cheaper than pdfrx's `loadText()`, which also builds a
/// box for every character (T10.3 measured ~0.4 s per text page with it on
/// the emulator).
TextPagesResult textPages(String path, int minChars, {String? modulePath}) {
  final p = pdfium_bindings.getPdfium(modulePath: modulePath);
  return using((arena) {
    final doc = p.FPDF_LoadDocument(path.toNativeUtf8(allocator: arena).cast(), nullptr);
    if (doc == nullptr) {
      return TextPagesResult(
          p.FPDF_GetLastError() == pdfium_bindings.FPDF_ERR_PASSWORD ? RawResult.encrypted : RawResult.corrupt);
    }
    try {
      final flags = <bool>[];
      for (var i = 0, n = p.FPDF_GetPageCount(doc); i < n; i++) {
        final page = p.FPDF_LoadPage(doc, i);
        if (page == nullptr) {
          flags.add(false);
          continue;
        }
        var count = 0;
        final text = p.FPDFText_LoadPage(page);
        if (text != nullptr) {
          for (var k = 0, chars = p.FPDFText_CountChars(text); k < chars && count < minChars; k++) {
            if (!_isSpace(p.FPDFText_GetUnicode(text, k))) count++;
          }
          p.FPDFText_ClosePage(text);
        }
        p.FPDF_ClosePage(page);
        flags.add(count >= minChars);
      }
      return TextPagesResult(RawResult.ok, flags);
    } finally {
      p.FPDF_CloseDocument(doc);
    }
  });
}

final _space = RegExp(r'\s');

/// Same rule as `hasEnoughText` (`\s`), plus the NUL PDFium reports for
/// characters it can't map.
bool _isSpace(int unicode) => unicode == 0 || _space.hasMatch(String.fromCharCode(unicode));

/// Worker entry point. Sends `[done, total]` progress lists on
/// [BalancedRequest.progress] and returns a [RawResult] code.
String balancedReduceInWorker(BalancedRequest r) {
  try {
    return _balanced(r);
  } catch (_) {
    return RawResult.failed;
  }
}

String _balanced(BalancedRequest r) {
  final p = pdfium_bindings.getPdfium(modulePath: r.modulePath);
  final cancel = Pointer<Uint8>.fromAddress(r.cancelFlagAddress);
  final arena = Arena();
  try {
    final doc = p.FPDF_LoadDocument(r.input.toNativeUtf8(allocator: arena).cast(), nullptr);
    if (doc == nullptr) {
      return p.FPDF_GetLastError() == pdfium_bindings.FPDF_ERR_PASSWORD ? RawResult.encrypted : RawResult.corrupt;
    }
    try {
      final n = p.FPDF_GetPageCount(doc);

      // Pass 1: fingerprint image streams so shared images (logos repeated on
      // every page) are left alone — replacing one copy would duplicate data.
      final seen = <String, int>{};
      for (var i = 0; i < n; i++) {
        if (cancel.value != 0) return RawResult.cancelled;
        final page = p.FPDF_LoadPage(doc, i);
        if (page == nullptr) continue;
        _forEachImage(p, page, (obj) {
          final key = _fingerprint(p, obj, arena);
          seen[key] = (seen[key] ?? 0) + 1;
        });
        p.FPDF_ClosePage(page);
      }

      // Pass 2: recompress large, unique, single-filter DCT images.
      for (var i = 0; i < n; i++) {
        if (cancel.value != 0) return RawResult.cancelled;
        r.progress.send([i, n]);
        final page = p.FPDF_LoadPage(doc, i);
        if (page == nullptr) continue;
        var changed = false;
        final pages = arena<pdfium_bindings.FPDF_PAGE>(1)..value = page;
        _forEachImage(p, page, (obj) {
          if (cancel.value != 0) return;
          if (seen[_fingerprint(p, obj, arena)] != 1) return;
          if (_recompress(p, obj, page, pages, r, arena)) changed = true;
        });
        if (changed) p.FPDFPage_GenerateContent(page);
        p.FPDF_ClosePage(page);
      }
      if (cancel.value != 0) return RawResult.cancelled;
      return _save(p, doc, r.output) ? RawResult.ok : RawResult.failed;
    } finally {
      p.FPDF_CloseDocument(doc);
    }
  } finally {
    arena.releaseAll();
  }
}

void _forEachImage(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_PAGE page, void Function(pdfium_bindings.FPDF_PAGEOBJECT) f) {
  final count = p.FPDFPage_CountObjects(page);
  for (var k = 0; k < count; k++) {
    final obj = p.FPDFPage_GetObject(page, k);
    if (obj != nullptr && p.FPDFPageObj_GetType(obj) == pdfium_bindings.FPDF_PAGEOBJ_IMAGE) f(obj);
  }
}

String _fingerprint(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_PAGEOBJECT obj, Arena arena) {
  final w = arena<UnsignedInt>(), h = arena<UnsignedInt>();
  p.FPDFImageObj_GetImagePixelSize(obj, w, h);
  final len = p.FPDFImageObj_GetImageDataRaw(obj, nullptr, 0);
  return '${w.value}x${h.value}:$len';
}

bool _recompress(
  pdfium_bindings.PDFium p,
  pdfium_bindings.FPDF_PAGEOBJECT obj,
  pdfium_bindings.FPDF_PAGE page,
  Pointer<pdfium_bindings.FPDF_PAGE> pages,
  BalancedRequest r,
  Arena arena,
) {
  // Only single-filter DCT (JPEG) images: keeps transparency, masks and line art untouched.
  if (p.FPDFImageObj_GetImageFilterCount(obj) != 1) return false;
  final nameBuf = arena<Uint8>(32);
  final nameLen = p.FPDFImageObj_GetImageFilter(obj, 0, nameBuf.cast(), 32);
  if (nameLen <= 1 || String.fromCharCodes(nameBuf.asTypedList(nameLen - 1)) != 'DCTDecode') return false;

  final meta = arena<pdfium_bindings.FPDF_IMAGEOBJ_METADATA>();
  if (p.FPDFImageObj_GetImageMetadata(obj, page, meta) == 0) return false;
  if (meta.ref.bits_per_pixel <= 1) return false;

  final pw = arena<UnsignedInt>(), ph = arena<UnsignedInt>();
  if (p.FPDFImageObj_GetImagePixelSize(obj, pw, ph) == 0) return false;
  final l = arena<Float>(), b = arena<Float>(), rt = arena<Float>(), t = arena<Float>();
  if (p.FPDFPageObj_GetBounds(obj, l, b, rt, t) == 0) return false;
  final bw = (rt.value - l.value).abs(), bh = (t.value - b.value).abs();
  if (bw < 1 || bh < 1 || pw.value == 0 || ph.value == 0) return false;
  final effDpi = math.min(pw.value / (bw / 72), ph.value / (bh / 72));
  if (effDpi <= r.skipBelowDpi) return false;

  final rawLen = p.FPDFImageObj_GetImageDataRaw(obj, nullptr, 0);
  if (rawLen <= 0) return false;

  final bmp = p.FPDFImageObj_GetBitmap(obj);
  if (bmp == nullptr) return false;
  img.Image decoded;
  try {
    final decodedOrNull = _bitmapToImage(p, bmp);
    if (decodedOrNull == null) return false;
    decoded = decodedOrNull;
  } finally {
    p.FPDFBitmap_Destroy(bmp);
  }
  final scale = r.targetDpi / effDpi; // < 1, never upscales
  final nw = math.max(1, (decoded.width * scale).round());
  final nh = math.max(1, (decoded.height * scale).round());
  final resized = img.copyResize(decoded, width: nw, height: nh, interpolation: img.Interpolation.average);
  final jpeg = img.encodeJpg(resized, quality: r.jpegQuality);
  if (jpeg.length >= rawLen * 0.9) return false;

  return _loadJpegInline(p, pages, obj, jpeg);
}

img.Image? _bitmapToImage(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_BITMAP bmp) {
  final w = p.FPDFBitmap_GetWidth(bmp), h = p.FPDFBitmap_GetHeight(bmp);
  final stride = p.FPDFBitmap_GetStride(bmp);
  final format = p.FPDFBitmap_GetFormat(bmp);
  final buf = p.FPDFBitmap_GetBuffer(bmp).cast<Uint8>();
  if (w <= 0 || h <= 0 || buf == nullptr) return null;
  final src = buf.asTypedList(stride * h);
  final out = img.Image(width: w, height: h, numChannels: 3);
  for (var y = 0; y < h; y++) {
    final row = y * stride;
    for (var x = 0; x < w; x++) {
      switch (format) {
        case pdfium_bindings.FPDFBitmap_Gray:
          final v = src[row + x];
          out.setPixelRgb(x, y, v, v, v);
        case pdfium_bindings.FPDFBitmap_BGR:
          final o = row + x * 3;
          out.setPixelRgb(x, y, src[o + 2], src[o + 1], src[o]);
        case pdfium_bindings.FPDFBitmap_BGRx:
        case pdfium_bindings.FPDFBitmap_BGRA:
          final o = row + x * 4;
          out.setPixelRgb(x, y, src[o + 2], src[o + 1], src[o]);
        default:
          return null;
      }
    }
  }
  return out;
}

// --- FPDF_FILEACCESS over an in-memory JPEG -------------------------------

Uint8List? _currentJpeg;

int _getBlock(Pointer<Void> param, int position, Pointer<UnsignedChar> pBuf, int size) {
  final data = _currentJpeg;
  if (data == null || position + size > data.length) return 0;
  pBuf.cast<Uint8>().asTypedList(size).setRange(0, size, data, position);
  return 1;
}

bool _loadJpegInline(
  pdfium_bindings.PDFium p,
  Pointer<pdfium_bindings.FPDF_PAGE> pages,
  pdfium_bindings.FPDF_PAGEOBJECT obj,
  Uint8List jpeg,
) {
  final callable = NativeCallable<
      Int Function(Pointer<Void>, UnsignedLong, Pointer<UnsignedChar>, UnsignedLong)>.isolateLocal(
    _getBlock,
    exceptionalReturn: 0,
  );
  final fa = calloc<pdfium_bindings.FPDF_FILEACCESS>();
  try {
    _currentJpeg = jpeg;
    fa.ref
      ..m_FileLen = jpeg.length
      ..m_GetBlock = callable.nativeFunction
      ..m_Param = nullptr;
    return p.FPDFImageObj_LoadJpegFileInline(pages, 1, obj, fa) != 0;
  } finally {
    _currentJpeg = null;
    calloc.free(fa);
    callable.close();
  }
}

// --- FPDF_FILEWRITE streaming to disk --------------------------------------

RandomAccessFile? _sink;
bool _writeFailed = false;

int _writeBlock(Pointer<pdfium_bindings.FPDF_FILEWRITE_> self, Pointer<Void> data, int size) {
  final sink = _sink;
  if (sink == null) return 0;
  try {
    sink.writeFromSync(data.cast<Uint8>().asTypedList(size));
    return 1;
  } catch (_) {
    _writeFailed = true;
    return 0;
  }
}

bool _save(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_DOCUMENT doc, String output) {
  final callable = NativeCallable<
      Int Function(Pointer<pdfium_bindings.FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)>.isolateLocal(
    _writeBlock,
    exceptionalReturn: 0,
  );
  final fw = calloc<pdfium_bindings.FPDF_FILEWRITE_>();
  final raf = File(output).openSync(mode: FileMode.write);
  try {
    _sink = raf;
    _writeFailed = false;
    fw.ref
      ..version = 1
      ..WriteBlock = callable.nativeFunction;
    final ok = p.FPDF_SaveAsCopy(doc, fw, pdfium_bindings.FPDF_NO_INCREMENTAL) != 0;
    raf.flushSync();
    return ok && !_writeFailed;
  } finally {
    _sink = null;
    raf.closeSync();
    calloc.free(fw);
    callable.close();
  }
}
