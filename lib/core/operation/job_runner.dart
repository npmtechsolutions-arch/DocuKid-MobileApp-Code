import 'dart:io';

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
import 'composite_operation.dart';
import 'job_state.dart';
import 'multi_output.dart';
import 'tool_operation.dart';

export '../files/file_naming.dart' show safeOutputName;

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
      inputs: _inputRecords(inputs),
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
    } catch (e) {
      await _settleError(jobId, e, elapsed(), emit);
    } finally {
      options.wipe();
      await device.endBackgroundTask(bgToken);
      // Never leave a half-written output behind.
      await deleteQuietly(paths.jobDir(jobId));
    }
  }

  /// A job with N outputs (RELEASE_V1_1 §4.2). Items run one after another;
  /// a bad item is recorded and the batch goes on (FR-BAT-05). Outputs are
  /// adopted only after the loop, so cancel leaves nothing behind (FR-BAT-06).
  Future<void> runMulti<O extends ToolOptions>({
    required String jobId,
    required MultiToolOperation<O> op,
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
      inputs: _inputRecords(inputs),
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
      final n = op.itemCount(inputs, options);
      final ctx = JobContext(
        jobId: jobId,
        workDir: work,
        cancel: cancel,
        // Per-item progress comes from the loop; items don't report their own.
        report: (_) {},
      );
      // N inputs → N items: each item has its own source; else they share one.
      final perInput = inputs.length == n;
      String sourceOf(int i) => inputs.isEmpty ? '' : (perInput ? inputs[i] : inputs.first).displayName;

      final done = <int, (RawOutput, OutputMeta)>{};
      final failed = <int, AppErrorCode>{};
      for (var i = 0; i < n; i++) {
        cancel.throwIfCancelled();
        emit(JobProcessing(Determinate(i, n, op.itemStepKey, unit: op.itemUnit)));
        try {
          final raw = await op.executeItem(ctx, i, inputs, options);
          final meta = await op.validateItem(raw, i, options);
          done[i] = (raw, meta);
        } on CancelledException {
          rethrow;
        } on AppError catch (e) {
          if (e.code == AppErrorCode.cancelled) rethrow;
          if (e.code == AppErrorCode.insufficientStorage) {
            // The rest can't fit either: stop and fail them all.
            for (var j = i; j < n; j++) {
              failed[j] = e.code;
            }
            break;
          }
          failed[i] = e.code;
        } on OutOfMemoryError {
          failed[i] = AppErrorCode.outOfMemory;
        } catch (_) {
          // Never log the exception text: it may contain a path.
          failed[i] = AppErrorCode.processingFailed;
        }
        if (failed.containsKey(i)) Log.job(jobId, 'item_failed', '$i ${failed[i]!.name}');
      }
      cancel.throwIfCancelled();
      if (done.isEmpty) {
        // All failed: report the first item's error (maps keep insertion order).
        throw AppError(failed.values.firstOrNull ?? AppErrorCode.processingFailed);
      }
      emit(JobProcessing(Determinate(n, n, op.itemStepKey, unit: op.itemUnit)));

      final items = <OutputItem>[];
      try {
        for (var i = 0; i < n; i++) {
          final d = done[i];
          if (d == null) {
            items.add(OutputFailed(i, sourceOf(i), failed[i] ?? AppErrorCode.processingFailed));
            continue;
          }
          final (raw, meta) = d;
          final (abs, rel) = await outputs.adopt(jobId, raw.path, safeOutputName(raw.suggestedName));
          items.add(OutputOk(
            i,
            sourceOf(i),
            path: abs,
            relPath: rel,
            name: p.basename(abs),
            mime: raw.mime,
            meta: meta,
            beforeBytes: perInput ? inputs[i].sizeBytes : null,
          ));
        }
      } catch (_) {
        // Never keep some of the outputs without a history record of them.
        await outputs.deleteFor(jobId);
        rethrow;
      }

      final duration = elapsed();
      await history.completeMulti(
        jobId,
        finishedAt: _now(),
        duration: duration,
        outputs: [
          for (final item in items)
            switch (item) {
              OutputOk() => OutputRecord(
                  displayName: item.name,
                  relPath: item.relPath,
                  mime: item.mime,
                  sizeBytes: item.meta.bytes,
                  beforeBytes: item.beforeBytes,
                  meta: item.meta.toJson(),
                ),
              OutputFailed() => OutputRecord(displayName: item.sourceName, errorCode: item.code.name),
            },
        ],
      );
      final result = MultiOutput(items);
      Log.job(jobId, 'completed', 'ok=${result.succeeded} failed=${result.failed}');
      emit(JobCompletedMulti(MultiJobResult(
        jobId: jobId,
        tool: op.tool,
        output: result,
        inputBytes: inputs.fold(0, (s, f) => s + f.sizeBytes),
        inputCount: inputs.length,
        duration: duration,
      )));
    } catch (e) {
      await _settleError(jobId, e, elapsed(), emit);
    } finally {
      options.wipe();
      try {
        await op.close();
      } catch (_) {
        // Releasing is best effort; the job's outcome is already decided.
      }
      await device.endBackgroundTask(bgToken);
      await deleteQuietly(paths.jobDir(jobId));
    }
  }

  /// One pass with its own progress that makes 0–N files plus stats
  /// (ADR-066, Text Recognition). Like [run], nothing is adopted until every
  /// file is validated; [CompositeOutput.reviewDir] is moved out of the job
  /// folder only on success, so a cancel or failure leaves no text behind.
  Future<void> runComposite<O extends ToolOptions>({
    required String jobId,
    required CompositeToolOperation<O> op,
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
      inputs: _inputRecords(inputs),
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
      final metas = await op.validateOutputs(raw, inputs, options);
      cancel.throwIfCancelled();

      final items = <OutputItem>[];
      final source = inputs.isEmpty ? '' : inputs.first.displayName;
      try {
        for (final (i, f) in raw.files.indexed) {
          final (abs, rel) = await outputs.adopt(jobId, f.path, safeOutputName(f.suggestedName));
          items.add(OutputOk(i, source, path: abs, relPath: rel, name: p.basename(abs), mime: f.mime, meta: metas[i]));
        }
        if (raw.reviewDir != null) {
          final dest = paths.reviewDir(jobId);
          await deleteQuietly(dest);
          await dest.parent.create(recursive: true);
          await Directory(raw.reviewDir!).rename(dest.path);
        }
        final duration = elapsed();
        await history.completeMulti(
          jobId,
          finishedAt: _now(),
          duration: duration,
          outputs: [
            for (final item in items.cast<OutputOk>())
              OutputRecord(
                displayName: item.name,
                relPath: item.relPath,
                mime: item.mime,
                sizeBytes: item.meta.bytes,
                meta: item.meta.toJson(),
              ),
          ],
          jobMeta: raw.stats,
        );
        Log.job(jobId, 'completed', 'files=${items.length}');
        emit(JobCompletedMulti(MultiJobResult(
          jobId: jobId,
          tool: op.tool,
          output: MultiOutput(items),
          inputBytes: inputs.fold(0, (s, f) => s + f.sizeBytes),
          inputCount: inputs.length,
          duration: duration,
          stats: raw.stats,
          reviewAvailable: raw.reviewDir != null,
        )));
      } catch (_) {
        // Never keep outputs or review text without a history record of them.
        await outputs.deleteFor(jobId);
        await deleteQuietly(paths.reviewDir(jobId));
        rethrow;
      }
    } catch (e) {
      await _settleError(jobId, e, elapsed(), emit);
    } finally {
      options.wipe();
      await device.endBackgroundTask(bgToken);
      await deleteQuietly(paths.jobDir(jobId));
    }
  }

  List<InputRecord> _inputRecords(List<PickedFile> inputs) => [
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
      ];

  /// Cancelled, failed with a code, or an unexpected error → history + state.
  Future<void> _settleError(String jobId, Object e, Duration elapsed, void Function(JobState) emit) async {
    if (e is ReturnToTool) {
      await history.remove(jobId);
      Log.job(jobId, 'returned', e.reason);
      emit(JobReturned(e.reason));
      return;
    }
    if (e is CancelledException || (e is AppError && e.code == AppErrorCode.cancelled)) {
      await history.markCancelled(jobId, finishedAt: _now());
      Log.job(jobId, 'cancelled');
      emit(const JobCancelled());
      return;
    }
    final error = switch (e) {
      AppError() => e,
      OutOfMemoryError() => const AppError(AppErrorCode.outOfMemory),
      // Never log the exception text: it may contain a path.
      _ => const AppError(AppErrorCode.processingFailed),
    };
    await history.fail(jobId, error.code.name, finishedAt: _now(), duration: elapsed);
    Log.job(jobId, 'failed', error.code.name);
    emit(JobFailed(error));
  }
}
