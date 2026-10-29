import '../../features/search/tool_catalog.dart';
import '../errors/app_error.dart';
import 'multi_output.dart';
import 'tool_operation.dart';

/// Live job states (ARCHITECTURE §5.2). Interrupted exists only in history.
sealed class JobState {
  const JobState();
  bool get isTerminal => isCompleted || this is JobFailed || this is JobCancelled;

  /// Finished with at least one output (single or multi).
  bool get isCompleted => this is JobCompleted || this is JobCompletedMulti;
}

final class JobCreated extends JobState {
  const JobCreated();
}

final class JobValidating extends JobState {
  const JobValidating();
}

final class JobProcessing extends JobState {
  const JobProcessing(this.progress);
  final JobProgress progress;
}

final class JobValidatingOutput extends JobState {
  const JobValidatingOutput();
}

final class JobCompleted extends JobState {
  const JobCompleted(this.result);
  final JobResult result;
}

/// A multi-output job with ≥ 1 succeeded item (RELEASE_V1_1 §4.2), or a
/// composite job with 0–N files (ADR-066).
final class JobCompletedMulti extends JobState {
  const JobCompletedMulti(this.result);
  final MultiJobResult result;
}

final class JobFailed extends JobState {
  const JobFailed(this.error);
  final AppError error;
}

final class JobCancelled extends JobState {
  const JobCancelled();
}

class JobResult {
  const JobResult({
    required this.jobId,
    required this.tool,
    required this.outputPath,
    required this.outputName,
    required this.mime,
    required this.meta,
    required this.inputBytes,
    required this.inputCount,
    required this.duration,
    this.inputWidth,
    this.inputHeight,
    this.inputPages,
    this.firstInputPath,
  });

  final String jobId;
  final ToolId tool;

  /// Absolute path of the app-managed copy (`outputs/<id>/<name>`).
  final String outputPath;
  final String outputName;
  final String mime;
  final OutputMeta meta;
  final int inputBytes;
  final int inputCount;
  final Duration duration;
  final int? inputWidth, inputHeight, inputPages;

  /// Input copy for the before/after compare (single-image tools); may be
  /// deleted later, so callers must check that it still exists.
  final String? firstInputPath;

  bool get isImage => mime.startsWith('image/');
  bool get notSmaller => meta.bytes >= inputBytes;
  bool get targetMissed => meta.flags['targetMissed'] == true;
  int? get targetBytes => meta.flags['targetBytes'] as int?;

  JobResult renamed(String path, String name) => JobResult(
        jobId: jobId,
        tool: tool,
        outputPath: path,
        outputName: name,
        mime: mime,
        meta: meta,
        inputBytes: inputBytes,
        inputCount: inputCount,
        duration: duration,
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        inputPages: inputPages,
        firstInputPath: firstInputPath,
      );
}

class MultiJobResult {
  const MultiJobResult({
    required this.jobId,
    required this.tool,
    required this.output,
    required this.inputBytes,
    required this.inputCount,
    required this.duration,
    this.stats = const {},
    this.reviewAvailable = false,
  });

  final String jobId;
  final ToolId tool;

  /// Composite jobs (ADR-066) may have no items: OCR text only.
  final MultiOutput output;
  final int inputBytes;
  final int inputCount;
  final Duration duration;

  /// Composite jobs: job-level facts, e.g. OCR {pages, words, lowTextPages}.
  final Map<String, Object?> stats;

  /// Composite jobs: text is kept in `AppPaths.reviewDir(jobId)` (ADR-066).
  final bool reviewAvailable;
}
