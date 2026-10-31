// T12.1 — LibraryRepository (RELEASE_V1_5 §4.2–4.4, §8), written before the
// implementation, against an in-memory DB and a temp directory: add (copy,
// hash, `.part` cleanup), duplicates, name uniqueness, folders (depth ≤ 3,
// names, moves incl. invalid targets, delete modes), documents (rename, move,
// star, notes, tags, expiry, delete), copyForTool, stats, orphan sweep, and
// the change stream.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late Directory tmp, support;
  late LibraryRepositoryImpl repo;
  var now = DateTime(2026, 10, 31, 9);

  setUp(() {
    db = memoryDb();
    tmp = Directory.systemTemp.createTempSync('lib_repo');
    support = Directory(p.join(tmp.path, 'support'))..createSync();
    now = DateTime(2026, 10, 31, 9);
    repo = LibraryRepositoryImpl(db, support, clock: () => now);
  });
  tearDown(() async {
    await repo.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  String src(String name, String content) => (File(p.join(tmp.path, name))..writeAsStringSync(content)).path;
  Future<LibraryDoc> add(String name, String content, {String? folderId, bool dup = false}) async {
    final r = await repo.addFile(src(name, content),
        displayName: name, folderId: folderId, source: DocSource.import, mime: 'application/pdf', allowDuplicate: dup);
    return (r as Added).doc;
  }

  group('add (§4.2)', () {
    test('copies into library/<id>/<name>, hashes it, records it; the source is untouched; no .part left', () async {
      final s = src('Passport.pdf', '%PDF passport');
      final r = await repo.addFile(s,
          displayName: 'Passport.pdf', source: DocSource.result, sourceTool: ToolId.imageToPdf, mime: 'application/pdf', pageCount: 2);
      final d = (r as Added).doc;
      expect(d.relPath, 'library/${d.id}/Passport.pdf');
      final f = File(repo.absolutePath(d));
      expect(f.readAsStringSync(), '%PDF passport');
      expect(d.sha256, sha256.convert(utf8.encode('%PDF passport')).toString());
      expect((d.sizeBytes, d.pageCount, d.source, d.sourceTool, d.addedAt), (13, 2, DocSource.result, ToolId.imageToPdf, now));
      expect(File(s).readAsStringSync(), '%PDF passport');
      expect(f.parent.listSync().map((e) => p.basename(e.path)), ['Passport.pdf']);
      expect(await repo.get(d.id), isNotNull);
    });

    test('a failing copy leaves no .part, no folder and no row', () async {
      final r = await repo.addFile(p.join(tmp.path, 'missing.pdf'),
          displayName: 'missing.pdf', source: DocSource.import, mime: 'application/pdf');
      expect(r, isA<AddFailed>());
      final lib = Directory(p.join(support.path, 'library'));
      expect(lib.existsSync() ? lib.listSync(recursive: true).whereType<File>() : const <File>[], isEmpty);
      expect(await repo.stats(), const LibraryStats(docCount: 0, totalBytes: 0));
    });

    test('duplicate (same SHA-256) → Duplicate(existing) unless allowDuplicate (FR-LIB-21)', () async {
      final first = await add('a.pdf', 'same bytes');
      final again = await repo.addFile(src('b.pdf', 'same bytes'),
          displayName: 'b.pdf', source: DocSource.import, mime: 'application/pdf');
      expect((again as Duplicate).existing.id, first.id);
      expect((await repo.stats()).docCount, 1, reason: 'nothing added');
      final copy = await add('b.pdf', 'same bytes', dup: true);
      expect(copy.id, isNot(first.id));
    });

    test('a name already in the folder gets " (2)", " (3)" … (case-insensitive)', () async {
      await add('Payslip.pdf', '1');
      expect((await add('payslip.PDF', '2')).name, 'payslip (2).PDF');
      expect((await add('Payslip.pdf', '3')).name, 'Payslip (3).pdf');
      final f = await repo.createFolder('IDs');
      expect((await add('Payslip.pdf', '4', folderId: f.id)).name, 'Payslip.pdf', reason: 'another folder');
    });
  });

  group('folders (FR-LIB-06)', () {
    test('depth ≤ 3: folder → subfolder → sub-subfolder; a 4th level is refused', () async {
      final a = await repo.createFolder('A');
      final b = await repo.createFolder('B', parentId: a.id);
      final c = await repo.createFolder('C', parentId: b.id);
      expect((a.depth, b.depth, c.depth), (1, 2, 3));
      await expectLater(repo.createFolder('D', parentId: c.id),
          throwsA(isA<LibraryException>().having((e) => e.code, 'code', LibraryErrorCode.folderTooDeep)));
    });

    test('names: 1–60 characters after trimming; unique per parent, ignoring case', () async {
      await repo.createFolder('Insurance');
      for (final bad in ['', '   ', 'x' * 61]) {
        await expectLater(repo.createFolder(bad), throwsA(isA<LibraryException>().having((e) => e.code, 'code', LibraryErrorCode.folderNameInvalid)));
      }
      await expectLater(repo.createFolder(' insurance '),
          throwsA(isA<LibraryException>().having((e) => e.code, 'code', LibraryErrorCode.folderNameTaken)));
      final other = await repo.createFolder('Car');
      expect((await repo.createFolder('Insurance', parentId: other.id)).name, 'Insurance');
      final f = await repo.createFolder('Tax');
      await expectLater(repo.renameFolder(f.id, 'INSURANCE'), throwsA(isA<LibraryException>()));
      await repo.renameFolder(f.id, 'Tax 2026');
      expect((await repo.folder(f.id))!.name, 'Tax 2026');
    });

    test('move: not into itself or a descendant; not deeper than 3; depths of the subtree follow', () async {
      final a = await repo.createFolder('A');
      final b = await repo.createFolder('B', parentId: a.id);
      final x = await repo.createFolder('X');
      final y = await repo.createFolder('Y', parentId: x.id);
      final z = await repo.createFolder('Z', parentId: y.id);
      for (final target in [a.id, b.id]) {
        await expectLater(repo.moveFolder(a.id, target),
            throwsA(isA<LibraryException>().having((e) => e.code, 'code', LibraryErrorCode.invalidMove)));
      }
      await expectLater(repo.moveFolder(x.id, a.id), throwsA(isA<LibraryException>().having((e) => e.code, 'code', LibraryErrorCode.folderTooDeep)),
          reason: 'X(+2 levels) under A would reach depth 4');
      await repo.moveFolder(y.id, a.id);
      expect(((await repo.folder(y.id))!.depth, (await repo.folder(z.id))!.depth), (2, 3));
      expect(await repo.canMoveFolder(a.id, x.id), isFalse, reason: 'A now holds Y → Z: under X, Z would be at depth 4');
      expect(await repo.canMoveFolder(b.id, null), isTrue);
    });

    test('delete, "move contents to parent": subfolders and documents go up; names kept unique', () async {
      final a = await repo.createFolder('A');
      final b = await repo.createFolder('B', parentId: a.id);
      await add('Same.pdf', 'root copy');
      await add('Same.pdf', 'in A', folderId: a.id);
      final inB = await add('Deep.pdf', 'in B', folderId: b.id);
      final s = await repo.deleteFolder(a.id, mode: FolderDeleteMode.moveContentsUp);
      expect((s.foldersDeleted, s.docsMoved, s.docsDeleted), (1, 1, 0));
      expect(await repo.folder(a.id), isNull);
      final movedB = (await repo.folder(b.id))!;
      expect((movedB.parentId, movedB.depth), (null, 1));
      expect((await repo.get(inB.id))!.folderId, b.id);
      final rootNames = (await repo.watchDocs().first).map((d) => d.name).toList()..sort();
      expect(rootNames, ['Same (2).pdf', 'Same.pdf']);
    });

    test('delete, "delete everything": the subtree\'s folders, documents, files and search rows go', () async {
      final a = await repo.createFolder('A');
      final b = await repo.createFolder('B', parentId: a.id);
      final d1 = await add('one.pdf', '1', folderId: a.id);
      final d2 = await add('two.pdf', '2', folderId: b.id);
      final keep = await add('keep.pdf', '3');
      final s = await repo.deleteFolder(a.id, mode: FolderDeleteMode.deleteEverything);
      expect((s.foldersDeleted, s.docsDeleted), (2, 2));
      for (final d in [d1, d2]) {
        expect(await repo.get(d.id), isNull);
        expect(Directory(p.dirname(repo.absolutePath(d))).existsSync(), isFalse);
      }
      expect(await repo.get(keep.id), isNotNull);
      expect(await repo.search('one').first, isEmpty);
    });

    test('watchFolders lists a level with direct document counts, by name', () async {
      final b = await repo.createFolder('b-Tax');
      await repo.createFolder('A-IDs');
      await add('x.pdf', 'x', folderId: b.id);
      final level = await repo.watchFolders().first;
      expect(level.map((f) => (f.name, f.docCount)), [('A-IDs', 0), ('b-Tax', 1)]);
      expect(await repo.folderPath(b.id), ['b-Tax']);
    });
  });

  group('documents (FR-LIB-07…13)', () {
    test('rename keeps unique names per folder; move picks a free name; star / notes / tags / expiry', () async {
      final f = await repo.createFolder('IDs');
      final a = await add('A.pdf', 'a');
      await add('B.pdf', 'b');
      await expectLater(repo.rename(a.id, 'b.pdf'),
          throwsA(isA<LibraryException>().having((e) => e.code, 'code', LibraryErrorCode.nameTaken)));
      await repo.rename(a.id, 'Passport.pdf');
      await add('Passport.pdf', 'other', folderId: f.id);
      await repo.move([a.id], f.id);
      final moved = (await repo.get(a.id))!;
      expect((moved.folderId, moved.name), (f.id, 'Passport (2).pdf'));
      await repo.setStarred([a.id], true);
      await repo.setNotes(a.id, 'renew at the consulate');
      await repo.setTags(a.id, [' travel ', 'ID', 'travel', 'x' * 31]);
      await repo.setExpiry(a.id, DateTime(2031, 3, 12), [30, 7, 0], 540);
      final d = (await repo.get(a.id))!;
      expect((d.starred, d.notes, d.expiryDate, d.reminderMinuteOfDay), (true, 'renew at the consulate', DateTime(2031, 3, 12), 540));
      expect(d.tags, ['ID', 'travel']);
      expect(d.reminderOffsets, [30, 7, 0]);
      await expectLater(repo.setNotes(a.id, 'x' * 2001), throwsA(isA<LibraryException>()));
      await repo.setExpiry(a.id, null, const [], null);
      expect((await repo.get(a.id))!.expiryDate, isNull);
    });

    test('watchDocs: sort by name / added / size / expiry (no expiry last); starred filter across folders', () async {
      final f = await repo.createFolder('F');
      now = DateTime(2026, 1, 1);
      final big = await add('beta.pdf', 'x' * 50);
      now = DateTime(2026, 2, 1);
      final small = await add('Alpha.pdf', 'x');
      now = DateTime(2026, 3, 1);
      final mid = await add('gamma.pdf', 'x' * 10);
      await repo.setExpiry(small.id, DateTime(2027, 1, 1), const [7], null);
      await repo.setExpiry(big.id, DateTime(2026, 12, 1), const [7], null);
      Future<List<String>> order(LibrarySort s) async => [for (final d in await repo.watchDocs(sort: s).first) d.name];
      expect(await order(LibrarySort.name), ['Alpha.pdf', 'beta.pdf', 'gamma.pdf']);
      expect(await order(LibrarySort.added), ['gamma.pdf', 'Alpha.pdf', 'beta.pdf']);
      expect(await order(LibrarySort.size), ['beta.pdf', 'gamma.pdf', 'Alpha.pdf']);
      expect(await order(LibrarySort.expiry), ['beta.pdf', 'Alpha.pdf', 'gamma.pdf']);
      await repo.move([mid.id], f.id);
      await repo.setStarred([mid.id, small.id], true);
      expect([for (final d in await repo.watchDocs(starredOnly: true).first) d.name]..sort(), ['Alpha.pdf', 'gamma.pdf']);
      expect([for (final d in await repo.watchDocs(folderId: f.id).first) d.name], ['gamma.pdf']);
    });

    test('expiring soon: within N days, expired ones included, soonest first', () async {
      final a = await add('a.pdf', 'a');
      final b = await add('b.pdf', 'b');
      final c = await add('c.pdf', 'c');
      await repo.setExpiry(a.id, DateTime(2026, 11, 20), const [7], null);
      await repo.setExpiry(b.id, DateTime(2026, 10, 1), const [7], null);
      await repo.setExpiry(c.id, DateTime(2027, 6, 1), const [7], null);
      expect([for (final d in await repo.watchExpiringSoon(days: 60).first) d.name], ['b.pdf', 'a.pdf']);
    });

    test('delete removes rows, files and search rows; copyForTool returns a NEW path with the same bytes', () async {
      final a = await add('Report.pdf', '%PDF report');
      final job = Directory(p.join(tmp.path, 'jobs', 'draft', 'in'))..createSync(recursive: true);
      final copy = await repo.copyForTool(a.id, job);
      expect(copy, isNot(repo.absolutePath(a)));
      expect(p.isWithin(job.path, copy), isTrue);
      expect(File(copy).readAsStringSync(), '%PDF report');
      expect(p.basename(await repo.copyForTool(a.id, job)), 'Report (2).pdf', reason: 'never overwrites');
      await repo.delete([a.id]);
      expect(await repo.get(a.id), isNull);
      expect(File(repo.absolutePath(a)).existsSync(), isFalse);
      expect(File(copy).existsSync(), isTrue, reason: 'the tool\'s copy is the tool\'s');
      expect(await repo.search('report').first, isEmpty);
    });

    test('stats: count and bytes; markOpened sets openedAt', () async {
      final a = await add('a.pdf', '12345');
      await add('b.pdf', '123');
      expect(await repo.stats(), const LibraryStats(docCount: 2, totalBytes: 8));
      now = DateTime(2026, 11, 2);
      await repo.markOpened(a.id);
      expect((await repo.get(a.id))!.openedAt, DateTime(2026, 11, 2));
    });
  });

  test('orphan sweep: library/<id> dirs with no row, stray .part files and import staging are removed', () async {
    final kept = await add('kept.pdf', 'k');
    final lib = Directory(p.join(support.path, 'library'));
    Directory(p.join(lib.path, 'orphan-id')).createSync();
    File(p.join(lib.path, 'orphan-id', 'x.pdf')).writeAsStringSync('x');
    File(p.join(lib.path, kept.id, 'kept.pdf.part')).writeAsStringSync('half');
    Directory(p.join(lib.path, '_import_tmp', 'z')).createSync(recursive: true);
    Directory(p.join(lib.path, '_thumbs')).createSync();
    final removed = await repo.sweepOrphans();
    expect(removed, 3);
    expect(Directory(p.join(lib.path, 'orphan-id')).existsSync(), isFalse);
    expect(File(repo.absolutePath(kept)).existsSync(), isTrue);
    expect(Directory(p.join(lib.path, '_thumbs')).existsSync(), isTrue, reason: 'thumbnails are kept');
    expect(Directory(p.join(lib.path, '_import_tmp')).listSync(), isEmpty);
  });

  test('changes: every write emits an event with the ids it touched', () async {
    final events = <LibraryChange>[];
    final sub = repo.changes.listen(events.add);
    final a = await add('a.pdf', 'a');
    await repo.setExpiry(a.id, DateTime(2027, 1, 1), const [7], null);
    await repo.delete([a.id]);
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.kind), [LibraryChangeKind.added, LibraryChangeKind.updated, LibraryChangeKind.deleted]);
    expect(events.every((e) => e.ids.length == 1 && e.ids.single == a.id), isTrue);
    await sub.cancel();
  });
}
