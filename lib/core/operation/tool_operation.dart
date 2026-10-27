import 'dart:io';

import '../../features/search/tool_catalog.dart';
import '../errors/app_error.dart';
import '../files/picked_file.dart';

/// Options for one tool run. Must be JSON-serialisable for "Run again"
/// (non-sensitive values only — never paths or names).
abstract class ToolOptions {
  const ToolOptions();
  Map<String, Object?> toJson();
}

/// Cooperative cancellation (ARCHITECTURE §5.1).
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }
}

/// Progress is either indeterminate or a real count (rule 3: never fabricated).
sealed class JobProgress {
  const JobProgress(this.stepKey);
  final String stepKey;
}

final class Indeterminate extends JobProgress {
  const Indeterminate(super.stepKey);
}

enum ProgressUnit { pages, images, files }

final class Determinate extends JobProgress {
  const Determinate(this.done, this.total, super.stepKey, {this.unit = ProgressUnit.pages});
  final int done, total;
  final ProgressUnit unit;
}

class JobContext {
  JobContext({required this.jobId, required this.workDir, required this.cancel, required this.report});
  final String jobId;

  /// `cache/jobs/<id>/work` — the only place an operation may write.
  final Directory workDir;
  final CancelToken cancel;
  final void Function(JobProgress) report;
}

/// What `execute` produced, still inside the work dir.
class RawOutput {
  const RawOutput({required this.path, required this.suggestedName, required this.mime, this.flags = const {}});
  final String path;
  final String suggestedName;
  final String mime;

  /// Tool-specific facts for the Result screen, e.g. {'targetMissed': true}.
  final Map<String, Object?> flags;
}

/// Facts verified by re-opening the output (ARCHITECTURE §5.4).
class OutputMeta {
  const OutputMeta({required this.bytes, this.width, this.height, this.pages, this.flags = const {}});
  final int bytes;
  final int? width, height, pages;
  final Map<String, Object?> flags;

  Map<String, Object?> toJson() => {
        'bytes': bytes,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
        if (pages != null) 'pages': pages,
        ...flags,
      };
}

/// One run of a tool; implemented once per tool in `features/<tool>/application/`.
abstract interface class ToolOperation<O extends ToolOptions> {
  ToolId get tool;

  /// Fast checks before heavy work. Throws [AppError].
  Future<void> validateInputs(List<PickedFile> inputs, O options);

  /// Rough bytes for temp + output, for the storage pre-check (FEATURE_SPECS §2.3).
  int estimateRequiredBytes(List<PickedFile> inputs, O options);

  /// Writes ONLY inside ctx.workDir and reports real progress.
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, O options);

  /// Re-opens and checks the output. Throws AppError(outputValidationFailed).
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, O options);
}
