import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_copy.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../data/library/library_repository.dart';
import '../../search/tool_catalog.dart';
import '../presentation/folder_picker_sheet.dart';

/// S41 "Scan a document" from inside a folder: the scan's "Save to My
/// Documents" preselects that folder instead of "Scans". Used once.
final scanTargetFolderProvider = NotifierProvider<ScanTargetFolder, String?>(ScanTargetFolder.new);

class ScanTargetFolder extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? folderId) => state = folderId;

  String? take() {
    final id = state;
    state = null;
    return id;
  }
}

/// Where "View" goes after a save: the folder that now holds the document.
String libraryRouteFor(String? folderId) => folderId == null ? '/library' : '/library/folder/$folderId';

/// FR-LIB-03 / 05 · Save one file (a result, a scan, a shared file) into My
/// Documents (RELEASE_V1_5 §4.5): pick a folder (S43, "Save to…"), copy it in,
/// ask on a duplicate (FR-LIB-21), then "Saved to My Documents · View".
/// [defaultFolderName] preselects a root folder by that name, created if
/// missing ("Scans", FR-LIB-05) and removed again if the user cancels.
Future<void> saveToLibrary(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  required String name,
  required String mime,
  required DocSource source,
  ToolId? sourceTool,
  int? pageCount,
  int? width,
  int? height,
  String? defaultFolderName,
}) async {
  final l = context.l10n;
  final repo = ref.read(libraryRepositoryProvider);
  final router = GoRouter.of(context);
  String? createdId;
  var initial = source == DocSource.scan ? ref.read(scanTargetFolderProvider.notifier).take() : null;
  if (initial != null && await repo.folder(initial) == null) initial = null;
  if (initial == null && defaultFolderName != null) {
    final existing = (await repo.watchFolders().first).where((f) => f.name.toLowerCase() == defaultFolderName.toLowerCase());
    if (existing.isNotEmpty) {
      initial = existing.first.id;
    } else {
      initial = createdId = (await repo.createFolder(defaultFolderName)).id;
    }
  }
  if (!context.mounted) return;
  final pick = await showFolderPicker(context, title: l.libSaveToTitle, actionLabel: l.libSaveHere, initialFolderId: initial);
  if (pick == null) {
    // Don't leave an empty "Scans" behind when the user changed their mind.
    if (createdId != null && (await repo.folderContents(createdId)) == (docs: 0, folders: 0)) {
      await repo.deleteFolder(createdId, mode: FolderDeleteMode.moveContentsUp);
    }
    return;
  }
  Future<AddResult> add({bool allowDuplicate = false}) => repo.addFile(path,
      displayName: name,
      folderId: pick.folderId,
      source: source,
      sourceTool: sourceTool,
      mime: mime,
      pageCount: pageCount,
      width: width,
      height: height,
      allowDuplicate: allowDuplicate);

  var r = await add();
  if (!context.mounted) return;
  if (r is Duplicate) {
    final choice = await askDuplicate(context, ref, r.existing);
    if (!context.mounted || choice == null) return;
    if (choice == DuplicateChoice.openExisting) {
      unawaited(router.push(libraryRouteFor(r.existing.folderId)));
      return;
    }
    r = await add(allowDuplicate: true);
    if (!context.mounted) return;
  }
  switch (r) {
    case Added(:final doc):
      showAppSnack(context, l.libSavedSnack, actionLabel: l.libSavedView, onAction: () => router.push(libraryRouteFor(doc.folderId)));
    case AddFailed(:final error):
      showAppSnack(context, errorCopy(l, error).title);
    case Duplicate():
      break;
  }
}

enum DuplicateChoice { openExisting, addCopy }

/// FR-LIB-21: "This file is already saved as Passport.pdf in IDs. Add another copy?"
Future<DuplicateChoice?> askDuplicate(BuildContext context, WidgetRef ref, LibraryDoc existing) async {
  final l = context.l10n;
  final path = await ref.read(libraryRepositoryProvider).folderPath(existing.folderId);
  if (!context.mounted) return null;
  return showAdaptiveDialog<DuplicateChoice>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(l.libDupTitle),
      content: Text(l.libDupBody(existing.name, path.isEmpty ? l.libRoot : path.join(' › '))),
      actions: [
        adaptiveAction(ctx, label: l.actionCancel, onPressed: () => Navigator.pop(ctx)),
        adaptiveAction(ctx, label: l.libDupOpen, onPressed: () => Navigator.pop(ctx, DuplicateChoice.openExisting)),
        adaptiveAction(ctx, label: l.libDupAdd, primary: true, onPressed: () => Navigator.pop(ctx, DuplicateChoice.addCopy)),
      ],
    ),
  );
}

/// FR-LIB-04 · Import PDFs or images into [folderId] with the tools' pickers
/// and limits. Returns how many were added.
Future<int> importToLibrary(BuildContext context, WidgetRef ref, {required bool pdfs, String? folderId}) async {
  final gateway = ref.read(fileGatewayProvider);
  final draft = 'lib-import-${const Uuid().v7()}';
  try {
    final picked = pdfs ? await gateway.pickPdfs(draftId: draft, multiple: true) : await gateway.pickImages(draftId: draft, max: 50);
    if (!context.mounted) return 0;
    return await addAllToLibrary(context, ref, files: picked.files, folderId: folderId, source: DocSource.import);
  } finally {
    await gateway.discardDraft(draft);
  }
}

/// S19 · "Save to My Documents" for files shared into DocuKit (FR-LIB-05):
/// one folder for all of them.
Future<int> saveIncomingToLibrary(BuildContext context, WidgetRef ref, List<PickedFile> files) async {
  final l = context.l10n;
  final pick = await showFolderPicker(context, title: l.libSaveToTitle, actionLabel: l.libSaveHere);
  if (pick == null || !context.mounted) return 0;
  return addAllToLibrary(context, ref, files: files, folderId: pick.folderId, source: DocSource.incoming);
}

/// Adds [files] one by one ("Adding 2 of 5…" when more than one); a
/// duplicate asks each time (FR-LIB-21). A password-protected PDF is fine to
/// keep; other invalid files are skipped and counted. Returns how many were added.
Future<int> addAllToLibrary(BuildContext context, WidgetRef ref,
    {required List<PickedFile> files, required String? folderId, required DocSource source}) async {
  final l = context.l10n;
  final repo = ref.read(libraryRepositoryProvider);
  final ok = [for (final f in files) if (f.status.isValid || f.status.error == AppErrorCode.encryptedDocument) f];
  var skipped = files.length - ok.length;
  if (ok.isEmpty) {
    if (skipped > 0) showAppSnack(context, l.libImportSummary(0, skipped));
    return 0;
  }
  final router = GoRouter.of(context);
  final progress = ValueNotifier(0);
  final showProgress = ok.length > 1;
  if (showProgress) {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (ctx, done, _) => Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: done / ok.length),
              const SizedBox(height: 16),
              Text(l.libAdding((done + 1).clamp(1, ok.length), ok.length)),
            ]),
          ),
        ),
      ),
    ));
  }
  var added = 0;
  for (final f in ok) {
    Future<AddResult> add({bool allowDuplicate = false}) => repo.addFile(f.path,
        displayName: f.displayName,
        folderId: folderId,
        source: source,
        mime: f.mime,
        pageCount: f.pdf?.pageCount,
        width: f.image?.width,
        height: f.image?.height,
        allowDuplicate: allowDuplicate);
    var r = await add();
    if (r is Duplicate && context.mounted) {
      if (await askDuplicate(context, ref, r.existing) == DuplicateChoice.addCopy) r = await add(allowDuplicate: true);
    }
    if (r is Added) {
      added++;
    } else if (r is AddFailed) {
      skipped++;
    }
    progress.value++;
  }
  if (showProgress && context.mounted) Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  if (context.mounted && (added > 0 || skipped > 0)) {
    showAppSnack(context, skipped == 0 ? l.libSavedSnack : l.libImportSummary(added, skipped),
        actionLabel: added > 0 ? l.libSavedView : null, onAction: added > 0 ? () => router.push(libraryRouteFor(folderId)) : null);
  }
  return added;
}

/// "Import files" → which picker (the system file picker for PDFs, the photo
/// picker for images).
Future<void> chooseImport(BuildContext context, WidgetRef ref, {String? folderId}) async {
  final l = context.l10n;
  final pdfs = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(l.libImportPdfs), onTap: () => Navigator.pop(ctx, true)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l.libImportImages), onTap: () => Navigator.pop(ctx, false)),
      ]),
    ),
  );
  if (pdfs == null || !context.mounted) return;
  await importToLibrary(context, ref, pdfs: pdfs, folderId: folderId);
}
