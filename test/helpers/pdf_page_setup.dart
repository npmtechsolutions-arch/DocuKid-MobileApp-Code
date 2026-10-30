// Test fixtures (TESTING corpus PDF-04 rotated_pages.pdf, PDF-15
// cropbox_offset.pdf): sets /Rotate and an inset crop box with PDFium, which
// the `pdf` package can't write. Runs in pdfrx's PDFium worker. Used by the
// host stamper test and the on-device accuracy test.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;

class PageSetupRequest {
  const PageSetupRequest(this.input, this.output, this.module, {this.quarterTurns = const [], this.cropInset = 0});
  final String input, output;
  final String? module;

  /// Per page, repeating: 0–3 quarter turns clockwise.
  final List<int> quarterTurns;

  /// Points to inset the crop box from the media box on every side.
  final double cropInset;
}

/// '' or the failing step.
String setupPagesInWorker(PageSetupRequest r) {
  final pd = pdfium.getPdfium(modulePath: r.module);
  return using((arena) {
    final doc = pd.FPDF_LoadDocument(r.input.toNativeUtf8(allocator: arena).cast(), nullptr);
    if (doc == nullptr) return 'load';
    try {
      for (var i = 0, n = pd.FPDF_GetPageCount(doc); i < n; i++) {
        final page = pd.FPDF_LoadPage(doc, i);
        // The input pages are unrotated, so this is the media box size.
        final w = pd.FPDF_GetPageWidthF(page), h = pd.FPDF_GetPageHeightF(page);
        if (r.quarterTurns.isNotEmpty) pd.FPDFPage_SetRotation(page, r.quarterTurns[i % r.quarterTurns.length]);
        if (r.cropInset > 0) {
          final c = r.cropInset;
          pd.FPDFPage_SetCropBox(page, c, c, w - c, h - c);
        }
        pd.FPDF_ClosePage(page);
      }
      return _save(pd, doc, r.output) ? '' : 'save';
    } finally {
      pd.FPDF_CloseDocument(doc);
    }
  });
}

RandomAccessFile? _sink;
int _writeBlock(Pointer<pdfium.FPDF_FILEWRITE_> self, Pointer<Void> data, int size) {
  _sink!.writeFromSync(data.cast<Uint8>().asTypedList(size));
  return 1;
}

bool _save(pdfium.PDFium pd, pdfium.FPDF_DOCUMENT doc, String out) {
  final cb = NativeCallable<Int Function(Pointer<pdfium.FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)>.isolateLocal(
      _writeBlock,
      exceptionalReturn: 0);
  final fw = calloc<pdfium.FPDF_FILEWRITE_>();
  final raf = File(out).openSync(mode: FileMode.write);
  try {
    _sink = raf;
    fw.ref
      ..version = 1
      ..WriteBlock = cb.nativeFunction;
    return pd.FPDF_SaveAsCopy(doc, fw, pdfium.FPDF_NO_INCREMENTAL) != 0;
  } finally {
    _sink = null;
    raf.closeSync();
    calloc.free(fw);
    cb.close();
  }
}
