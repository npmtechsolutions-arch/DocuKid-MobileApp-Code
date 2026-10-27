import 'dart:io';

import '../errors/app_error.dart';
import '../image/image_header.dart';
import '../image/image_options.dart';
import '../pdf/pdf_engine.dart';

const _invalid = AppError(AppErrorCode.outputValidationFailed);

/// ARCHITECTURE §5.4 (images): exists, size > 0, magic bytes match, the
/// header decodes, and the dimensions match when they're expected.
Future<ImageHeader> validateImageOutput(String path, ImageFormat format, {int? width, int? height}) async {
  final f = File(path);
  if (!await f.exists() || await f.length() == 0) throw _invalid;
  final ImageHeader h;
  try {
    h = await readImageHeader(path);
  } on ImageHeaderException {
    throw _invalid;
  }
  if (h.type != format.sniffed) throw _invalid;
  if (width != null && h.displayWidth != width) throw _invalid;
  if (height != null && h.displayHeight != height) throw _invalid;
  return h;
}

/// ARCHITECTURE §5.4 (PDFs): opens, page count matches, and the first (and
/// optionally last) page renders.
Future<int> validatePdfOutput(PdfEngine engine, String path, {required int expectedPages, bool renderLast = false}) async {
  final f = File(path);
  if (!await f.exists() || await f.length() == 0) throw _invalid;
  try {
    final meta = await engine.inspect(path);
    if (meta.pageCount != expectedPages) throw _invalid;
    final first = await engine.renderPage(path, 0, targetWidthPx: 64);
    if (first == null) throw _invalid;
    first.dispose();
    if (renderLast && meta.pageCount > 1) {
      final last = await engine.renderPage(path, meta.pageCount - 1, targetWidthPx: 64);
      if (last == null) throw _invalid;
      last.dispose();
    }
    return meta.pageCount;
  } on AppError {
    throw _invalid;
  } finally {
    await engine.close(path);
  }
}
