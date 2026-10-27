import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/formatting/bytes_format.dart';
import '../../../core/image/image_options.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/compress_controller.dart';
import '../application/compress_operation.dart';

const _maxEdges = [null, 4096, 2048, 1600, 1280, 1080];
const _quickTargets = [50 * 1024, 100 * 1024, 200 * 1024, 500 * 1024, 1024 * 1024];

/// S03 · Image Compressor.
class CompressScreen extends ConsumerStatefulWidget {
  const CompressScreen({super.key});

  @override
  ConsumerState<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends ConsumerState<CompressScreen> {
  static const tool = ToolId.imageCompress;
  late final TextEditingController _target;
  bool _targetInMb = false;

  @override
  void initState() {
    super.initState();
    final o = ref.read(compressOptionsProvider);
    _targetInMb = o.targetBytes >= 1024 * 1024 && o.targetBytes % (1024 * 1024) == 0;
    _target = TextEditingController(text: '${_targetInMb ? o.targetBytes ~/ (1024 * 1024) : o.targetBytes ~/ 1024}');
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _setTarget(int bytes) {
    final c = ref.read(compressOptionsProvider.notifier);
    c.set(ref.read(compressOptionsProvider).copyWith(targetBytes: bytes));
  }

  void _onTargetText() {
    final v = int.tryParse(_target.text) ?? 0;
    _setTarget(v * (_targetInMb ? 1024 * 1024 : 1024));
  }

  void _quick(int bytes) {
    setState(() {
      _targetInMb = bytes >= 1024 * 1024;
      _target.text = '${_targetInMb ? bytes ~/ (1024 * 1024) : bytes ~/ 1024}';
    });
    _setTarget(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final ctrl = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(compressOptionsProvider);
    final set = ref.read(compressOptionsProvider.notifier).set;
    final engine = ref.watch(imageEngineProvider);
    final file = inputs.single;
    final accent = context.docu.imageAccent;

    final resolved = file == null ? null : compressFormatFor(o, file, engine);
    final pngNoQuality = o.mode == CompressMode.quality && resolved == ImageFormat.png;
    final alphaLost = file?.image?.hasAlpha == true && resolved != null && !resolved.supportsAlpha;
    final targetTooSmall = o.mode == CompressMode.targetSize && o.targetBytes < Limits.targetMinBytes;
    final alreadyUnder = o.mode == CompressMode.targetSize && file != null && file.sizeBytes <= o.targetBytes;
    final valid = file != null && file.status.isValid;
    final canRun = valid && !targetTooSmall && !inputs.picking;

    String? helper;
    if (file == null) {
      helper = l.pickImage;
    } else if (!valid) {
      helper = l.chooseAnother;
    } else if (targetTooSmall) {
      helper = l.cmpTargetMin;
    } else if (alreadyUnder) {
      helper = l.cmpTargetAlreadySmaller(formatBytes(o.targetBytes));
    }

    final formats = <(OutputFormatChoice, String)>[
      (OutputFormatChoice.same, l.cmpFormatSame),
      (OutputFormatChoice.jpeg, l.fmtJpeg),
      (OutputFormatChoice.png, l.fmtPng),
      (OutputFormatChoice.webp, l.fmtWebp),
      if (engine.canEncode(ImageFormat.heic)) (OutputFormatChoice.heic, l.fmtHeic),
    ];

    return ToolScaffold(
      title: l.toolImageCompressTitle,
      info: l.infoImageCompress,
      hasWork: !inputs.isEmpty,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: alreadyUnder ? l.cmpRunAnyway : l.cmpRun,
        icon: Icons.compress_rounded,
        helper: helper,
        onPressed: canRun ? () => runTool(context, ref, ref.read(compressOperationProvider), [file], o) : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickImage,
            formats: l.pickFormatsImages,
            icon: Icons.add_photo_alternate_rounded,
            accent: accent,
            loading: inputs.picking,
            onTap: () => ctrl.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => ctrl.pick(replace: true)),
        LargeFileHint(bytes: inputs.totalBytes),
      ],
      secondary: [
        OptionsCard(icon: Icons.tune_rounded, title: l.cmpSectionHow, children: [
          ChoiceSegments<CompressMode>(
            value: o.mode,
            options: [(CompressMode.quality, l.cmpModeQuality), (CompressMode.targetSize, l.cmpModeTarget)],
            onChanged: (m) => set(o.copyWith(mode: m)),
          ),
          const SizedBox(height: Space.x4),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.medium),
            child: o.mode == CompressMode.quality
                ? QualitySlider(key: const ValueKey('q'), value: o.quality, onChanged: (v) => set(o.copyWith(quality: v)))
                : Column(
                    key: const ValueKey('t'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _target,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                            decoration: InputDecoration(
                              labelText: l.cmpTargetLabel,
                              errorText: targetTooSmall ? l.cmpTargetMin : null,
                            ),
                            onChanged: (_) => _onTargetText(),
                          ),
                        ),
                        const SizedBox(width: Space.x3),
                        DropdownMenu<bool>(
                          width: 112,
                          initialSelection: _targetInMb,
                          dropdownMenuEntries: [
                            DropdownMenuEntry(value: false, label: l.cmpUnitKb),
                            DropdownMenuEntry(value: true, label: l.cmpUnitMb),
                          ],
                          onSelected: (v) {
                            setState(() => _targetInMb = v ?? false);
                            _onTargetText();
                          },
                        ),
                      ]),
                      const SizedBox(height: Space.x3),
                      Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
                        for (final b in _quickTargets)
                          ChoiceChip(label: Text(formatBytes(b)), selected: o.targetBytes == b, onSelected: (_) => _quick(b)),
                      ]),
                      if (o.format == OutputFormatChoice.png) ...[
                        const SizedBox(height: Space.x3),
                        InlineBanner(kind: BannerKind.info, text: l.cmpTargetUsesJpeg),
                      ],
                    ],
                  ),
          ),
        ]),
        if (pngNoQuality) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(
            kind: BannerKind.warning,
            text: l.cmpPngWarning,
            actions: [
              TextButton(onPressed: () => set(o.copyWith(format: OutputFormatChoice.jpeg)), child: Text(l.cmpSwitchJpeg)),
            ],
          ),
        ],
        if (alphaLost) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.warning, text: l.warnAlphaLost),
        ],
        const SizedBox(height: Space.x4),
        Card(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(l.cmpMoreOptions, style: context.text.titleMedium),
              leading: const Icon(Icons.tune_rounded),
              childrenPadding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x4),
              children: [
                OptionGroup(
                  title: l.cmpFormat,
                  child: DropdownMenu<OutputFormatChoice>(
                    expandedInsets: EdgeInsets.zero,
                    initialSelection: o.format,
                    dropdownMenuEntries: [for (final (v, t) in formats) DropdownMenuEntry(value: v, label: t)],
                    onSelected: (v) => set(o.copyWith(format: v)),
                  ),
                ),
                OptionGroup(
                  title: l.cmpMaxSize,
                  child: DropdownMenu<int?>(
                    expandedInsets: EdgeInsets.zero,
                    initialSelection: o.maxLongEdge,
                    dropdownMenuEntries: [
                      for (final e in _maxEdges) DropdownMenuEntry(value: e, label: e == null ? l.cmpMaxOriginal : l.cmpMaxPx(e)),
                    ],
                    onSelected: (v) => set(o.copyWith(maxLongEdge: () => v)),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.cmpStripMeta),
                  value: o.stripMetadata,
                  onChanged: (v) => set(o.copyWith(stripMetadata: v)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
