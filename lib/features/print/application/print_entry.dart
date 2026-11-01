import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/files/mime_sniffer.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../incoming/incoming_controller.dart';
import '../../search/tool_catalog.dart';

/// The Print tool's route that goes straight on to S48 with handed-over files.
final printPreviewRoute = '${toolById(ToolId.print).route}?preview=1';

/// FR-PRN-02 · Print from a finished output (Result, Details): a COPY goes to
/// the Print tool like a share into DocuKit — the output itself is never
/// touched — and S48 opens with it, no re-picking.
Future<void> printOutput(BuildContext context, WidgetRef ref, {required String path, required String name}) async {
  final l = context.l10n;
  final router = GoRouter.of(context);
  final gateway = ref.read(fileGatewayProvider);
  final draft = 'print-open-${const Uuid().v7()}';
  final dir = ref.read(appPathsProvider).jobIn(draft);
  List<PickedFile> files;
  try {
    await dir.create(recursive: true);
    final copy = await File(path).copy(p.join(dir.path, p.basename(path)));
    final type = await sniffFile(copy.path);
    files = await gateway.reinspect([
      PickedFile(path: copy.path, displayName: name, type: type, sizeBytes: await copy.length()),
    ]);
  } on FileSystemException {
    files = const [];
  }
  if (files.isEmpty) {
    await gateway.discardDraft(draft);
    if (context.mounted) showAppSnack(context, l.histUnavailable);
    return;
  }
  // The Print tool moves the copy into its own draft and deletes this one.
  ref.read(incomingHandoffProvider.notifier).put(ToolId.print, files, draft);
  unawaited(router.push(printPreviewRoute));
}
