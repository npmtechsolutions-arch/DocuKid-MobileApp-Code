// T10.5 — JobRunner.runComposite (ADR-066): one pass with its own progress,
// 0–N files plus job stats, and a private review folder that outlives the
// job folder (RELEASE_V1_3 §4.3, §5). Written before the implementation.
import 'dart:convert';
import 'dart:io';

import 'package:docukit/app/bootstrap/sweeps.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/composite_operation.dart';
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

/// Writes [files] (name → content) and, when [review], a review folder.
class _Tool implements CompositeToolOperation<FakeOptions> {
  _Tool({this.files = const {'a.pdf': '%PDF-1.4 a', 'a.txt': 'text'}, this.review = true, this.failWith, this.badOutput = false});
  final Map<String, String> files;
  final bool review;
  final AppErrorCode? failWith;
  final bool badOutput;
  CancelToken? cancelDuring;
  final progress = <JobProgress>[];

  @override
  ToolId get tool => ToolId.ocr;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, FakeOptions options) async {}

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, FakeOptions options) => 0;

  @override
  Future<CompositeOutput> execute(JobContext ctx, List<PickedFile> inputs, FakeOptions options) async {
    for (var i = 0; i < 3; i++) {
      ctx.cancel.throwIfCancelled();
      ctx.report(Determinate(i, 3, 'stepOcrPage'));
      if (i == 1) cancelDuring?.cancel();
    }
    if (failWith != null) throw AppError(failWith!);
    String? reviewDir;
    if (review) {
      final d = Directory(p.join(ctx.workDir.path, 'review'))..createSync();
      File(p.join(d.path, 'page_0.txt')).writeAsStringSync('secret text');
      reviewDir = d.path;
    }
    return CompositeOutput(
      files: [
        for (final MapEntry(key: name, value: body) in files.entries)
          RawOutput(
            path: (File(p.join(ctx.workDir.path, 'out_$name'))..writeAsStringSync(body)).path,
            suggestedName: name,
            mime: name.endsWith('.pdf') ? 'application/pdf' : 'text/plain',
          ),
      ],
      stats: const {'pages': 3, 'words': 120, 'lowTextPages': 1},
      reviewDir: reviewDir,
    );
  }

  @override
  Future<List<OutputMeta>> validateOutputs(CompositeOutput out, List<PickedFile> inputs, FakeOptions options) async {
    if (badOutput) throw const AppError(AppErrorCode.outputValidationFailed);
    return [for (final f in out.files) OutputMeta(bytes: File(f.path).lengthSync())];
  }
}

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late HistoryRepository history;
  late OutputsRepository outputs;

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    history = HistoryRepository(db);
    outputs = OutputsRepository(paths);
  });
  tearDown(() async => db.close());

  Future<List<JobState>> run(_Tool tool, {String id = 'ocr-1', CancelToken? cancel}) async {
    final states = <JobState>[];
    await JobRunner(paths: paths, history: history, outputs: outputs, device: FakeDevice()).runComposite(
      jobId: id,
      op: tool,
      inputs: const [],
      options: const FakeOptions(),
      cancel: cancel ?? CancelToken(),
      emit: states.add,
    );
    return states;
  }

  test('files adopted, stats in the result and in history, progress passed through', () async {
    final states = await run(_Tool());
    expect(states.whereType<JobProcessing>().map((s) => s.progress).whereType<Determinate>().map((d) => d.done), [0, 1, 2]);
    final r = (states.last as JobCompletedMulti).result;
    expect(r.output.items.cast<OutputOk>().map((o) => o.name), ['a.pdf', 'a.txt']);
    expect(r.stats, {'pages': 3, 'words': 120, 'lowTextPages': 1});
    expect(r.reviewAvailable, isTrue);
    final row = (await history.get('ocr-1'))!;
    expect((row.status, row.tool), (OpStatus.success, ToolId.ocr));
    expect(jsonDecode(row.row.outputMetaJson!), containsPair('words', 120));
    expect(row.row.outputCount, 2);
  });

  test('the review folder survives the job folder; the job folder is gone (ADR-066)', () async {
    await run(_Tool());
    expect(paths.jobDir('ocr-1').existsSync(), isFalse);
    expect(File(p.join(paths.reviewDir('ocr-1').path, 'page_0.txt')).readAsStringSync(), 'secret text');
  });

  test('text only: no file, still a SUCCESS row with the stats (§5)', () async {
    final states = await run(_Tool(files: const {}));
    final r = (states.last as JobCompletedMulti).result;
    expect(r.output.items, isEmpty);
    expect(r.reviewAvailable, isTrue);
    final row = (await history.get('ocr-1'))!;
    expect((row.status, row.row.outputCount, row.row.outputRelPath), (OpStatus.success, 0, null));
    expect(jsonDecode(row.row.outputMetaJson!), containsPair('pages', 3));
    expect(states.last.isCompleted, isTrue);
  });

  test('a single file: its meta and the stats are both kept', () async {
    await run(_Tool(files: const {'a.pdf': '%PDF-1.4'}, review: false));
    final meta = jsonDecode((await history.get('ocr-1'))!.row.outputMetaJson!) as Map;
    expect((meta['bytes'], meta['words']), (8, 120));
    expect(paths.reviewDir('ocr-1').existsSync(), isFalse);
  });

  test('cancel: nothing kept — no outputs, no review text, history cancelled (FR-OCR-10)', () async {
    final cancel = CancelToken();
    final tool = _Tool()..cancelDuring = cancel;
    final states = await run(tool, cancel: cancel);
    expect(states.last, isA<JobCancelled>());
    expect(Directory(p.join(paths.outputsRoot.path, 'ocr-1')).existsSync(), isFalse);
    expect(paths.reviewDir('ocr-1').existsSync(), isFalse);
    expect((await history.get('ocr-1'))!.status, OpStatus.cancelled);
  });

  test('failure or a bad output: no outputs, no review text, history failed with the code', () async {
    for (final (tool, code) in [
      (_Tool(failWith: AppErrorCode.ocrModelUnavailable), AppErrorCode.ocrModelUnavailable),
      (_Tool(badOutput: true), AppErrorCode.outputValidationFailed),
    ]) {
      final id = 'ocr-${code.name}';
      final states = await run(tool, id: id);
      expect((states.last as JobFailed).error.code, code);
      expect(paths.reviewDir(id).existsSync(), isFalse);
      expect(Directory(p.join(paths.outputsRoot.path, id)).existsSync(), isFalse);
      expect((await history.get(id))!.row.errorCode, code.name);
    }
  });

  test('every launch clears all review folders, whatever their age (ADR-047)', () async {
    await run(_Tool());
    await run(_Tool(), id: 'ocr-2');
    expect(await sweepReview(paths), 2);
    expect(paths.reviewRoot.existsSync() ? paths.reviewRoot.listSync() : const <FileSystemEntity>[], isEmpty);
    expect(await sweepReview(paths), 0);
  });

  test('deleteReview removes one job\'s review text (leaving Result/Review)', () async {
    await run(_Tool());
    await deleteReview(paths, 'ocr-1');
    expect(paths.reviewDir('ocr-1').existsSync(), isFalse);
  });
}
