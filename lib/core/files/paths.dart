import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App directories (ARCHITECTURE §6.1).
class AppPaths {
  const AppPaths({required this.cacheRoot, required this.supportRoot});

  /// getTemporaryDirectory(): job temp dirs (`cache/jobs/<id>/{in,work}`).
  final Directory cacheRoot;

  /// getApplicationSupportDirectory(): app-managed outputs.
  final Directory supportRoot;

  static Future<AppPaths> resolve() async => AppPaths(
        cacheRoot: await getTemporaryDirectory(),
        supportRoot: await getApplicationSupportDirectory(),
      );

  Directory get jobsRoot => Directory(p.join(cacheRoot.path, 'jobs'));
  Directory jobDir(String id) => Directory(p.join(jobsRoot.path, id));
  Directory jobIn(String id) => Directory(p.join(jobsRoot.path, id, 'in'));
  Directory jobWork(String id) => Directory(p.join(jobsRoot.path, id, 'work'));
  Directory get outputsRoot => Directory(p.join(supportRoot.path, 'outputs'));
  Directory get draftsRoot => Directory(p.join(supportRoot.path, 'drafts'));

  String outputAbsolute(String relPath) => p.join(outputsRoot.path, relPath);
}

Future<int> directorySize(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File) {
      try {
        total += await e.length();
      } on FileSystemException {
        // File vanished mid-walk.
      }
    }
  }
  return total;
}

Future<void> deleteQuietly(FileSystemEntity e) async {
  try {
    if (await e.exists()) await e.delete(recursive: true);
  } on FileSystemException {
    // Best effort; the launch sweep retries.
  }
}
