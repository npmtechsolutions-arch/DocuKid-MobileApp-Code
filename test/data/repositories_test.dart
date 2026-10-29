import 'dart:io';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  group('HistoryRepository', () {
    late AppDatabase db;
    late HistoryRepository repo;
    final t0 = DateTime(2026, 10, 22, 14);

    setUp(() {
      db = memoryDb();
      repo = HistoryRepository(db);
    });
    tearDown(() => db.close());

    Future<void> insert(String id, ToolId tool, {DateTime? at}) => repo.insertRunning(
          id: id,
          tool: tool,
          createdAt: at ?? t0,
          inputs: const [
            InputRecord(displayName: 'a.pdf', mime: 'application/pdf', sizeBytes: 1000, meta: {'p': 3}),
            InputRecord(displayName: 'b.pdf', mime: 'application/pdf', sizeBytes: 500, meta: {'p': 2}),
          ],
          options: {'q': 80},
        );

    test('insert running → complete', () async {
      await insert('1', ToolId.pdfMerge);
      await repo.complete('1',
          finishedAt: t0,
          duration: const Duration(seconds: 2),
          outputName: 'Merged.pdf',
          outputMime: 'application/pdf',
          outputBytes: 1400,
          outputRelPath: '1/Merged.pdf',
          outputMeta: {'pages': 5});
      final r = (await repo.get('1'))!;
      expect(r.status, OpStatus.success);
      expect(r.row.inputTotalBytes, 1500);
      expect(r.inputs.length, 2);
      expect(r.inputPages, 5);
      expect(r.outputMeta['pages'], 5);
      expect(r.options['q'], 80);
      expect(r.outputRecorded, isTrue);
    });

    test('fail / cancel', () async {
      await insert('1', ToolId.pdfMerge);
      await repo.fail('1', 'corruptFile', finishedAt: t0, duration: Duration.zero);
      expect((await repo.get('1'))!.row.errorCode, 'corruptFile');
      await insert('2', ToolId.pdfMerge);
      await repo.markCancelled('2', finishedAt: t0);
      expect((await repo.get('2'))!.status, OpStatus.cancelled);
    });

    test('running rows become interrupted at launch', () async {
      await insert('1', ToolId.pdfMerge);
      await insert('2', ToolId.imageCompress);
      await repo.fail('2', 'x', finishedAt: t0, duration: Duration.zero);
      expect(await repo.markRunningAsInterrupted(), 1);
      expect((await repo.get('1'))!.status, OpStatus.interrupted);
      expect((await repo.get('2'))!.status, OpStatus.failed);
    });

    test('watchRecent returns newest first, limited', () async {
      for (var i = 0; i < 7; i++) {
        await insert('$i', ToolId.imageCompress, at: t0.add(Duration(minutes: i)));
      }
      final list = await repo.watchRecent(5).first;
      expect(list.map((e) => e.id), ['6', '5', '4', '3', '2']);
    });

    test('filters by category and failure', () async {
      await insert('img', ToolId.imageCompress);
      await insert('pdf', ToolId.pdfMerge, at: t0.add(const Duration(minutes: 1)));
      await repo.fail('pdf', 'corruptFile', finishedAt: t0, duration: Duration.zero);
      expect((await repo.watchPage(limit: 50, filter: HistoryFilter.images).first).map((e) => e.id), ['img']);
      expect((await repo.watchPage(limit: 50, filter: HistoryFilter.pdfs).first).map((e) => e.id), ['pdf']);
      expect((await repo.watchPage(limit: 50, filter: HistoryFilter.failed).first).map((e) => e.id), ['pdf']);
      expect((await repo.watchPage(limit: 50, sort: HistorySort.oldest).first).first.id, 'img');
    });

    test('Secure & Sign jobs make PDFs: they are under the PDFs filter (1.4)', () async {
      await insert('img', ToolId.imageCompress);
      await insert('sign', ToolId.pdfSign, at: t0.add(const Duration(minutes: 1)));
      await insert('lock', ToolId.pdfProtect, at: t0.add(const Duration(minutes: 2)));
      expect((await repo.watchPage(limit: 50, filter: HistoryFilter.pdfs).first).map((e) => e.id), ['lock', 'sign']);
      expect((await repo.watchPage(limit: 50, filter: HistoryFilter.images).first).map((e) => e.id), ['img']);
    });

    test('remove cascades inputs; clear empties everything', () async {
      await insert('1', ToolId.pdfMerge);
      await repo.remove('1');
      expect(await repo.get('1'), isNull);
      expect(await db.select(db.operationInputs).get(), isEmpty);
      await insert('2', ToolId.pdfMerge);
      await repo.clear();
      expect(await db.select(db.operations).get(), isEmpty);
    });

    test('retention query finds only finished, undeleted copies before the cutoff', () async {
      await insert('old', ToolId.imageCompress);
      await repo.complete('old',
          finishedAt: t0,
          duration: Duration.zero,
          outputName: 'a.jpg',
          outputMime: 'image/jpeg',
          outputBytes: 1,
          outputRelPath: 'old/a.jpg');
      await insert('new', ToolId.imageCompress);
      await repo.complete('new',
          finishedAt: t0.add(const Duration(days: 10)),
          duration: Duration.zero,
          outputName: 'b.jpg',
          outputMime: 'image/jpeg',
          outputBytes: 1,
          outputRelPath: 'new/b.jpg');
      final due = await repo.outputsFinishedBefore(t0.add(const Duration(days: 1)));
      expect(due.map((r) => r.id), ['old']);
      await repo.markOutputDeleted('old', t0);
      expect(await repo.outputsFinishedBefore(t0.add(const Duration(days: 1))), isEmpty);
    });
  });

  group('OutputsRepository', () {
    late AppPaths paths;
    late OutputsRepository repo;
    setUp(() async {
      paths = await tempPaths();
      repo = OutputsRepository(paths);
    });

    String raw(String name) {
      final d = paths.jobWork('j')..createSync(recursive: true);
      final f = File(p.join(d.path, name))..writeAsBytesSync([1, 2, 3, 4]);
      return f.path;
    }

    test('adopt moves into outputs/<id>/ with a unique name', () async {
      final (abs, rel) = await repo.adopt('j', raw('a.pdf'), 'a.pdf');
      expect(File(abs).existsSync(), isTrue);
      expect(rel, p.join('j', 'a.pdf'));
      final (abs2, _) = await repo.adopt('j', raw('a2.pdf'), 'a.pdf');
      expect(p.basename(abs2), 'a (1).pdf');
      expect(await repo.exists(rel), isTrue);
      expect(await repo.totalBytes(), 8);
    });

    test('rename and delete', () async {
      final (_, rel) = await repo.adopt('j', raw('a.pdf'), 'a.pdf');
      final (abs2, rel2) = await repo.rename(rel, 'b.pdf');
      expect(p.basename(abs2), 'b.pdf');
      expect(await repo.exists(rel2), isTrue);
      await repo.deleteFor('j');
      expect(await repo.exists(rel2), isFalse);
    });
  });

  group('SettingsRepository', () {
    test('defaults', () {
      final s = SettingsRepository(MemoryStore()).load();
      expect(s.imgQuality, 80);
      expect(s.imgFormat, OutputFormatChoice.same);
      expect(s.imgStripMetadata, isTrue);
      expect(s.pdfPageSize, PdfPageSize.a4);
      expect(s.reduceLevel, ReduceLevel.balanced);
      expect(s.outputRetention, Retention.d7);
      expect(s.onboardingDone, isFalse);
    });

    test('US locale defaults to Letter', () {
      expect(SettingsRepository(MemoryStore(), countryCode: 'US').load().pdfPageSize, PdfPageSize.letter);
    });

    test('round-trips every key', () async {
      final store = MemoryStore();
      final repo = SettingsRepository(store);
      final s = repo.load().copyWith(
            themeMode: ThemeMode.dark,
            imgQuality: 55,
            imgFormat: OutputFormatChoice.webp,
            imgStripMetadata: false,
            resizeLockRatio: false,
            resizeCustomPresets: const [CustomPreset('Visa', 600, 600)],
            pdfPageSize: PdfPageSize.legal,
            pdfFit: PdfFit.fill,
            pdfMargin: PdfMargin.large,
            pdfImageQuality: PdfImageQuality.compact,
            reduceLevel: ReduceLevel.strong,
            outputRetention: Retention.forever,
            confirmDestructive: false,
            onboardingDone: true,
            lastTool: ToolId.pdfMerge,
          );
      await repo.save(s);
      final r = SettingsRepository(store).load();
      expect(r.themeMode, ThemeMode.dark);
      expect(r.imgQuality, 55);
      expect(r.imgFormat, OutputFormatChoice.webp);
      expect(r.imgStripMetadata, isFalse);
      expect(r.resizeLockRatio, isFalse);
      expect(r.resizeCustomPresets.single.name, 'Visa');
      expect(r.pdfPageSize, PdfPageSize.legal);
      expect(r.pdfFit, PdfFit.fill);
      expect(r.pdfMargin, PdfMargin.large);
      expect(r.pdfImageQuality, PdfImageQuality.compact);
      expect(r.reduceLevel, ReduceLevel.strong);
      expect(r.outputRetention, Retention.forever);
      expect(r.confirmDestructive, isFalse);
      expect(r.onboardingDone, isTrue);
      expect(r.lastTool, ToolId.pdfMerge);
    });

    test('garbage values fall back to defaults', () {
      final r = SettingsRepository(MemoryStore({'img_quality': 'x', 'reduce_level': 'nope', 'resize_custom_presets': '{'})).load();
      expect(r.imgQuality, 80);
      expect(r.reduceLevel, ReduceLevel.balanced);
      expect(r.resizeCustomPresets, isEmpty);
    });
  });
}
