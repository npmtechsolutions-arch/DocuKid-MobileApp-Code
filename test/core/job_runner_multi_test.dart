// RELEASE_V1_1 §4.2 / §8.1 — JobRunner.runMulti, written before the
// implementation (T8.2).
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// Writes `i + 1` bytes per item. [fail] maps item index → what that item does.
class FakeMultiTool implements MultiToolOperation<FakeOptions> {
  FakeMultiTool(this.n, {this.fail = const {}, this.cancelAt, this.estimate = 10, this.name});
  final int n;
  final Map<int, Object> fail;
  final int? cancelAt;
  final int estimate;

  /// Same suggested name for every item when set (adoption must de-duplicate).
  final String? name;
  final executed = <int>[];
  String? workDirSeen;
  CancelToken? token;

  @override
  ToolId get tool => ToolId.imageCompress;
  @override
  String get itemStepKey => 'stepCompressing';
  @override
  ProgressUnit get itemUnit => ProgressUnit.images;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, FakeOptions options) async {}
  @override
  int estimateRequiredBytes(List<PickedFile> inputs, FakeOptions options) => estimate;
  @override
  int itemCount(List<PickedFile> inputs, FakeOptions options) => n;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, FakeOptions options) async {
    executed.add(i);
    workDirSeen = ctx.workDir.path;
    final f = fail[i];
    if (f != null) throw f;
    final out = File(p.join(ctx.workDir.path, 'raw_$i.bin'))..writeAsBytesSync(List.filled(i + 1, i));
    if (cancelAt == i) ctx.cancel.cancel();
    return RawOutput(path: out.path, suggestedName: name ?? 'out_$i.jpg', mime: 'image/jpeg');
  }

  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, FakeOptions options) async =>
      OutputMeta(bytes: File(out.path).lengthSync(), width: 10, height: 10);
}

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late HistoryRepository history;
  late OutputsRepository outputs;
  late FakeDevice device;
  late List<PickedFile> inputs;

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    history = HistoryRepository(db);
    outputs = OutputsRepository(paths);
    device = FakeDevice();
    final inDir = paths.jobIn('draft')..createSync(recursive: true);
    inputs = [
      for (var i = 0; i < 3; i++)
        fakeInput((File(p.join(inDir.path, '${i}_photo.jpg'))..writeAsBytesSync(List.filled(100, 7))).path),
    ];
  });

  tearDown(() async => db.close());

  Future<List<JobState>> run(FakeMultiTool tool, {String id = 'job-1', List<PickedFile>? ins}) async {
    final states = <JobState>[];
    await JobRunner(paths: paths, history: history, outputs: outputs, device: device).runMulti(
      jobId: id,
      op: tool,
      inputs: ins ?? inputs,
      options: const FakeOptions(),
      cancel: CancelToken(),
      emit: states.add,
    );
    return states;
  }

  List<String> outputFiles(String id) {
    final dir = Directory(p.join(paths.outputsRoot.path, id));
    return dir.existsSync() ? (dir.listSync().map((e) => p.basename(e.path)).toList()..sort()) : const [];
  }

  test('all succeed: real n-of-N progress, every output adopted, history SUCCESS with one row per output', () async {
    final states = await run(FakeMultiTool(3));
    expect(states.first, isA<JobValidating>());
    final progress = states.whereType<JobProcessing>().map((s) => s.progress).whereType<Determinate>().toList();
    expect(progress.map((d) => (d.done, d.total)), [(0, 3), (1, 3), (2, 3), (3, 3)]);
    expect(progress.every((d) => d.unit == ProgressUnit.images && d.stepKey == 'stepCompressing'), isTrue);

    final done = states.last as JobCompletedMulti;
    final r = done.result;
    expect(r.output.succeeded, 3);
    expect(r.output.failed, 0);
    expect(r.output.items.map((i) => i.index), [0, 1, 2]);
    for (final item in r.output.items.cast<OutputOk>()) {
      expect(File(item.path).existsSync(), isTrue);
      expect(p.isWithin(paths.outputsRoot.path, item.path), isTrue);
      expect(item.beforeBytes, 100, reason: 'N inputs → N items: before = that input');
      expect(item.sourceName, 'photo.jpg');
    }
    expect(r.output.outputBytes, 1 + 2 + 3);
    expect(outputFiles('job-1'), ['out_0.jpg', 'out_1.jpg', 'out_2.jpg']);

    final rec = (await history.get('job-1'))!;
    expect(rec.status, OpStatus.success);
    expect(rec.row.outputCount, 3);
    expect(rec.row.failedCount, 0);
    expect(rec.row.outputBytes, 6);
    expect(rec.row.outputRelPath, isNull, reason: 'multi jobs use operation_outputs');
    final rows = await history.outputsOf('job-1');
    expect(rows.map((o) => o.position), [0, 1, 2]);
    expect(rows.map((o) => o.relPath), ['job-1/out_0.jpg', 'job-1/out_1.jpg', 'job-1/out_2.jpg']);
    expect(rows.map((o) => o.sizeBytes), [1, 2, 3]);
    expect(rows.map((o) => o.beforeBytes), [100, 100, 100]);
    expect(paths.jobDir('job-1').existsSync(), isFalse);
    expect(device.begun, device.ended);
  });

  test('partial: a bad item is recorded and the batch continues; history PARTIAL', () async {
    final tool = FakeMultiTool(3, fail: {1: const AppError(AppErrorCode.corruptFile)});
    final states = await run(tool);
    expect(tool.executed, [0, 1, 2]);
    final r = (states.last as JobCompletedMulti).result;
    expect(r.output.succeeded, 2);
    expect(r.output.failed, 1);
    expect((r.output.items[1] as OutputFailed).code, AppErrorCode.corruptFile);
    expect(outputFiles('job-1'), ['out_0.jpg', 'out_2.jpg']);

    final rec = (await history.get('job-1'))!;
    expect(rec.status, OpStatus.partial);
    expect(rec.row.failedCount, 1);
    final rows = await history.outputsOf('job-1');
    expect(rows[1].errorCode, 'corruptFile');
    expect(rows[1].relPath, isNull);
    expect(rows[1].displayName, 'photo.jpg', reason: 'failed rows keep the source name');
  });

  test('unknown errors and out-of-memory fail only that item', () async {
    final tool = FakeMultiTool(3, fail: {0: StateError('boom /secret/path'), 1: const OutOfMemoryError()});
    final r = ((await run(tool)).last as JobCompletedMulti).result;
    expect((r.output.items[0] as OutputFailed).code, AppErrorCode.processingFailed);
    expect((r.output.items[1] as OutputFailed).code, AppErrorCode.outOfMemory);
    expect(r.output.items[2], isA<OutputOk>());
  });

  test('all fail → Failed with the first error, history FAILED, nothing adopted', () async {
    final tool = FakeMultiTool(2, fail: {
      0: const AppError(AppErrorCode.unsupportedFormat),
      1: const AppError(AppErrorCode.corruptFile),
    });
    final states = await run(tool);
    expect(states.whereType<JobCompletedMulti>(), isEmpty);
    expect((states.last as JobFailed).error.code, AppErrorCode.unsupportedFormat);
    final rec = (await history.get('job-1'))!;
    expect(rec.status, OpStatus.failed);
    expect(rec.row.errorCode, 'unsupportedFormat');
    expect(outputFiles('job-1'), isEmpty);
    expect(paths.jobDir('job-1').existsSync(), isFalse);
  });

  test('cancel mid-way stops after the current item and keeps nothing', () async {
    final tool = FakeMultiTool(3, cancelAt: 1);
    final states = await run(tool);
    expect(tool.executed, [0, 1]);
    expect(states.last, isA<JobCancelled>());
    expect((await history.get('job-1'))!.status, OpStatus.cancelled);
    expect(await history.outputsOf('job-1'), isEmpty);
    expect(outputFiles('job-1'), isEmpty, reason: 'finished outputs are discarded on cancel');
    expect(Directory(tool.workDirSeen!).existsSync(), isFalse);
  });

  test('insufficient storage mid-batch stops the loop and fails the rest', () async {
    final tool = FakeMultiTool(4, fail: {1: const AppError(AppErrorCode.insufficientStorage)});
    final r = ((await run(tool)).last as JobCompletedMulti).result;
    expect(tool.executed, [0, 1]);
    expect(r.output.items.map((i) => i is OutputFailed ? i.code.name : 'ok'),
        ['ok', 'insufficientStorage', 'insufficientStorage', 'insufficientStorage']);
    expect((await history.get('job-1'))!.status, OpStatus.partial);
  });

  test('storage pre-check for the whole batch fails before any item runs', () async {
    device.free = 10;
    final tool = FakeMultiTool(3, estimate: 1000);
    final states = await run(tool);
    expect((states.last as JobFailed).error.code, AppErrorCode.insufficientStorage);
    expect(tool.executed, isEmpty);
  });

  test('same suggested names are made unique in outputs/<jobId>/', () async {
    final r = ((await run(FakeMultiTool(3, name: 'page.jpg'))).last as JobCompletedMulti).result;
    final names = r.output.items.cast<OutputOk>().map((o) => o.name).toList();
    expect(names.toSet(), hasLength(3));
    expect(outputFiles('job-1'), hasLength(3));
  });

  test('one input → N items (split / PDF to images): every item names that input; no per-item before size', () async {
    final r = ((await run(FakeMultiTool(3), ins: [inputs.first])).last as JobCompletedMulti).result;
    for (final item in r.output.items.cast<OutputOk>()) {
      expect(item.sourceName, 'photo.jpg');
      expect(item.beforeBytes, isNull);
    }
  });

  test('a batch of one also fills the single-output columns (ADR-036)', () async {
    await run(FakeMultiTool(1), ins: [inputs.first]);
    final rec = (await history.get('job-1'))!;
    expect(rec.status, OpStatus.success);
    expect(rec.row.outputCount, 1);
    expect(rec.row.outputRelPath, 'job-1/out_0.jpg');
    expect(rec.row.outputName, 'out_0.jpg');
    expect(rec.row.outputMime, 'image/jpeg');
    expect(rec.outputRecorded, isTrue);
  });

  group('history queries see multi jobs', () {
    test('retention finds multi-output rows; "completed only" includes PARTIAL', () async {
      await run(FakeMultiTool(3, fail: {2: const AppError(AppErrorCode.corruptFile)}), id: 'multi');
      final later = DateTime.now().add(const Duration(days: 30));
      expect((await history.outputsFinishedBefore(later)).map((r) => r.id), ['multi']);
      final page = await history.watchPage(limit: 10, onlyCompleted: true).first;
      expect(page.map((r) => r.id), ['multi']);
    });

    test('"delete all outputs" marks multi-output rows too', () async {
      await run(FakeMultiTool(2), id: 'multi');
      await history.markAllOutputsDeleted(DateTime(2030));
      expect((await history.get('multi'))!.row.outputDeletedAt, isNotNull);
    });
  });
}
