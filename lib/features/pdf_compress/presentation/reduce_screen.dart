import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/reduce_operation.dart';

/// S08 · PDF Size Reducer.
class ReduceScreen extends ConsumerWidget {
  const ReduceScreen({super.key});
  static const tool = ToolId.pdfCompress;

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final o = ref.read(reduceOptionsProvider);
    final file = ref.read(toolInputsProvider(tool)).single!;
    if (o.level == ReduceLevel.strong) {
      final ok = await askAdaptive(
        context,
        title: l.strongConfirmTitle,
        body: l.strongConfirmBody,
        no: l.actionCancel,
        yes: l.strongConfirmOk,
      );
      if (!ok || !context.mounted) return;
    }
    runTool(context, ref, ref.read(reduceOperationProvider), [file], o);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(reduceOptionsProvider);
    final set = ref.read(reduceOptionsProvider.notifier).set;
    final file = inputs.single;
    final valid = file?.status.isValid == true;
    final analysis = valid ? ref.watch(pdfAnalysisProvider((file!.path, file.sizeBytes))) : null;

    Widget level(ReduceLevel v, String t, String d, IconData icon, {bool recommended = false}) {
      final selected = o.level == v;
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => set(v),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(
              color: selected ? context.colors.primaryContainer.withValues(alpha: 0.55) : context.colors.surfaceContainer,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: selected ? context.colors.primary : Colors.transparent, width: 2),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? context.colors.primary : context.colors.onSurfaceVariant),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: Space.x2, runSpacing: Space.x1, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(t, style: context.text.titleMedium),
                    if (recommended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
                        decoration: BoxDecoration(color: context.docu.successContainer, borderRadius: BorderRadius.circular(Radii.full)),
                        child: Text(l.redRecommended, style: context.text.labelSmall?.copyWith(color: context.docu.success)),
                      ),
                  ]),
                  const SizedBox(height: Space.x1),
                  Text(d, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(width: Space.x2),
              Icon(icon, color: context.colors.onSurfaceVariant),
            ]),
          ),
        ),
      );
    }

    return ToolScaffold(
      title: l.toolPdfCompressTitle,
      info: l.infoPdfCompress,
      hasWork: file != null,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.redRun,
        icon: Icons.compress_rounded,
        helper: file == null ? l.pickPdf : (!valid ? l.chooseAnother : null),
        onPressed: valid && !inputs.picking ? () => _run(context, ref) : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: Icons.folder_zip_rounded,
            accent: context.docu.pdfAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(
            file: file,
            onChange: () => pick.pick(replace: true),
            extra: !valid
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: Space.x1),
                    child: switch (analysis) {
                      AsyncData(:final value) => Row(children: [
                          Icon(value.imageHeavy ? Icons.image_outlined : Icons.text_snippet_outlined,
                              size: 16, color: context.colors.primary),
                          const SizedBox(width: Space.x1),
                          Flexible(
                            child: Text(
                              l.redAnalysis(value.pageCount, value.imageCount, value.imageHeavy ? l.redKindImage : l.redKindText),
                              style: context.text.bodySmall?.copyWith(color: context.colors.primary),
                            ),
                          ),
                        ]),
                      AsyncLoading() => Text(l.redAnalysing, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                      _ => const SizedBox.shrink(),
                    },
                  ),
          ),
        LargeFileHint(bytes: inputs.totalBytes),
      ],
      secondary: [
        SectionHeader(l.redSectionLevel),
        level(ReduceLevel.basic, l.redBasicT, l.redBasicD, Icons.cleaning_services_outlined),
        const SizedBox(height: Space.x2),
        level(ReduceLevel.balanced, l.redBalancedT, l.redBalancedD, Icons.photo_size_select_large_rounded, recommended: true),
        const SizedBox(height: Space.x2),
        level(ReduceLevel.strong, l.redStrongT, l.redStrongD, Icons.image_rounded),
        const SizedBox(height: Space.x4),
        if (o.level == ReduceLevel.balanced) ...[
          InlineBanner(kind: BannerKind.warning, text: l.redBalancedWarning),
          const SizedBox(height: Space.x3),
        ],
        InlineBanner(kind: BannerKind.info, text: l.redNote),
      ],
    );
  }
}
