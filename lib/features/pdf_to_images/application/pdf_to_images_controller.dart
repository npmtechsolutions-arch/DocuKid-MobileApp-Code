import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import 'pdf_to_images_operation.dart';

class PdfToImagesController extends Notifier<PdfToImagesOptions> {
  @override
  PdfToImagesOptions build() {
    final s = ref.read(settingsProvider);
    final defaults = PdfToImagesOptions(format: s.p2iFormat, dpi: s.p2iDpi);
    final init = initialOptions(ref, ToolId.pdfToImages);
    return init == null ? defaults : PdfToImagesOptions.fromJson(init, defaults);
  }

  void set(PdfToImagesOptions o) {
    final remember = o.format != state.format || o.dpi != state.dpi;
    state = o;
    writeOptionsDraft(ref, ToolId.pdfToImages, o.toJson());
    // p2i_format / p2i_dpi remember the last choice (§5.2).
    if (remember) unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(p2iFormat: o.format, p2iDpi: o.dpi)));
  }
}

final pdfToImagesOptionsProvider =
    NotifierProvider.autoDispose<PdfToImagesController, PdfToImagesOptions>(PdfToImagesController.new);

/// [endWord]: the localised "end" alias (§4.6).
final pdfToImagesOperationProvider = Provider.family<PdfToImagesOperation, String>(
  (ref, endWord) => PdfToImagesOperation(ref.watch(pdfEngineProvider), ref.watch(pageImageEncoderProvider), endWords: {'end', endWord}),
);
