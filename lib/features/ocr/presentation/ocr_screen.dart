import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ocr/ocr_labels.dart';
import '../../../core/ocr/text_recognizer.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/batch_inputs.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/ocr_operation.dart';
import '../application/ocr_options_controller.dart';
import '../application/ocr_screen_model.dart';
import '../application/text_detection.dart';

/// The scripts this build can recognise, in [OcrScript] order (ADR-045).
final ocrScriptsProvider = FutureProvider.autoDispose<List<OcrScript>>((ref) async {
  final r = ref.watch(textRecognizerFactoryProvider)();
  try {
    final available = await r.availableScripts();
    return [for (final s in OcrScript.values) if (available.contains(s)) s];
  } finally {
    await r.dispose();
  }
});

/// S30 · Text Recognition (RELEASE_V1_3 §3.1): 1–50 images or one PDF →
/// searchable PDF, review text and/or `.txt`. Tools bottom banner with the
/// 24 dp gap (ToolScaffold, ADR-035).
class OcrScreen extends ConsumerWidget {
  const OcrScreen({super.key});
  static const tool = ToolId.ocr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(ocrOptionsProvider);
    final set = ref.read(ocrOptionsProvider.notifier).set;
    final file = inputs.single;
    final checkPdf = inputs.files.length == 1 && file!.isPdf && file.status.isValid;
    final textPages = checkPdf ? ref.watch(pdfTextPagesProvider(file.path)) : null;
    final m = ocrScreenModel(files: inputs.files, textPages: textPages, options: o);
    final scripts = ref.watch(ocrScriptsProvider).value ?? const [OcrScript.latin];
    final script = scripts.contains(o.script) ? o.script : OcrScript.latin;
    final accent = accentFor(context, ToolCategory.scan);

    final helper = switch (m.helper) {
      OcrHelper.pick => l.ocrPickHint,
      OcrHelper.mixed => l.ocrMixRefused,
      OcrHelper.chooseAnother => l.chooseAnother,
      OcrHelper.chooseOutput => l.ocrNeedOutput,
      null => null,
    };

    Widget output(String label, bool value, ValueChanged<bool> onChanged, {bool enabled = true, String? subtitle}) =>
        CheckboxListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value,
          onChanged: enabled ? (v) => onChanged(v ?? false) : null,
        );

    return ToolScaffold(
      title: l.toolOcrTitle,
      hasWork: !inputs.isEmpty,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: m.getText ? l.ocrRunGetText : l.ocrRun(m.pagesToRecognise),
        icon: Icons.text_fields_rounded,
        helper: helper,
        onPressed: m.canRun && !inputs.picking
            ? () => runCompositeTool(context, ref, ref.read(ocrOperationProvider), m.runInputs, m.effective.copyWith(script: script))
            : null,
      ),
      primary: [
        if (m.kind == OcrInputKind.images && inputs.files.length > 1)
          const BatchInputs(tool: tool)
        else ...[
          SectionHeader(l.inputsFileHeader),
          if (file == null) ...[
            PickerDropCard(
              label: l.ocrPickImages,
              formats: l.pickFormatsImages,
              icon: Icons.add_photo_alternate_rounded,
              accent: accent,
              loading: inputs.picking,
              onTap: () => pick.pick(as: InputKind.images),
            ),
            const SizedBox(height: Space.x2),
            PickerDropCard(
              label: l.ocrPickPdf,
              formats: l.pickFormatsPdf,
              icon: Icons.picture_as_pdf_rounded,
              accent: accent,
              loading: inputs.picking,
              onTap: () => pick.pick(as: InputKind.singlePdf),
            ),
            const SizedBox(height: Space.x2),
            Text(l.ocrPickHint, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ] else if (m.kind == OcrInputKind.mixed)
            InlineBanner(
              kind: BannerKind.warning,
              text: l.ocrMixRefused,
              actions: [TextButton(onPressed: pick.clear, child: Text(l.draftStartOver))],
            )
          else
            SingleFileCard(
              file: file,
              onChange: () => pick.pick(replace: true, as: file.isPdf ? InputKind.singlePdf : InputKind.images),
              onAdd: file.isPdf || inputs.picking ? null : () => pick.pick(as: InputKind.images),
              extra: m.kind == OcrInputKind.pdf && file.status.isValid ? _TextBadge(model: m) : null,
            ),
        ],
        if (m.text != null && m.text!.withText > 0) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(
            kind: BannerKind.info,
            text: m.getText ? l.ocrPdfHasText : l.ocrPdfPartial(m.text!.withText, m.text!.total),
          ),
        ],
        if (m.showRebuildNote) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.info, text: l.ocrPdfRebuildNote),
        ],
        if (m.showLongJob) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.info, text: l.ocrLongJob),
        ],
        LargeFileHint(bytes: inputs.totalBytes),
      ],
      secondary: [
        OptionsCard(icon: Icons.checklist_rounded, title: l.ocrResultsHeader, children: [
          output(
            l.ocrOutPdf,
            m.effective.searchablePdf,
            (v) => set(o.copyWith(searchablePdf: v)),
            enabled: !m.pdfOutputDisabled,
            subtitle: m.pdfOutputDisabled ? l.ocrOutPdfDisabled : null,
          ),
          output(l.ocrOutReview, o.review, (v) => set(o.copyWith(review: v))),
          output(l.ocrOutTxt, o.txt, (v) => set(o.copyWith(txt: v))),
        ]),
        const SizedBox(height: Space.x3),
        OptionsCard(icon: Icons.translate_rounded, title: l.ocrLanguage, children: [
          LayoutBuilder(
            builder: (context, c) => DropdownMenu<OcrScript>(
              width: c.maxWidth,
              initialSelection: script,
              label: Text(l.ocrLanguage),
              onSelected: (s) {
                if (s != null) set(o.copyWith(script: s));
              },
              dropdownMenuEntries: [
                for (final s in scripts) DropdownMenuEntry(value: s, label: ocrScriptLabel(l, s)),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

/// "Checking for text…" while §4.6 runs, then the PDF's text badge.
class _TextBadge extends StatelessWidget {
  const _TextBadge({required this.model});
  final OcrScreenModel model;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    final text = model.text;
    return Padding(
      padding: const EdgeInsets.only(top: Space.x1),
      child: Row(children: [
        if (model.checkingText)
          const SizedBox.square(dimension: 14, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
        else
          Icon(text?.withText == 0 ? Icons.text_snippet_outlined : Icons.manage_search_rounded,
              size: 16, color: context.colors.primary),
        const SizedBox(width: Space.x1),
        Flexible(
          child: Text(
            model.checkingText ? l.ocrCheckingText : (text == null ? '' : ocrTextBadge(l, text)),
            style: model.checkingText ? style : style?.copyWith(color: context.colors.primary),
          ),
        ),
      ]),
    );
  }
}
