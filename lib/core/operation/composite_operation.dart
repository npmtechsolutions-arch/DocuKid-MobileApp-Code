import '../../features/search/tool_catalog.dart';
import '../files/picked_file.dart';
import 'tool_operation.dart';

/// What a [CompositeToolOperation] produced, still inside the work dir.
class CompositeOutput {
  const CompositeOutput({required this.files, this.stats = const {}, this.reviewDir});

  /// 0–N files, in the order the Result screen lists them. None is a valid
  /// result (OCR "Review and copy text" only, RELEASE_V1_3 §5).
  final List<RawOutput> files;

  /// Job-level facts for the Result screen and history `outputMetaJson`,
  /// e.g. {pages, words, lowTextPages}. Never document text (ADR-047).
  final Map<String, Object?> stats;

  /// A folder inside the work dir to keep after the job for a review screen;
  /// the runner moves it to `AppPaths.reviewDir` (ADR-066).
  final String? reviewDir;
}

/// One pass over the inputs that reports its own progress and makes 0–N
/// files plus stats (ADR-066). Text Recognition: pages are recognised one by
/// one ("Recognising page n of N"), then the searchable PDF and/or `.txt`
/// are written from the same pass.
abstract interface class CompositeToolOperation<O extends ToolOptions> {
  ToolId get tool;

  /// Fast checks before heavy work. Throws `AppError`.
  Future<void> validateInputs(List<PickedFile> inputs, O options);

  /// Rough bytes for temp + outputs, for the storage pre-check.
  int estimateRequiredBytes(List<PickedFile> inputs, O options);

  /// Writes ONLY inside ctx.workDir and reports real progress.
  Future<CompositeOutput> execute(JobContext ctx, List<PickedFile> inputs, O options);

  /// Re-opens every file, one [OutputMeta] each, in order. Throws
  /// `AppError(outputValidationFailed)`.
  Future<List<OutputMeta>> validateOutputs(CompositeOutput out, List<PickedFile> inputs, O options);
}
