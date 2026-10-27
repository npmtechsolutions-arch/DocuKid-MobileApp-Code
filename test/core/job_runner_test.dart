import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late HistoryRepository history;
  late OutputsRepository outputs;
  late FakeDevice device;
  late String inputPath;

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    history = HistoryRepository(db);
    outputs = OutputsRepository(paths);
    device = FakeDevice();
    final inDir = paths.jobIn('draft')..createSync(recursive: true);
    inputPath = p.join(inDir.path, '0_photo.jpg');
    File(inputPath).writeAsBytesSync(List.filled(100, 7));
  });

  tearDown(() async => db.close());

  Future<List<JobState>> run(FakeCopyTool tool, {CancelToken? cancel, String id = 'job-1'}) async {
    final states = <JobState>[];
    await JobRunner(paths: paths, history: history, outputs: outputs, device: device).run(
      jobId: id,
      op: tool,
      inputs: [fakeInput(inputPath)],
      options: const FakeOptions(),
      cancel: cancel ?? CancelToken(),
      emit: states.add,
    );
    return states;
  }

  test('success: validates, processes, adopts the output and records history', () async {
    final states = await run(FakeCopyTool(FakeMode.success));
    expect(states.first, isA<JobValidating>());
    expect(states.whereType<JobProcessing>(), isNotEmpty);
    expect(states.any((s) => s is JobValidatingOutput), isTrue);
    final done = states.last as JobCompleted;
    expect(File(done.result.outputPath).existsSync(), isTrue);
    expect(done.result.outputName, 'my_out.bin'); // sanitised
    expect(p.isWithin(paths.outputsRoot.path, done.result.outputPath), isTrue);
    final rec = (await history.get('job-1'))!;
    expect(rec.status, OpStatus.success);
    expect(rec.row.outputBytes, 3);
    expect(rec.inputs.single.displayName, 'photo.jpg');
    expect(device.begun, device.ended);
  });

  test('the input copy is never modified', () async {
    final before = File(inputPath).readAsBytesSync();
    await run(FakeCopyTool(FakeMode.success));
    expect(File(inputPath).readAsBytesSync(), before);
  });

  test('validation failure → Failed with the code, history FAILED', () async {
    final states = await run(FakeCopyTool(FakeMode.failValidate));
    expect((states.last as JobFailed).error.code, AppErrorCode.notEnoughFiles);
    expect((await history.get('job-1'))!.row.errorCode, 'notEnoughFiles');
  });

  test('storage pre-check fails before any work starts', () async {
    device.free = 10;
    final tool = FakeCopyTool(FakeMode.success, estimate: 1000);
    final states = await run(tool);
    final err = (states.last as JobFailed).error;
    expect(err.code, AppErrorCode.insufficientStorage);
    expect(tool.workDirSeen, isNull, reason: 'execute must not run');
  });

  test('execute failure maps to its code and leaves no temp files', () async {
    final tool = FakeCopyTool(FakeMode.failExecute);
    final states = await run(tool);
    expect((states.last as JobFailed).error.code, AppErrorCode.corruptFile);
    expect(Directory(tool.workDirSeen!).existsSync(), isFalse);
    expect(paths.jobDir('job-1').existsSync(), isFalse);
  });

  test('unknown exceptions become processingFailed', () async {
    final states = await run(FakeCopyTool(FakeMode.throwUnknown));
    expect((states.last as JobFailed).error.code, AppErrorCode.processingFailed);
  });

  test('output validation failure never shows success', () async {
    final states = await run(FakeCopyTool(FakeMode.badOutput));
    expect(states.whereType<JobCompleted>(), isEmpty);
    expect((states.last as JobFailed).error.code, AppErrorCode.outputValidationFailed);
    expect(await directorySize(paths.outputsRoot), 0);
  });

  test('cancel mid-way → Cancelled, history CANCELLED, temp dir deleted', () async {
    final tool = FakeCopyTool(FakeMode.cancelMidway);
    final states = await run(tool);
    expect(states.last, isA<JobCancelled>());
    expect((await history.get('job-1'))!.status, OpStatus.cancelled);
    expect(Directory(tool.workDirSeen!).existsSync(), isFalse);
  });

  test('the draft inputs dir survives the job (re-run from the tool screen)', () async {
    await run(FakeCopyTool(FakeMode.success));
    expect(File(inputPath).existsSync(), isTrue);
  });
}
