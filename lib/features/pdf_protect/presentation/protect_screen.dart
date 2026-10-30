import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/pdf/pdf_security.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/protect_operation.dart';

/// S37 · Protect PDF (RELEASE_V1_4 §3, FR-PRT-01…04). The password lives only
/// in this screen's text fields until Run, then in the job's
/// [OneTimePassword]; the fields are cleared at Run (FR-PRT-07).
class ProtectScreen extends ConsumerStatefulWidget {
  const ProtectScreen({super.key});
  static const tool = ToolId.pdfProtect;

  @override
  ConsumerState<ProtectScreen> createState() => _ProtectScreenState();
}

class _ProtectScreenState extends ConsumerState<ProtectScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  var _showPassword = false, _showConfirm = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final l = context.l10n;
    final file = ref.read(toolInputsProvider(ProtectScreen.tool)).single!;
    if (passwordStrength(_password.text) == PasswordStrength.weak) {
      final ok = await askAdaptive(context,
          title: l.prtWeakTitle, body: l.prtWeakBody, no: l.prtWeakChange, yes: l.prtWeakUse);
      if (!mounted) return;
      if (!ok) {
        _passwordFocus.requestFocus();
        return;
      }
    }
    final options = ProtectOptions(OneTimePassword(_password.text));
    setState(() {
      _password.clear();
      _confirm.clear();
      _showPassword = _showConfirm = false;
    });
    runTool(context, ref, ref.read(protectOperationProvider), [file], options);
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool shown,
    required VoidCallback onToggle,
    FocusNode? focus,
    String? error,
  }) {
    final l = context.l10n;
    return TextField(
      key: key,
      controller: controller,
      focusNode: focus,
      obscureText: !shown,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofillHints: null,
      keyboardType: shown ? TextInputType.visiblePassword : TextInputType.text,
      inputFormatters: [LengthLimitingTextInputFormatter(maxPasswordChars + 1)],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: shown ? l.prtHide : l.prtShow,
          icon: Icon(shown ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const tool = ProtectScreen.tool;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final file = inputs.single;
    final valid = file?.status.isValid == true;
    final protection = valid ? ref.watch(pdfProtectionProvider(file!.path)) : null;
    final locked = file?.status.error == AppErrorCode.encryptedDocument ||
        switch (protection) { AsyncData(:final value) => value != PdfProtection.none, _ => false };
    final checked = protection is AsyncData;

    final pw = _password.text, confirm = _confirm.text;
    final problem = passwordProblem(pw, confirm);
    final pwError = pw.isEmpty
        ? null
        : switch (problem) {
            PasswordProblem.tooShort => l.prtErrShort,
            PasswordProblem.tooLong => l.prtErrLong,
            PasswordProblem.tooManyBytes => l.prtErrBytes,
            _ => null,
          };
    final confirmError = confirm.isNotEmpty && problem == PasswordProblem.mismatch ? l.prtErrMismatch : null;
    final strength = passwordStrength(pw);
    final canRun = valid && checked && !locked && problem == null && !inputs.picking;

    return ToolScaffold(
      title: l.toolPdfProtectTitle,
      hasWork: file != null,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.prtRun,
        icon: Icons.lock_rounded,
        helper: file == null ? l.pickPdf : null,
        onPressed: canRun ? _run : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: Icons.lock_rounded,
            accent: context.docu.secureAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
        if (locked) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(
            kind: BannerKind.warning,
            text: l.prtAlready,
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => context.push(toolById(ToolId.pdfUnlock).route),
                child: Text(l.encUnlockAction),
              ),
            ],
          ),
        ],
      ],
      secondary: [
        const SizedBox(height: Space.x2),
        _field(
          key: const ValueKey('prt-password'),
          controller: _password,
          focus: _passwordFocus,
          label: l.prtPassword,
          shown: _showPassword,
          onToggle: () => setState(() => _showPassword = !_showPassword),
          error: pwError,
        ),
        if (pw.isNotEmpty) ...[
          const SizedBox(height: Space.x2),
          _StrengthMeter(strength: strength),
        ],
        const SizedBox(height: Space.x4),
        _field(
          key: const ValueKey('prt-confirm'),
          controller: _confirm,
          label: l.prtConfirm,
          shown: _showConfirm,
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
          error: confirmError,
        ),
        const SizedBox(height: Space.x4),
        // FR-PRT-04: always visible, above the button.
        InlineBanner(kind: BannerKind.warning, text: l.prtNoRecover),
      ],
    );
  }
}

/// Three bars + the word: colour is never the only signal.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});
  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (filled, word, colour) = switch (strength) {
      PasswordStrength.weak => (1, l.prtStrengthWeak, context.colors.error),
      PasswordStrength.ok => (2, l.prtStrengthOk, context.docu.warning),
      PasswordStrength.strong => (3, l.prtStrengthStrong, context.docu.success),
    };
    return Semantics(
      label: '${l.prtStrength}: $word',
      excludeSemantics: true,
      child: Row(children: [
        Text(l.prtStrength, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(width: Space.x3),
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 28,
            height: 6,
            decoration: BoxDecoration(
              color: i < filled ? colour : context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
          const SizedBox(width: Space.x1),
        ],
        const SizedBox(width: Space.x2),
        Flexible(child: Text(word, style: context.text.labelLarge?.copyWith(color: colour))),
      ]),
    );
  }
}
