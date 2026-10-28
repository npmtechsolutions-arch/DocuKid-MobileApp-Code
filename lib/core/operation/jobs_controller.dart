import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/search/tool_catalog.dart';
import '../files/picked_file.dart';
import '../providers.dart';
import '../validation/input_validator.dart';
import 'job_state.dart';
import 'multi_output.dart';
import 'tool_operation.dart';

class JobBusyException implements Exception {
  const JobBusyException();
}

/// A job the UI is watching. [restart] re-runs it with the same inputs and
/// options (S18 "Try again").
class LiveJob {
  const LiveJob({
    required this.id,
    required this.tool,
    required this.state,
    required this.cancel,
    required this.restart,
    required this.inputBytes,
    this.multi = false,
  });

  final String id;
  final ToolId tool;
  final JobState state;
  final CancelToken cancel;
  final String Function() restart;
  final int inputBytes;

  /// Runs a [MultiToolOperation] (S22 result; S18 all-failed copy).
  final bool multi;

  bool get isLarge => inputBytes > Limits.largeFileBytes;
  bool get isRunning => !state.isTerminal;

  LiveJob withState(JobState s) =>
      LiveJob(id: id, tool: tool, state: s, cancel: cancel, restart: restart, inputBytes: inputBytes, multi: multi);
}

/// Live jobs (ARCHITECTURE §5.3: a queue of 1).
class JobsController extends Notifier<Map<String, LiveJob>> {
  @override
  Map<String, LiveJob> build() => const {};

  LiveJob? get active {
    for (final j in state.values) {
      if (j.isRunning) return j;
    }
    return null;
  }

  /// Starts a job and returns its id. Throws [JobBusyException] if one runs.
  String start<O extends ToolOptions>(ToolOperation<O> op, List<PickedFile> inputs, O options) {
    if (active != null) throw const JobBusyException();
    final id = const Uuid().v7();
    final cancel = CancelToken();
    final job = LiveJob(
      id: id,
      tool: op.tool,
      state: const JobCreated(),
      cancel: cancel,
      restart: () => start(op, inputs, options),
      inputBytes: inputs.fold(0, (s, f) => s + f.sizeBytes),
    );
    state = {...state, id: job};
    unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastTool: op.tool)));
    unawaited(ref.read(jobRunnerProvider).run<O>(
          jobId: id,
          op: op,
          inputs: inputs,
          options: options,
          cancel: cancel,
          emit: (s) => _set(id, s),
        ));
    return id;
  }

  /// Same as [start] for a job with N outputs (RELEASE_V1_1 §4.2).
  String startMulti<O extends ToolOptions>(MultiToolOperation<O> op, List<PickedFile> inputs, O options) {
    if (active != null) throw const JobBusyException();
    final id = const Uuid().v7();
    final cancel = CancelToken();
    final job = LiveJob(
      id: id,
      tool: op.tool,
      state: const JobCreated(),
      cancel: cancel,
      restart: () => startMulti(op, inputs, options),
      inputBytes: inputs.fold(0, (s, f) => s + f.sizeBytes),
      multi: true,
    );
    state = {...state, id: job};
    unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastTool: op.tool)));
    unawaited(ref.read(jobRunnerProvider).runMulti<O>(
          jobId: id,
          op: op,
          inputs: inputs,
          options: options,
          cancel: cancel,
          emit: (s) => _set(id, s),
        ));
    return id;
  }

  void _set(String id, JobState s) {
    final j = state[id];
    if (j == null) return;
    state = {...state, id: j.withState(s)};
    if (s.isCompleted && !j.state.isCompleted) {
      final saved = switch (s) {
        JobCompleted(:final result) => savedBytes(result),
        JobCompletedMulti(:final result) => savedBytesMulti(result.output),
        _ => 0,
      };
      if (saved > 0) {
        // Local-only savings counter (UI_REFRESH §2.2, FR-HOME-07).
        unawaited(ref.read(settingsProvider.notifier).update(
              (x) => x.copyWith(statsTotalSavedBytes: x.statsTotalSavedBytes + saved),
            ));
      }
    }
  }

  void cancel(String id) => state[id]?.cancel.cancel();

  /// Forget a finished job (its history row stays).
  void dismiss(String id) {
    if (state[id]?.isRunning ?? false) return;
    state = {...state}..remove(id);
  }

  /// Replace the result after a rename (D3).
  void updateResult(String id, JobResult r) => _set(id, JobCompleted(r));
}

/// Bytes a finished job saved (input − output), never negative.
int savedBytes(JobResult r) => r.meta.bytes < r.inputBytes ? r.inputBytes - r.meta.bytes : 0;

/// Per item with its own input (batch tools); Split / PDF to Images save nothing.
int savedBytesMulti(MultiOutput o) => o.items.whereType<OutputOk>().fold(0, (s, i) {
      final before = i.beforeBytes;
      return before != null && i.meta.bytes < before ? s + before - i.meta.bytes : s;
    });

final jobsProvider = NotifierProvider<JobsController, Map<String, LiveJob>>(JobsController.new);
