import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/files/file_naming.dart';
import '../../core/files/paths.dart';

/// App-managed result copies in `appSupport/outputs/<jobId>/<name>` (ADR-008).
class OutputsRepository {
  OutputsRepository(this._paths, {Future<void> Function(String path)? protect}) : _protect = protect;
  final AppPaths _paths;
  final Future<void> Function(String path)? _protect;

  /// Moves [rawPath] (in the job work dir) into `outputs/<jobId>/` and returns
  /// (absolutePath, relativePath).
  Future<(String, String)> adopt(String jobId, String rawPath, String name) async {
    final dir = Directory(p.join(_paths.outputsRoot.path, jobId));
    await dir.create(recursive: true);
    final finalName = uniqueIn(dir, name);
    final dest = p.join(dir.path, finalName);
    try {
      await File(rawPath).rename(dest);
    } on FileSystemException {
      // Different volume: copy then delete.
      await File(rawPath).copy(dest);
      await File(rawPath).delete();
    }
    await _protect?.call(_paths.outputsRoot.path);
    await _protect?.call(dest);
    return (dest, p.join(jobId, finalName));
  }

  String absolute(String relPath) => _paths.outputAbsolute(relPath);

  Future<bool> exists(String? relPath) async => relPath != null && await File(absolute(relPath)).exists();

  /// Renames the app copy (D3). Returns the new (absolute, relative) paths.
  Future<(String, String)> rename(String relPath, String newName) async {
    final file = File(absolute(relPath));
    final dir = file.parent;
    final unique = uniqueName(newName, (c) => c != p.basename(file.path) && File(p.join(dir.path, c)).existsSync());
    final dest = p.join(dir.path, unique);
    if (dest != file.path) await file.rename(dest);
    return (dest, p.join(p.basename(dir.path), unique));
  }

  Future<void> deleteFor(String jobId) => deleteQuietly(Directory(p.join(_paths.outputsRoot.path, jobId)));

  Future<void> deleteAll() => deleteQuietly(_paths.outputsRoot);

  /// Result copies + job temp files (FR-SET-03).
  Future<int> totalBytes() async =>
      await directorySize(_paths.outputsRoot) + await directorySize(_paths.jobsRoot);

  Future<void> clearTemp({Set<String> keep = const {}}) async {
    final root = _paths.jobsRoot;
    if (!await root.exists()) return;
    await for (final e in root.list(followLinks: false)) {
      if (!keep.contains(p.basename(e.path))) await deleteQuietly(e);
    }
  }
}
