import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/operation/job_state.dart';
import '../../../core/operation/jobs_controller.dart';
import '../../../core/pdf/pdf_security.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../secure/unlock_first.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/unlock_operation.dart';

/// S38 · Unlock PDF (RELEASE_V1_4 §3, FR-UNL-01…07). The password check runs
/// in the job; a wrong password comes back here as an inline error with the
/// field still filled (FR-UNL-03). The field is cleared when the job ends on
/// Result, Cancel or Error (FR-UNL-07).
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});
  static const tool = ToolId.pdfUnlock;

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  var _shown = false;
  String? _jobId;

  /// The last job's [UnlockReturn] reason, until the file or password changes.
  String? _returned;

  @override
  void dispose() {
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run() {
    final file = ref.read(toolInputsProvider(UnlockScreen.tool)).single!;
    setState(() => _returned = null);
    _jobId = runTool(
        context, ref, ref.read(unlockOperationProvider), [file], UnlockOptions(OneTimePassword(_password.text)));
  }

  void _onJob(JobState? next) {
    final id = _jobId;
    if (id == null || next == null || !next.isTerminal) return;
    if (next is JobReturned) {
      setState(() => _returned = next.reason);
      ref.read(jobsProvider.notifier).dismiss(id);
      if (next.reason == UnlockReturn.wrongPassword) _focus.requestFocus();
    } else {
      setState(() {
        _password.clear();
        _shown = false;
      });
    }
    _jobId = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const tool = UnlockScreen.tool;
    listenPickResults(context, ref, tool);
    ref.listen(jobsProvider.select((m) => _jobId == null ? null : m[_jobId]?.state), (_, next) => _onJob(next));
    ref.listen(toolInputsProvider(tool).select((s) => s.single?.path), (_, _) => setState(() => _returned = null));
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final file = inputs.single;
    final locked = file != null && isLockedPdf(file);
    // A file that opens without a password: unprotected or owner-restricted.
    final protection = file != null && file.status.isValid ? ref.watch(pdfProtectionProvider(file.path)) : null;
    final notice = switch ((_returned, protection)) {
      (UnlockReturn.notEncrypted, _) || (_, AsyncData(value: PdfProtection.none)) => l.unlNotEncrypted,
      (UnlockReturn.ownerOnly, _) || (_, AsyncData(value: PdfProtection.ownerOnly)) => l.unlOwnerOnly,
      _ => null,
    };
    final usable = locked && notice == null;
    final canRun = usable && _password.text.isNotEmpty && !inputs.picking;

    return ToolScaffold(
      title: l.toolPdfUnlockTitle,
      hasWork: file != null,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.unlRun,
        icon: Icons.lock_open_rounded,
        helper: file == null ? l.pickPdf : null,
        onPressed: canRun ? _run : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: Icons.lock_open_rounded,
            accent: context.docu.secureAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
        if (notice != null) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.info, text: notice),
        ],
      ],
      secondary: [
        const SizedBox(height: Space.x2),
        TextField(
          key: const ValueKey('unl-password'),
          controller: _password,
          focusNode: _focus,
          enabled: file == null || usable,
          obscureText: !_shown,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          autofillHints: null,
          keyboardType: _shown ? TextInputType.visiblePassword : TextInputType.text,
          onChanged: (_) => setState(() {
            if (_returned == UnlockReturn.wrongPassword) _returned = null;
          }),
          onSubmitted: (_) {
            if (canRun) _run();
          },
          decoration: InputDecoration(
            labelText: l.unlPassword,
            errorText: _returned == UnlockReturn.wrongPassword ? l.unlWrong : null,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _shown ? l.prtHide : l.prtShow,
              icon: Icon(_shown ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _shown = !_shown),
            ),
          ),
        ),
        const SizedBox(height: Space.x4),
        InlineBanner(kind: BannerKind.info, text: l.unlNeedPw),
      ],
    );
  }
}
