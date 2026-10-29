import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/ocr/ocr_text_file.dart';
import '../../../core/ocr/pdf_text_reader.dart';
import '../../../core/ocr/searchable_pdf_builder.dart';
import '../../../core/operation/composite_operation.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/providers.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';
import 'ocr_options.dart';
import 'ocr_pipeline.dart';

/// Text Recognition (RELEASE_V1_3): a searchable PDF and/or a `.txt` from
/// one recognition pass, plus the per-page text for Review (ADR-066).
class OcrOperation implements CompositeToolOperation<OcrOptions> {
  OcrOperation({required this.pipeline, required this.pdfEngine, required this.textReader});

  final OcrPipeline pipeline;
  final PdfEngine pdfEngine;
  final PdfTextReader textReader;

  /// FR-OCR-01.
  static const maxImages = 50, maxPdfPages = 300;

  @override
  ToolId get tool => ToolId.ocr;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, OcrOptions options) async {
    if (inputs.isEmpty) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    if (!options.anyOutput) throw const AppError(AppErrorCode.invalidInput);
    final pdfs = inputs.where((f) => f.isPdf).toList();
    if (pdfs.isNotEmpty) {
      // "Choose images or one PDF, not both." (S30 prevents it before this.)
      if (inputs.length != 1) throw const AppError(AppErrorCode.invalidInput);
      final meta = pdfs.single.pdf;
      if (meta == null) throw AppError(AppErrorCode.corruptFile, fileDisplayName: pdfs.single.displayName);
      if (meta.isEncrypted) throw AppError(AppErrorCode.encryptedDocument, fileDisplayName: pdfs.single.displayName);
      if (meta.pageCount > maxPdfPages) throw const AppError(AppErrorCode.invalidInput);
      return;
    }
    if (inputs.length > maxImages) throw const AppError(AppErrorCode.tooManyFiles, count: maxImages);
    for (final f in inputs) {
      final error = f.status.error;
      if (error != null) throw AppError(error, fileDisplayName: f.displayName);
    }
  }

  /// Page JPEGs, OCR files, the PDF and the text: about 3× the inputs, plus
  /// ~1.5 MB per rendered PDF page.
  @override
  int estimateRequiredBytes(List<PickedFile> inputs, OcrOptions options) {
    final bytes = inputs.fold<int>(0, (s, f) => s + f.sizeBytes);
    final pages = inputs.fold<int>(0, (s, f) => s + (f.pdf?.pageCount ?? 0));
    return bytes * 3 + pages * 1536 * 1024;
  }

  @override
  Future<CompositeOutput> execute(JobContext ctx, List<PickedFile> inputs, OcrOptions options) async {
    final r = await pipeline.run(ctx, inputs, options);
    final base = safeBaseName(inputs.first.displayName);
    return CompositeOutput(
      files: [
        if (r.pdfPath != null)
          RawOutput(
            path: r.pdfPath!,
            suggestedName: '${base}_searchable.pdf',
            mime: 'application/pdf',
            flags: {'pages': r.pages, if (r.firstRecognisedPage != null) 'checkPage': r.firstRecognisedPage},
          ),
        if (r.txtPath != null)
          RawOutput(path: r.txtPath!, suggestedName: ocrTxtName(base), mime: 'text/plain', flags: {'pages': r.pages}),
      ],
      stats: {'pages': r.pages, 'words': r.words, 'lowTextPages': r.lowTextPages},
      reviewDir: options.review ? r.reviewDir : null,
    );
  }

  /// §4.10: the PDF opens, has every page, renders, and its first recognised
  /// page gives text back; the `.txt` is UTF-8 with a marker per page.
  @override
  Future<List<OutputMeta>> validateOutputs(CompositeOutput out, List<PickedFile> inputs, OcrOptions options) async {
    final metas = <OutputMeta>[];
    for (final f in out.files) {
      final pages = f.flags['pages']! as int;
      if (f.mime == 'application/pdf') {
        await validatePdfOutput(pdfEngine, f.path, expectedPages: pages);
        final check = f.flags['checkPage'] as int?;
        if (check != null && !hasAnyText(await textReader.pageText(f.path, check))) {
          throw const AppError(AppErrorCode.outputValidationFailed);
        }
        metas.add(OutputMeta(bytes: await File(f.path).length(), pages: pages));
      } else {
        if (!await isValidOcrTxt(f.path, pageCount: pages)) throw const AppError(AppErrorCode.outputValidationFailed);
        metas.add(OutputMeta(bytes: await File(f.path).length(), pages: pages));
      }
    }
    return metas;
  }
}

bool hasAnyText(String s) => s.trim().isNotEmpty;

final ocrOperationProvider = Provider<OcrOperation>((ref) {
  final pdf = ref.watch(pdfEngineProvider);
  final reader = ref.watch(pdfTextReaderProvider);
  return OcrOperation(
    pdfEngine: pdf,
    textReader: reader,
    pipeline: OcrPipeline(
      images: ref.watch(imageEngineProvider),
      encoder: ref.watch(pageImageEncoderProvider),
      textReader: reader,
      recognizer: ref.watch(textRecognizerFactoryProvider),
      openPages: pdf.openExtractor,
      buildPdf: SearchablePdfBuilder(pdf, _asset).build,
    ),
  );
});

Future<Uint8List> _asset(String path) async => (await rootBundle.load(path)).buffer.asUint8List();
