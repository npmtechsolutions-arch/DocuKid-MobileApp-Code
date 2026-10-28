// RELEASE_V1_1 §5.1 / DECISIONS C-4: schema v1 → v2. The v1 baseline is the
// DDL dumped from the 1.0 code (test/data/schemas/schema_v1.sql); the pinned
// drift_dev CLI can't run against drift 2.34.4, so there is no drift_dev
// snapshot — this test builds a real v1 file and migrates it instead.
import 'dart:io';

import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
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
  test('schemaVersion is 2', () {
    final db = memoryDb();
    expect(db.schemaVersion, 2);
    db.close();
  });

  test('v1 → v2: the migrated schema equals a fresh v2 schema', () async {
    final migrated = v1Database();
    final fresh = memoryDb();
    expect(await schemaOf(migrated), await schemaOf(fresh));
    final version = await migrated.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 2);
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
}
