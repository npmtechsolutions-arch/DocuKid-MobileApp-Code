import 'package:path/path.dart' as p;

import '../../data/repositories/history_repository.dart';
import '../../data/repositories/outputs_repository.dart';
import '../errors/app_error.dart';
import '../files/file_naming.dart';
import '../files/paths.dart';
import '../files/picked_file.dart';
import '../logging/log.dart';
import '../platform/device_services.dart';
import '../validation/input_validator.dart';
import 'job_state.dart';
import 'tool_operation.dart';

/// Runs one job through its lifecycle (ARCHITECTURE §5.3). One at a time.
class JobRunner {
  JobRunner({
    required this.paths,
    required this.history,
    required this.outputs,
    required this.device,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final AppPaths paths;
  final HistoryRepository history;
  final OutputsRepository outputs;
  final DeviceServices device;
  final DateTime Function() _now;

  Future<void> run<O extends ToolOptions>({
    required String jobId,
    required ToolOperation<O> op,
    required List<PickedFile> inputs,
    required O options,
    required CancelToken cancel,
    required void Function(JobState) emit,
  }) async {
    final started = _now();
    final work = paths.jobWork(jobId);
    var bgToken = -1;
    Duration elapsed() => _now().difference(started);

    await history.insertRunning(
      id: jobId,
      tool: op.tool,
      createdAt: started,
      inputs: [
        for (final f in inputs)
          InputRecord(
            displayName: f.displayName,
            mime: f.mime,
            sizeBytes: f.sizeBytes,
            meta: f.image != null
                ? {'w': f.image!.width, 'h': f.image!.height}
                : f.pdf != null
                    ? {'p': f.pdf!.pageCount}
                    : null,
          ),
      ],
      options: options.toJson(),
    );
    Log.job(jobId, 'start', op.tool.name);

    try {
      emit(const JobValidating());
      await op.validateInputs(inputs, options);

      final need = op.estimateRequiredBytes(inputs, options);
      final free = await device.freeBytes();
      if (!hasEnoughSpace(freeBytes: free, requiredBytes: need)) {
        throw AppError(AppErrorCode.insufficientStorage, neededBytes: need + Limits.freeSpaceMargin);
      }

      bgToken = await device.beginBackgroundTask('docukit-job');
      await work.create(recursive: true);
      final ctx = JobContext(
        jobId: jobId,
        workDir: work,
        cancel: cancel,
        report: (pr) {
          if (!cancel.isCancelled) emit(JobProcessing(pr));
        },
      );
      emit(const JobProcessing(Indeterminate('stepPreparing')));
      final raw = await op.execute(ctx, inputs, options);
      cancel.throwIfCancelled();

      emit(const JobValidatingOutput());
      final meta = await op.validateOutput(raw, inputs, options);
      cancel.throwIfCancelled();

      final (abs, rel) = await outputs.adopt(jobId, raw.path, safeOutputName(raw.suggestedName));
      final duration = elapsed();
      await history.complete(
        jobId,
        finishedAt: _now(),
        duration: duration,
        outputName: p.basename(abs),
        outputMime: raw.mime,
        outputBytes: meta.bytes,
        outputRelPath: rel,
        outputMeta: meta.toJson(),
      );
      Log.job(jobId, 'completed');
      final first = inputs.isEmpty ? null : inputs.first;
      emit(JobCompleted(JobResult(
        jobId: jobId,
        tool: op.tool,
        outputPath: abs,
        outputName: p.basename(abs),
        mime: raw.mime,
        meta: meta,
        inputBytes: inputs.fold(0, (s, f) => s + f.sizeBytes),
        inputCount: inputs.length,
        duration: duration,
        inputWidth: first?.image?.width,
        inputHeight: first?.image?.height,
        inputPages: inputs.every((f) => f.pdf != null) && inputs.isNotEmpty
            ? inputs.fold<int>(0, (s, f) => s + f.pdf!.pageCount)
            : null,
        firstInputPath: first?.path,
      )));
    } on CancelledException {
      await history.markCancelled(jobId, finishedAt: _now());
      Log.job(jobId, 'cancelled');
      emit(const JobCancelled());
    } on AppError catch (e) {
      if (e.code == AppErrorCode.cancelled) {
        await history.markCancelled(jobId, finishedAt: _now());
        emit(const JobCancelled());
      } else {
        await history.fail(jobId, e.code.name, finishedAt: _now(), duration: elapsed());
        Log.job(jobId, 'failed', e.code.name);
        emit(JobFailed(e));
      }
    } on OutOfMemoryError {
      await history.fail(jobId, AppErrorCode.outOfMemory.name, finishedAt: _now(), duration: elapsed());
      Log.job(jobId, 'failed', AppErrorCode.outOfMemory.name);
      emit(const JobFailed(AppError(AppErrorCode.outOfMemory)));
    } catch (_) {
      // Never log the exception text: it may contain a path.
      await history.fail(jobId, AppErrorCode.processingFailed.name, finishedAt: _now(), duration: elapsed());
      Log.job(jobId, 'failed', AppErrorCode.processingFailed.name);
      emit(const JobFailed(AppError(AppErrorCode.processingFailed)));
    } finally {
      await device.endBackgroundTask(bgToken);
      // Never leave a half-written output behind.
      await deleteQuietly(paths.jobDir(jobId));
    }
  }
}

/// Keeps the extension and sanitises the base (FR-FILE-03).
String safeOutputName(String name) {
  final ext = p.extension(name);
  final base = ext.isEmpty ? name : name.substring(0, name.length - ext.length);
  return withExtension(base, ext.isEmpty ? 'bin' : ext);
}
