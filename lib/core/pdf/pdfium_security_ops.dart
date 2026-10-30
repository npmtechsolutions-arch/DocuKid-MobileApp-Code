import 'package:pdfrx/pdfrx.dart';

import '../errors/app_error.dart';
import 'pdf_security.dart';
import 'pdfium_raw_ops.dart';

/// [PdfiumSecurityOps] in pdfrx's PDFium worker (both platforms).
class PdfrxSecurityOps implements PdfiumSecurityOps {
  const PdfrxSecurityOps();

  @override
  Future<PdfProtection> inspect(String path) async {
    final r = await PdfrxEntryFunctions.instance
        .compute(inspectSecurityInWorker, SecurityRequest(path, Pdfrx.pdfiumModulePath));
    return switch (r) {
      'none' => PdfProtection.none,
      'openPassword' => PdfProtection.openPassword,
      'ownerOnly' => PdfProtection.ownerOnly,
      _ => throw const AppError(AppErrorCode.corruptFile),
    };
  }

  @override
  Future<String> removeSecurity(String inPath, String outPath, String password) =>
      PdfrxEntryFunctions.instance.compute(
          removeSecurityInWorker, SecurityRequest(inPath, Pdfrx.pdfiumModulePath, output: outPath, password: password));

  @override
  Future<int> pageCount(String path, String password) async {
    final n = await PdfrxEntryFunctions.instance
        .compute(pageCountInWorker, SecurityRequest(path, Pdfrx.pdfiumModulePath, password: password));
    if (n < -1) throw const AppError(AppErrorCode.corruptFile);
    return n;
  }
}
