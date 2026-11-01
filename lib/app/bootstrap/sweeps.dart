import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/files/paths.dart';
import '../../core/logging/log.dart';
import '../../core/print/print_gateway.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/outputs_repository.dart';
import '../../data/settings/app_settings.dart';
import '../../data/settings/settings_repository.dart';
import '../../features/search/tool_catalog.dart';

const tempMaxAge = Duration(hours: 24);

/// Draft ids still referenced by a saved tool draft (FR-LIFE-03) — their
/// input copies must survive the temp sweep.
Set<String> activeDraftIds(SettingsRepository settings) {
  final ids = <String>{};
  for (final t in ToolId.values) {
    final raw = settings.readDraft(t.name);
    if (raw == null) continue;
    try {
      final id = (jsonDecode(raw) as Map)['id'];
      if (id is String) ids.add(id);
    } catch (_) {
      // Corrupt draft: ignore; the sweep may then remove its files.
    }
  }
  return ids;
}

/// Deletes `cache/jobs/*` older than 24 h, except [keep]; print work folders
/// from before [now] whatever their age (FR-PRN-13: a print file never
/// outlives the session); and received files
/// the app never took (`cache/incoming/*`, FR-SHR-04). Returns the count.
Future<int> sweepTemp(AppPaths paths, {required DateTime now, Set<String> keep = const {}}) async {
  var n = 0;
  for (final root in [paths.jobsRoot, Directory(p.join(paths.cacheRoot.path, 'incoming'))]) {
    if (!await root.exists()) continue;
    n += await _sweepDir(root, now: now, keep: keep);
  }
  return n;
}

Future<int> _sweepDir(Directory root, {required DateTime now, required Set<String> keep}) async {
  var n = 0;
  await for (final e in root.list(followLinks: false)) {
    if (keep.contains(p.basename(e.path))) continue;
    try {
      final modified = (await e.stat()).modified;
      final leftoverPrint = p.basename(e.path).startsWith(printJobPrefix) && modified.isBefore(now);
      if (leftoverPrint || now.difference(modified) > tempMaxAge) {
        await e.delete(recursive: true);
        n++;
      }
    } on FileSystemException {
      // Best effort.
    }
  }
  return n;
}

/// ADR-066/047: review text (OCR) never outlives the session that made it,
/// so every launch deletes all of `cache/review/*`, whatever its age.
/// Returns the count.
Future<int> sweepReview(AppPaths paths) async {
  final root = paths.reviewRoot;
  if (!await root.exists()) return 0;
  var n = 0;
  await for (final e in root.list(followLinks: false)) {
    try {
      await e.delete(recursive: true);
      n++;
    } on FileSystemException {
      // Best effort; the next launch retries.
    }
  }
  return n;
}

/// The user left Result/Review: drop that job's review text.
Future<void> deleteReview(AppPaths paths, String jobId) => deleteQuietly(paths.reviewDir(jobId));

/// FR-HIS-04: delete app copies past retention; rows keep their metadata.
Future<int> runRetentionSweep(HistoryRepository history, OutputsRepository outputs, Retention r, DateTime now) async {
  final d = r.duration;
  if (d == null) return 0;
  final due = await history.outputsFinishedBefore(now.subtract(d));
  for (final row in due) {
    await outputs.deleteFor(row.id);
    await history.markOutputDeleted(row.id, now);
  }
  return due.length;
}

/// Launch tasks (run after the first frame, never blocking startup).
Future<void> runLaunchSweeps({
  required AppPaths paths,
  required HistoryRepository history,
  required OutputsRepository outputs,
  required SettingsRepository settings,
  required Retention retention,
  required DateTime now,
}) async {
  try {
    final interrupted = await history.markRunningAsInterrupted();
    final temp = await sweepTemp(paths, now: now, keep: activeDraftIds(settings));
    final review = await sweepReview(paths);
    final expired = await runRetentionSweep(history, outputs, retention, now);
    Log.event('launch_sweep', 'interrupted=$interrupted temp=$temp review=$review expired=$expired');
  } catch (_) {
    Log.event('launch_sweep_failed');
  }
}
