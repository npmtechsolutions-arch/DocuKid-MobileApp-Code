// T12.1 — library search (RELEASE_V1_5 §4.3, §8 "FTS search", ADR-055),
// written before the implementation: prefix matching, diacritics, Hindi,
// ranking name > notes > body, snippets, folder scope (incl. subfolders),
// deleted docs drop out, recognised text capped at 200k, and the query
// builder never passes FTS syntax through.
import 'dart:io';

import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/fts.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LibraryRepositoryImpl repo;

  setUp(() {
    db = memoryDb();
    tmp = Directory.systemTemp.createTempSync('lib_fts');
    repo = LibraryRepositoryImpl(db, Directory(p.join(tmp.path, 'support'))..createSync(), clock: () => DateTime(2026, 10, 31));
  });
  tearDown(() async {
    await repo.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<LibraryDoc> add(String name, {String? folderId, String notes = '', String body = '', List<String> tags = const []}) async {
    final s = (File(p.join(tmp.path, '${name.hashCode}_$name'))..writeAsStringSync('content of $name')).path;
    final d = ((await repo.addFile(s, displayName: name, folderId: folderId, source: DocSource.import, mime: 'application/pdf'))
            as Added)
        .doc;
    if (notes.isNotEmpty) await repo.setNotes(d.id, notes);
    if (tags.isNotEmpty) await repo.setTags(d.id, tags);
    if (body.isNotEmpty) await repo.setIndexedText(d.id, body, state: IndexState.done);
    return d;
  }

  Future<List<String>> names(String q, {String? folderId}) async =>
      [for (final h in await repo.search(q, folderId: folderId).first) h.doc.name];

  test('query builder: words → quoted prefix terms; FTS operators and quotes in the input are inert', () {
    expect(ftsMatchQuery('pass port'), '"pass"* "port"*');
    expect(ftsMatchQuery('  '), isNull);
    expect(ftsMatchQuery('NEAR(a b) OR "x" -y*'), '"NEAR"* "a"* "b"* "OR"* "x"* "y"*');
    expect(ftsMatchQuery('पासपोर्ट संख्या'), '"पासपोर्ट"* "संख्या"*');
  });

  test('prefix matching and diacritics: "pass" finds Passport; "cafe" finds "café"', () async {
    await add('Passport.pdf');
    await add('Receipt café.pdf');
    expect(await names('pass'), ['Passport.pdf']);
    expect(await names('cafe'), ['Receipt café.pdf']);
    expect(await names('CAFÉ'), ['Receipt café.pdf']);
  });

  test('Hindi: whole words, prefixes and words in recognised text (ADR-055 tokenizer)', () async {
    await add('Card.pdf', body: 'भारत सरकार पासपोर्ट संख्या Z1234567');
    expect(await names('पासपोर्ट'), ['Card.pdf']);
    expect(await names('पासपो'), ['Card.pdf']);
    expect(await names('संख्या'), ['Card.pdf']);
  });

  test('ranking: a match in the name beats tags, notes and body', () async {
    await add('Notes.pdf', notes: 'insurance renewal due');
    await add('Body.pdf', body: 'this policy covers insurance claims');
    await add('Insurance.pdf');
    await add('Tagged.pdf', tags: ['insurance']);
    final order = await names('insurance');
    expect(order.first, 'Insurance.pdf');
    expect(order.indexOf('Tagged.pdf'), lessThan(order.indexOf('Body.pdf')));
    expect(order.indexOf('Notes.pdf'), lessThan(order.indexOf('Body.pdf')));
  });

  test('snippets: only for matches in recognised text, as (text, bold) runs — brackets never shown', () async {
    await add('Statement.pdf', body: 'Account summary for October. Closing balance 1,250.00 credited.');
    await add('Balance.pdf');
    final hits = await repo.search('balance').first;
    final inBody = hits.firstWhere((h) => h.doc.name == 'Statement.pdf');
    expect(inBody.snippet, isNotNull);
    final runs = snippetRuns(inBody.snippet!);
    expect(runs.where((r) => r.$2).map((r) => r.$1), ['balance']);
    expect(runs.map((r) => r.$1).join(), isNot(contains('[')));
    expect(hits.firstWhere((h) => h.doc.name == 'Balance.pdf').snippet, isNull, reason: 'matched by name only');
  });

  test('folder scope includes subfolders; hits carry their folder path', () async {
    final ids = await repo.createFolder('IDs');
    final travel = await repo.createFolder('Travel', parentId: ids.id);
    await add('Visa.pdf', folderId: travel.id);
    await add('Visa copy.pdf');
    expect((await names('visa', folderId: ids.id)), ['Visa.pdf']);
    final hit = (await repo.search('visa').first).firstWhere((h) => h.doc.name == 'Visa.pdf');
    expect(hit.folderPath, ['IDs', 'Travel']);
  });

  test('renames, note edits and deletes are reflected; recognised text is capped at 200,000 characters', () async {
    final d = await add('Old name.pdf', notes: 'first note');
    await repo.rename(d.id, 'Lease.pdf');
    expect(await names('old'), isEmpty);
    expect(await names('lease'), ['Lease.pdf']);
    await repo.setNotes(d.id, 'second note');
    expect(await names('first'), isEmpty);
    await repo.setIndexedText(d.id, '${'word ' * 50000}tailmarker', state: IndexState.done);
    expect(await names('tailmarker'), isEmpty, reason: 'beyond the cap');
    expect((await repo.get(d.id))!.indexState, IndexState.done);
    await repo.delete([d.id]);
    expect(await names('lease'), isEmpty);
    expect(await names('second'), isEmpty);
  });
}
