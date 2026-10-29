import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/tool_scaffold.dart';
import '../search/tool_catalog.dart';
import '../tools/tool_common.dart';
import '../tools/tool_inputs.dart';

/// The Secure & Sign tools' screen until each one's own screen lands
/// (RELEASE_V1_4: S37 Protect in T11.3, S38 Unlock in T11.4, S33 Sign in
/// T11.7, S36 Watermark in T11.8): the tool's title, the PDF picker and its
/// run button, which stays disabled. The router replaces it per tool.
class SecureToolShell extends ConsumerWidget {
  const SecureToolShell({super.key, required this.tool});
  final ToolId tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final d = toolById(tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final file = inputs.single;
    final (label, icon) = switch (tool) {
      ToolId.pdfSign => (l.sigPlaceCta, Icons.draw_rounded),
      ToolId.pdfWatermark => (l.wmkRun, Icons.branding_watermark_rounded),
      ToolId.pdfProtect => (l.prtRun, Icons.lock_rounded),
      _ => (l.unlRun, Icons.lock_open_rounded),
    };
    return ToolScaffold(
      title: d.title(l),
      hasWork: file != null,
      banner: RestoredBanner(tool: tool),
      action: PrimaryActionBar(label: label, icon: icon, helper: file == null ? l.pickPdf : null, onPressed: null),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: d.icon,
            accent: accentFor(context, d.category),
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
      ],
    );
  }
}
