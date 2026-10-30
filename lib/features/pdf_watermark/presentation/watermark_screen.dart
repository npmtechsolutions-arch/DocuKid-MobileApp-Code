import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/files/mime_sniffer.dart';
import '../../../core/files/png_size.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/pdf/text_stamp_renderer.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/pdf_thumbnail.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../secure/unlock_first.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/watermark_layout.dart';
import '../application/watermark_operation.dart';

/// FR-WMK-02: the six preset colours (the seventh chip is "custom").
const watermarkColours = [0xFFD32F2F, 0xFF212121, 0xFF757575, 0xFF1565C0, 0xFF2E7D32, 0xFFEF6C00];

/// S36 · Watermark PDF (RELEASE_V1_4 §3; FR-WMK-01…10). The preview uses the
/// same layout maths and the same kind of image as the job, so what you see
/// is where it lands (FR-WMK-09).
class WatermarkScreen extends ConsumerStatefulWidget {
  const WatermarkScreen({super.key});
  static const tool = ToolId.pdfWatermark;

  @override
  ConsumerState<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends ConsumerState<WatermarkScreen> {
  final _text = TextEditingController(text: 'CONFIDENTIAL');
  final _range = TextEditingController();
  final _pages = PageController();
  var _image = false;
  var _colour = watermarkColours.first;
  var _bold = true;
  var _position = WatermarkPosition.diagonal;
  var _size = defaultSizePct(image: false);
  var _opacity = defaultOpacityPct;
  var _rotation = defaultRotation(WatermarkPosition.diagonal);
  var _mode = PageMode.all;
  var _busy = false;

  // The text rendered for the preview, and the picked logo (PNG).
  String? _textPng;
  double _textAspect = 4;
  var _textVersion = 0;
  String? _logoPng;
  double _logoAspect = 1;

  static const tool = WatermarkScreen.tool;

  @override
  void initState() {
    super.initState();
    final saved = WatermarkTextStyle.fromJson(ref.read(settingsRepositoryProvider).readWatermarkStyle());
    if (saved != null) {
      _text.text = saved.text;
      _colour = saved.colour;
      _bold = saved.bold;
      _position = saved.position;
      _size = saved.sizePct;
      _opacity = saved.opacityPct;
      _rotation = saved.rotation;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _renderPreviewText());
  }

  @override
  void dispose() {
    _text.dispose();
    _range.dispose();
    _pages.dispose();
    super.dispose();
  }

  Directory get _dir => Directory(
      p.join(ref.read(appPathsProvider).jobDir(ref.read(toolInputsProvider(tool)).draftId).path, 'wmk'));

  /// FR-WMK-07: re-rendered on each text/colour/bold change (≈ 10–30 ms).
  Future<void> _renderPreviewText() async {
    final text = _text.text.trim();
    final v = ++_textVersion;
    if (text.isEmpty) {
      setState(() => _textPng = null);
      return;
    }
    await _dir.create(recursive: true);
    final r = await renderTextPng(text,
        outPath: p.join(_dir.path, 'preview_$v.png'), colour: Color(_colour), heightPt: 40, bold: _bold, dpi: 150);
    if (!mounted || v != _textVersion) return;
    final old = _textPng;
    setState(() {
      _textPng = r.pngPath;
      _textAspect = r.widthPt / r.heightPt;
    });
    if (old != null) unawaitedDelete(old);
  }

  void unawaitedDelete(String path) => File(path).delete().ignore();

  Future<void> _pickLogo() async {
    final r = await ref.read(fileGatewayProvider).pickImages(draftId: ref.read(toolInputsProvider(tool)).draftId, max: 1);
    final f = r.files.where((f) => f.status.isValid).firstOrNull;
    if (f == null || !mounted) return;
    setState(() => _busy = true);
    await _dir.create(recursive: true);
    final out = p.join(_dir.path, 'logo_${const Uuid().v4()}.png');
    if (f.type == SniffedType.png) {
      // A PNG keeps its transparency as it is (FR-WMK-03).
      await File(f.path).copy(out);
    } else {
      await ref.read(imageEngineProvider).transform(
          f.path, out, const ImageTransform(format: ImageFormat.png, maxLongEdge: 2400));
    }
    final size = pngSize(out);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logoPng = size == null ? null : out;
      _logoAspect = size == null ? 1 : size.$1 / size.$2;
    });
  }

  void _setPosition(WatermarkPosition v) => setState(() {
        _position = v;
        _rotation = defaultRotation(v);
      });

  void _setKind(bool image) => setState(() {
        _image = image;
        _size = defaultSizePct(image: image);
      });

  Future<void> _customColour() async {
    final l = context.l10n;
    var hue = HSVColor.fromColor(Color(_colour)).hue;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final c = HSVColor.fromAHSV(1, hue, 0.8, 0.75).toColor();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x4),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.wmkCustomColour, style: ctx.text.titleLarge),
              const SizedBox(height: Space.x3),
              Container(height: 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(Radii.md))),
              Slider(
                value: hue,
                max: 359,
                semanticFormatterCallback: (v) => '${l.wmkCustomColour} ${v.round()}°',
                onChanged: (v) => set(() => hue = v),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(ctx, c.toARGB32()),
                child: Text(l.actionDone),
              ),
            ]),
          ),
        );
      }),
    );
    if (picked != null) {
      setState(() => _colour = picked);
      await _renderPreviewText();
    }
  }

  Future<void> _run(List<Size> sizes, List<int> pages) async {
    final file = ref.read(toolInputsProvider(tool)).single!;
    setState(() => _busy = true);
    String png;
    double aspect;
    if (_image) {
      (png, aspect) = (_logoPng!, _logoAspect);
    } else {
      // 300 dpi of the placed height on the first stamped page (§4.2).
      final first = watermarkLayout(sizes[pages.first], _textAspect, position: _position, sizePct: _size, rotation: _rotation).first;
      await _dir.create(recursive: true);
      final r = await renderTextPng(_text.text.trim(),
          outPath: p.join(_dir.path, 'text_${const Uuid().v4()}.png'), colour: Color(_colour), heightPt: first.rect.height, bold: _bold);
      (png, aspect) = (r.pngPath, r.widthPt / r.heightPt);
      await ref.read(settingsRepositoryProvider).writeWatermarkStyle(WatermarkTextStyle(
              text: _text.text.trim(),
              colour: _colour,
              bold: _bold,
              position: _position,
              sizePct: _size,
              opacityPct: _opacity,
              rotation: _rotation)
          .toJson());
    }
    if (!mounted) return;
    setState(() => _busy = false);
    runTool(
      context,
      ref,
      ref.read(watermarkOperationProvider),
      [file],
      WatermarkOptions(
        pngPath: png,
        aspect: aspect,
        image: _image,
        position: _position,
        sizePct: _size,
        opacityPct: _opacity,
        rotation: _rotation,
        pageMode: _mode,
        pages: pages,
        pageSizes: sizes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final file = inputs.single;
    final valid = file?.status.isValid == true;
    final sizes = valid ? visualPageSizes(ref, file!) : null;
    final count = sizes?.length ?? 0;
    final pages = count == 0 ? null : selectPages(_mode, _range.text, count, endWords: {'end', l.rangeEndWord});
    final rangeError = _mode == PageMode.range && _range.text.isNotEmpty && pages == null ? l.wmkRangeError : null;
    final png = _image ? _logoPng : _textPng;
    final aspect = _image ? _logoAspect : _textAspect;
    final needText = !_image && _text.text.trim().isEmpty;

    String? helper;
    if (file == null) {
      helper = l.pickPdf;
    } else if (needText) {
      helper = l.wmkNeedText;
    } else if (_image && _logoPng == null) {
      helper = l.wmkChooseImage;
    }
    final canRun = valid && sizes != null && pages != null && pages.isNotEmpty && png != null && !needText && !_busy && !inputs.picking;

    String posLabel(WatermarkPosition v) => switch (v) {
          WatermarkPosition.diagonal => l.wmkPosDiagonal,
          WatermarkPosition.centre => l.wmkPosCentre,
          WatermarkPosition.tile => l.wmkPosTile,
          WatermarkPosition.topLeft => l.wmkPosTl,
          WatermarkPosition.topRight => l.wmkPosTr,
          WatermarkPosition.bottomLeft => l.wmkPosBl,
          WatermarkPosition.bottomRight => l.wmkPosBr,
        };

    Widget slider(String label, String value, double v, double min, double max, ValueChanged<double> onChanged, {int? divisions}) =>
        Row(children: [
          SizedBox(width: 88, child: Text(label, style: context.text.bodyMedium)),
          Expanded(
            child: Slider(
              value: v.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: value,
              semanticFormatterCallback: (_) => '$label $value',
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 48, child: Text(value, textAlign: TextAlign.end, style: context.text.labelLarge)),
        ]);

    Widget preview() {
      if (sizes == null) return const SizedBox.shrink();
      return SizedBox(
        height: 300,
        child: PageView.builder(
          key: const ValueKey('wmk-preview'),
          controller: _pages,
          itemCount: count,
          itemBuilder: (context, i) => Semantics(
            label: l.wmkPreviewA11y(i + 1),
            child: LayoutBuilder(builder: (context, c) {
              final s = sizes[i];
              final scale = math.min(c.maxWidth / s.width, (c.maxHeight - 20) / s.height);
              final stamps = png == null || pages == null || !pages.contains(i)
                  ? const <WatermarkStamp>[]
                  : watermarkLayout(s, aspect, position: _position, sizePct: _size, rotation: _rotation);
              return Column(children: [
                SizedBox(
                  width: s.width * scale,
                  height: s.height * scale,
                  child: ClipRect(
                    child: Stack(children: [
                      Positioned.fill(child: PdfThumbnail(path: file!.path, pageIndex: i, width: s.width * scale, aspect: s.width / s.height)),
                      for (final (n, st) in stamps.indexed)
                        Positioned(
                          key: ValueKey('wmk-stamp-$n'),
                          left: st.rect.left * scale,
                          top: st.rect.top * scale,
                          width: st.rect.width * scale,
                          height: st.rect.height * scale,
                          child: Transform.rotate(
                            angle: st.rotation * math.pi / 180,
                            child: Opacity(
                              opacity: _opacity / 100,
                              child: Image.file(File(png!), fit: BoxFit.fill, gaplessPlayback: true),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(l.sigPageN(i + 1), style: context.text.labelSmall),
              ]);
            }),
          ),
        ),
      );
    }

    return ToolScaffold(
      title: l.toolPdfWatermarkTitle,
      info: l.wmkNotSearchable,
      hasWork: file != null,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.wmkRun,
        icon: Icons.branding_watermark_rounded,
        helper: helper,
        onPressed: canRun ? () => _run(sizes, pages) : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: Icons.branding_watermark_rounded,
            accent: context.docu.secureAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
        if (file != null && isLockedPdf(file)) UnlockFirstBanner(tool: tool, file: file),
        if (valid) ...[
          const SizedBox(height: Space.x3),
          preview(),
        ],
      ],
      secondary: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.wmkText), icon: const Icon(Icons.text_fields_rounded)),
            ButtonSegment(value: true, label: Text(l.wmkImage), icon: const Icon(Icons.image_outlined)),
          ],
          selected: {_image},
          onSelectionChanged: (s) => _setKind(s.first),
        ),
        const SizedBox(height: Space.x3),
        if (!_image) ...[
          TextField(
            key: const ValueKey('wmk-text'),
            controller: _text,
            maxLength: maxWatermarkChars,
            decoration: InputDecoration(labelText: l.wmkTextHint, border: const OutlineInputBorder()),
            onChanged: (_) => _renderPreviewText(),
          ),
          Wrap(spacing: Space.x1, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(l.sigColour, style: context.text.bodyMedium),
            for (final (c, name) in [
              (watermarkColours[0], l.wmkColourRed),
              (watermarkColours[1], l.wmkColourBlack),
              (watermarkColours[2], l.wmkColourGrey),
              (watermarkColours[3], l.wmkColourBlue),
              (watermarkColours[4], l.wmkColourGreen),
              (watermarkColours[5], l.wmkColourOrange),
            ])
              Semantics(
                selected: _colour == c,
                button: true,
                label: name,
                excludeSemantics: true,
                child: InkResponse(
                  radius: 24,
                  onTap: () {
                    setState(() => _colour = c);
                    _renderPreviewText();
                  },
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: _colour == c ? context.colors.primary : Colors.transparent, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: l.wmkCustomColour,
              icon: Icon(Icons.palette_outlined,
                  color: watermarkColours.contains(_colour) ? null : Color(_colour)),
              onPressed: _customColour,
            ),
            FilterChip(
              label: Text(l.wmkBold),
              selected: _bold,
              onSelected: (v) {
                setState(() => _bold = v);
                _renderPreviewText();
              },
            ),
          ]),
        ] else if (_logoPng == null)
          PickerDropCard(
            label: l.wmkChooseImage,
            formats: l.pickFormatsImages,
            icon: Icons.image_outlined,
            accent: context.docu.secureAccent,
            loading: _busy,
            onTap: _pickLogo,
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 64,
              height: 48,
              child: Checkerboard(child: Image.file(File(_logoPng!), fit: BoxFit.contain)),
            ),
            title: Text(l.wmkImage),
            trailing: TextButton(onPressed: _pickLogo, child: Text(l.actionChange)),
          ),
        const SizedBox(height: Space.x3),
        DropdownButtonFormField<WatermarkPosition>(
          key: const ValueKey('wmk-position'),
          initialValue: _position,
          decoration: InputDecoration(labelText: l.wmkPosition, border: const OutlineInputBorder()),
          items: [for (final v in WatermarkPosition.values) DropdownMenuItem(value: v, child: Text(posLabel(v)))],
          onChanged: (v) {
            if (v != null) _setPosition(v);
          },
        ),
        const SizedBox(height: Space.x2),
        slider(l.wmkSize, '$_size%', _size.toDouble(), minSizePct.toDouble(), maxSizePct.toDouble(),
            (v) => setState(() => _size = v.round()), divisions: maxSizePct - minSizePct),
        slider(l.wmkOpacity, '$_opacity%', _opacity.toDouble(), minOpacityPct.toDouble(), maxOpacityPct.toDouble(),
            (v) => setState(() => _opacity = v.round()), divisions: maxOpacityPct - minOpacityPct),
        slider(l.wmkRotation, '${_rotation.round()}°', _rotation, -90, 90, (v) => setState(() => _rotation = v.roundToDouble()),
            divisions: 180),
        const SizedBox(height: Space.x2),
        Text(l.wmkPages, style: context.text.titleSmall),
        const SizedBox(height: Space.x1),
        Wrap(spacing: Space.x2, children: [
          for (final (m, label) in [
            (PageMode.all, l.wmkPagesAll),
            (PageMode.range, l.wmkPagesRange),
            (PageMode.odd, l.wmkPagesOdd),
            (PageMode.even, l.wmkPagesEven),
          ])
            ChoiceChip(label: Text(label), selected: _mode == m, onSelected: (_) => setState(() => _mode = m)),
        ]),
        if (_mode == PageMode.range) ...[
          const SizedBox(height: Space.x2),
          TextField(
            key: const ValueKey('wmk-range'),
            controller: _range,
            decoration: InputDecoration(hintText: l.wmkRangeHint, errorText: rangeError, border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: Space.x3),
        // FR-WMK-08: on top only.
        InlineBanner(kind: BannerKind.info, text: l.wmkOnTop),
      ],
    );
  }
}
