import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/errors/app_error.dart';
import '../../core/files/file_naming.dart';
import '../../features/search/tool_catalog.dart';
import '../db/app_database.dart';
import 'fts.dart';
import 'library_repository.dart';

/// drift + files under `appSupport/library/` (RELEASE_V1_5 §4.2–4.4).
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl(this._db, this._support, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final AppDatabase _db;
  final Directory _support;
  final DateTime Function() _now;
  final _changes = StreamController<LibraryChange>.broadcast();

  Directory get _root => Directory(p.join(_support.path, 'library'));

  @override
  Stream<LibraryChange> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();

  void _emit(LibraryChangeKind kind, List<String> ids) {
    if (!_changes.isClosed) _changes.add(LibraryChange(kind, ids));
  }

  /// Re-runs [q] whenever a library table changes.
  Stream<T> _watch<T>(Future<T> Function() q) async* {
    yield await q();
    await for (final _ in _db.tableUpdates(
        TableUpdateQuery.onAllTables([_db.libraryDocuments, _db.libraryFolders, _db.libraryTags]))) {
      yield await q();
    }
  }

  // ---------------------------------------------------------------- dates

  static int _ms(DateTime t) => t.millisecondsSinceEpoch;
  static DateTime _at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);
  static int _day(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  static DateTime _date(int day) {
    final u = DateTime.fromMillisecondsSinceEpoch(day * Duration.millisecondsPerDay, isUtc: true);
    return DateTime(u.year, u.month, u.day);
  }

  // ---------------------------------------------------------------- mapping

  Future<Map<String, List<String>>> _tagsOf(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const {};
    final rows = await (_db.select(_db.libraryTags)..where((t) => t.docId.isIn(list))).get();
    final out = <String, List<String>>{};
    for (final r in rows) {
      (out[r.docId] ??= []).add(r.tag);
    }
    for (final v in out.values) {
      v.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return out;
  }

  LibraryDoc _doc(LibraryDocRow r, List<String> tags) => LibraryDoc(
        id: r.id,
        folderId: r.folderId,
        name: r.name,
        relPath: r.relPath,
        mime: r.mime,
        sizeBytes: r.sizeBytes,
        sha256: r.sha256,
        source: DocSource.values.firstWhere((s) => s.name == r.source, orElse: () => DocSource.import),
        sourceTool: r.sourceTool == null ? null : ToolId.values.where((t) => t.name == r.sourceTool).firstOrNull,
        pageCount: r.pageCount,
        width: r.width,
        height: r.height,
        addedAt: _at(r.addedAt),
        openedAt: r.openedAt == null ? null : _at(r.openedAt!),
        starred: r.starred,
        notes: r.notes,
        tags: tags,
        expiryDate: r.expiryDate == null ? null : _date(r.expiryDate!),
        reminderOffsets: [for (final o in jsonDecode(r.reminderOffsets) as List) (o as num).toInt()],
        reminderMinuteOfDay: r.reminderMinuteOfDay,
        indexState: IndexState.values.firstWhere((s) => s.name == r.indexState, orElse: () => IndexState.none),
        indexedAt: r.indexedAt == null ? null : _at(r.indexedAt!),
      );

  Future<List<LibraryDoc>> _docs(List<LibraryDocRow> rows) async {
    final tags = await _tagsOf(rows.map((r) => r.id));
    return [for (final r in rows) _doc(r, tags[r.id] ?? const [])];
  }

  LibraryFolder _folder(LibraryFolderRow r, [int docCount = 0]) =>
      LibraryFolder(id: r.id, parentId: r.parentId, name: r.name, depth: r.depth, createdAt: _at(r.createdAt), docCount: docCount);

  @override
  String absolutePath(LibraryDoc doc) => p.join(_support.path, doc.relPath);

  // ---------------------------------------------------------------- names

  static (String, String) _split(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? (name.substring(0, dot), name.substring(dot)) : (name, '');
  }

  /// [name], or "base (2).ext", "base (3).ext"… free among [taken] (any case).
  static String _free(String name, Iterable<String> taken) {
    final lower = {for (final t in taken) t.toLowerCase()};
    if (!lower.contains(name.toLowerCase())) return name;
    final (base, ext) = _split(name);
    for (var n = 2;; n++) {
      final c = '$base ($n)$ext';
      if (!lower.contains(c.toLowerCase())) return c;
    }
  }

  Future<List<String>> _docNamesIn(String? folderId, {String? except}) async {
    final q = _db.select(_db.libraryDocuments)
      ..where((t) => folderId == null ? t.folderId.isNull() : t.folderId.equals(folderId));
    return [for (final r in await q.get()) if (r.id != except) r.name];
  }

  Future<List<LibraryFolderRow>> _childFolders(String? parentId) => (_db.select(_db.libraryFolders)
        ..where((t) => parentId == null ? t.parentId.isNull() : t.parentId.equals(parentId)))
      .get();

  String _validFolderName(String name) {
    final n = name.trim();
    if (n.isEmpty || n.runes.length > maxFolderNameChars) throw const LibraryException(LibraryErrorCode.folderNameInvalid);
    return n;
  }

  Future<void> _ensureFreeFolderName(String? parentId, String name, {String? except}) async {
    final siblings = await _childFolders(parentId);
    if (siblings.any((f) => f.id != except && f.name.toLowerCase() == name.toLowerCase())) {
      throw const LibraryException(LibraryErrorCode.folderNameTaken);
    }
  }

  // ---------------------------------------------------------------- folders

  @override
  Stream<List<LibraryFolder>> watchFolders({String? parentId}) => _watch(() async {
        final rows = await _childFolders(parentId);
        rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final counts = <String, int>{};
        if (rows.isNotEmpty) {
          final c = _db.libraryDocuments.id.count();
          final q = _db.selectOnly(_db.libraryDocuments)
            ..addColumns([_db.libraryDocuments.folderId, c])
            ..where(_db.libraryDocuments.folderId.isIn(rows.map((r) => r.id)))
            ..groupBy([_db.libraryDocuments.folderId]);
          for (final r in await q.get()) {
            counts[r.read(_db.libraryDocuments.folderId)!] = r.read(c)!;
          }
        }
        return [for (final r in rows) _folder(r, counts[r.id] ?? 0)];
      });

  @override
  Future<LibraryFolder?> folder(String id) async {
    final r = await (_db.select(_db.libraryFolders)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _folder(r);
  }

  @override
  Future<List<String>> folderPath(String? id) async {
    final names = <String>[];
    var at = id;
    while (at != null) {
      final f = await (_db.select(_db.libraryFolders)..where((t) => t.id.equals(at!))).getSingleOrNull();
      if (f == null) break;
      names.insert(0, f.name);
      at = f.parentId;
    }
    return names;
  }

  @override
  Future<LibraryFolder> createFolder(String name, {String? parentId}) async {
    final n = _validFolderName(name);
    final parent = parentId == null ? null : await folder(parentId);
    if (parentId != null && parent == null) throw const LibraryException(LibraryErrorCode.notFound);
    final depth = (parent?.depth ?? 0) + 1;
    if (depth > maxFolderDepth) throw const LibraryException(LibraryErrorCode.folderTooDeep);
    await _ensureFreeFolderName(parentId, n);
    final row = LibraryFoldersCompanion.insert(
        id: const Uuid().v7(), parentId: Value(parentId), name: n, depth: depth, createdAt: _ms(_now()));
    await _db.into(_db.libraryFolders).insert(row);
    _emit(LibraryChangeKind.folders, [row.id.value]);
    return (await folder(row.id.value))!;
  }

  @override
  Future<void> renameFolder(String id, String name) async {
    final n = _validFolderName(name);
    final f = await folder(id);
    if (f == null) throw const LibraryException(LibraryErrorCode.notFound);
    await _ensureFreeFolderName(f.parentId, n, except: id);
    await (_db.update(_db.libraryFolders)..where((t) => t.id.equals(id))).write(LibraryFoldersCompanion(name: Value(n)));
    _emit(LibraryChangeKind.folders, [id]);
  }

  /// [id] and every folder below it, parents before children.
  Future<List<LibraryFolderRow>> _subtree(String id) async {
    final all = await _db.select(_db.libraryFolders).get();
    final byParent = <String?, List<LibraryFolderRow>>{};
    for (final f in all) {
      (byParent[f.parentId] ??= []).add(f);
    }
    final out = <LibraryFolderRow>[...all.where((f) => f.id == id)];
    for (var i = 0; i < out.length; i++) {
      out.addAll(byParent[out[i].id] ?? const []);
    }
    return out;
  }

  @override
  Future<bool> canMoveFolder(String id, String? newParentId) async {
    try {
      await _checkFolderMove(id, newParentId);
      return true;
    } on LibraryException {
      return false;
    }
  }

  Future<(List<LibraryFolderRow>, int)> _checkFolderMove(String id, String? newParentId) async {
    final tree = await _subtree(id);
    if (tree.isEmpty) throw const LibraryException(LibraryErrorCode.notFound);
    if (newParentId != null && tree.any((f) => f.id == newParentId)) throw const LibraryException(LibraryErrorCode.invalidMove);
    final parentDepth = newParentId == null ? 0 : (await folder(newParentId))?.depth;
    if (parentDepth == null) throw const LibraryException(LibraryErrorCode.notFound);
    final shift = parentDepth + 1 - tree.first.depth;
    if (tree.any((f) => f.depth + shift > maxFolderDepth)) throw const LibraryException(LibraryErrorCode.folderTooDeep);
    return (tree, shift);
  }

  @override
  Future<void> moveFolder(String id, String? newParentId) async {
    final (tree, shift) = await _checkFolderMove(id, newParentId);
    await _ensureFreeFolderName(newParentId, tree.first.name, except: id);
    await _db.transaction(() async {
      for (final f in tree) {
        await (_db.update(_db.libraryFolders)..where((t) => t.id.equals(f.id))).write(LibraryFoldersCompanion(
            depth: Value(f.depth + shift), parentId: f.id == id ? Value(newParentId) : const Value.absent()));
      }
    });
    _emit(LibraryChangeKind.folders, [id]);
  }

  @override
  Future<FolderDeleteSummary> deleteFolder(String id, {required FolderDeleteMode mode}) async {
    final tree = await _subtree(id);
    if (tree.isEmpty) throw const LibraryException(LibraryErrorCode.notFound);
    final target = tree.first;
    if (mode == FolderDeleteMode.deleteEverything) {
      final ids = tree.map((f) => f.id).toList();
      final docs = await (_db.select(_db.libraryDocuments)..where((t) => t.folderId.isIn(ids))).get();
      await _deleteDocs(docs.map((d) => d.id).toList(), afterRows: () async {
        for (final f in tree.reversed) {
          await (_db.delete(_db.libraryFolders)..where((t) => t.id.equals(f.id))).go();
        }
      });
      _emit(LibraryChangeKind.folders, ids);
      return FolderDeleteSummary(foldersDeleted: tree.length, docsMoved: 0, docsDeleted: docs.length);
    }
    // Move the contents up one level, keeping names unique there.
    final up = target.parentId;
    final docs = await (_db.select(_db.libraryDocuments)..where((t) => t.folderId.equals(id))).get();
    final children = await _childFolders(id);
    await _db.transaction(() async {
      final docNames = await _docNamesIn(up);
      for (final d in docs) {
        final name = _free(d.name, docNames);
        docNames.add(name);
        await (_db.update(_db.libraryDocuments)..where((t) => t.id.equals(d.id)))
            .write(LibraryDocumentsCompanion(folderId: Value(up), name: Value(name)));
        await _ftsSet(d.id, name: name);
      }
      final folderNames = [for (final f in await _childFolders(up)) if (f.id != id) f.name];
      for (final c in children) {
        final name = _free(c.name, folderNames);
        folderNames.add(name);
        await (_db.update(_db.libraryFolders)..where((t) => t.id.equals(c.id)))
            .write(LibraryFoldersCompanion(parentId: Value(up), name: Value(name)));
      }
      for (final f in tree.skip(1)) {
        await (_db.update(_db.libraryFolders)..where((t) => t.id.equals(f.id))).write(LibraryFoldersCompanion(depth: Value(f.depth - 1)));
      }
      await (_db.delete(_db.libraryFolders)..where((t) => t.id.equals(id))).go();
    });
    _emit(LibraryChangeKind.moved, docs.map((d) => d.id).toList());
    _emit(LibraryChangeKind.folders, [id]);
    return FolderDeleteSummary(foldersDeleted: 1, docsMoved: docs.length, docsDeleted: 0);
  }

  // ---------------------------------------------------------------- documents

  @override
  Stream<List<LibraryDoc>> watchDocs({String? folderId, bool starredOnly = false, String? tag, LibrarySort sort = LibrarySort.added}) =>
      _watch(() async {
        final t = _db.libraryDocuments;
        final q = _db.select(t);
        if (starredOnly) {
          q.where((d) => d.starred.equals(true));
        } else if (tag == null) {
          q.where((d) => folderId == null ? d.folderId.isNull() : d.folderId.equals(folderId));
        }
        q.orderBy([
          switch (sort) {
            LibrarySort.name => (d) => OrderingTerm(expression: d.name.collate(Collate.noCase)),
            LibrarySort.added => (d) => OrderingTerm.desc(d.addedAt),
            LibrarySort.size => (d) => OrderingTerm.desc(d.sizeBytes),
            LibrarySort.expiry => (d) => OrderingTerm(expression: d.expiryDate.isNull()),
          },
          if (sort == LibrarySort.expiry) (d) => OrderingTerm(expression: d.expiryDate),
          (d) => OrderingTerm(expression: d.name.collate(Collate.noCase)),
        ]);
        var docs = await _docs(await q.get());
        if (tag != null) docs = docs.where((d) => d.tags.any((x) => x.toLowerCase() == tag.toLowerCase())).toList();
        return docs;
      });

  @override
  Stream<List<LibraryDoc>> watchExpiringSoon({int days = 60}) => _watch(() async {
        final until = _day(_now()) + days;
        final q = _db.select(_db.libraryDocuments)
          ..where((d) => d.expiryDate.isNotNull() & d.expiryDate.isSmallerOrEqualValue(until))
          ..orderBy([(d) => OrderingTerm(expression: d.expiryDate)]);
        return _docs(await q.get());
      });

  @override
  Future<LibraryDoc?> get(String id) async {
    final r = await (_db.select(_db.libraryDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : (await _docs([r])).single;
  }

  Future<LibraryDocRow> _row(String id) async {
    final r = await (_db.select(_db.libraryDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (r == null) throw const LibraryException(LibraryErrorCode.notFound);
    return r;
  }

  /// Copies [src] to [dst] and hashes it in one pass, off the UI isolate;
  /// fsyncs before returning. (sha256 hex, bytes).
  static Future<(String, int)> _copyAndHash(String src, String dst) => Isolate.run(() {
        final input = File(src).openSync();
        final out = File(dst).openSync(mode: FileMode.write);
        final sink = _DigestSink();
        final hasher = sha256.startChunkedConversion(sink);
        var n = 0;
        try {
          final buf = Uint8List(1 << 20);
          while (true) {
            final read = input.readIntoSync(buf);
            if (read == 0) break;
            out.writeFromSync(buf, 0, read);
            hasher.add(Uint8List.sublistView(buf, 0, read));
            n += read;
          }
          out.flushSync();
        } finally {
          input.closeSync();
          out.closeSync();
        }
        hasher.close();
        return (sink.value.toString(), n);
      });

  @override
  Future<AddResult> addFile(
    String sourcePath, {
    required String displayName,
    required DocSource source,
    required String mime,
    String? folderId,
    ToolId? sourceTool,
    int? pageCount,
    int? width,
    int? height,
    bool allowDuplicate = false,
  }) async {
    final id = const Uuid().v7();
    final dir = Directory(p.join(_root.path, id));
    final fileName = safeOutputName(displayName);
    final part = File(p.join(dir.path, '$fileName.part'));
    try {
      await dir.create(recursive: true);
      final (hash, bytes) = await _copyAndHash(sourcePath, part.path);
      if (!allowDuplicate) {
        final existing = await (_db.select(_db.libraryDocuments)..where((t) => t.sha256.equals(hash))..limit(1)).getSingleOrNull();
        if (existing != null) {
          await _deleteDir(dir);
          return Duplicate((await _docs([existing])).single);
        }
      }
      await part.rename(p.join(dir.path, fileName));
      final name = _free(displayName, await _docNamesIn(folderId));
      await _db.transaction(() async {
        await _db.into(_db.libraryDocuments).insert(LibraryDocumentsCompanion.insert(
              id: id,
              folderId: Value(folderId),
              name: name,
              relPath: p.posix.join('library', id, fileName),
              mime: mime,
              sizeBytes: bytes,
              pageCount: Value(pageCount),
              width: Value(width),
              height: Value(height),
              sha256: hash,
              source: source.name,
              sourceTool: Value(sourceTool?.name),
              addedAt: _ms(_now()),
            ));
        await _db.customInsert('INSERT INTO library_fts(doc_id, name, notes, tags, body) VALUES (?, ?, ?, ?, ?)',
            variables: [Variable.withString(id), Variable.withString(name), Variable.withString(''), Variable.withString(''), Variable.withString('')]);
      });
      _emit(LibraryChangeKind.added, [id]);
      return Added((await get(id))!);
    } catch (e) {
      await _deleteDir(dir);
      return AddFailed(e is AppError ? e : const AppError(AppErrorCode.processingFailed));
    }
  }

  Future<void> _ftsSet(String id, {String? name, String? notes, String? tags, String? body}) async {
    final sets = <String>[], vars = <Variable>[];
    for (final (col, v) in [('name', name), ('notes', notes), ('tags', tags), ('body', body)]) {
      if (v != null) {
        sets.add('$col = ?');
        vars.add(Variable.withString(v));
      }
    }
    if (sets.isEmpty) return;
    await _db.customUpdate('UPDATE library_fts SET ${sets.join(', ')} WHERE doc_id = ?', variables: [...vars, Variable.withString(id)]);
  }

  @override
  Future<void> rename(String id, String name) async {
    final r = await _row(id);
    final n = name.trim();
    if (n.isEmpty) throw const LibraryException(LibraryErrorCode.nameTaken);
    final taken = await _docNamesIn(r.folderId, except: id);
    if (taken.any((t) => t.toLowerCase() == n.toLowerCase())) throw const LibraryException(LibraryErrorCode.nameTaken);
    await _db.transaction(() async {
      await (_db.update(_db.libraryDocuments)..where((t) => t.id.equals(id))).write(LibraryDocumentsCompanion(name: Value(n)));
      await _ftsSet(id, name: n);
    });
    _emit(LibraryChangeKind.updated, [id]);
  }

  @override
  Future<void> move(List<String> ids, String? folderId) async {
    if (folderId != null && await folder(folderId) == null) throw const LibraryException(LibraryErrorCode.notFound);
    await _db.transaction(() async {
      final names = await _docNamesIn(folderId);
      for (final id in ids) {
        final r = await _row(id);
        if (r.folderId == folderId) continue;
        final name = _free(r.name, names);
        names.add(name);
        await (_db.update(_db.libraryDocuments)..where((t) => t.id.equals(id)))
            .write(LibraryDocumentsCompanion(folderId: Value(folderId), name: Value(name)));
        await _ftsSet(id, name: name);
      }
    });
    _emit(LibraryChangeKind.moved, ids);
  }

  @override
  Future<void> setStarred(List<String> ids, bool starred) async {
    await (_db.update(_db.libraryDocuments)..where((t) => t.id.isIn(ids))).write(LibraryDocumentsCompanion(starred: Value(starred)));
    _emit(LibraryChangeKind.updated, ids);
  }

  @override
  Future<void> setNotes(String id, String notes) async {
    if (notes.runes.length > maxNotesChars) throw const LibraryException(LibraryErrorCode.notesTooLong);
    await _row(id);
    await _db.transaction(() async {
      await (_db.update(_db.libraryDocuments)..where((t) => t.id.equals(id))).write(LibraryDocumentsCompanion(notes: Value(notes)));
      await _ftsSet(id, notes: notes);
    });
    _emit(LibraryChangeKind.updated, [id]);
  }

  /// Trimmed, ≤ 30 characters, no duplicates (any case), at most 10 (FR-LIB-13).
  @override
  Future<void> setTags(String id, List<String> tags) async {
    await _row(id);
    final clean = <String>[];
    for (final t in tags.map((t) => t.trim())) {
      if (t.isEmpty || t.runes.length > maxTagChars || clean.any((c) => c.toLowerCase() == t.toLowerCase())) continue;
      clean.add(t);
      if (clean.length == maxTags) break;
    }
    await _db.transaction(() async {
      await (_db.delete(_db.libraryTags)..where((t) => t.docId.equals(id))).go();
      for (final t in clean) {
        await _db.into(_db.libraryTags).insert(LibraryTagsCompanion.insert(docId: id, tag: t));
      }
      await _ftsSet(id, tags: clean.join(' '));
    });
    _emit(LibraryChangeKind.updated, [id]);
  }

  @override
  Future<void> setExpiry(String id, DateTime? date, List<int> offsets, int? minuteOfDay) async {
    await _row(id);
    await (_db.update(_db.libraryDocuments)..where((t) => t.id.equals(id))).write(LibraryDocumentsCompanion(
          expiryDate: Value(date == null ? null : _day(date)),
          reminderOffsets: Value(jsonEncode(date == null ? const <int>[] : offsets)),
          reminderMinuteOfDay: Value(minuteOfDay),
        ));
    _emit(LibraryChangeKind.updated, [id]);
  }

  @override
  Future<void> markOpened(String id) async {
    await (_db.update(_db.libraryDocuments)..where((t) => t.id.equals(id)))
        .write(LibraryDocumentsCompanion(openedAt: Value(_ms(_now()))));
    _emit(LibraryChangeKind.updated, [id]);
  }

  @override
  Future<void> delete(List<String> ids) async {
    await _deleteDocs(ids);
    _emit(LibraryChangeKind.deleted, ids);
  }

  /// Rows (tags cascade) and search rows in one transaction, then the files.
  Future<void> _deleteDocs(List<String> ids, {Future<void> Function()? afterRows}) async {
    await _db.transaction(() async {
      if (ids.isNotEmpty) {
        await (_db.delete(_db.libraryDocuments)..where((t) => t.id.isIn(ids))).go();
        await _db.customUpdate('DELETE FROM library_fts WHERE doc_id IN (${List.filled(ids.length, '?').join(', ')})',
            variables: [for (final id in ids) Variable.withString(id)]);
      }
      await afterRows?.call();
    });
    for (final id in ids) {
      await _deleteDir(Directory(p.join(_root.path, id)));
      await _deleteFile(File(p.join(_root.path, '_thumbs', '$id.jpg')));
    }
  }

  @override
  Future<String> copyForTool(String id, Directory jobInDir) async {
    final doc = (await get(id))!;
    await jobInDir.create(recursive: true);
    final existing = [for (final e in jobInDir.listSync()) p.basename(e.path)];
    final out = p.join(jobInDir.path, _free(safeOutputName(doc.name), existing));
    await File(absolutePath(doc)).copy(out);
    return out;
  }

  // ---------------------------------------------------------------- search

  @override
  Stream<List<SearchHit>> search(String query, {String? folderId}) => _watch(() async {
        final match = ftsMatchQuery(query);
        if (match == null) return const <SearchHit>[];
        final rows = await _db.customSelect(
          'SELECT doc_id, $ftsSnippet AS snip FROM library_fts WHERE library_fts MATCH ? ORDER BY $ftsRank LIMIT 200',
          variables: [Variable.withString(match)],
        ).get();
        Set<String>? scope;
        if (folderId != null) scope = {for (final f in await _subtree(folderId)) f.id};
        final docs = {
          for (final d in await _docs(await (_db.select(_db.libraryDocuments)
                ..where((t) => t.id.isIn(rows.map((r) => r.read<String>('doc_id')))))
              .get()))
            d.id: d,
        };
        final hits = <SearchHit>[];
        for (final r in rows) {
          final d = docs[r.read<String>('doc_id')];
          if (d == null || (scope != null && !scope.contains(d.folderId))) continue;
          final snip = r.read<String>('snip');
          hits.add(SearchHit(doc: d, folderPath: await folderPath(d.folderId), snippet: snip.contains('[') ? snip : null));
        }
        return hits;
      });

  @override
  Future<void> setIndexedText(String id, String text, {required IndexState state}) async {
    await _row(id);
    final body = text.length > maxBodyChars ? text.substring(0, maxBodyChars) : text;
    await _db.transaction(() async {
      await _ftsSet(id, body: body);
      await (_db.update(_db.libraryDocuments)..where((t) => t.id.equals(id)))
          .write(LibraryDocumentsCompanion(indexState: Value(state.name), indexedAt: Value(_ms(_now()))));
    });
    _emit(LibraryChangeKind.updated, [id]);
  }

  // ---------------------------------------------------------------- storage

  @override
  Future<LibraryStats> stats() async {
    final c = _db.libraryDocuments.id.count(), s = _db.libraryDocuments.sizeBytes.sum();
    final r = await (_db.selectOnly(_db.libraryDocuments)..addColumns([c, s])).getSingle();
    return LibraryStats(docCount: r.read(c) ?? 0, totalBytes: r.read(s) ?? 0);
  }

  @override
  Future<int> sweepOrphans() async {
    if (!await _root.exists()) return 0;
    final ids = {for (final r in await _db.select(_db.libraryDocuments).get()) r.id};
    var removed = 0;
    await for (final e in _root.list()) {
      final name = p.basename(e.path);
      if (e is! Directory) continue;
      if (name == '_import_tmp') {
        await for (final c in e.list()) {
          await c.delete(recursive: true);
          removed++;
        }
      } else if (!name.startsWith('_') && !ids.contains(name)) {
        await e.delete(recursive: true);
        removed++;
      } else if (ids.contains(name)) {
        await for (final f in e.list()) {
          if (f is File && f.path.endsWith('.part')) {
            await f.delete();
            removed++;
          }
        }
      }
    }
    return removed;
  }

  static Future<void> _deleteDir(Directory d) async {
    try {
      if (await d.exists()) await d.delete(recursive: true);
    } on FileSystemException {
      // The launch sweep catches leftovers.
    }
  }

  static Future<void> _deleteFile(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Best effort.
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
