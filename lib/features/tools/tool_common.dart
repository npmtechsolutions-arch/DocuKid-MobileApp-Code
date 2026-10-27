import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_copy.dart';
import '../../core/files/picked_file.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/operation/jobs_controller.dart';
import '../../core/operation/tool_operation.dart';
import '../../core/validation/input_validator.dart';
import '../../core/widgets/common.dart';
import '../search/tool_catalog.dart';
import 'tool_inputs.dart';

/// Starts the job and opens the Processing route (S10).
void runTool<O extends ToolOptions>(
    BuildContext context, WidgetRef ref, ToolOperation<O> op, List<PickedFile> inputs, O options) {
  try {
    final id = ref.read(jobsProvider.notifier).start(op, inputs, options);
    // An "Undo" from the tool screen must not follow the user to Processing.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.push('/job/$id');
  } on JobBusyException {
    showAppSnack(context, context.l10n.busySnack);
  }
}

/// Snackbars for one-shot pick outcomes (truncation, too large, all invalid).
void listenPickResults(BuildContext context, WidgetRef ref, ToolId tool) {
  ref.listen(toolInputsProvider(tool).select((s) => s.lastPick), (_, r) {
    if (r == null) return;
    final l = context.l10n;
    final d = toolById(tool);
    final inputs = ref.read(toolInputsProvider(tool));
    if (r.lowStorageNeededBytes case final needed?) {
      final copy = errorCopy(l, AppError(AppErrorCode.insufficientStorage, neededBytes: needed));
      showAppSnack(context, '${copy.title}. ${copy.body}');
    } else if (r.truncated) {
      showAppSnack(context, l.inputsTruncated(d.maxInputs));
    } else if (r.rejectedTooLarge > 0) {
      final pdf = d.inputKind == InputKind.pdfs || d.inputKind == InputKind.singlePdf;
      showAppSnack(context, l.errFileTooLargeBody(formatBytes(pdf ? Limits.pdfMaxBytes : Limits.imageMaxBytes)));
    } else if (r.files.isNotEmpty && r.files.every((f) => !f.status.isValid) && inputs.valid.isEmpty) {
      showAppSnack(context, l.inputsAllInvalid);
    }
    ref.read(toolInputsProvider(tool).notifier).acknowledgePick();
  });
}

/// "Restored your last session." [Start over].
class RestoredBanner extends ConsumerWidget {
  const RestoredBanner({super.key, required this.tool});
  final ToolId tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restored = ref.watch(toolInputsProvider(tool).select((s) => s.restored));
    if (!restored) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InlineBanner(
        kind: BannerKind.info,
        text: l.draftRestored,
        onDismiss: () => ref.read(toolInputsProvider(tool).notifier).acknowledgeRestore(),
        actions: [
          TextButton(onPressed: () => ref.read(toolInputsProvider(tool).notifier).clear(), child: Text(l.draftStartOver)),
        ],
      ),
    );
  }
}

/// "Large file — this may take a while." (global state matrix).
class LargeFileHint extends StatelessWidget {
  const LargeFileHint({super.key, required this.bytes});
  final int bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes <= Limits.largeFileBytes) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InlineBanner(kind: BannerKind.info, text: context.l10n.largeFileHint),
    );
  }
}
