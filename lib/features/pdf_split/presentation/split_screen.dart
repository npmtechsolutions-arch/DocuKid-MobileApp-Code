import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../search/tool_catalog.dart';
import '../../secure/unlock_first.dart';
import '../../tools/range_text.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/split_controller.dart';
import '../application/split_operation.dart';

/// "pages 1–3 · page 5 · pages 8–10", the first few parts only.
String rangePartsText(AppLocalizations l, List<List<int>> groups, {int max = 6}) {
  String part(List<int> g) =>
      g.length == 1 ? l.splPartPage(g.first + 1) : l.splPartPages(g.first + 1, g.last + 1);
  final shown = [for (final g in groups.take(max)) part(g)];
  return groups.length > max ? '${shown.join(' · ')} · …' : shown.join(' · ');
}

/// S24 · Split PDF (RELEASE_V1_1 §3): one PDF → several (S22 result).
class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key});

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> {
  static const tool = ToolId.pdfSplit;
  late final TextEditingController _ranges;

  @override
  void initState() {
    super.initState();
    _ranges = TextEditingController(text: ref.read(splitOptionsProvider).ranges);
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
    final o = ref.watch(splitOptionsProvider);
    final set = ref.read(splitOptionsProvider.notifier).set;
    final file = inputs.single;
    final valid = file != null && file.status.isValid;
    final pages = valid ? file.pdf?.pageCount ?? 0 : 0;
    final endWords = {'end', l.rangeEndWord};
    final plan = valid ? splitGroups(o, pages, endWords: endWords) : null;
    final groups = plan?.groups;
    final n = pages < 2 ? 2 : o.everyN.clamp(minEveryN(pages), pages - 1);

    String? fieldError;
    if (plan?.rangeError case final e? when o.ranges.trim().isNotEmpty) fieldError = rangeErrorText(l, e, pages);

    String? helper;
    if (file == null) {
      helper = l.pickPdf;
    } else if (!valid) {
      helper = l.chooseAnother;
    } else if (plan?.error == SplitError.onePage) {
      helper = l.splOnePage;
    } else if (plan?.error == SplitError.eachCap) {
      helper = l.splEachCap;
    } else if (plan?.rangeError case final e?) {
      helper = rangeErrorText(l, e, pages);
    }

    final preview = switch ((o.mode, groups)) {
      (_, null) => null,
      (SplitMode.ranges, final g?) => l.splPreviewFiles(g.length, rangePartsText(l, g)),
      (SplitMode.everyN, final g?) => l.splEveryPreview(g.length, g.last.length),
      (SplitMode.each, final g?) => l.splEachPreview(g.length),
    };

    return ToolScaffold(
      title: l.toolPdfSplitTitle,
      hasWork: !inputs.isEmpty,
      banner: const RestoredBanner(tool: tool),
      action: file != null && isLockedPdf(file)
          ? unlockFirstAction(context, ref, tool, file)
          : PrimaryActionBar(
        label: l.splRun(groups?.length ?? 0),
        icon: Icons.call_split_rounded,
        helper: helper,
        onPressed: groups == null || inputs.picking
            ? null
            : () => runMultiTool(context, ref, ref.read(splitOperationProvider(l.rangeEndWord)), [file!], o),
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
        if (plan?.error == SplitError.onePage) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.info, text: l.splOnePage),
        ],
      ],
      secondary: [
        OptionsCard(icon: Icons.call_split_rounded, title: l.splHow, children: [
          ChoiceSegments<SplitMode>(
            value: o.mode,
            options: [
              (SplitMode.ranges, l.splModeRanges),
              (SplitMode.everyN, l.splModeEvery),
              (SplitMode.each, l.splModeEach),
            ],
            onChanged: (m) => set(o.copyWith(mode: m)),
          ),
          const SizedBox(height: Space.x4),
          switch (o.mode) {
            SplitMode.ranges => TextField(
                key: const ValueKey('split-ranges'),
                controller: _ranges,
                enabled: valid && pages > 1,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                // Digits, commas, dashes, spaces, and letters for "end".
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\- \t\p{L}]', unicode: true))],
                decoration: InputDecoration(
                  labelText: l.splModeRanges,
                  helperText: l.splRangesHint,
                  helperMaxLines: 2,
                  errorText: fieldError,
                  errorMaxLines: 3,
                ),
                onChanged: (t) => set(o.copyWith(ranges: t)),
              ),
            SplitMode.everyN => Row(children: [
                Expanded(child: Text(l.splEveryLabel, style: context.text.titleSmall)),
                IconButton.filledTonal(
                  tooltip: l.splEveryLess,
                  onPressed: valid && n > minEveryN(pages) ? () => set(o.copyWith(everyN: n - 1)) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 56,
                  child: Text('$n', textAlign: TextAlign.center, style: context.text.titleLarge),
                ),
                IconButton.filledTonal(
                  tooltip: l.splEveryMore,
                  onPressed: valid && n < pages - 1 ? () => set(o.copyWith(everyN: n + 1)) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ]),
            SplitMode.each => const SizedBox.shrink(),
          },
          if (preview != null) ...[
            const SizedBox(height: Space.x3),
            Semantics(
              liveRegion: true,
              child: Text(preview, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
          ],
          if (o.mode == SplitMode.each && plan?.error == SplitError.eachCap) ...[
            const SizedBox(height: Space.x3),
            InlineBanner(
              kind: BannerKind.warning,
              text: l.splEachCap,
              actions: [
                TextButton(onPressed: () => set(o.copyWith(mode: SplitMode.everyN)), child: Text(l.splModeEvery)),
              ],
            ),
          ],
        ]),
      ],
    );
  }
}
