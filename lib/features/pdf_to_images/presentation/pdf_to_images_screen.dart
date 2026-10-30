import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/image/image_options.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../secure/unlock_first.dart';
import '../../tools/range_text.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/pdf_to_images_controller.dart';
import '../application/pdf_to_images_operation.dart';

/// S25 · PDF to Images (RELEASE_V1_1 §3): one PDF → one image per page (S22).
class PdfToImagesScreen extends ConsumerStatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  ConsumerState<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends ConsumerState<PdfToImagesScreen> {
  static const tool = ToolId.pdfToImages;
  late final TextEditingController _ranges;

  @override
  void initState() {
    super.initState();
    _ranges = TextEditingController(text: ref.read(pdfToImagesOptionsProvider).ranges);
  }

  @override
  void dispose() {
    _ranges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(pdfToImagesOptionsProvider);
    final set = ref.read(pdfToImagesOptionsProvider.notifier).set;
    final file = inputs.single;
    final meta = file != null && file.status.isValid ? file.pdf : null;
    final pageCount = meta?.pageCount ?? 0;
    final sel = meta == null ? null : selectedPages(o, pageCount, endWords: {'end', l.rangeEndWord});
    final pages = sel?.pages;
    final sizesKnown = meta != null && meta.pageSizes.length == pageCount;

    // Live estimate from the first chosen page; the first page that would be
    // capped at 40 MP is named (FR-P2I-04).
    (int, int)? estimate;
    (int, int)? capped;
    if (pages != null && pages.isNotEmpty && sizesKnown) {
      final (w0, h0) = meta.pageSizes[pages.first - 1];
      final (ew, eh, _) = pagePixelSize(w0, h0, o.dpi);
      estimate = (ew, eh);
      for (final pg in pages) {
        final (w, h) = meta.pageSizes[pg - 1];
        final (cw, ch, c) = pagePixelSize(w, h, o.dpi);
        if (c) {
          capped = (pg, math.max(cw, ch));
          break;
        }
      }
    }

    String? fieldError;
    if (sel?.error case final e? when o.ranges.trim().isNotEmpty) fieldError = rangeErrorText(l, e, pageCount);

    String? helper;
    if (file == null) {
      helper = l.pickPdf;
    } else if (meta == null) {
      helper = l.chooseAnother;
    } else if (sel?.error case final e?) {
      helper = rangeErrorText(l, e, pageCount);
    }
    final canRun = pages != null && pages.isNotEmpty && sizesKnown && !inputs.picking;

    return ToolScaffold(
      title: l.toolPdfToImagesTitle,
      hasWork: !inputs.isEmpty,
      banner: const RestoredBanner(tool: tool),
      action: file != null && isLockedPdf(file)
          ? unlockFirstAction(context, ref, tool, file)
          : PrimaryActionBar(
        label: l.p2iRun(pages?.length ?? 0),
        icon: Icons.photo_library_rounded,
        helper: helper,
        onPressed: canRun ? () => runMultiTool(context, ref, ref.read(pdfToImagesOperationProvider(l.rangeEndWord)), [file!], o) : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: Icons.upload_file_rounded,
            accent: context.docu.pdfAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
      ],
      secondary: [
        OptionsCard(icon: Icons.description_outlined, title: l.fdPages, children: [
          ChoiceSegments<bool>(
            value: o.allPages,
            options: [(true, l.p2iPagesAll), (false, l.p2iPagesChoose)],
            onChanged: (all) => set(o.copyWith(allPages: all)),
          ),
          if (!o.allPages) ...[
            const SizedBox(height: Space.x3),
            TextField(
              key: const ValueKey('p2i-ranges'),
              controller: _ranges,
              enabled: meta != null,
              keyboardType: TextInputType.text,
              autocorrect: false,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\- \t\p{L}]', unicode: true))],
              decoration: InputDecoration(
                labelText: l.p2iPagesChoose,
                helperText: l.splRangesHint,
                helperMaxLines: 2,
                errorText: fieldError,
                errorMaxLines: 3,
              ),
              onChanged: (t) => set(o.copyWith(ranges: t)),
            ),
          ],
        ]),
        OptionsCard(icon: Icons.image_outlined, title: l.cmpFormat, children: [
          ChoiceSegments<ImageFormat>(
            value: o.format,
            options: [(ImageFormat.jpeg, l.fmtJpeg), (ImageFormat.png, l.fmtPng)],
            onChanged: (f) => set(o.copyWith(format: f)),
          ),
          if (o.format == ImageFormat.jpeg) ...[
            const SizedBox(height: Space.x4),
            QualitySlider(value: o.quality, onChanged: (v) => set(o.copyWith(quality: v))),
          ] else
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.p2iKeepTransparent),
              value: o.keepTransparent,
              onChanged: (v) => set(o.copyWith(keepTransparent: v)),
            ),
        ]),
        OptionsCard(icon: Icons.high_quality_outlined, title: l.p2iResolution, children: [
          ChoiceSegments<int>(
            value: o.dpi,
            options: [(72, '72 · ${l.p2iRes72}'), (150, '150 · ${l.p2iRes150}'), (300, '300 · ${l.p2iRes300}')],
            onChanged: (d) => set(o.copyWith(dpi: d)),
          ),
          if (estimate != null) ...[
            const SizedBox(height: Space.x3),
            Semantics(
              liveRegion: true,
              child: Text(l.p2iPxEstimate(estimate.$1, estimate.$2),
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
          ],
          if (capped != null) ...[
            const SizedBox(height: Space.x3),
            InlineBanner(kind: BannerKind.info, text: l.p2iPageCapped(capped.$1, capped.$2)),
          ],
        ]),
      ],
    );
  }
}
