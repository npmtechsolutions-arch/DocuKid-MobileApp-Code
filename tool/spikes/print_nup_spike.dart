// T13.0 spike (throwaway, RELEASE_PRINT §4.3, ADR-070): N-up composition with
// PDFium form XObjects through the pdfium_dart bindings pdfrx ships. Not app
// code — the real composer is T13.2. Runs in pdfrx's PDFium worker
// (`PdfrxEntryFunctions.compute`) like every other raw PDFium call.
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;

enum SpikeScale { fit, fill, actual }

class NupRequest {
  const NupRequest({
    required this.input,
    required this.output,
    required this.modulePath,
    required this.sheetW,
    required this.sheetH,
    required this.cols,
    required this.rows,
    this.margin = 17,
    this.gap = 11.34, // 4 mm
    this.scale = SpikeScale.fit,
    this.debug = false,
  });
  final bool debug;
  final String input, output;
  final String? modulePath;
  final double sheetW, sheetH, margin, gap;
  final int cols, rows;
  final SpikeScale scale;
}

/// Matrix [a b c d e f]: x' = a·x + c·y + e, y' = b·x + d·y + f.
typedef M = (double, double, double, double, double, double);

M scaleThenMove(M m, double s, double tx, double ty) =>
    (m.$1 * s, m.$2 * s, m.$3 * s, m.$4 * s, m.$5 * s + tx, m.$6 * s + ty);

/// The cells of one sheet, left→right, top→bottom, in PDF space (y up).
List<(double, double, double, double)> cells(NupRequest r) {
  final aw = r.sheetW - 2 * r.margin, ah = r.sheetH - 2 * r.margin;
  final cw = (aw - (r.cols - 1) * r.gap) / r.cols, ch = (ah - (r.rows - 1) * r.gap) / r.rows;
  return [
    for (var row = 0; row < r.rows; row++)
      for (var col = 0; col < r.cols; col++)
        (r.margin + col * (cw + r.gap), r.sheetH - r.margin - (row + 1) * ch - row * r.gap, cw, ch),
  ];
}

/// Composes [r.input] onto sheets; returns '' or what failed (no names).
String nupInWorker(NupRequest r) => _nup(r, debug: r.debug);

String _nup(NupRequest r, {bool debug = false}) {
  final p = pdfium.getPdfium(modulePath: r.modulePath);
  final arena = Arena();
  final src = p.FPDF_LoadDocument(r.input.toNativeUtf8(allocator: arena).cast(), nullptr);
  if (src == nullptr) return 'load';
  final out = p.FPDF_CreateNewDocument();
  final temps = <pdfium.FPDF_DOCUMENT>[];
  final xobjects = <pdfium.FPDF_XOBJECT>[];
  try {
    final n = p.FPDF_GetPageCount(src);
    final grid = cells(r);
    final box = arena<pdfium.FS_RECTF>();
    final mx = arena<pdfium.FS_MATRIX>();
    bool setMatrix(pdfium.FPDF_PAGEOBJECT o, M m) {
      mx.ref
        ..a = m.$1
        ..b = m.$2
        ..c = m.$3
        ..d = m.$4
        ..e = m.$5
        ..f = m.$6;
      return p.FPDFPageObj_SetMatrix(o, mx) != 0;
    }

    for (var sheetIdx = 0; sheetIdx * grid.length < n; sheetIdx++) {
      final sheet = p.FPDFPage_New(out, sheetIdx, r.sheetW, r.sheetH);
      if (sheet == nullptr) return 'sheet';
      try {
        for (var c = 0; c < grid.length && sheetIdx * grid.length + c < n; c++) {
          final si = sheetIdx * grid.length + c;
          final page = p.FPDF_LoadPage(src, si);
          if (page == nullptr) return 'page';
          double x0, y0, x1, y1;
          int turns;
          try {
            if (p.FPDF_GetPageBoundingBox(page, box) == 0) return 'bbox';
            (x0, y0, x1, y1) = (box.ref.left, box.ref.bottom, box.ref.right, box.ref.top);
            turns = p.FPDFPage_GetRotation(page);
          } finally {
            p.FPDF_ClosePage(page);
          }
          // Found in this spike: FPDF_NewXObjectFromPage gives the page AS
          // DISPLAYED — /Rotate applied and the crop box's lower-left at the
          // origin — so it spans (0,0)-(vw,vh) in visual size and only needs
          // scale + move. (A rotation matrix on top turned /Rotate 90 pages
          // upside down.)
          final w0 = x1 - x0, h0 = y1 - y0;
          final (vw, vh) = turns.isOdd ? (h0, w0) : (w0, h0);
          if (debug) {
            // ignore: avoid_print
            print('SPIKE page ${si + 1}: /Rotate ${turns * 90}, box ($x0,$y0,$x1,$y1) → visual ${vw.round()}×${vh.round()}');
          }
          const M up = (1, 0, 0, 1, 0, 0);
          final (cx, cy, cw, ch) = grid[c];
          final s = switch (r.scale) {
            SpikeScale.fit => math.min(cw / vw, ch / vh),
            SpikeScale.fill => math.max(cw / vw, ch / vh),
            SpikeScale.actual => 1.0,
          };
          final xobj = p.FPDF_NewXObjectFromPage(out, src, si);
          if (xobj == nullptr) return 'xobject';
          xobjects.add(xobj);
          final form = p.FPDF_NewFormObjectFromXObject(xobj);
          if (form == nullptr) return 'form';
          if (r.scale == SpikeScale.fit) {
            // Fit never overflows the cell: place directly.
            if (!setMatrix(form, scaleThenMove(up, s, cx + (cw - s * vw) / 2, cy + (ch - s * vh) / 2))) return 'matrix';
            p.FPDFPage_InsertObject(sheet, form);
          } else {
            // Fill / actual overflow: clip on a cell-sized page, then place
            // that page as one XObject (still vector).
            final tmp = p.FPDF_CreateNewDocument();
            temps.add(tmp);
            final cell = p.FPDFPage_New(tmp, 0, cw, ch);
            final inner = p.FPDF_NewXObjectFromPage(tmp, src, si);
            if (inner == nullptr) return 'inner';
            xobjects.add(inner);
            final innerForm = p.FPDF_NewFormObjectFromXObject(inner);
            p.FPDFPageObj_Destroy(form);
            if (!setMatrix(innerForm, scaleThenMove(up, s, (cw - s * vw) / 2, (ch - s * vh) / 2))) return 'inner matrix';
            p.FPDFPage_InsertObject(cell, innerForm);
            final clip = p.FPDF_CreateClipPath(0, 0, cw, ch);
            p.FPDFPage_InsertClipPath(cell, clip);
            p.FPDF_DestroyClipPath(clip);
            if (p.FPDFPage_GenerateContent(cell) == 0) return 'cell content';
            p.FPDF_ClosePage(cell);
            final cellX = p.FPDF_NewXObjectFromPage(out, tmp, 0);
            if (cellX == nullptr) return 'cell xobject';
            xobjects.add(cellX);
            final cellForm = p.FPDF_NewFormObjectFromXObject(cellX);
            if (!setMatrix(cellForm, (1, 0, 0, 1, cx, cy))) return 'cell matrix';
            p.FPDFPage_InsertObject(sheet, cellForm);
          }
        }
        if (p.FPDFPage_GenerateContent(sheet) == 0) return 'content';
      } finally {
        p.FPDF_ClosePage(sheet);
      }
    }
    return _save(p, out, r.output) ? '' : 'save';
  } finally {
    for (final x in xobjects) {
      p.FPDF_CloseXObject(x);
    }
    for (final t in temps) {
      p.FPDF_CloseDocument(t);
    }
    p.FPDF_CloseDocument(out);
    p.FPDF_CloseDocument(src);
    arena.releaseAll();
  }
}

RandomAccessFile? _sink;
bool _failed = false;

int _write(Pointer<pdfium.FPDF_FILEWRITE_> _, Pointer<Void> data, int size) {
  try {
    _sink!.writeFromSync(data.cast<Uint8>().asTypedList(size));
    return 1;
  } catch (_) {
    _failed = true;
    return 0;
  }
}

bool _save(pdfium.PDFium p, pdfium.FPDF_DOCUMENT doc, String output) {
  final cb = NativeCallable<Int Function(Pointer<pdfium.FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)>.isolateLocal(_write,
      exceptionalReturn: 0);
  final fw = calloc<pdfium.FPDF_FILEWRITE_>();
  final raf = File(output).openSync(mode: FileMode.write);
  try {
    _sink = raf;
    _failed = false;
    fw.ref
      ..version = 1
      ..WriteBlock = cb.nativeFunction;
    final ok = p.FPDF_SaveAsCopy(doc, fw, pdfium.FPDF_NO_INCREMENTAL) != 0;
    raf.flushSync();
    return ok && !_failed;
  } finally {
    _sink = null;
    raf.closeSync();
    calloc.free(fw);
    cb.close();
  }
}
