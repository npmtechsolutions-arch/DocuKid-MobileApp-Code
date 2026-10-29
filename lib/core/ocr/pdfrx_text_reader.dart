import 'package:pdfrx/pdfrx.dart';

import '../errors/app_error.dart';
import '../pdf/pdfium_raw_ops.dart';
import '../pdf/pdfrx_pdf_engine.dart';
import 'pdf_text_reader.dart';

/// Existing PDF text (RELEASE_V1_3 §4.6). [textPages] counts characters in
/// pdfrx's PDFium worker (`textPagesInWorker`), with text extraction only and
/// no rendering, so 300 pages stay quick; [pageText] uses pdfrx's
/// `PdfPage.loadText()` (verified in T10.0, ADR-046). A password-protected PDF
/// → `encryptedDocument`, as everywhere (rule 7).
class PdfrxTextReader implements PdfTextReader {
  const PdfrxTextReader();

  @override
  Future<List<bool>> textPages(String path) async {
    final r = await PdfrxEntryFunctions.instance
        .compute(textPagesInWorker, TextPagesRequest(path, minPageTextChars, Pdfrx.pdfiumModulePath));
    return switch (r.code) {
      RawResult.ok => r.flags,
      RawResult.encrypted => throw const AppError(AppErrorCode.encryptedDocument),
      _ => throw const AppError(AppErrorCode.corruptFile),
    };
  }

  @override
  Future<String> pageText(String path, int index) async {
    final doc = await PdfrxPdfEngine.openChecked(path);
    try {
      return (await doc.pages[index].loadText())?.fullText ?? '';
    } finally {
      await doc.dispose();
    }
  }
}
