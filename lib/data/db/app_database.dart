import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Metadata only — never file bytes (rule 10). Names are display names, never
/// paths (ADR-016).
@DataClassName('OperationRow')
class Operations extends Table {
  TextColumn get id => text()();
  TextColumn get tool => text()(); // ToolId.name
  TextColumn get status => text()(); // RUNNING|SUCCESS|PARTIAL|FAILED|CANCELLED|INTERRUPTED
  TextColumn get errorCode => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get finishedAt => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get inputCount => integer()();
  IntColumn get inputTotalBytes => integer()();
  TextColumn get outputName => text().nullable()();
  TextColumn get outputMime => text().nullable()();
  IntColumn get outputBytes => integer().nullable()();
  TextColumn get outputRelPath => text().nullable()();
  TextColumn get outputMetaJson => text().nullable()();
  TextColumn get optionsJson => text().nullable()();
  BoolColumn get savedExternally => boolean().withDefault(const Constant(false))();
  IntColumn get outputDeletedAt => integer().nullable()();

  // v2 (RELEASE_V1_1 §5.1). Multi-output jobs list their files in
  // OperationOutputs when outputCount > 1.
  IntColumn get outputCount => integer().withDefault(const Constant(1))();
  IntColumn get failedCount => integer().withDefault(const Constant(0))();
  TextColumn get zipRelPath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OperationInputRow')
class OperationInputs extends Table {
  TextColumn get operationId => text().references(Operations, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get displayName => text()();
  TextColumn get mime => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get metaJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {operationId, position};
}

/// One row per item of a multi-output job (v2).
@DataClassName('OperationOutputRow')
class OperationOutputs extends Table {
  TextColumn get operationId => text().references(Operations, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get displayName => text()(); // file name only
  TextColumn get relPath => text().nullable()(); // relative to outputs/; null if the item failed
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get beforeBytes => integer().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get metaJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {operationId, position};
}

@DriftDatabase(tables: [Operations, OperationInputs, OperationOutputs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'docukit'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX IF NOT EXISTS idx_ops_created ON operations (created_at DESC)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_ops_tool ON operations (tool)');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(operations, operations.outputCount);
            await m.addColumn(operations, operations.failedCount);
            await m.addColumn(operations, operations.zipRelPath);
            await m.createTable(operationOutputs);
          }
          // v3 (1.2, RELEASE_V1_2 §5): no DDL. `tool` is stored as text, so
          // `scanDocument` rows need nothing; the version marks 1.2 data.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
