import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/zip_builder.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../data/library/library_repository.dart';
import '../../search/tool_catalog.dart';

/// The manifest's identity (RELEASE_V1_5 §4.9). Readers accept versions ≤ this.
const backupFormat = 'docukit-library', backupVersion = 1;
const backupManifestName = 'docukit-library.json';

/// Free space an import keeps beyond the unpacked files (§4.9).
const importHeadroomBytes = 50 * 1024 * 1024;

enum BackupProblem { notBackup, tooNew }

/// Not a DocuKit backup, or written by a newer DocuKit (FR-LIB-19).
class BackupException implements Exception {
  const BackupException(this.problem);
  final BackupProblem problem;
}

/// "Imported 34 · Skipped 3 duplicates · 1 damaged file".
class ImportSummary {
  const ImportSummary({required this.imported, required this.duplicates, required this.damaged});
  final int imported, duplicates, damaged;
}

/// `DocuKit-Backup-20261028`.
String backupBaseName(DateTime now) => 'DocuKit-Backup-${DateFormat('yyyyMMdd').format(now)}';

String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// A name unique among [used] (ignoring case), " (2)" style like the library.
String _free(String name, Set<String> used) {
  var candidate = name;
  final ext = p.extension(name);
  final base = name.substring(0, name.length - ext.length);
  for (var n = 2; used.contains(candidate.toLowerCase()); n++) {
    candidate = '$base ($n)$ext';
  }
  used.add(candidate.toLowerCase());
  return candidate;
}

/// FR-LIB-18 · what an export contains: the manifest (folders, documents and
/// their notes, tags, expiry, reminders, star, dates, origin) and one ZIP
/// entry per file under `files/` with readable, unique folder paths.
/// [folderId]: only that folder and below, paths starting at it. Recognised
/// text isn't exported (re-indexed after an import).
Future<({Map<String, Object?> manifest, List<ZipItem> files})> planExport(
  LibraryRepository repo, {
  String? folderId,
  required DateTime now,
}) async {
  final all = await repo.allFolders();
  final children = <String?, List<LibraryFolder>>{};
  for (final f in all) {
    (children[f.parentId] ??= []).add(f);
  }
  final folders = <Map<String, Object?>>[];
  final docs = <Map<String, Object?>>[];
  final files = <ZipItem>[];

  Future<void> walk(String? id, String? manifestParent, String dir) async {
    final usedNames = <String>{};
    for (final d in await repo.watchDocs(folderId: id, sort: LibrarySort.name).first) {
      final name = _free(safeOutputName(d.name), usedNames);
      final file = dir.isEmpty ? 'files/$name' : 'files/$dir/$name';
      files.add(ZipItem(repo.absolutePath(d), file));
      docs.add({
        'id': d.id,
        'folderId': manifestParent,
        'name': d.name,
        'file': file,
        'sha256': d.sha256,
        'mime': d.mime,
        'sizeBytes': d.sizeBytes,
        'source': d.source.name,
        if (d.sourceTool != null) 'sourceTool': d.sourceTool!.name,
        if (d.pageCount != null) 'pageCount': d.pageCount,
        if (d.width != null) 'width': d.width,
        if (d.height != null) 'height': d.height,
        'notes': d.notes,
        'tags': d.tags,
        'starred': d.starred,
        'expiryDate': d.expiryDate == null ? null : _date(d.expiryDate!),
        'reminderOffsets': d.reminderOffsets,
        if (d.reminderMinuteOfDay != null) 'reminderMinuteOfDay': d.reminderMinuteOfDay,
        'addedAt': d.addedAt.toIso8601String(),
      });
    }
    for (final f in (children[id] ?? const <LibraryFolder>[])) {
      final seg = _free(safeBaseName(f.name, removeExtension: false), usedNames);
      folders.add({'id': f.id, 'parentId': manifestParent, 'name': f.name});
      await walk(f.id, f.id, dir.isEmpty ? seg : '$dir/$seg');
    }
  }

  if (folderId == null) {
    await walk(null, null, '');
  } else {
    final top = all.where((f) => f.id == folderId).firstOrNull;
    if (top == null) throw const AppError(AppErrorCode.invalidInput);
    final seg = safeBaseName(top.name, removeExtension: false);
    folders.add({'id': top.id, 'parentId': null, 'name': top.name});
    await walk(top.id, top.id, seg);
  }
  return (
    manifest: <String, Object?>{
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': now.toIso8601String(),
      'folders': folders,
      'documents': docs,
    },
    files: files,
  );
}

/// FR-LIB-18 · writes the backup ZIP into [workDir] and returns its path:
/// `<base>/docukit-library.json` + `<base>/files/…`. Progress counts entries.
Future<String> exportLibrary(
  LibraryRepository repo, {
  required Directory workDir,
  required DateTime now,
  String? folderId,
  CancelToken? cancel,
  void Function(int done, int total)? onProgress,
}) async {
  final plan = await planExport(repo, folderId: folderId, now: now);
  final base = backupBaseName(now);
  await workDir.create(recursive: true);
  final manifest = File(p.join(workDir.path, backupManifestName));
  await manifest.writeAsString(jsonEncode(plan.manifest));
  final out = p.join(workDir.path, '$base.zip');
  await buildZip(
    [ZipItem(manifest.path, '$base/$backupManifestName'), for (final f in plan.files) ZipItem(f.path, '$base/${f.name}')],
    out,
    keepNames: true,
    cancel: cancel,
    onProgress: onProgress,
  );
  return out;
}

/// The manifest and its folder inside the ZIP (`DocuKit-Backup-…/` or the root).
typedef BackupManifest = ({Map<String, Object?> json, String prefix, int unpackedBytes});

/// A manifest file path we read: inside `files/`, no `..`, not absolute.
bool _safeFilePath(String f) =>
    f.startsWith('files/') && !f.contains('\\') && !p.posix.split(f).contains('..') && !p.posix.isAbsolute(f);

/// FR-LIB-19 · reads and checks the manifest (in an isolate). Throws
/// [BackupException] for anything that isn't a DocuKit backup this version
/// can read.
Future<BackupManifest> readBackupManifest(String zipPath) => Isolate.run(() {
      final input = InputFileStream(zipPath);
      try {
        final Archive archive;
        try {
          archive = ZipDecoder().decodeStream(input);
        } catch (_) {
          throw const BackupException(BackupProblem.notBackup);
        }
        final entry = archive.files.where((f) {
          final parts = p.posix.split(f.name);
          return f.isFile && parts.last == backupManifestName && parts.length <= 2;
        }).firstOrNull;
        if (entry == null) throw const BackupException(BackupProblem.notBackup);
        final Map<String, Object?> json;
        try {
          json = (jsonDecode(utf8.decode(entry.content as List<int>)) as Map).cast<String, Object?>();
        } catch (_) {
          throw const BackupException(BackupProblem.notBackup);
        }
        if (json['format'] != backupFormat || json['version'] is! int) throw const BackupException(BackupProblem.notBackup);
        if ((json['version']! as int) > backupVersion) throw const BackupException(BackupProblem.tooNew);
        final prefix = p.posix.dirname(entry.name) == '.' ? '' : '${p.posix.dirname(entry.name)}/';
        final sizes = {for (final f in archive.files) f.name: f.size};
        var bytes = 0;
        for (final d in (json['documents'] as List? ?? const [])) {
          final file = (d as Map)['file'];
          if (file is String && _safeFilePath(file)) bytes += sizes['$prefix$file'] ?? 0;
        }
        return (json: json, prefix: prefix, unpackedBytes: bytes);
      } finally {
        input.closeSync();
      }
    });

/// Extracts each document's file to `staging/<n>` and checks its SHA-256
/// (in an isolate). Returns the staged path per manifest index, or null when
/// it's missing, unsafe or damaged. Entry names never become paths on disk.
Future<List<String?>> _extract(String zipPath, String prefix, List<Map<String, Object?>> docs, String staging) =>
    Isolate.run(() async {
      final input = InputFileStream(zipPath);
      try {
        final archive = ZipDecoder().decodeStream(input);
        final byName = {for (final f in archive.files) if (f.isFile) f.name: f};
        final out = <String?>[];
        for (var i = 0; i < docs.length; i++) {
          final file = docs[i]['file'], sha = docs[i]['sha256'];
          final entry = file is String && _safeFilePath(file) ? byName['$prefix$file'] : null;
          if (entry == null || sha is! String) {
            out.add(null);
            continue;
          }
          final path = p.join(staging, '$i');
          try {
            final os = OutputFileStream(path);
            entry.writeContent(os);
            os.closeSync();
            // Streamed: files can be hundreds of MB.
            final digest = (await sha256.bind(File(path).openRead()).first).toString();
            if (digest != sha) {
              File(path).deleteSync();
              out.add(null);
              continue;
            }
            out.add(path);
          } catch (_) {
            out.add(null);
          }
        }
        return out;
      } finally {
        input.closeSync();
      }
    });

DateTime? _parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// FR-LIB-19 · merges a backup into the library: folders matched by path and
/// name (ignoring case) or created; files verified; documents already in the
/// library (same SHA-256) skipped and counted; notes, tags, star, expiry and
/// reminders restored. Indexing and reminders follow from the library's
/// change events. Throws [BackupException] or `AppError(insufficientStorage)`.
Future<ImportSummary> importBackup(
  LibraryRepository repo, {
  required String zipPath,
  required Directory staging,
  required Future<int> Function() freeBytes,
}) async {
  final m = await readBackupManifest(zipPath);
  if (await freeBytes() < m.unpackedBytes + importHeadroomBytes) throw const AppError(AppErrorCode.insufficientStorage);
  final docs = [for (final d in (m.json['documents'] as List? ?? const [])) if (d is Map) d.cast<String, Object?>()];
  final folders = [for (final f in (m.json['folders'] as List? ?? const [])) if (f is Map) f.cast<String, Object?>()];

  if (await staging.exists()) await staging.delete(recursive: true);
  await staging.create(recursive: true);
  try {
    final staged = await _extract(zipPath, m.prefix, docs, staging.path);

    // Folders, parents first: an existing one with the same name under the
    // same parent is reused (merge), otherwise created.
    final ids = <String, String?>{};
    final pending = [...folders];
    while (pending.isNotEmpty) {
      final ready = pending.where((f) => f['parentId'] == null || ids.containsKey(f['parentId'])).toList();
      if (ready.isEmpty) break; // a broken parent chain: those folders' documents go to the root
      for (final f in ready) {
        pending.remove(f);
        final parent = f['parentId'] == null ? null : ids[f['parentId']];
        final name = (f['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final existing = (await repo.watchFolders(parentId: parent).first).where((x) => x.name.toLowerCase() == name.toLowerCase());
        try {
          ids[f['id']! as String] = existing.isNotEmpty ? existing.first.id : (await repo.createFolder(name, parentId: parent)).id;
        } on LibraryException {
          ids[f['id']! as String] = parent; // too deep or an invalid name: keep its documents one level up
        }
      }
    }

    var imported = 0, duplicates = 0, damaged = 0;
    for (var i = 0; i < docs.length; i++) {
      final d = docs[i];
      final path = staged[i];
      if (path == null) {
        damaged++;
        continue;
      }
      final r = await repo.addFile(
        path,
        displayName: (d['name'] as String?) ?? p.posix.basename((d['file'] as String?) ?? 'Document.pdf'),
        source: DocSource.values.where((s) => s.name == d['source']).firstOrNull ?? DocSource.backup,
        sourceTool: toolIdByName(d['sourceTool'] as String?),
        mime: (d['mime'] as String?) ?? 'application/octet-stream',
        folderId: d['folderId'] == null ? null : ids[d['folderId']],
        pageCount: d['pageCount'] as int?,
        width: d['width'] as int?,
        height: d['height'] as int?,
        addedAt: _parseDate(d['addedAt']),
      );
      switch (r) {
        case Duplicate():
          duplicates++;
        case AddFailed():
          damaged++;
        case Added(:final doc):
          imported++;
          final notes = d['notes'];
          if (notes is String && notes.isNotEmpty) await repo.setNotes(doc.id, notes.length > maxNotesChars ? notes.substring(0, maxNotesChars) : notes);
          final tags = d['tags'];
          if (tags is List && tags.isNotEmpty) await repo.setTags(doc.id, [for (final t in tags) if (t is String) t]);
          if (d['starred'] == true) await repo.setStarred([doc.id], true);
          final expiry = _parseDate(d['expiryDate']);
          if (expiry != null) {
            await repo.setExpiry(doc.id, expiry, [for (final o in (d['reminderOffsets'] as List? ?? const [])) if (o is int) o],
                d['reminderMinuteOfDay'] as int?);
          }
      }
    }
    return ImportSummary(imported: imported, duplicates: duplicates, damaged: damaged);
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}
