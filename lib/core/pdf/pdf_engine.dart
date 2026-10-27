import 'dart:ui' as ui;

import '../files/picked_file.dart';
import '../operation/tool_operation.dart';
import 'page_edit.dart';
import 'pdf_options.dart';

/// Reducer pre-analysis (FR-CMP-06).
class PdfAnalysis {
  const PdfAnalysis({required this.pageCount, required this.imageCount, required this.imageHeavy});
  final int pageCount;

  /// Extrapolated from the first ≤ 20 pages.
  final int imageCount;
  final bool imageHeavy;
}

abstract interface class PdfEngine {
  /// Throws AppError(encryptedDocument | corruptFile | permissionLost).
  Future<PdfMeta> inspect(String path);

  Future<PdfAnalysis> analyse(String path, int fileBytes);

  /// Renders page [index] (0-based, original rotation) at [targetWidthPx].
  Future<ui.Image?> renderPage(String path, int index, {required int targetWidthPx});

  /// Releases any document kept open for rendering.
  Future<void> close(String path);

  Future<void> merge(List<String> inputs, String out, JobContext ctx);
  Future<void> organize(String input, List<PageEdit> edits, String out, JobContext ctx);
  Future<void> reduce(String input, String out, ReduceLevel level, JobContext ctx);

  /// Builds a PDF of full-page JPEGs (pt sizes per page), for Image→PDF chunks
  /// and Strong reduction.
  Future<void> combineFiles(List<String> inputs, String out);
}
