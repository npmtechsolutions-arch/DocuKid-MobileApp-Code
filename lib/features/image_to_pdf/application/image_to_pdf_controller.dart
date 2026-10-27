import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import 'image_to_pdf_operation.dart';

class ImageToPdfController extends Notifier<ImageToPdfOptions> {
  @override
  ImageToPdfOptions build() {
    final s = ref.read(settingsProvider);
    final defaults = ImageToPdfOptions(size: s.pdfPageSize, fit: s.pdfFit, margin: s.pdfMargin, quality: s.pdfImageQuality);
    final init = initialOptions(ref, ToolId.imageToPdf);
    return init == null ? defaults : ImageToPdfOptions.fromJson(init, defaults);
  }

  void set(ImageToPdfOptions o) {
    state = o;
    writeOptionsDraft(ref, ToolId.imageToPdf, o.toJson());
  }
}

final imageToPdfOptionsProvider =
    NotifierProvider.autoDispose<ImageToPdfController, ImageToPdfOptions>(ImageToPdfController.new);

final imageToPdfOperationProvider = Provider<ImageToPdfOperation>((ref) => ImageToPdfOperation(
      ref.watch(imageEngineProvider),
      ref.watch(pdfEngineProvider),
      clock: ref.watch(clockProvider),
    ));

/// Set by the Error screen's "Remove and continue" (FR-I2P-05) so the tool
/// screen re-runs as soon as it's visible again.
class AutoRun extends Notifier<bool> {
  @override
  bool build() => false;
  void request() => state = true;
  bool take() {
    final v = state;
    state = false;
    return v;
  }
}

final imageToPdfAutoRunProvider = NotifierProvider<AutoRun, bool>(AutoRun.new);
