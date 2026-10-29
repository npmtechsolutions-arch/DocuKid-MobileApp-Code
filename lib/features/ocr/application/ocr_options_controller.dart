import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ocr/text_recognizer.dart';
import '../../../core/providers.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import 'ocr_options.dart';

/// S30 options. They start from the last choices (`ocr_outputs`, `ocr_script`;
/// Devanagari on Hindi/Marathi devices) and remember the next ones, like the
/// 1.1 tools; `ocr_rotate_retry` is a setting only (RELEASE_V1_3 §5).
class OcrOptionsController extends Notifier<OcrOptions> {
  @override
  OcrOptions build() {
    final s = ref.read(settingsProvider);
    final init = initialOptions(ref, ToolId.ocr);
    if (init != null) return OcrOptions.fromJson(init, rotateRetry: s.ocrRotateRetry);
    return OcrOptions(
      searchablePdf: s.ocrOutputPdf,
      review: s.ocrOutputReview,
      txt: s.ocrOutputTxt,
      script: s.ocrScript,
      rotateRetry: s.ocrRotateRetry,
    );
  }

  void set(OcrOptions o) {
    state = o;
    writeOptionsDraft(ref, ToolId.ocr, o.toJson());
    unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(
          ocrOutputPdf: o.searchablePdf,
          ocrOutputReview: o.review,
          ocrOutputTxt: o.txt,
          ocrScript: o.script,
        )));
  }
}

final ocrOptionsProvider = NotifierProvider.autoDispose<OcrOptionsController, OcrOptions>(OcrOptionsController.new);

/// The scripts this build can recognise, in [OcrScript] order (ADR-045);
/// S30's "Text language" and S29's "Make searchable" language.
final ocrScriptsProvider = FutureProvider.autoDispose<List<OcrScript>>((ref) async {
  final r = ref.watch(textRecognizerFactoryProvider)();
  try {
    final available = await r.availableScripts();
    return [for (final s in OcrScript.values) if (available.contains(s)) s];
  } finally {
    await r.dispose();
  }
});
