import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_copy.dart';
import '../../../core/files/file_gateway.dart';
import '../../../core/files/paths.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../application/library_backup.dart';

/// FR-LIB-18 · Export library / Export folder as ZIP: builds the ZIP with
/// real progress (entries) and Cancel, then the system Save dialog. The ZIP
/// is a temporary copy, removed afterwards.
Future<void> exportLibraryFlow(BuildContext context, WidgetRef ref, {String? folderId}) async {
  final l = context.l10n;
  final job = 'lib-export-${const Uuid().v7()}';
  final paths = ref.read(appPathsProvider);
  final cancel = CancelToken();
  final progress = ValueNotifier<(int, int)>((0, 0));
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('export-progress'),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, v, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            // Indeterminate until the first real count (rule 3).
            LinearProgressIndicator(value: v.$2 == 0 ? null : v.$1 / v.$2),
            if (v.$2 > 0) ...[const SizedBox(height: Space.x4), Text(l.expExporting(v.$1, v.$2))],
          ]),
        ),
        actions: [TextButton(onPressed: cancel.cancel, child: Text(l.actionCancel))],
      ),
    ),
  ));
  var dialogOpen = true;
  void close() {
    if (dialogOpen) navigator.pop();
    dialogOpen = false;
  }

  try {
    final zip = await exportLibrary(
      ref.read(libraryRepositoryProvider),
      workDir: paths.jobWork(job),
      now: ref.read(clockProvider)(),
      folderId: folderId,
      cancel: cancel,
      onProgress: (done, total) => progress.value = (done, total),
    );
    close();
    if (!context.mounted) return;
    final saved = await ref.read(fileGatewayProvider).saveAs(zip, suggestedName: p.basename(zip), mime: 'application/zip');
    if (!context.mounted) return;
    switch (saved) {
      case Saved():
        showAppSnack(context, l.expDone);
      case SaveFailed():
        showAppSnack(context, l.saveFailed);
      case SaveCancelled() || PhotosAccessDenied():
        break;
    }
  } on CancelledException {
    close();
  } on AppError catch (e) {
    close();
    if (context.mounted) showAppSnack(context, errorCopy(l, e).title);
  } finally {
    progress.dispose();
    await deleteQuietly(paths.jobDir(job));
  }
}

/// FR-LIB-19 · Import backup: pick a `.zip`, merge it (indeterminate: the
/// unpacking has no honest count), then the summary.
Future<void> importBackupFlow(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final gateway = ref.read(fileGatewayProvider);
  final draft = 'lib-import-zip-${const Uuid().v7()}';
  final navigator = Navigator.of(context, rootNavigator: true);
  try {
    final zip = await gateway.pickZip(draftId: draft);
    if (zip == null || !context.mounted) return;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const ValueKey('import-progress'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const LinearProgressIndicator(),
            const SizedBox(height: Space.x4),
            Text(l.impImporting),
          ]),
        ),
      ),
    ));
    String? problem;
    ImportSummary? summary;
    try {
      summary = await importBackup(
        ref.read(libraryRepositoryProvider),
        zipPath: zip,
        staging: Directory(p.join(ref.read(appPathsProvider).supportRoot.path, 'library', '_import_tmp')),
        freeBytes: ref.read(deviceServicesProvider).freeBytes,
      );
    } on BackupException catch (e) {
      problem = e.problem == BackupProblem.tooNew ? l.impTooNew : l.impNotBackup;
    } on AppError catch (e) {
      problem = errorCopy(l, e).title;
    } finally {
      navigator.pop();
    }
    if (!context.mounted) return;
    if (problem != null) {
      showAppSnack(context, problem);
      return;
    }
    final s = summary!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('import-summary'),
        content: Text(l.impSummary(s.imported, s.duplicates, s.damaged)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.actionDone))],
      ),
    );
  } finally {
    await gateway.discardDraft(draft);
  }
}
