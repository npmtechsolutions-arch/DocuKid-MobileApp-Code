// T12.1 on a device (RELEASE_V1_5 §4.3–4.4): LibraryRepository on the SQLite
// the app ships (FTS5 + the Devanagari-friendly tokenizer) and the real file
// system: a migrated-style fresh DB, add with hashing, duplicate, search in
// English / with diacritics / in Hindi, snippet, delete.
//
//   flutter test integration_test/library_repository_test.dart -d <android device>
import 'dart:io';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add, duplicate, search (English, café, Hindi, recognised text), delete', (_) async {
    final paths = await AppPaths.resolve();
    final root = Directory(p.join(paths.cacheRoot.path, 'it_library'))..createSync(recursive: true);
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LibraryRepositoryImpl(db, root);
    String src(String n, String c) => (File(p.join(root.path, n))..writeAsStringSync(c)).path;
    try {
      final passport = (await repo.addFile(src('p.pdf', '%PDF passport'),
              displayName: 'Passport.pdf', source: DocSource.scan, mime: 'application/pdf')) as Added;
      expect(File(repo.absolutePath(passport.doc)).existsSync(), isTrue);
      expect(await repo.addFile(src('p2.pdf', '%PDF passport'),
          displayName: 'Copy.pdf', source: DocSource.import, mime: 'application/pdf'), isA<Duplicate>());
      final cafe = (await repo.addFile(src('c.pdf', 'cafe'),
              displayName: 'Receipt café.pdf', source: DocSource.import, mime: 'application/pdf')) as Added;
      await repo.setIndexedText(passport.doc.id, 'भारत सरकार पासपोर्ट संख्या Z1234567 date of expiry 2031', state: IndexState.done);
      Future<List<String>> names(String q) async => [for (final h in await repo.search(q).first) h.doc.name];
      expect(await names('pass'), ['Passport.pdf']);
      expect(await names('cafe'), ['Receipt café.pdf']);
      expect(await names('पासपोर्ट'), ['Passport.pdf']);
      final hit = (await repo.search('expiry').first).single;
      // ignore: avoid_print
      print('T12.1 device snippet: ${hit.snippet}');
      expect(hit.snippet, contains('[expiry]'));
      final hindi = (await repo.search('पासपोर्ट').first).single;
      // ignore: avoid_print
      print('T12.1 device Hindi snippet: ${hindi.snippet}');
      expect(hindi.snippet, contains('[पासपोर्ट]'), reason: 'the whole word is highlighted (M* kept in tokens)');
      await repo.delete([cafe.doc.id]);
      expect(await names('cafe'), isEmpty);
      expect(await repo.stats(), const LibraryStats(docCount: 1, totalBytes: 13));
    } finally {
      await repo.dispose();
      await db.close();
      root.deleteSync(recursive: true);
    }
  });
}
