import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/files/file_gateway.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';

/// S12 · Save / Export. Images get D5 (Photos / Files…); PDFs go straight to
/// the system save dialog. User cancel is silent.
Future<void> saveResult(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  required String name,
  required String mime,
  required String opId,
}) async {
  final l = context.l10n;
  final gateway = ref.read(fileGatewayProvider);
  final history = ref.read(historyRepositoryProvider);
  var toPhotos = false;
  if (mime.startsWith('image/')) {
    final choice = await showAppSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.saveSheetTitle, style: ctx.text.titleMedium),
        const SizedBox(height: Space.x2),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l.saveToPhotos),
          onTap: () => Navigator.pop(ctx, true),
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(l.saveToFiles),
          onTap: () => Navigator.pop(ctx, false),
        ),
        const SizedBox(height: Space.x4),
      ]),
    );
    if (choice == null) return;
    toPhotos = choice;
  }
  if (!context.mounted) return;
  final outcome = toPhotos
      ? await gateway.saveToPhotos(path)
      : await gateway.saveAs(path, suggestedName: name, mime: mime);
  if (!context.mounted) return;
  switch (outcome) {
    case Saved(:final displayName):
      await history.markSaved(opId);
      if (context.mounted) {
        showAppSnack(context, displayName == null || displayName == name ? l.savedSnack : l.savedSnackNamed(displayName));
      }
    case SaveCancelled():
      break;
    case PhotosAccessDenied():
      showAppSnack(context, l.photosDenied, actionLabel: l.saveFilesInstead, onAction: () async {
        final r = await gateway.saveAs(path, suggestedName: name, mime: mime);
        if (r is Saved) await history.markSaved(opId);
      });
    case SaveFailed():
      showAppSnack(context, l.saveFailed, actionLabel: l.actionTryAgain, onAction: () {
        saveResult(context, ref, path: path, name: name, mime: mime, opId: opId);
      });
  }
}

/// S13 · system share sheet (iPad popover anchored to [anchor]). Cancel is silent.
Future<void> shareResult(BuildContext anchor, WidgetRef ref, {required String path, required String mime}) async {
  final outcome = await ref.read(fileGatewayProvider).share([path], mime: mime, origin: originOf(anchor));
  if (outcome == ShareOutcome.failed && anchor.mounted) showAppSnack(anchor, anchor.l10n.saveFailed);
}

Future<void> openWithResult(BuildContext anchor, WidgetRef ref, {required String path, required String mime}) async {
  final ok = await ref.read(fileGatewayProvider).openWith(path, mime: mime, origin: originOf(anchor));
  if (!ok && anchor.mounted) showAppSnack(anchor, anchor.l10n.openWithNone);
}
