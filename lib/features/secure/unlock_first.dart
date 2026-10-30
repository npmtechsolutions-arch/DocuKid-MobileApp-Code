import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/errors/app_error.dart';
import '../../core/files/picked_file.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/tool_scaffold.dart';
import '../incoming/incoming_controller.dart';
import '../search/tool_catalog.dart';
import '../tools/tool_inputs.dart';

/// "Unlock it first" (RELEASE_V1_4 FR-UNL-08): tools that can't use a
/// password-protected PDF send it to Unlock PDF.
bool isLockedPdf(PickedFile f) => f.status.error == AppErrorCode.encryptedDocument;

/// The first locked PDF in [tool]'s inputs, if any.
PickedFile? firstLockedPdf(ToolInputs inputs) {
  for (final f in inputs.files) {
    if (isLockedPdf(f)) return f;
  }
  return null;
}

/// Hands a copy of [file] to S38 for its next open; [from] keeps its list.
void handFileToUnlock(WidgetRef ref, ToolId from, PickedFile file) => ref
    .read(incomingHandoffProvider.notifier)
    .put(ToolId.pdfUnlock, [file], ref.read(toolInputsProvider(from)).draftId, copy: true);

/// Opens S38 with a copy of [file].
void openUnlockWith(BuildContext context, WidgetRef ref, ToolId from, PickedFile file) {
  handFileToUnlock(ref, from, file);
  context.push(toolById(ToolId.pdfUnlock).route);
}

/// A single-PDF tool's primary action while its file is locked.
PrimaryActionBar unlockFirstAction(BuildContext context, WidgetRef ref, ToolId tool, PickedFile file) => PrimaryActionBar(
      label: context.l10n.encUnlockAction,
      icon: Icons.lock_open_rounded,
      helper: context.l10n.encUnlockFirst,
      onPressed: () => openUnlockWith(context, ref, tool, file),
    );

/// For list tools (Merge): the message and an Unlock PDF button for [file].
class UnlockFirstBanner extends ConsumerWidget {
  const UnlockFirstBanner({super.key, required this.tool, required this.file});
  final ToolId tool;
  final PickedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: Space.x3),
        child: InlineBanner(
          kind: BannerKind.warning,
          text: context.l10n.encUnlockFirst,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => openUnlockWith(context, ref, tool, file),
              child: Text(context.l10n.encUnlockAction),
            ),
          ],
        ),
      );
}
