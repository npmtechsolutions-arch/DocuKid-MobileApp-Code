import 'dart:ui' as ui;

import '../files/picked_file.dart';
import '../image/page_image_encoder.dart';
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

  /// Opens [input] once for writing many page subsets (Split, Extract;
  /// RELEASE_V1_1 §4.7). The caller must [PdfPageExtractor.close] it.
  Future<PdfPageExtractor> openExtractor(String input);

  /// Builds a PDF of full-page JPEGs (pt sizes per page), for Image→PDF chunks
  /// and Strong reduction.
  Future<void> combineFiles(List<String> inputs, String out);
}

/// An open source PDF that writes page subsets to new files.
abstract interface class PdfPageExtractor {
  int get pageCount;

  /// Writes a PDF of [pages] (0-based, in this order, rotation kept) to [out].
  Future<void> extract(List<int> pages, String out);

  /// Renders page [index] (0-based) at exactly [width]×[height] px: white
  /// background, or transparent when [transparent] (PDF to Images, §4.7).
  /// The pixels are a copy; the native bitmap is already released.
  Future<PagePixels> renderPage(int index, {required int width, required int height, required bool transparent});

  Future<void> close();
}
