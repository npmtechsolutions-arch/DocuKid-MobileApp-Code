import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/image/image_options.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../search/tool_catalog.dart';
import '../../tools/batch_inputs.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/convert_controller.dart';
import '../application/convert_operation.dart';

String formatLabel(AppLocalizations l, ImageFormat f) => switch (f) {
      ImageFormat.jpeg => l.fmtJpeg,
      ImageFormat.png => l.fmtPng,
      ImageFormat.webp => l.fmtWebp,
      ImageFormat.heic => l.fmtHeic,
    };

/// S23 · Convert Image (RELEASE_V1_1 §3): one image (S11 result) or a batch
/// of 2–50 in the S21 grid (S22 result). Never resizes.
class ConvertScreen extends ConsumerWidget {
  const ConvertScreen({super.key});
  static const tool = ToolId.imageConvert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final ctrl = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(convertOptionsProvider);
    final set = ref.read(convertOptionsProvider.notifier).set;
    final engine = ref.watch(imageEngineProvider);
    final file = inputs.single;
    final batch = inputs.files.length > 1;
    final valids = inputs.valid;
    final formats = convertFormats(engine);
    final same = sameFormatCount(inputs.files, o.format);
    final canRun = valids.isNotEmpty && !inputs.picking;

    String? helper;
    if (file == null) {
      helper = l.pickImages;
    } else if (valids.isEmpty) {
      helper = batch ? l.batchNoneValid : l.chooseAnother;
    }

    return ToolScaffold(
      title: l.toolImageConvertTitle,
      hasWork: !inputs.isEmpty,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.batchRunConvert(batch ? valids.length : 1),
        icon: Icons.swap_horiz_rounded,
        helper: helper,
        onPressed: !canRun
            ? null
            : batch
                // Invalid images run as failed items, so the result lists them.
                ? () => runMultiTool(context, ref, ref.read(batchConvertOperationProvider), inputs.files, o)
                : () => runTool(context, ref, ref.read(convertOperationProvider), [file!], o),
      ),
      primary: [
        if (batch)
          const BatchInputs(tool: tool)
        else ...[
          SectionHeader(l.inputsFileHeader),
          if (file == null)
            PickerDropCard(
              label: l.pickImages,
              formats: l.pickFormatsImages,
              icon: Icons.add_photo_alternate_rounded,
              accent: context.docu.imageAccent,
              loading: inputs.picking,
              onTap: () => ctrl.pick(),
            )
          else
            SingleFileCard(
              file: file,
              onChange: () => ctrl.pick(replace: true),
              onAdd: inputs.picking ? null : () => ctrl.pick(),
            ),
        ],
        LargeFileHint(bytes: inputs.totalBytes),
      ],
      secondary: [
        OptionsCard(icon: Icons.swap_horiz_rounded, title: l.cnvTo, children: [
          Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
            for (final f in formats)
              ChoiceChip(
                label: Text(formatLabel(l, f)),
                selected: o.format == f,
                onSelected: (_) => set(o.copyWith(format: f)),
              ),
          ]),
          // FR-CNV-02: HEIC output is iPhone-only (ADR-060); say why it's missing.
          if (Platform.isAndroid && !formats.contains(ImageFormat.heic)) ...[
            const SizedBox(height: Space.x2),
            Text(l.cnvHeicIosOnly, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
          if (o.hasQuality) ...[
            const SizedBox(height: Space.x4),
            QualitySlider(value: o.quality, onChanged: (v) => set(o.copyWith(quality: v))),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.cmpStripMeta),
            value: o.stripMetadata,
            onChanged: (v) => set(o.copyWith(stripMetadata: v)),
          ),
        ]),
        if (alphaWillBeLost(inputs.files, o.format)) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.warning, text: l.warnAlphaLost),
        ],
        if (same > 0) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.info, text: l.cnvSameFormat(same, formatLabel(l, o.format))),
        ],
      ],
    );
  }
}
