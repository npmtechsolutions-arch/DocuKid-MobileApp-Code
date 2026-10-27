import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/resize_math.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/options.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/resize_controller.dart';
import '../application/resize_operation.dart';

const _percentChips = [25, 50, 75, 150, 200];

String presetLabel(AppLocalizations l, BuiltInPreset p) => switch (p) {
      BuiltInPreset.passport => l.resPresetPassport,
      BuiltInPreset.signature => l.resPresetSignature,
      BuiltInPreset.square => l.resPresetSquare,
      BuiltInPreset.story => l.resPresetStory,
      BuiltInPreset.hd => l.resPresetHd,
      BuiltInPreset.fullHd => l.resPresetFullhd,
    };

/// S04 · Image Resizer.
class ResizeScreen extends ConsumerStatefulWidget {
  const ResizeScreen({super.key});

  @override
  ConsumerState<ResizeScreen> createState() => _ResizeScreenState();
}

class _ResizeScreenState extends ConsumerState<ResizeScreen> {
  static const tool = ToolId.imageResize;
  final _w = TextEditingController();
  final _h = TextEditingController();
  final _wFocus = FocusNode();
  final _hFocus = FocusNode();

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _wFocus.dispose();
    _hFocus.dispose();
    super.dispose();
  }

  void _sync(ResizeOptions o) {
    final ws = o.width?.toString() ?? '';
    final hs = o.height?.toString() ?? '';
    if (!_wFocus.hasFocus && _w.text != ws) _w.text = ws;
    if (!_hFocus.hasFocus && _h.text != hs) _h.text = hs;
    // The non-focused side follows the locked ratio while typing.
    if (_wFocus.hasFocus && _h.text != hs) _h.text = hs;
    if (_hFocus.hasFocus && _w.text != ws) _w.text = ws;
  }

  String? _dimsError(AppLocalizations l, DimsError? e) => switch (e) {
        DimsError.range => l.resErrRange,
        DimsError.megapixels => l.resErrMegapixels,
        null => null,
      };

  Future<void> _savePreset(int w, int h) async {
    final l = context.l10n;
    final ctrl = TextEditingController();
    final name = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.resSavePreset),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(labelText: l.resPresetNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l.actionSave),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final ok = await ref.read(resizeOptionsProvider.notifier).savePreset(name, w, h);
    if (!ok && mounted) showAppSnack(context, l.resPresetLimit);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final o = ref.watch(resizeOptionsProvider);
    final c = ref.read(resizeOptionsProvider.notifier);
    final custom = ref.watch(settingsProvider.select((s) => s.resizeCustomPresets));
    final engine = ref.watch(imageEngineProvider);
    final file = inputs.single;
    final meta = file?.status.isValid == true ? file!.image : null;
    final ow = meta?.width ?? 0, oh = meta?.height ?? 0;

    ref.listen(toolInputsProvider(tool).select((s) => s.single?.image), (_, m) {
      if (m != null) c.seedFrom(m.width, m.height);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(ref.read(resizeOptionsProvider));
    });

    final dims = meta == null ? null : o.dimsFor(ow, oh);
    // Field errors only once there's an image (the fields are disabled before).
    final wErr = meta != null && o.mode == ResizeMode.pixels ? validateSide(o.width) : null;
    final hErr = meta != null && o.mode == ResizeMode.pixels ? validateSide(o.height) : null;
    final dimsErr = dims == null ? DimsError.range : validateDims(dims.$1, dims.$2);
    final shapeChanges = dims != null && meta != null && ratioDiffers(dims.$1, dims.$2, ow, oh);
    final upscale = dims != null && meta != null && isUpscale(dims.$1, dims.$2, ow, oh);
    final resolved = file == null ? null : resolveOutputFormat(o.format, file.type, heicSupported: engine.canEncode(ImageFormat.heic));
    final canRun = meta != null && dimsErr == null && !inputs.picking;

    String? helper;
    if (file == null) {
      helper = l.pickImage;
    } else if (meta == null) {
      helper = l.chooseAnother;
    } else if (dimsErr != null) {
      helper = _dimsError(l, dimsErr);
    } else {
      helper = l.resResultLine(dims!.$1, dims.$2);
    }

    final sizeSection = <Widget>[
      OptionsCard(icon: Icons.straighten_rounded, title: l.resSectionSize, children: [
        ChoiceSegments<ResizeMode>(
          value: o.mode,
          options: [
            (ResizeMode.pixels, l.resModePixels),
            (ResizeMode.percent, l.resModePercent),
            (ResizeMode.preset, l.resModePreset),
          ],
          onChanged: (m) => c.set(o.copyWith(mode: m)),
        ),
        const SizedBox(height: Space.x4),
        if (o.mode == ResizeMode.pixels) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _w,
                focusNode: _wFocus,
                enabled: meta != null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                decoration: InputDecoration(labelText: l.resWidth, suffixText: l.resUnitPx, errorText: _dimsError(l, wErr), errorMaxLines: 3),
                onChanged: (t) => c.setWidth(int.tryParse(t), ow, oh),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: Space.x1),
              child: IconButton.filledTonal(
                tooltip: o.lockRatio ? l.resLockOn : l.resLockOff,
                isSelected: o.lockRatio,
                onPressed: meta == null ? null : () => c.toggleLock(ow, oh),
                icon: Icon(o.lockRatio ? Icons.link_rounded : Icons.link_off_rounded),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _h,
                focusNode: _hFocus,
                enabled: meta != null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                decoration: InputDecoration(labelText: l.resHeight, suffixText: l.resUnitPx, errorText: _dimsError(l, hErr), errorMaxLines: 3),
                onChanged: (t) => c.setHeight(int.tryParse(t), ow, oh),
              ),
            ),
          ]),
          if (meta != null) ...[
            const SizedBox(height: Space.x2),
            Text(l.resOriginal(ow, oh), style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
          if (wErr == null && hErr == null && dimsErr == DimsError.megapixels) ...[
            const SizedBox(height: Space.x2),
            Text(l.resErrMegapixels, style: context.text.bodySmall?.copyWith(color: context.colors.error)),
          ],
        ],
        if (o.mode == ResizeMode.percent) ...[
          OptionGroup(
            title: l.resScale,
            trailing: Text(l.resPercentValue(o.percent), style: context.text.titleMedium),
            child: Slider(
              value: o.percent.toDouble(),
              min: 1,
              max: 400,
              divisions: 399,
              label: l.resPercentValue(o.percent),
              onChanged: meta == null ? null : (v) => c.set(o.copyWith(percent: v.round())),
            ),
          ),
          Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
            for (final p in _percentChips)
              ChoiceChip(
                label: Text(l.resPercentValue(p)),
                selected: o.percent == p,
                onSelected: meta == null ? null : (_) => c.set(o.copyWith(percent: p)),
              ),
          ]),
        ],
        if (o.mode == ResizeMode.preset)
          Card.filled(
            margin: EdgeInsets.zero,
            child: Column(children: [
              for (final p in BuiltInPreset.values)
                _PresetTile(
                  label: presetLabel(l, p),
                  w: p.width,
                  h: p.height,
                  selected: o.preset == p.name,
                  onTap: meta == null ? null : () => c.choosePreset(p.name, p.width, p.height, ow, oh),
                ),
              if (custom.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.x4, Space.x2, Space.x4, 0),
                  child: SectionHeader(l.resMyPresets, top: 0),
                ),
                for (final cp in custom)
                  _PresetTile(
                    label: cp.name,
                    w: cp.width,
                    h: cp.height,
                    selected: o.preset == 'custom:${cp.name}',
                    onTap: meta == null ? null : () => c.choosePreset('custom:${cp.name}', cp.width, cp.height, ow, oh),
                    onDelete: () => c.deletePreset(cp),
                  ),
              ],
            ]),
          ),
        if (dims != null && dimsErr == null && o.mode != ResizeMode.preset && custom.length < 10)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _savePreset(dims.$1, dims.$2),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l.resSavePreset),
            ),
          ),
      ]),
      if (upscale) ...[
        const SizedBox(height: Space.x3),
        InlineBanner(kind: BannerKind.warning, text: l.resUpscaleWarning),
      ],
      if (shapeChanges) ...[
        OptionsCard(icon: Icons.crop_rounded, title: l.resShapeHeader, children: [
          ChoiceSegments<FitMode>(
            value: o.fit,
            options: [
              (FitMode.stretch, l.resFitStretch),
              (FitMode.contain, l.resFitContain),
              (FitMode.cover, l.resFitCover),
            ],
            onChanged: (f) => c.set(o.copyWith(fit: f)),
          ),
          if (o.fit == FitMode.contain) ...[
            const SizedBox(height: Space.x3),
            Text(l.resPadColor, style: context.text.titleSmall),
            const SizedBox(height: Space.x2),
            Wrap(spacing: Space.x2, children: [
              ChoiceChip(label: Text(l.resPadWhite), selected: o.pad == PadColor.white, onSelected: (_) => c.set(o.copyWith(pad: PadColor.white))),
              ChoiceChip(label: Text(l.resPadBlack), selected: o.pad == PadColor.black, onSelected: (_) => c.set(o.copyWith(pad: PadColor.black))),
              if (resolved?.supportsAlpha ?? false)
                ChoiceChip(
                  label: Text(l.resPadTransparent),
                  selected: o.pad == PadColor.transparent,
                  onSelected: (_) => c.set(o.copyWith(pad: PadColor.transparent)),
                ),
            ]),
          ],
          const SizedBox(height: Space.x4),
          Center(child: _ShapePreview(file: file!, w: dims.$1, h: dims.$2, origW: ow, origH: oh, fit: o.fit, pad: o.pad)),
        ]),
      ],
    ];

    final more = Card(
      margin: const EdgeInsets.only(top: Space.x4),
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
                dropdownMenuEntries: [
                  DropdownMenuEntry(value: OutputFormatChoice.same, label: l.cmpFormatSame),
                  DropdownMenuEntry(value: OutputFormatChoice.jpeg, label: l.fmtJpeg),
                  DropdownMenuEntry(value: OutputFormatChoice.png, label: l.fmtPng),
                  DropdownMenuEntry(value: OutputFormatChoice.webp, label: l.fmtWebp),
                  if (engine.canEncode(ImageFormat.heic)) DropdownMenuEntry(value: OutputFormatChoice.heic, label: l.fmtHeic),
                ],
                onSelected: (v) => c.set(o.copyWith(format: v)),
              ),
            ),
            if (resolved?.usesQuality ?? true)
              OptionGroup(title: l.resQuality, child: QualitySlider(value: o.quality, onChanged: (v) => c.set(o.copyWith(quality: v)))),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.cmpStripMeta),
              value: o.stripMetadata,
              onChanged: (v) => c.set(o.copyWith(stripMetadata: v)),
            ),
          ],
        ),
      ),
    );

    return ToolScaffold(
      title: l.toolImageResizeTitle,
      info: l.infoImageResize,
      hasWork: !inputs.isEmpty,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.resRun,
        icon: Icons.aspect_ratio_rounded,
        helper: helper,
        onPressed: canRun ? () => runTool(context, ref, ref.read(resizeOperationProvider), [file!], o) : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickImage,
            formats: l.pickFormatsImages,
            icon: Icons.add_photo_alternate_rounded,
            accent: context.docu.imageAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
        LargeFileHint(bytes: inputs.totalBytes),
      ],
      secondary: [...sizeSection, more],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.label, required this.w, required this.h, required this.selected, this.onTap, this.onDelete});
  final String label;
  final int w, h;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
          color: selected ? context.colors.primary : null),
      title: Text(label),
      subtitle: Text('${l.metaDims(w, h)} ${l.resUnitPx}'),
      trailing: onDelete == null
          ? _RatioGlyph(w: w, h: h)
          : IconButton(tooltip: l.resDeletePreset, icon: const Icon(Icons.delete_outline_rounded), onPressed: onDelete),
    );
  }
}

class _RatioGlyph extends StatelessWidget {
  const _RatioGlyph({required this.w, required this.h});
  final int w, h;

  @override
  Widget build(BuildContext context) {
    final r = w / h;
    final bw = r >= 1 ? 28.0 : 28 * r, bh = r >= 1 ? 28 / r : 28.0;
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: Container(
          width: bw,
          height: bh,
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.onSurfaceVariant, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// Live mini-preview of the result shape (S04 ③).
class _ShapePreview extends StatelessWidget {
  const _ShapePreview({
    required this.file,
    required this.w,
    required this.h,
    required this.origW,
    required this.origH,
    required this.fit,
    required this.pad,
  });
  final PickedFile file;
  final int w, h, origW, origH;
  final FitMode fit;
  final PadColor pad;

  @override
  Widget build(BuildContext context) {
    const box = 160.0;
    final r = w / h;
    final pw = r >= 1 ? box : box * r, ph = r >= 1 ? box / r : box;
    final rect = fitRect(fit, 1000, (1000 / r).round(), origW, origH);
    final sx = pw / 1000, sy = ph / (1000 / r).round();
    final bg = switch (pad) {
      PadColor.white => Colors.white,
      PadColor.black => Colors.black,
      PadColor.transparent => Colors.transparent,
    };
    return Semantics(
      label: context.l10n.resResultLine(w, h),
      child: Container(
        width: pw,
        height: ph,
        decoration: BoxDecoration(border: Border.all(color: context.colors.outlineVariant)),
        clipBehavior: Clip.hardEdge,
        child: Checkerboard(
          child: Container(
            color: fit == FitMode.contain ? bg : null,
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned(
                left: rect.left * sx,
                top: rect.top * sy,
                width: rect.width * sx,
                height: rect.height * sy,
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.fill,
                  cacheWidth: 320,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
