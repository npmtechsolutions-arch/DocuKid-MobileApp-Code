import 'dart:convert';
import 'dart:io';

import 'package:docukit/app/bootstrap/sweeps.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  test('temp sweep deletes job dirs older than 24 h and keeps drafts', () async {
    final paths = await tempPaths();
    final a = paths.jobDir('a')..createSync(recursive: true);
    final draft = paths.jobDir('draft')..createSync(recursive: true);
    // Just created: nothing is old yet.
    expect(await sweepTemp(paths, now: DateTime.now(), keep: {'draft'}), 0);
    expect(a.existsSync(), isTrue);
    // 30 h later: the plain job dir goes, the draft stays.
    final later = DateTime.now().add(const Duration(hours: 30));
    expect(await sweepTemp(paths, now: later, keep: {'draft'}), 1);
    expect(a.existsSync(), isFalse);
    expect(draft.existsSync(), isTrue);
  });

  test('active draft ids come from saved drafts', () async {
    final store = MemoryStore();
    final repo = SettingsRepository(store);
    await repo.writeDraft(ToolId.pdfMerge.name, jsonEncode({'id': 'abc', 'at': 0, 'files': []}));
    await repo.writeDraft(ToolId.imageCompress.name, '{broken');
    expect(activeDraftIds(repo), {'abc'});
  });

  test('retention sweep deletes expired app copies and marks rows', () async {
    final db = memoryDb();
    final paths = await tempPaths();
    final history = HistoryRepository(db);
    final outputs = OutputsRepository(paths);
    final t0 = DateTime(2026, 10, 1);
    Future<void> make(String id, DateTime finished) async {
      await history.insertRunning(id: id, tool: ToolId.imageCompress, createdAt: finished, inputs: const []);
      final work = paths.jobWork(id)..createSync(recursive: true);
      final raw = File(p.join(work.path, 'x.jpg'))..writeAsBytesSync([1]);
      final (_, rel) = await outputs.adopt(id, raw.path, 'x.jpg');
      await history.complete(id,
          finishedAt: finished,
          duration: Duration.zero,
          outputName: 'x.jpg',
          outputMime: 'image/jpeg',
          outputBytes: 1,
          outputRelPath: rel);
    }

    await make('old', t0);
    await make('new', t0.add(const Duration(days: 6)));
    final now = t0.add(const Duration(days: 8));
    expect(await runRetentionSweep(history, outputs, Retention.d7, now), 1);
    expect((await history.get('old'))!.row.outputDeletedAt, isNotNull);
    expect(await outputs.exists((await history.get('old'))!.row.outputRelPath), isFalse);
    expect(await outputs.exists((await history.get('new'))!.row.outputRelPath), isTrue);
    expect(await runRetentionSweep(history, outputs, Retention.forever, now.add(const Duration(days: 999))), 0);
    await db.close();
  });
}

