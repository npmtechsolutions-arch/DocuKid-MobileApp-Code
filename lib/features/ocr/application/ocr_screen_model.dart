import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/picked_file.dart';
import '../../../core/ocr/pdf_text_reader.dart';
import 'ocr_options.dart';

enum OcrInputKind { none, images, pdf, mixed }

/// Why Run is disabled (S30 helper line).
enum OcrHelper {
  /// "Up to 50 images or one PDF".
  pick,

  /// "Choose images or one PDF, not both." (FR-OCR-01).
  mixed,
  chooseAnother,

  /// "Choose at least one result" (FR-OCR-03; also a fully text PDF with
  /// only "Searchable PDF" ticked, §4.11 ocrNothingToDo).
  chooseOutput,
}

/// Everything S30 decides from its inputs, the text check and the options
/// (RELEASE_V1_3 §3.1). Pure, so every state is unit-tested.
class OcrScreenModel {
  const OcrScreenModel({
    required this.kind,
    required this.effective,
    required this.runInputs,
    this.checkingText = false,
    this.text,
    this.helper,
    this.pagesToRecognise = 0,
  });

  final OcrInputKind kind;

  /// The PDF's text check is still running ("Checking for text…").
  final bool checkingText;

  /// The PDF's text summary, once known.
  final PdfTextSummary? text;

  /// The options to run with: a PDF that already has text on every page
  /// can't become "more searchable", so its PDF output is off.
  final OcrOptions effective;

  /// Valid inputs only (invalid images are left out, as in the batch tools).
  final List<PickedFile> runInputs;
  final OcrHelper? helper;

  /// Images, or PDF pages without text.
  final int pagesToRecognise;

  bool get pdfOutputDisabled => text?.state == PdfTextState.all;

  /// Run says "Get text": the text is extracted, nothing is recognised.
  bool get getText => text?.state == PdfTextState.all;

  bool get canRun =>
      helper == null && !checkingText && (kind == OcrInputKind.images || kind == OcrInputKind.pdf) && runInputs.isNotEmpty;

  /// FR-OCR-07: shown for PDFs whose pages will be rebuilt from images.
  bool get showRebuildNote => kind == OcrInputKind.pdf && effective.searchablePdf && pagesToRecognise > 0;

  /// §3.1 "Large job (> 30 pages)".
  bool get showLongJob => pagesToRecognise > 30;
}

OcrScreenModel ocrScreenModel({
  required List<PickedFile> files,
  required AsyncValue<List<bool>>? textPages,
  required OcrOptions options,
}) {
  if (files.isEmpty) {
    return OcrScreenModel(kind: OcrInputKind.none, effective: options, runInputs: const [], helper: OcrHelper.pick);
  }
  final pdfs = files.where((f) => f.isPdf).length;
  if (pdfs > 0 && files.length > 1) {
    return OcrScreenModel(kind: OcrInputKind.mixed, effective: options, runInputs: const [], helper: OcrHelper.mixed);
  }
  final valid = files.where((f) => f.status.isValid).toList();
  if (pdfs == 0) {
    return OcrScreenModel(
      kind: OcrInputKind.images,
      effective: options,
      runInputs: valid,
      pagesToRecognise: valid.length,
      helper: valid.isEmpty
          ? OcrHelper.chooseAnother
          : !options.anyOutput
              ? OcrHelper.chooseOutput
              : null,
    );
  }
  if (valid.isEmpty) {
    return OcrScreenModel(kind: OcrInputKind.pdf, effective: options, runInputs: const [], helper: OcrHelper.chooseAnother);
  }
  return switch (textPages) {
    null || AsyncLoading() => OcrScreenModel(kind: OcrInputKind.pdf, effective: options, runInputs: valid, checkingText: true),
    AsyncError() => OcrScreenModel(kind: OcrInputKind.pdf, effective: options, runInputs: const [], helper: OcrHelper.chooseAnother),
    AsyncData(:final value) => () {
        final summary = PdfTextSummary.of(value);
        final effective = summary.state == PdfTextState.all ? options.copyWith(searchablePdf: false) : options;
        return OcrScreenModel(
          kind: OcrInputKind.pdf,
          effective: effective,
          runInputs: valid,
          text: summary,
          pagesToRecognise: summary.withoutText,
          helper: effective.anyOutput ? null : OcrHelper.chooseOutput,
        );
      }(),
  };
}
