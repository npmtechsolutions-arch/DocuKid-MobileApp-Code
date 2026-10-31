// T12.8 — library export / import (RELEASE_V1_5 §4.9, FR-LIB-18/19) and
// FR-LIB-22, on the real LibraryRepository (in-memory DB, temp files): the
// ZIP layout and manifest, a full round trip into an empty library, a folder
// export, duplicates, merging into existing folders, damaged files, files
// outside `files/` (zip-slip), not-a-backup / newer version, the space check;
// and the Recent sweeps never touching library files.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/library/application/library_backup.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  late Directory tmp;
  final dbs = <AppDatabase>[];
  final repos = <LibraryRepositoryImpl>[];
  final now = DateTime(2026, 10, 28, 9);

  setUp(() => tmp = Directory.systemTemp.createTempSync('lib_backup'));
  tearDown(() async {
    for (final r in repos) {
      await r.dispose();
    }
    for (final d in dbs) {
      await d.close();
    }
    repos.clear();
    dbs.clear();
    tmp.deleteSync(recursive: true);
  });

  /// A fresh library (a "new phone").
  LibraryRepositoryImpl library(String name) {
    final db = memoryDb();
    dbs.add(db);
    final r = LibraryRepositoryImpl(db, Directory(p.join(tmp.path, name))..createSync(), clock: () => now);
    repos.add(r);
    return r;
  }

  Future<LibraryDoc> add(LibraryRepository r, String name, String content,
      {String? folderId, DocSource source = DocSource.import, String mime = 'application/pdf'}) async {
    final f = File(p.join(tmp.path, 'src_${DateTime.now().microsecondsSinceEpoch}'))..writeAsStringSync(content);
    return ((await r.addFile(f.path, displayName: name, folderId: folderId, source: source, mime: mime)) as Added).doc;
  }

  List<String> entries(String zip) {
    final input = InputFileStream(zip);
    try {
      return [for (final f in ZipDecoder().decodeStream(input).files) if (f.isFile) f.name]..sort();
    } finally {
      input.closeSync();
    }
  }

  Future<String> export(LibraryRepository r, {String? folderId, String dir = 'work'}) =>
      exportLibrary(r, workDir: Directory(p.join(tmp.path, dir)), now: now, folderId: folderId);

  Future<ImportSummary> import(LibraryRepository r, String zip, {int free = 1 << 40}) =>
      importBackup(r, zipPath: zip, staging: Directory(p.join(tmp.path, 'staging')), freeBytes: () async => free);

  /// "Folder/Sub › name" for every document.
  Future<Set<String>> tree(LibraryRepository r) async {
    final out = <String>{};
    Future<void> walk(String? id) async {
      for (final d in await r.watchDocs(folderId: id).first) {
        out.add('${(await r.folderPath(id)).join('/')} › ${d.name}');
      }
      for (final f in await r.watchFolders(parentId: id).first) {
        await walk(f.id);
      }
    }

    await walk(null);
    return out;
  }

  /// A ZIP written by hand (for broken backups).
  String zipOf(Map<String, List<int>> files) {
    final a = Archive();
    files.forEach((name, bytes) => a.addFile(ArchiveFile(name, bytes.length, bytes)));
    final path = p.join(tmp.path, 'hand_${DateTime.now().microsecondsSinceEpoch}.zip');
    File(path).writeAsBytesSync(ZipEncoder().encode(a));
    return path;
  }

  String sha(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<LibraryRepositoryImpl> seeded() async {
    final r = library('a');
    final ids = await r.createFolder('IDs');
    final travel = await r.createFolder('Travel', parentId: ids.id);
    final passport = await add(r, 'Passport.pdf', '%PDF passport', folderId: travel.id, source: DocSource.scan);
    await r.setNotes(passport.id, 'Number on page 2');
    await r.setTags(passport.id, ['travel', 'id']);
    await r.setStarred([passport.id], true);
    await r.setExpiry(passport.id, DateTime(2031, 3, 15), [30, 7, 0], 600);
    await add(r, 'Passport.pdf', '%PDF other passport', folderId: ids.id); // same name, other folder
    await add(r, 'Travel', 'a file named like the folder', folderId: ids.id, mime: 'application/octet-stream');
    await add(r, 'Lease.pdf', '%PDF lease');
    return r;
  }

  test('FR-LIB-18 export: DocuKit-Backup-<date>/ with the manifest and readable, unique folder paths', () async {
    final r = await seeded();
    final zip = await export(r);
    expect(p.basename(zip), 'DocuKit-Backup-20261028.zip');
    expect(entries(zip), [
      'DocuKit-Backup-20261028/docukit-library.json',
      'DocuKit-Backup-20261028/files/IDs/Passport.pdf',
      'DocuKit-Backup-20261028/files/IDs/Travel.bin',
      'DocuKit-Backup-20261028/files/IDs/Travel/Passport.pdf',
      'DocuKit-Backup-20261028/files/Lease.pdf',
    ]);
    final m = await readBackupManifest(zip);
    expect((m.json['format'], m.json['version'], m.prefix), ('docukit-library', 1, 'DocuKit-Backup-20261028/'));
    final passport = (m.json['documents']! as List).cast<Map<String, Object?>>().firstWhere((d) => d['notes'] == 'Number on page 2');
    expect(passport['file'], 'files/IDs/Travel/Passport.pdf');
    expect(passport['tags'], ['id', 'travel']);
    expect(passport['reminderOffsets'], [30, 7, 0]);
    expect((passport['starred'], passport['expiryDate'], passport['source']), (true, '2031-03-15', 'scan'));
    expect(m.json.toString(), isNot(contains('indexed')), reason: 'no recognised text');
  });

  test('FR-LIB-19 round trip into an empty library: folders, names, notes, tags, star, expiry, reminders, origin, dates', () async {
    final a = await seeded();
    final zip = await export(a);
    final b = library('b');
    final s = await import(b, zip);
    expect((s.imported, s.duplicates, s.damaged), (4, 0, 0));
    expect(await tree(b), await tree(a));
    final pa = (await b.search('Passport').first).map((h) => h.doc).firstWhere((d) => d.notes.isNotEmpty);
    expect((pa.notes, pa.starred, pa.expiryDate, pa.reminderMinuteOfDay, pa.source),
        ('Number on page 2', true, DateTime(2031, 3, 15), 600, DocSource.scan));
    expect(pa.tags, ['id', 'travel']);
    expect(pa.reminderOffsets, [30, 7, 0]);
    expect(pa.addedAt, now);
    expect(File(b.absolutePath(pa)).readAsStringSync(), '%PDF passport');
    expect(Directory(p.join(tmp.path, 'staging')).existsSync(), isFalse, reason: 'staging removed');
  });

  test('importing the same backup again: everything is a duplicate, nothing added', () async {
    final a = await seeded();
    final zip = await export(a);
    final s = await import(a, zip);
    expect((s.imported, s.duplicates, s.damaged), (0, 4, 0));
    expect((await a.stats()).docCount, 4);
  });

  test('merges into existing folders (by path, ignoring case) instead of creating "IDs (2)"', () async {
    final a = await seeded();
    final zip = await export(a);
    final b = library('b');
    final ids = await b.createFolder('ids');
    await add(b, 'Visa.pdf', '%PDF visa', folderId: ids.id);
    await import(b, zip);
    expect({for (final f in await b.allFolders()) f.name}, {'ids', 'Travel'});
    expect(await tree(b), contains('ids › Visa.pdf'));
    expect(await tree(b), contains('ids/Travel › Passport.pdf'));
  });

  test('a folder export holds that folder and below; importing recreates it at the root', () async {
    final a = await seeded();
    final travel = (await a.allFolders()).firstWhere((f) => f.name == 'Travel');
    final zip = await export(a, folderId: travel.id, dir: 'w2');
    expect(entries(zip), ['DocuKit-Backup-20261028/docukit-library.json', 'DocuKit-Backup-20261028/files/Travel/Passport.pdf']);
    final b = library('b');
    expect((await import(b, zip)).imported, 1);
    expect(await tree(b), {'Travel › Passport.pdf'});
  });

  test('a file whose SHA-256 doesn\'t match is skipped as damaged; the rest is imported', () async {
    final manifest = {
      'format': 'docukit-library',
      'version': 1,
      'folders': <Object>[],
      'documents': [
        {'id': 'a', 'folderId': null, 'name': 'ok.pdf', 'file': 'files/ok.pdf', 'sha256': sha('%PDF ok'), 'mime': 'application/pdf'},
        {'id': 'b', 'folderId': null, 'name': 'bad.pdf', 'file': 'files/bad.pdf', 'sha256': sha('%PDF original'), 'mime': 'application/pdf'},
        {'id': 'c', 'folderId': null, 'name': 'gone.pdf', 'file': 'files/gone.pdf', 'sha256': sha('x'), 'mime': 'application/pdf'},
      ],
    };
    final zip = zipOf({
      'docukit-library.json': utf8.encode(jsonEncode(manifest)),
      'files/ok.pdf': utf8.encode('%PDF ok'),
      'files/bad.pdf': utf8.encode('%PDF tampered'),
    });
    final s = await import(library('b'), zip);
    expect((s.imported, s.duplicates, s.damaged), (1, 0, 2));
  });

  test('zip-slip: a manifest path outside files/ is never read or written', () async {
    final manifest = {
      'format': 'docukit-library',
      'version': 1,
      'folders': <Object>[],
      'documents': [
        for (final f in ['../evil.pdf', 'files/../../evil.pdf', '/etc/evil.pdf', 'files\\..\\evil.pdf'])
          {'id': f, 'folderId': null, 'name': 'evil.pdf', 'file': f, 'sha256': sha('evil'), 'mime': 'application/pdf'},
      ],
    };
    final zip = zipOf({'docukit-library.json': utf8.encode(jsonEncode(manifest)), '../evil.pdf': utf8.encode('evil')});
    final b = library('b');
    final s = await import(b, zip);
    expect((s.imported, s.damaged), (0, 4));
    expect(File(p.join(tmp.path, 'evil.pdf')).existsSync(), isFalse);
    expect((await b.stats()).docCount, 0);
  });

  test('not a DocuKit backup (no manifest, not JSON, wrong format, not a ZIP) / a newer version → explained', () async {
    final b = library('b');
    for (final zip in [
      zipOf({'photo.jpg': [1, 2, 3]}),
      zipOf({'docukit-library.json': utf8.encode('not json')}),
      zipOf({'docukit-library.json': utf8.encode(jsonEncode({'format': 'other', 'version': 1}))}),
      (File(p.join(tmp.path, 'x.zip'))..writeAsStringSync('not a zip')).path,
    ]) {
      await expectLater(import(b, zip), throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.notBackup)));
    }
    final newer = zipOf({'docukit-library.json': utf8.encode(jsonEncode({'format': 'docukit-library', 'version': 2}))});
    await expectLater(import(b, newer), throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.tooNew)));
  });

  test('not enough space (files + 50 MB) → insufficientStorage, nothing imported', () async {
    final a = await seeded();
    final zip = await export(a);
    final b = library('b');
    await expectLater(import(b, zip, free: importHeadroomBytes), throwsA(isA<AppError>()
        .having((e) => e.code, 'code', AppErrorCode.insufficientStorage)));
    expect((await b.stats()).docCount, 0);
  });

  test('FR-LIB-22: Recent\'s retention sweep, temp clean-up and Clear history never touch library files', () async {
    final root = Directory(p.join(tmp.path, 'app'));
    final paths = AppPaths(cacheRoot: Directory(p.join(root.path, 'cache'))..createSync(recursive: true),
        supportRoot: Directory(p.join(root.path, 'support'))..createSync(recursive: true));
    final db = memoryDb();
    dbs.add(db);
    final lib = LibraryRepositoryImpl(db, paths.supportRoot);
    repos.add(lib);
    final d = await add(lib, 'Passport.pdf', '%PDF keep');
    final outputs = OutputsRepository(paths);
    await outputs.deleteFor('some-job');
    await outputs.clearTemp();
    await outputs.deleteAll();
    await HistoryRepository(db).clear();
    expect(File(lib.absolutePath(d)).readAsStringSync(), '%PDF keep');
    expect(await lib.get(d.id), isNotNull);
    expect(toolIdByName('pdfMerge'), ToolId.pdfMerge);
  });
}

