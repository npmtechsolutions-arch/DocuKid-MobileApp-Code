// T12.8 on a device (RELEASE_V1_5 R67, FR-LIB-18/19): export the library to
// a ZIP with the real streaming ZIP writer and file system, then import it
// into a brand-new library (fresh database and folder — what a reinstall
// gives) and compare. The real uninstall / reinstall is a phone check:
// flutter test uninstalls the app itself.
//
//   flutter test integration_test/library_backup_test.dart -d <android device>
import 'dart:io';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/features/library/application/library_backup.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R67: export → a fresh library → import: folders, files and details restored (recognised text re-indexed)',
      (_) async {
    final paths = await AppPaths.resolve();
    final dir = Directory(p.join(paths.cacheRoot.path, 'it_backup'))..createSync(recursive: true);
    final dbA = AppDatabase(NativeDatabase.memory()), dbB = AppDatabase(NativeDatabase.memory());
    final a = LibraryRepositoryImpl(dbA, Directory(p.join(dir.path, 'phoneA'))..createSync());
    final b = LibraryRepositoryImpl(dbB, Directory(p.join(dir.path, 'phoneB'))..createSync());
    try {
      Future<LibraryDoc> add(LibraryRepository r, String name, List<int> bytes, {String? folderId}) async {
        final f = File(p.join(dir.path, 'src_$name'))..writeAsBytesSync(bytes);
        return ((await r.addFile(f.path, displayName: name, folderId: folderId, source: DocSource.scan, mime: 'application/pdf'))
                as Added)
            .doc;
      }

      final pdf = await (pw.Document()..addPage(pw.Page(build: (_) => pw.Text('Passport')))).save();
      final ids = await a.createFolder('IDs');
      final travel = await a.createFolder('Travel', parentId: ids.id);
      final passport = await add(a, 'Passport.pdf', pdf, folderId: travel.id);
      await a.setNotes(passport.id, 'Renew at the consulate');
      await a.setTags(passport.id, ['travel']);
      await a.setExpiry(passport.id, DateTime(2031, 3, 15), [30, 7, 0], null);
      await a.setIndexedText(passport.id, 'Republic passport Z1234567', state: IndexState.done);
      await add(a, 'Big.pdf', List.generate(3 * 1024 * 1024, (i) => i % 251), folderId: ids.id);
      await add(a, 'Lease.pdf', [...pdf, 1, 2, 3]);

      final sw = Stopwatch()..start();
      final zip = await exportLibrary(a, workDir: Directory(p.join(dir.path, 'work')), now: DateTime.now());
      final exportMs = sw.elapsedMilliseconds;
      sw.reset();
      final s = await importBackup(b,
          zipPath: zip, staging: Directory(p.join(dir.path, 'phoneB', 'library', '_import_tmp')), freeBytes: () async => 1 << 40);
      // ignore: avoid_print
      print('R67 zip=${File(zip).lengthSync()} B export=$exportMs ms import=${sw.elapsedMilliseconds} ms '
          'imported=${s.imported} dups=${s.duplicates} damaged=${s.damaged}');
      expect((s.imported, s.duplicates, s.damaged), (3, 0, 0));

      final folders = {for (final f in await b.allFolders()) f.name};
      expect(folders, {'IDs', 'Travel'});
      final restored = (await b.search('Passport').first).single.doc;
      expect(await b.folderPath(restored.folderId), ['IDs', 'Travel']);
      expect((restored.notes, restored.expiryDate, restored.source), ('Renew at the consulate', DateTime(2031, 3, 15), DocSource.scan));
      expect(restored.tags, ['travel']);
      expect(restored.reminderOffsets, [30, 7, 0]);
      expect(restored.sha256, passport.sha256);
      expect(File(b.absolutePath(restored)).readAsBytesSync(), pdf);
      expect(restored.indexState, IndexState.none, reason: 'recognised text isn\'t exported; it\'s re-indexed');
      expect(await b.search('Z1234567').first, isEmpty);
      expect(Directory(p.join(dir.path, 'phoneB', 'library', '_import_tmp')).existsSync(), isFalse);
    } finally {
      await a.dispose();
      await b.dispose();
      await dbA.close();
      await dbB.close();
      dir.deleteSync(recursive: true);
    }
  });
}
