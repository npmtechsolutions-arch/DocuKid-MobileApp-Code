import '../../../core/ocr/text_recognizer.dart';
import '../../../core/operation/tool_operation.dart';

/// Text Recognition options (RELEASE_V1_3 §2, §5). [rotateRetry] comes from
/// the `ocr_rotate_retry` setting and isn't part of "Run again".
class OcrOptions extends ToolOptions {
  const OcrOptions({
    this.searchablePdf = true,
    this.review = true,
    this.txt = false,
    this.script = OcrScript.latin,
    this.rotateRetry = true,
  });

  /// FR-OCR-03: at least one must be on.
  final bool searchablePdf, review, txt;
  final OcrScript script;
  final bool rotateRetry;

  bool get anyOutput => searchablePdf || review || txt;
  bool get wantsText => review || txt;

  /// History "Run again" (FR-OCR-17): outputs and script only, never text.
  @override
  Map<String, Object?> toJson() => {
        'outputs': {'pdf': searchablePdf, 'review': review, 'txt': txt},
        'script': script.name,
      };

  factory OcrOptions.fromJson(Map<String, Object?> j, {bool rotateRetry = true}) {
    final outputs = (j['outputs'] as Map?) ?? const {};
    return OcrOptions(
      searchablePdf: outputs['pdf'] as bool? ?? true,
      review: outputs['review'] as bool? ?? true,
      txt: outputs['txt'] as bool? ?? false,
      script: OcrScript.values.asNameMap()[j['script']] ?? OcrScript.latin,
      rotateRetry: rotateRetry,
    );
  }

  OcrOptions copyWith({bool? searchablePdf, bool? review, bool? txt, OcrScript? script, bool? rotateRetry}) => OcrOptions(
        searchablePdf: searchablePdf ?? this.searchablePdf,
        review: review ?? this.review,
        txt: txt ?? this.txt,
        script: script ?? this.script,
        rotateRetry: rotateRetry ?? this.rotateRetry,
      );
}
