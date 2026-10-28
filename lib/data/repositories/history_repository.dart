import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/search/tool_catalog.dart';
import '../db/app_database.dart';

/// Status strings stored in `operations.status`.
abstract final class OpStatus {
  static const running = 'RUNNING';
  static const success = 'SUCCESS';

  /// Multi-output job where some items failed (RELEASE_V1_1 §5.1).
  static const partial = 'PARTIAL';
  static const failed = 'FAILED';
  static const cancelled = 'CANCELLED';
  static const interrupted = 'INTERRUPTED';
}

class InputRecord {
  const InputRecord({required this.displayName, required this.mime, required this.sizeBytes, this.meta});
  final String displayName;
  final String mime;
  final int sizeBytes;
  final Map<String, Object?>? meta;
}

/// One item of a multi-output job, for `operation_outputs`.
class OutputRecord {
  const OutputRecord({
    required this.displayName,
    this.relPath,
    this.mime,
    this.sizeBytes,
    this.beforeBytes,
    this.errorCode,
    this.meta,
  });
  final String displayName;
  final String? relPath, mime;
  final int? sizeBytes, beforeBytes;
  final String? errorCode;
  final Map<String, Object?>? meta;

  bool get ok => relPath != null;
}

enum HistoryFilter { all, images, pdfs, failed }

enum HistorySort { newest, oldest, saving }

/// One history row for the UI.
class OperationRecord {
  OperationRecord(this.row, this.inputs);
  final OperationRow row;
  final List<OperationInputRow> inputs;

  String get id => row.id;
  ToolId? get tool => toolIdByName(row.tool);
  String get status => row.status;
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(row.createdAt);
  DateTime? get finishedAt => row.finishedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(row.finishedAt!);
  Map<String, Object?> get outputMeta =>
      row.outputMetaJson == null ? const {} : (jsonDecode(row.outputMetaJson!) as Map).cast<String, Object?>();
  Map<String, Object?> get options =>
      row.optionsJson == null ? const {} : (jsonDecode(row.optionsJson!) as Map).cast<String, Object?>();
  int get inputPages {
    var total = 0;
    for (final i in inputs) {
      if (i.metaJson == null) continue;
      final m = (jsonDecode(i.metaJson!) as Map);
      total += (m['p'] as int?) ?? 0;
    }
    return total;
  }

  /// Several outputs, listed in `operation_outputs` (RELEASE_V1_1 §5.1).
  bool get isMulti => row.outputCount > 1;

  /// Finished with outputs: SUCCESS, or PARTIAL for a multi-output job.
  bool get completed => status == OpStatus.success || status == OpStatus.partial;

  /// The row says the copy should exist; the file check is done separately.
  bool get outputRecorded =>
      row.outputDeletedAt == null && (isMulti ? completed : row.outputRelPath != null);
}

class HistoryRepository {
  HistoryRepository(this._db);
  final AppDatabase _db;

  Future<void> insertRunning({
    required String id,
    required ToolId tool,
    required DateTime createdAt,
    required List<InputRecord> inputs,
    Map<String, Object?>? options,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.operations).insert(OperationsCompanion.insert(
            id: id,
            tool: tool.name,
            status: OpStatus.running,
            createdAt: createdAt.millisecondsSinceEpoch,
            inputCount: inputs.length,
            inputTotalBytes: inputs.fold(0, (s, i) => s + i.sizeBytes),
            optionsJson: Value(options == null ? null : jsonEncode(options)),
          ));
      for (var i = 0; i < inputs.length; i++) {
        final r = inputs[i];
        await _db.into(_db.operationInputs).insert(OperationInputsCompanion.insert(
              operationId: id,
              position: i,
              displayName: r.displayName,
              mime: r.mime,
              sizeBytes: r.sizeBytes,
              metaJson: Value(r.meta == null ? null : jsonEncode(r.meta)),
            ));
      }
    });
  }

  Future<void> complete(
    String id, {
    required DateTime finishedAt,
    required Duration duration,
    required String outputName,
    required String outputMime,
    required int outputBytes,
    required String outputRelPath,
    Map<String, Object?>? outputMeta,
  }) =>
      (_db.update(_db.operations)..where((t) => t.id.equals(id))).write(OperationsCompanion(
        status: const Value(OpStatus.success),
        finishedAt: Value(finishedAt.millisecondsSinceEpoch),
        durationMs: Value(duration.inMilliseconds),
        outputName: Value(outputName),
        outputMime: Value(outputMime),
        outputBytes: Value(outputBytes),
        outputRelPath: Value(outputRelPath),
        outputMetaJson: Value(outputMeta == null ? null : jsonEncode(outputMeta)),
      ));

  /// Finishes a multi-output job: SUCCESS when no item failed, else PARTIAL.
  /// A batch of one also fills the single-output columns, so History and
  /// Details treat it like a 1.0 job (ADR-036).
  Future<void> completeMulti(
    String id, {
    required DateTime finishedAt,
    required Duration duration,
    required List<OutputRecord> outputs,
  }) =>
      _db.transaction(() async {
        final ok = outputs.where((o) => o.ok).toList();
        final single = outputs.length == 1 ? ok.firstOrNull : null;
        await (_db.update(_db.operations)..where((t) => t.id.equals(id))).write(OperationsCompanion(
          status: Value(ok.length == outputs.length ? OpStatus.success : OpStatus.partial),
          finishedAt: Value(finishedAt.millisecondsSinceEpoch),
          durationMs: Value(duration.inMilliseconds),
          outputCount: Value(outputs.length),
          failedCount: Value(outputs.length - ok.length),
          outputBytes: Value(ok.fold<int>(0, (s, o) => s + (o.sizeBytes ?? 0))),
          outputName: Value(single?.displayName),
          outputMime: Value(single?.mime),
          outputRelPath: Value(single?.relPath),
          outputMetaJson: Value(single?.meta == null ? null : jsonEncode(single!.meta)),
        ));
        for (var i = 0; i < outputs.length; i++) {
          final o = outputs[i];
          await _db.into(_db.operationOutputs).insert(OperationOutputsCompanion.insert(
                operationId: id,
                position: i,
                displayName: o.displayName,
                relPath: Value(o.relPath),
                sizeBytes: Value(o.sizeBytes),
                beforeBytes: Value(o.beforeBytes),
                errorCode: Value(o.errorCode),
                metaJson: Value(o.meta == null && o.mime == null ? null : jsonEncode({...?o.meta, if (o.mime != null) 'mime': o.mime})),
              ));
        }
      });

  /// The ZIP built on demand for a multi-output job (`outputs/<jobId>/…`);
  /// null forgets it.
  Future<void> setZip(String id, String? relPath) => (_db.update(_db.operations)..where((t) => t.id.equals(id)))
      .write(OperationsCompanion(zipRelPath: Value(relPath)));

  /// One output of a multi job was discarded: its file is gone; the row stays
  /// with no path and no error (failed rows have an error code).
  Future<void> markItemDiscarded(String id, int position) => (_db.update(_db.operationOutputs)
        ..where((t) => t.operationId.equals(id) & t.position.equals(position)))
      .write(const OperationOutputsCompanion(relPath: Value(null)));

  Future<List<OperationOutputRow>> outputsOf(String id) => (_db.select(_db.operationOutputs)
        ..where((t) => t.operationId.equals(id))
        ..orderBy([(t) => OrderingTerm.asc(t.position)]))
      .get();

  Future<void> fail(String id, String errorCode, {required DateTime finishedAt, required Duration duration}) =>
      (_db.update(_db.operations)..where((t) => t.id.equals(id))).write(OperationsCompanion(
        status: const Value(OpStatus.failed),
        errorCode: Value(errorCode),
        finishedAt: Value(finishedAt.millisecondsSinceEpoch),
        durationMs: Value(duration.inMilliseconds),
      ));

  Future<void> markCancelled(String id, {required DateTime finishedAt}) =>
      (_db.update(_db.operations)..where((t) => t.id.equals(id))).write(OperationsCompanion(
        status: const Value(OpStatus.cancelled),
        finishedAt: Value(finishedAt.millisecondsSinceEpoch),
      ));

  /// Launch fix-up (FEATURE_SPECS §5). Returns the number of rows changed.
  Future<int> markRunningAsInterrupted() =>
      (_db.update(_db.operations)..where((t) => t.status.equals(OpStatus.running))).write(
        const OperationsCompanion(status: Value(OpStatus.interrupted), errorCode: Value('interrupted')),
      );

  Future<void> markSaved(String id) => (_db.update(_db.operations)..where((t) => t.id.equals(id)))
      .write(const OperationsCompanion(savedExternally: Value(true)));

  Future<void> markOutputDeleted(String id, DateTime at) =>
      (_db.update(_db.operations)..where((t) => t.id.equals(id)))
          .write(OperationsCompanion(outputDeletedAt: Value(at.millisecondsSinceEpoch)));

  Future<void> markAllOutputsDeleted(DateTime at) =>
      (_db.update(_db.operations)..where((t) => _hasOutputs(t) & t.outputDeletedAt.isNull()))
          .write(OperationsCompanion(outputDeletedAt: Value(at.millisecondsSinceEpoch)));

  Future<void> rename(String id, {required String name, required String relPath}) =>
      (_db.update(_db.operations)..where((t) => t.id.equals(id)))
          .write(OperationsCompanion(outputName: Value(name), outputRelPath: Value(relPath)));

  /// Successful rows whose app copy is past [cutoff] and not yet deleted.
  Future<List<OperationRow>> outputsFinishedBefore(DateTime cutoff) => (_db.select(_db.operations)
        ..where((t) =>
            _hasOutputs(t) &
            t.outputDeletedAt.isNull() &
            t.finishedAt.isSmallerThanValue(cutoff.millisecondsSinceEpoch)))
      .get();

  /// Rows with app copies: a single output, or a multi-output job's files.
  static Expression<bool> _hasOutputs($OperationsTable t) =>
      t.outputRelPath.isNotNull() | t.outputCount.isBiggerThanValue(1);

  Future<void> remove(String id) => (_db.delete(_db.operations)..where((t) => t.id.equals(id))).go();

  Future<void> clear() => _db.transaction(() async {
        await _db.delete(_db.operationInputs).go();
        await _db.delete(_db.operationOutputs).go();
        await _db.delete(_db.operations).go();
      });

  Future<OperationRecord?> get(String id) async {
    final row = await (_db.select(_db.operations)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return OperationRecord(row, await _inputsOf(id));
  }

  Stream<OperationRecord?> watch(String id) =>
      (_db.select(_db.operations)..where((t) => t.id.equals(id))).watchSingleOrNull().asyncMap(
            (row) async => row == null ? null : OperationRecord(row, await _inputsOf(id)),
          );

  Future<List<OperationInputRow>> _inputsOf(String id) => (_db.select(_db.operationInputs)
        ..where((t) => t.operationId.equals(id))
        ..orderBy([(t) => OrderingTerm.asc(t.position)]))
      .get();

  Stream<List<OperationRecord>> watchRecent(int limit) => watchPage(limit: limit);

  Stream<List<OperationRecord>> watchPage({
    required int limit,
    HistoryFilter filter = HistoryFilter.all,
    HistorySort sort = HistorySort.newest,
    bool onlyCompleted = false,
  }) {
    final q = _db.select(_db.operations);
    final imageTools = toolCatalog.where((t) => t.category == ToolCategory.image).map((t) => t.id.name);
    final pdfTools = toolCatalog.where((t) => t.category == ToolCategory.pdf).map((t) => t.id.name);
    switch (filter) {
      case HistoryFilter.all:
        break;
      case HistoryFilter.images:
        q.where((t) => t.tool.isIn(imageTools));
      case HistoryFilter.pdfs:
        q.where((t) => t.tool.isIn(pdfTools));
      case HistoryFilter.failed:
        q.where((t) => t.status.isIn([OpStatus.failed, OpStatus.interrupted, OpStatus.cancelled]));
    }
    if (onlyCompleted) q.where((t) => t.status.isIn([OpStatus.success, OpStatus.partial]));
    switch (sort) {
      case HistorySort.newest:
        q.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      case HistorySort.oldest:
        q.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
      case HistorySort.saving:
        q.orderBy([
          (t) => OrderingTerm(
                expression: t.inputTotalBytes - coalesce([t.outputBytes, t.inputTotalBytes]),
                mode: OrderingMode.desc,
              ),
          (t) => OrderingTerm.desc(t.createdAt),
        ]);
    }
    q.limit(limit);
    return q.watch().asyncMap((rows) async {
      if (rows.isEmpty) return const <OperationRecord>[];
      final ids = rows.map((r) => r.id).toList();
      final inputs = await (_db.select(_db.operationInputs)
            ..where((t) => t.operationId.isIn(ids))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
      final byOp = <String, List<OperationInputRow>>{};
      for (final i in inputs) {
        (byOp[i.operationId] ??= []).add(i);
      }
      return [for (final r in rows) OperationRecord(r, byOp[r.id] ?? const [])];
    });
  }
}
