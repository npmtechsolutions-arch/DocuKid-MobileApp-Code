import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_bindings;

import '../print/print_geometry.dart';
import '../print/print_settings.dart';
import 'stamp_geometry.dart';

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

  /// A request the document can't satisfy (e.g. a stamp on a missing page).
  static const invalid = 'invalid';
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

/// Protect/Unlock (RELEASE_V1_4 §4.5, ADR-049). [password] is used for the one
/// call and never logged; null for [inspectSecurityInWorker].
class SecurityRequest {
  const SecurityRequest(this.input, this.modulePath, {this.output, this.password});
  final String input;
  final String? output, password;
  final String? modulePath;
}

/// `none | openPassword | ownerOnly | corrupt`. A file that opens without a
/// password but has a security handler is owner-restricted.
String inspectSecurityInWorker(SecurityRequest r) {
  try {
    final p = pdfium_bindings.getPdfium(modulePath: r.modulePath);
    return using((arena) {
      final doc = p.FPDF_LoadDocument(r.input.toNativeUtf8(allocator: arena).cast(), nullptr);
      if (doc == nullptr) {
        return p.FPDF_GetLastError() == pdfium_bindings.FPDF_ERR_PASSWORD ? 'openPassword' : RawResult.corrupt;
      }
      try {
        return p.FPDF_GetSecurityHandlerRevision(doc) >= 0 ? 'ownerOnly' : 'none';
      } finally {
        p.FPDF_CloseDocument(doc);
      }
    });
  } catch (_) {
    return RawResult.corrupt;
  }
}

/// Opens with the given password only and saves a copy without security
/// (`FPDF_REMOVE_SECURITY`): `ok | wrongPassword | failed`.
String removeSecurityInWorker(SecurityRequest r) {
  try {
    final p = pdfium_bindings.getPdfium(modulePath: r.modulePath);
    return using((arena) {
      final doc = p.FPDF_LoadDocument(
          r.input.toNativeUtf8(allocator: arena).cast(), (r.password ?? '').toNativeUtf8(allocator: arena).cast());
      if (doc == nullptr) {
        return p.FPDF_GetLastError() == pdfium_bindings.FPDF_ERR_PASSWORD ? 'wrongPassword' : RawResult.failed;
      }
      try {
        return _save(p, doc, r.output!, flags: pdfium_bindings.FPDF_REMOVE_SECURITY) ? RawResult.ok : RawResult.failed;
      } finally {
        p.FPDF_CloseDocument(doc);
      }
    });
  } catch (_) {
    return RawResult.failed;
  }
}

/// Stamping (RELEASE_V1_4 §4.2, ADR-048). [stamps]: (page, png, visual rect,
/// clockwise degrees, opacity).
class StampRequest {
  const StampRequest({
    required this.input,
    required this.output,
    required this.stamps,
    required this.cancelFlagAddress,
    required this.progress,
    this.modulePath,
  });
  final String input, output;
  final List<(int, String, Rect, double, double)> stamps;

  /// Address of a 1-byte native flag set by the main isolate to cancel.
  final int cancelFlagAddress;

  /// `[done, total]` per stamped page, then [finished].
  final SendPort progress;
  final String? modulePath;

  static const finished = 'finished';

  /// 300 dpi of the placed size is the renderers' job; this caps any input.
  static const maxImageSide = 2400;
}

/// Worker entry point; returns a [RawResult] code.
String stampInWorker(StampRequest r) {
  try {
    return _stamp(r);
  } catch (_) {
    return RawResult.failed;
  } finally {
    r.progress.send(StampRequest.finished);
  }
}

String _stamp(StampRequest r) {
  final p = pdfium_bindings.getPdfium(modulePath: r.modulePath);
  final cancel = Pointer<Uint8>.fromAddress(r.cancelFlagAddress);
  final arena = Arena();
  final stampDocs = <pdfium_bindings.FPDF_DOCUMENT>[];
  final xobjects = <String, pdfium_bindings.FPDF_XOBJECT>{};
  final buffers = <Pointer<Uint8>>[];
  final doc = p.FPDF_LoadDocument(r.input.toNativeUtf8(allocator: arena).cast(), nullptr);
  if (doc == nullptr) {
    arena.releaseAll();
    return p.FPDF_GetLastError() == pdfium_bindings.FPDF_ERR_PASSWORD ? RawResult.encrypted : RawResult.corrupt;
  }
  try {
    final n = p.FPDF_GetPageCount(doc);
    final byPage = <int, List<(int, String, Rect, double, double)>>{};
    for (final s in r.stamps) {
      if (s.$1 < 0 || s.$1 >= n) return RawResult.invalid;
      (byPage[s.$1] ??= []).add(s);
    }
    final pages = byPage.keys.toList()..sort();
    final box = arena<pdfium_bindings.FS_RECTF>();
    final matrix = arena<pdfium_bindings.FS_MATRIX>();
    for (var done = 0; done < pages.length; done++) {
      if (cancel.value != 0) return RawResult.cancelled;
      r.progress.send([done, pages.length]);
      final page = p.FPDF_LoadPage(doc, pages[done]);
      if (page == nullptr) return RawResult.failed;
      try {
        // The visible area: media box ∩ crop box, in user space.
        if (p.FPDF_GetPageBoundingBox(page, box) == 0) return RawResult.failed;
        final geo = PageGeometry.normalised(
            x0: box.ref.left, y0: box.ref.bottom, x1: box.ref.right, y1: box.ref.top, rotation: p.FPDFPage_GetRotation(page) * 90);
        for (final (_, png, rect, degrees, opacity) in byPage[pages[done]]!) {
          final key = '$opacity|$png';
          final xobj = xobjects[key] ??= _stampXObject(p, doc, png, opacity, stampDocs, buffers, arena);
          if (xobj == nullptr) return RawResult.failed;
          final m = placementMatrix(geo, rect, degrees);
          final form = p.FPDF_NewFormObjectFromXObject(xobj);
          if (form == nullptr) return RawResult.failed;
          matrix.ref
            ..a = m.a
            ..b = m.b
            ..c = m.c
            ..d = m.d
            ..e = m.e
            ..f = m.f;
          if (p.FPDFPageObj_SetMatrix(form, matrix) == 0) {
            p.FPDFPageObj_Destroy(form);
            return RawResult.failed;
          }
          p.FPDFPage_InsertObject(page, form);
        }
        if (p.FPDFPage_GenerateContent(page) == 0) return RawResult.failed;
      } finally {
        p.FPDF_ClosePage(page);
      }
    }
    if (cancel.value != 0) return RawResult.cancelled;
    return _save(p, doc, r.output) ? RawResult.ok : RawResult.failed;
  } finally {
    for (final x in xobjects.values) {
      if (x != nullptr) p.FPDF_CloseXObject(x);
    }
    for (final d in stampDocs) {
      p.FPDF_CloseDocument(d);
    }
    for (final b in buffers) {
      calloc.free(b);
    }
    p.FPDF_CloseDocument(doc);
    arena.releaseAll();
  }
}

/// The PNG as one image on a 1×1 pt page of its own document, turned into a
/// form XObject of [doc] (ADR-048: +3 KB/page instead of a bitmap per page).
/// Straight alpha with the opacity baked in. nullptr on failure.
pdfium_bindings.FPDF_XOBJECT _stampXObject(
  pdfium_bindings.PDFium p,
  pdfium_bindings.FPDF_DOCUMENT doc,
  String pngPath,
  double opacity,
  List<pdfium_bindings.FPDF_DOCUMENT> stampDocs,
  List<Pointer<Uint8>> buffers,
  Arena arena,
) {
  var im = img.decodePng(File(pngPath).readAsBytesSync());
  if (im == null) return nullptr;
  // No explicit alpha: `convert` would overwrite the PNG's own; a missing
  // channel is filled opaque.
  im = im.convert(format: img.Format.uint8, numChannels: 4);
  final long = math.max(im.width, im.height);
  if (long > StampRequest.maxImageSide) {
    im = im.width >= im.height
        ? img.copyResize(im, width: StampRequest.maxImageSide, interpolation: img.Interpolation.average)
        : img.copyResize(im, height: StampRequest.maxImageSide, interpolation: img.Interpolation.average);
  }
  final w = im.width, h = im.height;
  final bgra = im.getBytes(order: img.ChannelOrder.bgra);
  final buf = calloc<Uint8>(w * h * 4);
  buffers.add(buf);
  final view = buf.asTypedList(w * h * 4)..setAll(0, bgra);
  if (opacity < 1) {
    for (var i = 3; i < view.length; i += 4) {
      view[i] = (view[i] * opacity).round();
    }
  }
  final stampDoc = p.FPDF_CreateNewDocument();
  if (stampDoc == nullptr) return nullptr;
  stampDocs.add(stampDoc);
  final sp = p.FPDFPage_New(stampDoc, 0, 1, 1);
  if (sp == nullptr) return nullptr;
  final bmp = p.FPDFBitmap_CreateEx(w, h, pdfium_bindings.FPDFBitmap_BGRA, buf.cast(), w * 4);
  try {
    final obj = p.FPDFPageObj_NewImageObj(stampDoc);
    final pages = arena<pdfium_bindings.FPDF_PAGE>()..value = sp;
    if (p.FPDFImageObj_SetBitmap(pages, 1, obj, bmp) == 0 || p.FPDFImageObj_SetMatrix(obj, 1, 0, 0, 1, 0, 0) == 0) {
      p.FPDFPageObj_Destroy(obj);
      return nullptr;
    }
    p.FPDFPage_InsertObject(sp, obj);
    if (p.FPDFPage_GenerateContent(sp) == 0) return nullptr;
  } finally {
    p.FPDFBitmap_Destroy(bmp);
    p.FPDF_ClosePage(sp);
  }
  return p.FPDF_NewXObjectFromPage(doc, stampDoc, 0);
}

/// Pages when opened with the password; -1 wrong password, -2 can't open.
int pageCountInWorker(SecurityRequest r) {
  try {
    final p = pdfium_bindings.getPdfium(modulePath: r.modulePath);
    return using((arena) {
      final doc = p.FPDF_LoadDocument(
          r.input.toNativeUtf8(allocator: arena).cast(), (r.password ?? '').toNativeUtf8(allocator: arena).cast());
      if (doc == nullptr) return p.FPDF_GetLastError() == pdfium_bindings.FPDF_ERR_PASSWORD ? -1 : -2;
      try {
        return p.FPDF_GetPageCount(doc);
      } finally {
        p.FPDF_CloseDocument(doc);
      }
    });
  } catch (_) {
    return -2;
  }
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

// --- Print sheets (RELEASE_PRINT §4.3, ADR-070) ----------------------------

class PrintSheetsRequest {
  const PrintSheetsRequest({
    required this.input,
    required this.output,
    required this.settings,
    required this.endWords,
    required this.cancelFlagAddress,
    required this.progress,
    this.modulePath,
  });
  final String input, output;
  final PrintSettings settings;

  /// The words for the last page in a range ("end" plus the ARB alias).
  final Set<String> endWords;

  /// Address of a 1-byte native flag set by the main isolate to cancel.
  final int cancelFlagAddress;

  /// `[done, total]` per sheet, then [StampRequest.finished].
  final SendPort progress;
  final String? modulePath;
}

/// A [RawResult] code and, on success, each sheet's size in points.
typedef PrintSheetsResult = ({String code, List<(double, double)> sheets});

/// Worker entry point.
PrintSheetsResult printSheetsInWorker(PrintSheetsRequest r) {
  try {
    return _printSheets(r);
  } catch (_) {
    return (code: RawResult.failed, sheets: const []);
  } finally {
    r.progress.send(StampRequest.finished);
  }
}

PrintSheetsResult _printSheets(PrintSheetsRequest r) {
  PrintSheetsResult fail(String code) => (code: code, sheets: const []);
  final p = pdfium_bindings.getPdfium(modulePath: r.modulePath);
  final cancel = Pointer<Uint8>.fromAddress(r.cancelFlagAddress);
  final arena = Arena();
  final src = p.FPDF_LoadDocument(r.input.toNativeUtf8(allocator: arena).cast(), nullptr);
  if (src == nullptr) {
    arena.releaseAll();
    return fail(p.FPDF_GetLastError() == pdfium_bindings.FPDF_ERR_PASSWORD ? RawResult.encrypted : RawResult.corrupt);
  }
  final out = p.FPDF_CreateNewDocument();
  try {
    final n = p.FPDF_GetPageCount(src);
    final selected = resolvePages(n, r.settings.pages, endWords: r.endWords);
    if (selected.error != null || selected.pages.isEmpty) return fail(RawResult.invalid);

    // Visual sizes (crop box, /Rotate applied): how page XObjects come.
    final box = arena<pdfium_bindings.FS_RECTF>();
    final sizes = <int, Size>{};
    for (final i in selected.pages) {
      if (sizes.containsKey(i)) continue;
      if (cancel.value != 0) return fail(RawResult.cancelled);
      final page = p.FPDF_LoadPage(src, i);
      if (page == nullptr) return fail(RawResult.corrupt);
      try {
        if (p.FPDF_GetPageBoundingBox(page, box) == 0) return fail(RawResult.corrupt);
        final w = (box.ref.right - box.ref.left).abs(), h = (box.ref.top - box.ref.bottom).abs();
        sizes[i] = p.FPDFPage_GetRotation(page).isOdd ? Size(h, w) : Size(w, h);
      } finally {
        p.FPDF_ClosePage(page);
      }
    }
    final plan = planPdfSheets([for (var i = 0; i < n; i++) sizes[i] ?? Size.zero], selected.pages, r.settings);

    final matrix = arena<pdfium_bindings.FS_MATRIX>();
    bool place(pdfium_bindings.FPDF_PAGE page, pdfium_bindings.FPDF_DOCUMENT doc, pdfium_bindings.FPDF_DOCUMENT from,
        int index, (double, double, double, double, double, double) m) {
      final x = p.FPDF_NewXObjectFromPage(doc, from, index);
      if (x == nullptr) return false;
      // Form objects made from it stay valid after the XObject is closed.
      final form = p.FPDF_NewFormObjectFromXObject(x);
      p.FPDF_CloseXObject(x);
      if (form == nullptr) return false;
      matrix.ref
        ..a = m.$1
        ..b = m.$2
        ..c = m.$3
        ..d = m.$4
        ..e = m.$5
        ..f = m.$6;
      if (p.FPDFPageObj_SetMatrix(form, matrix) == 0) {
        p.FPDFPageObj_Destroy(form);
        return false;
      }
      p.FPDFPage_InsertObject(page, form);
      return true;
    }

    for (final (si, sheet) in plan.indexed) {
      if (cancel.value != 0) return fail(RawResult.cancelled);
      r.progress.send([si, plan.length]);
      final page = p.FPDFPage_New(out, si, sheet.size.width, sheet.size.height);
      if (page == nullptr) return fail(RawResult.failed);
      try {
        for (final placed in sheet.pages) {
          final pl = placed.placement;
          if (!placed.clip) {
            if (!place(page, out, src, placed.source, pl.pdfMatrix(sheet.size.height))) return fail(RawResult.failed);
            continue;
          }
          // No per-object clip in PDFium: draw on a cell-sized page with a
          // clip path, then place that page as one XObject (still vector).
          final cell = placed.cell;
          final tmp = p.FPDF_CreateNewDocument();
          try {
            final cellPage = p.FPDFPage_New(tmp, 0, cell.width, cell.height);
            if (cellPage == nullptr) return fail(RawResult.failed);
            try {
              final inCell = Placement(
                  rect: pl.rect.shift(-cell.topLeft), scale: pl.scale, quarterTurn: pl.quarterTurn, overflows: pl.overflows);
              if (!place(cellPage, tmp, src, placed.source, inCell.pdfMatrix(cell.height))) return fail(RawResult.failed);
              final clip = p.FPDF_CreateClipPath(0, 0, cell.width, cell.height);
              p.FPDFPage_InsertClipPath(cellPage, clip);
              p.FPDF_DestroyClipPath(clip);
              if (p.FPDFPage_GenerateContent(cellPage) == 0) return fail(RawResult.failed);
            } finally {
              p.FPDF_ClosePage(cellPage);
            }
            if (!place(page, out, tmp, 0, (1, 0, 0, 1, cell.left, sheet.size.height - cell.bottom))) {
              return fail(RawResult.failed);
            }
          } finally {
            p.FPDF_CloseDocument(tmp);
          }
        }
        if (p.FPDFPage_GenerateContent(page) == 0) return fail(RawResult.failed);
      } finally {
        p.FPDF_ClosePage(page);
      }
    }
    if (cancel.value != 0) return fail(RawResult.cancelled);
    r.progress.send([plan.length, plan.length]);
    if (!_save(p, out, r.output)) return fail(RawResult.failed);
    return (code: RawResult.ok, sheets: [for (final s in plan) (s.size.width, s.size.height)]);
  } finally {
    p.FPDF_CloseDocument(out);
    p.FPDF_CloseDocument(src);
    arena.releaseAll();
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

bool _save(pdfium_bindings.PDFium p, pdfium_bindings.FPDF_DOCUMENT doc, String output,
    {int flags = pdfium_bindings.FPDF_NO_INCREMENTAL}) {
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
    final ok = p.FPDF_SaveAsCopy(doc, fw, flags) != 0;
    raf.flushSync();
    return ok && !_writeFailed;
  } finally {
    _sink = null;
    raf.closeSync();
    calloc.free(fw);
    callable.close();
  }
}
