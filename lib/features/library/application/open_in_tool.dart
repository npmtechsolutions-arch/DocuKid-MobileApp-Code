import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/files/mime_sniffer.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../data/library/library_repository.dart';
import '../../incoming/incoming_controller.dart';
import '../../search/tool_catalog.dart';

const _onePdfTools = [
  ToolId.pdfCompress,
  ToolId.pdfOrganize,
  ToolId.pdfSplit,
  ToolId.pdfToImages,
  ToolId.pdfMerge, // the user adds the second file there
  ToolId.ocr,
  ToolId.pdfSign,
  ToolId.pdfWatermark,
  ToolId.pdfProtect,
  ToolId.pdfUnlock,
];
const _imageTools = [ToolId.imageCompress, ToolId.imageResize, ToolId.imageConvert, ToolId.imageToPdf, ToolId.ocr];

bool _isImage(LibraryDoc d) => d.mime.startsWith('image/');

/// PDFs and images together: no tool takes both.
bool isMixedSelection(List<LibraryDoc> docs) => docs.any((d) => d.isPdf) && docs.any(_isImage);

/// FR-LIB-10 · the tools that take [docs] as they are, in Home's order.
List<ToolId> toolsForLibrary(List<LibraryDoc> docs) {
  if (docs.isEmpty || isMixedSelection(docs)) return const [];
  final List<ToolId> tools;
  if (docs.every((d) => d.isPdf)) {
    tools = docs.length == 1 ? _onePdfTools : const [ToolId.pdfMerge];
  } else if (docs.every(_isImage)) {
    tools = _imageTools;
  } else {
    return const [];
  }
  return [for (final t in tools) if (docs.length <= toolById(t).maxInputs) t];
}

/// FR-LIB-11 · "Open in tool…": pick a compatible tool, copy the documents
/// into a new job draft (never the library files themselves) and open the
/// tool with them, like a share into DocuKit.
Future<void> openInTool(BuildContext context, WidgetRef ref, List<LibraryDoc> docs) async {
  final l = context.l10n;
  final tools = toolsForLibrary(docs);
  if (tools.isEmpty) {
    showAppSnack(context, isMixedSelection(docs) ? l.libOpenMixed : l.libOpenNone);
    return;
  }
  final tool = await showModalBottomSheet<ToolId>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(l.libOpenInTool, style: ctx.text.titleMedium)),
          for (final t in tools)
            ListTile(
              key: ValueKey('open-in-${t.name}'),
              minTileHeight: 56,
              leading: GradientIconTile(icon: toolById(t).icon, category: toolById(t).category, size: 36, shadow: false),
              title: Text(toolById(t).title(l)),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ]),
      ),
    ),
  );
  if (tool == null || !context.mounted) return;
  final router = GoRouter.of(context);
  final repo = ref.read(libraryRepositoryProvider);
  final gateway = ref.read(fileGatewayProvider);
  final draft = 'lib-open-${const Uuid().v7()}';
  final dir = ref.read(appPathsProvider).jobIn(draft);
  final copies = <PickedFile>[];
  for (final d in docs.take(toolById(tool).maxInputs)) {
    try {
      final path = await repo.copyForTool(d.id, dir);
      copies.add(PickedFile(
          path: path, displayName: d.name, type: d.isPdf ? SniffedType.pdf : SniffedType.unknown, sizeBytes: d.sizeBytes));
    } on Exception {
      continue; // its file is missing: leave it out
    }
  }
  // Inspected like a picked file, so the tool validates it as usual.
  final files = await gateway.reinspect(copies);
  if (files.isEmpty) {
    await gateway.discardDraft(draft);
    if (context.mounted) showAppSnack(context, l.libFileMissing);
    return;
  }
  // The tool moves the copies into its own draft and deletes this one.
  ref.read(incomingHandoffProvider.notifier).put(tool, files, draft);
  unawaited(router.push(toolById(tool).route));
}
