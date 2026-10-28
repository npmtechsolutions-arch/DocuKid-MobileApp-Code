import '../../features/search/tool_catalog.dart';
import '../errors/app_error.dart';
import '../files/picked_file.dart';
import 'tool_operation.dart';

/// One item of a multi-output job (RELEASE_V1_1 §4.2), in item order.
sealed class OutputItem {
  const OutputItem(this.index, this.sourceName);
  final int index;

  /// Display name of the input this item came from (for the result list).
  final String sourceName;
}

/// An adopted, validated output in `outputs/<jobId>/`.
final class OutputOk extends OutputItem {
  const OutputOk(
    super.index,
    super.sourceName, {
    required this.path,
    required this.relPath,
    required this.name,
    required this.mime,
    required this.meta,
    this.beforeBytes,
  });

  final String path, relPath, name, mime;

  /// Facts from re-opening the output; tool notes such as `targetMissed` are
  /// in [OutputMeta.flags].
  final OutputMeta meta;

  /// Size of this item's own input (batch tools); null when one input makes
  /// many items (Split, PDF to Images).
  final int? beforeBytes;
}

final class OutputFailed extends OutputItem {
  const OutputFailed(super.index, super.sourceName, this.code);
  final AppErrorCode code;
}

class MultiOutput {
  const MultiOutput(this.items);
  final List<OutputItem> items;

  int get succeeded => items.whereType<OutputOk>().length;
  int get failed => items.whereType<OutputFailed>().length;
  int get outputBytes => items.whereType<OutputOk>().fold(0, (s, o) => s + o.meta.bytes);
}

/// A tool that turns its inputs into N outputs, one item at a time
/// (RELEASE_V1_1 §4.2). Batch/Convert: N inputs → N items; Split and PDF to
/// Images: one input → N items.
abstract interface class MultiToolOperation<O extends ToolOptions> {
  ToolId get tool;

  /// Progress label and unit for "n of N" (rule 3: real counts only).
  String get itemStepKey;
  ProgressUnit get itemUnit;

  /// Fast checks before heavy work. Throws [AppError].
  Future<void> validateInputs(List<PickedFile> inputs, O options);

  /// Rough bytes for the whole batch (FR-BAT-07), checked before item 0.
  int estimateRequiredBytes(List<PickedFile> inputs, O options);

  /// N, for progress and the item loop.
  int itemCount(List<PickedFile> inputs, O options);

  /// Called once per item; writes only inside ctx.workDir and returns one
  /// file, or throws [AppError].
  Future<RawOutput> executeItem(JobContext ctx, int itemIndex, List<PickedFile> inputs, O options);

  /// Re-opens and checks one output. Throws AppError(outputValidationFailed).
  Future<OutputMeta> validateItem(RawOutput out, int itemIndex, O options);

  /// Always called once the job ends (success, failure or cancel): release
  /// anything kept open across items (Split's source PDF, §4.7).
  Future<void> close();
}
