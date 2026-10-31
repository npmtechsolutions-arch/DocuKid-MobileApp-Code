// RELEASE_V1_1 §5.1 / DECISIONS C-4: schema v1 → v2. RELEASE_V1_2 §5: v2 → v3
// (no DDL: `scanDocument` is stored as text; the version marks 1.2 data).
// RELEASE_V1_5 §4.3: v3 → v4 adds the library tables, FTS5 and indexes
// (1.3 and 1.4 kept v3; schema_v3.sql is dumped from the 1.4 code). The v1 baseline is the
// DDL dumped from the 1.0 code (test/data/schemas/schema_v1.sql); the pinned
// drift_dev CLI can't run against drift 2.34.4, so there is no drift_dev
// snapshot — this test builds a real v1 file and migrates it instead.
import 'dart:io';

import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// A database exactly as 1.0 left it, with one finished job in it.
AppDatabase v1Database() => AppDatabase(NativeDatabase.memory(setup: (raw) {
      final ddl = File('test/data/schemas/schema_v1.sql').readAsStringSync();
      for (final stmt in ddl.split(';\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        raw.execute(stmt.endsWith(';') ? stmt : '$stmt;');
      }
      raw.execute('PRAGMA user_version = 1');
      raw.execute(
        "INSERT INTO operations (id, tool, status, created_at, finished_at, duration_ms, input_count, "
        "input_total_bytes, output_name, output_mime, output_bytes, output_rel_path, output_meta_json) VALUES "
        "('old', 'imageCompress', 'SUCCESS', 1000, 2000, 1000, 1, 500, 'a.jpg', 'image/jpeg', 200, 'old/a.jpg', '{\"bytes\":200}')",
      );
      raw.execute(
        "INSERT INTO operation_inputs (operation_id, position, display_name, mime, size_bytes) "
        "VALUES ('old', 0, 'a.jpg', 'image/jpeg', 500)",
      );
    }));

/// A database exactly as 1.1 left it (schema_v2.sql, dumped from the 1.1
/// code), with one multi-output job in it.
AppDatabase v2Database() => AppDatabase(NativeDatabase.memory(setup: (raw) {
      final ddl = File('test/data/schemas/schema_v2.sql').readAsStringSync();
      for (final stmt in ddl.split(';\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        raw.execute(stmt.endsWith(';') ? stmt : '$stmt;');
      }
      raw.execute('PRAGMA user_version = 2');
      raw.execute(
        "INSERT INTO operations (id, tool, status, created_at, input_count, input_total_bytes, output_count, failed_count) "
        "VALUES ('v2job', 'pdfSplit', 'SUCCESS', 1000, 1, 500, 3, 0)",
      );
    }));

/// A database exactly as 1.2–1.4 left it (schema_v3.sql), with one finished
/// Protect job in it.
AppDatabase v3Database() => AppDatabase(NativeDatabase.memory(setup: (raw) {
      final ddl = File('test/data/schemas/schema_v3.sql').readAsStringSync();
      for (final stmt in ddl.split(';\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        raw.execute(stmt.endsWith(';') ? stmt : '$stmt;');
      }
      raw.execute('PRAGMA user_version = 3');
      raw.execute(
        "INSERT INTO operations (id, tool, status, created_at, input_count, input_total_bytes, options_json, output_count, failed_count) "
        "VALUES ('v3job', 'pdfProtect', 'SUCCESS', 5000, 1, 700, '{}', 1, 0)",
      );
    }));

/// Columns, indexes and foreign keys per table — what must match between a
/// migrated and a freshly created database (the stored CREATE text differs
/// after ALTER TABLE, so it isn't compared).
Future<Map<String, Object>> schemaOf(AppDatabase db) async {
  final tables = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
      .get();
  final out = <String, Object>{};
  for (final t in tables.map((r) => r.read<String>('name'))) {
    final cols = await db.customSelect('PRAGMA table_info("$t")').get();
    final fks = await db.customSelect('PRAGMA foreign_key_list("$t")').get();
    out[t] = {
      'columns': [
        for (final c in cols) '${c.data['name']} ${c.data['type']} nn=${c.data['notnull']} d=${c.data['dflt_value']} pk=${c.data['pk']}',
      ]..sort(),
      'fks': [for (final f in fks) '${f.data['from']}→${f.data['table']}.${f.data['to']} ${f.data['on_delete']}']..sort(),
    };
  }
  final idx = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%' ORDER BY name")
      .get();
  out['indexes'] = [for (final i in idx) i.read<String>('name')];
  return out;
}

void main() {
  test('schemaVersion is 4', () {
    final db = memoryDb();
    expect(db.schemaVersion, 4);
    db.close();
  });

  test('v1 → current: the migrated schema equals a fresh one', () async {
    final migrated = v1Database();
    final fresh = memoryDb();
    expect(await schemaOf(migrated), await schemaOf(fresh));
    final version = await migrated.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 4);
    await migrated.close();
    await fresh.close();
  });

  test('v1 rows survive with single-output defaults', () async {
    final db = v1Database();
    final rec = (await HistoryRepository(db).get('old'))!;
    expect(rec.status, OpStatus.success);
    expect(rec.row.outputRelPath, 'old/a.jpg');
    expect(rec.row.outputCount, 1);
    expect(rec.row.failedCount, 0);
    expect(rec.row.zipRelPath, isNull);
    expect(rec.inputs.single.displayName, 'a.jpg');
    expect(await HistoryRepository(db).outputsOf('old'), isEmpty);
    await db.close();
  });

  test('after migrating, PARTIAL jobs and their outputs can be written; deleting the job cascades', () async {
    final db = v1Database();
    await db.into(db.operations).insert(OperationsCompanion.insert(
          id: 'multi',
          tool: 'imageCompress',
          status: OpStatus.partial,
          createdAt: 3000,
          inputCount: 2,
          inputTotalBytes: 900,
          outputCount: const Value(2),
          failedCount: const Value(1),
        ));
    await db.into(db.operationOutputs).insert(OperationOutputsCompanion.insert(
          operationId: 'multi',
          position: 0,
          displayName: 'a.jpg',
          relPath: const Value('multi/a.jpg'),
          sizeBytes: const Value(100),
        ));
    await db.into(db.operationOutputs).insert(OperationOutputsCompanion.insert(
          operationId: 'multi',
          position: 1,
          displayName: 'b.jpg',
          errorCode: const Value('corruptFile'),
        ));
    final repo = HistoryRepository(db);
    expect((await repo.outputsOf('multi')).map((o) => o.errorCode), [null, 'corruptFile']);
    await repo.remove('multi');
    expect(await repo.outputsOf('multi'), isEmpty);
    await db.close();
  });

  test('v2 → current: same schema as a fresh database; 1.1 rows intact', () async {
    final migrated = v2Database();
    final fresh = memoryDb();
    expect(await schemaOf(migrated), await schemaOf(fresh));
    final version = await migrated.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 4);
    final rec = (await HistoryRepository(migrated).get('v2job'))!;
    expect((rec.row.tool, rec.row.outputCount), ('pdfSplit', 3));
    await migrated.close();
    await fresh.close();
  });

  test('after v3, a Scan Document row reads back as ToolId.scanDocument', () async {
    final db = v2Database();
    await db.into(db.operations).insert(OperationsCompanion.insert(
          id: 'scan',
          tool: 'scanDocument',
          status: OpStatus.success,
          createdAt: 4000,
          inputCount: 3,
          inputTotalBytes: 900,
        ));
    final rec = (await HistoryRepository(db).get('scan'))!;
    expect(rec.tool, ToolId.scanDocument);
    await db.close();
  });

  test('v3 → v4: library tables, FTS5 table and indexes; same schema as fresh; 1.4 rows intact', () async {
    final migrated = v3Database();
    final fresh = memoryDb();
    expect(await schemaOf(migrated), await schemaOf(fresh));
    expect((await migrated.customSelect('PRAGMA user_version').getSingle()).data.values.single, 4);
    final names = [
      for (final r in await migrated.customSelect("SELECT name FROM sqlite_master WHERE type IN ('table', 'index')").get())
        r.read<String>('name'),
    ];
    expect(names, containsAll(['library_folders', 'library_documents', 'library_tags', 'library_fts',
        'idx_lib_docs_folder', 'idx_lib_docs_sha', 'idx_lib_docs_expiry', 'idx_lib_docs_added']));
    final fts = await migrated.customSelect("SELECT sql FROM sqlite_master WHERE name = 'library_fts'").getSingle();
    expect(fts.read<String>('sql'), allOf(contains('fts5'), contains('unicode61'), contains('L* N* Co M*')));
    final rec = (await HistoryRepository(migrated).get('v3job'))!;
    expect((rec.row.tool, rec.row.optionsJson), ('pdfProtect', '{}'));
    await migrated.close();
    await fresh.close();
  });
}
