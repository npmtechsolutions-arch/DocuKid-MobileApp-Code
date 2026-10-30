import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/pdf/text_stamp_renderer.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_inputs.dart';
import '../application/ink.dart';
import '../application/photo_signature.dart';
import '../application/signature_models.dart';
import '../application/signature_providers.dart';

/// FR-SIG-03: the bundled handwriting fonts (ADR-067).
const signatureFonts = ['DancingScript', 'Sacramento', 'MrDafoe'];

/// S34 · Signature creator (RELEASE_V1_4 §3, §4.7; FR-SIG-02/03/04/10): full
/// screen, **no ads**. Done → a transparent PNG in the Sign tool's draft
/// folder (deleted with the draft) → "Save for next time?" → pops a
/// [CreatedSignature].
class SignatureCreatorScreen extends ConsumerStatefulWidget {
  const SignatureCreatorScreen({super.key, required this.mode});
  final SignatureKind mode;

  static SignatureKind modeOf(String? q) =>
      SignatureKind.values.firstWhere((k) => k.name == q, orElse: () => SignatureKind.draw);

  @override
  ConsumerState<SignatureCreatorScreen> createState() => _SignatureCreatorScreenState();
}

class _SignatureCreatorScreenState extends ConsumerState<SignatureCreatorScreen> {
  // Draw.
  final _strokes = <InkStroke>[];
  List<Offset>? _current;
  var _colour = InkColour.black;
  var _thickness = InkThickness.medium;
  // Type.
  final _name = TextEditingController();
  var _font = 0;
  var _typeColour = InkColour.black;
  // Photo.
  String? _jpeg;
  Uint8List? _preview;
  var _cleanup = defaultCleanup;
  var _noInk = false;
  var _previewVersion = 0;

  var _busy = false;

  @override
  void initState() {
    super.initState();
    final (c, t) = ref.read(settingsRepositoryProvider).readInkStyle();
    _colour = InkColour.values.firstWhere((v) => v.name == c, orElse: () => InkColour.black);
    _thickness = InkThickness.values.firstWhere((v) => v.name == t, orElse: () => InkThickness.medium);
    _typeColour = _colour;
    if (widget.mode == SignatureKind.photo) WidgetsBinding.instance.addPostFrameCallback((_) => _pickPhoto());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Directory get _workDir {
    final draft = ref.read(toolInputsProvider(ToolId.pdfSign)).draftId;
    return Directory(p.join(ref.read(appPathsProvider).jobDir(draft).path, 'sig'));
  }

  bool get _dirty => switch (widget.mode) {
        SignatureKind.draw => _strokes.isNotEmpty,
        SignatureKind.type => _name.text.trim().isNotEmpty,
        SignatureKind.photo => _jpeg != null,
      };

  bool get _canFinish =>
      !_busy &&
      switch (widget.mode) {
        SignatureKind.draw => _strokes.isNotEmpty,
        SignatureKind.type => _name.text.trim().isNotEmpty,
        SignatureKind.photo => _preview != null && !_noInk,
      };

  void _saveInkStyle() =>
      ref.read(settingsRepositoryProvider).writeInkStyle(_colour.name, _thickness.name);

  // ---------------------------------------------------------------- photo

  Future<void> _pickPhoto() async {
    final draft = ref.read(toolInputsProvider(ToolId.pdfSign)).draftId;
    final r = await ref.read(fileGatewayProvider).pickImages(draftId: draft, max: 1);
    if (!mounted) return;
    final f = r.files.where((f) => f.status.isValid).firstOrNull;
    if (f == null) {
      if (context.canPop()) context.pop();
      return;
    }
    setState(() => _busy = true);
    final dir = _workDir;
    await dir.create(recursive: true);
    // The image engine applies EXIF orientation and reads HEIC; ≤ 2000 px (§4.7).
    final jpeg = p.join(dir.path, 'photo_${const Uuid().v4()}.jpg');
    await ref.read(imageEngineProvider).transform(
        f.path, jpeg, const ImageTransform(format: ImageFormat.jpeg, quality: 92, maxLongEdge: 2000));
    _jpeg = jpeg;
    await _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    final jpeg = _jpeg;
    if (jpeg == null) return;
    final version = ++_previewVersion;
    setState(() => _busy = true);
    final out = p.join(_workDir.path, 'preview.png');
    final r = await cleanSignaturePhoto(jpeg, out, cleanup: _cleanup, maxEdge: 700);
    if (!mounted || version != _previewVersion) return;
    final bytes = r == null ? null : await File(out).readAsBytes();
    if (!mounted || version != _previewVersion) return;
    setState(() {
      _busy = false;
      _noInk = r == null;
      _preview = bytes;
    });
  }

  // ---------------------------------------------------------------- done

  Future<void> _done() async {
    setState(() => _busy = true);
    final dir = _workDir;
    await dir.create(recursive: true);
    final out = p.join(dir.path, 'sig_${const Uuid().v4()}.png');
    int w, h;
    switch (widget.mode) {
      case SignatureKind.draw:
        final r = await exportInkPng(_strokes, colour: _colour, thickness: _thickness, outPath: out);
        (w, h) = (r.widthPx, r.heightPx);
      case SignatureKind.type:
        final r = await renderTextPng(_name.text.trim(),
            outPath: out, colour: _typeColour.color, heightPt: 60, fontFamily: signatureFonts[_font]);
        (w, h) = (r.widthPx, r.heightPx);
      case SignatureKind.photo:
        final r = await cleanSignaturePhoto(_jpeg!, out, cleanup: _cleanup);
        if (r == null) {
          setState(() {
            _busy = false;
            _noInk = true;
          });
          return;
        }
        (w, h) = r;
    }
    if (!mounted) return;
    final saved = ref.read(savedSignaturesProvider);
    final keep = await showSaveSignatureSheet(context, full: saved.length >= 3);
    String? savedId;
    if (keep) savedId = (await ref.read(savedSignaturesProvider.notifier).save(out, widget.mode)).id;
    if (!mounted) return;
    setState(() => _busy = false);
    context.pop(CreatedSignature(pngPath: out, kind: widget.mode, widthPx: w, heightPx: h, savedId: savedId));
  }

  Future<void> _confirmLeave() async {
    final l = context.l10n;
    final discard =
        await askAdaptive(context, title: l.sigDiscardTitle, no: l.actionCancel, yes: l.actionDiscard);
    if (discard && mounted) {
      setState(() {
        _strokes.clear();
        _name.clear();
        _jpeg = null;
      });
      if (context.canPop()) context.pop();
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Keeps the Sign tool's draft (where the PNG goes) alive while open.
    ref.watch(toolInputsProvider(ToolId.pdfSign).select((s) => s.draftId));
    final title = switch (widget.mode) {
      SignatureKind.draw => l.sigPadTitleDraw,
      SignatureKind.type => l.sigPadTitleType,
      SignatureKind.photo => l.sigPadTitlePhoto,
    };
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.actionClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(title),
          actions: widget.mode != SignatureKind.draw
              ? null
              : [
                  TextButton(
                    onPressed: _strokes.isEmpty ? null : () => setState(_strokes.removeLast),
                    child: Text(l.sigUndoStroke),
                  ),
                  TextButton(
                    onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
                    child: Text(l.sigClear),
                  ),
                ],
        ),
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: switch (widget.mode) {
                SignatureKind.draw => _drawBody(context),
                SignatureKind.type => _typeBody(context),
                SignatureKind.photo => _photoBody(context),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.x4, Space.x2, Space.x4, Space.x4),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _canFinish ? _done : null,
                child: Text(l.actionDone),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _colourPicker(InkColour value, ValueChanged<InkColour> onChanged) {
    final l = context.l10n;
    return Row(children: [
      Text(l.sigColour, style: context.text.bodyMedium),
      const SizedBox(width: Space.x2),
      for (final c in InkColour.values)
        Semantics(
          selected: value == c,
          button: true,
          label: c == InkColour.black ? l.sigBlack : l.sigBlue,
          excludeSemantics: true,
          child: InkResponse(
            radius: 24,
            onTap: () => onChanged(c),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: value == c ? context.colors.primary : Colors.transparent, width: 3),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _drawBody(BuildContext context) {
    final l = context.l10n;
    final portraitPhone = MediaQuery.orientationOf(context) == Orientation.portrait && MediaQuery.sizeOf(context).shortestSide < 600;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (portraitPhone)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Row(children: [
              const Icon(Icons.screen_rotation_rounded, size: 18),
              const SizedBox(width: Space.x2),
              Expanded(child: Text(l.sigPadLandscape, style: context.text.bodySmall)),
            ]),
          ),
        Expanded(
          child: Semantics(
            label: l.sigPadA11y,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                key: const ValueKey('sig-pad'),
                color: Colors.white,
                child: LayoutBuilder(builder: (context, c) {
                  Offset clamp(Offset o) => Offset(o.dx.clamp(0, c.maxWidth), o.dy.clamp(0, c.maxHeight));
                  return GestureDetector(
                    onPanStart: (d) => setState(() => _current = [clamp(d.localPosition)]),
                    onPanUpdate: (d) => setState(() => _current?.add(clamp(d.localPosition))),
                    onPanEnd: (_) => setState(() {
                      if (_current != null && _current!.isNotEmpty) _strokes.add(InkStroke(List.of(_current!)));
                      _current = null;
                    }),
                    onTapUp: (d) => setState(() => _strokes.add(InkStroke([clamp(d.localPosition)]))),
                    child: CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _InkPainter([..._strokes, if (_current != null) InkStroke(_current!)], _colour, _thickness,
                          hint: _strokes.isEmpty && _current == null ? l.sigPadHint : null,
                          hintStyle: context.text.bodyMedium?.copyWith(color: Colors.black45)),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.x2),
        Wrap(spacing: Space.x4, runSpacing: Space.x1, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _colourPicker(_colour, (c) {
            setState(() => _colour = c);
            _saveInkStyle();
          }),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(l.sigThickness, style: context.text.bodyMedium),
            const SizedBox(width: Space.x2),
            for (final t in InkThickness.values)
              Semantics(
                selected: _thickness == t,
                button: true,
                label: switch (t) {
                  InkThickness.thin => l.sigThin,
                  InkThickness.medium => l.sigMedium,
                  InkThickness.thick => l.sigThick,
                },
                excludeSemantics: true,
                child: InkResponse(
                  radius: 24,
                  onTap: () {
                    setState(() => _thickness = t);
                    _saveInkStyle();
                  },
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: t.width * 1.6,
                        decoration: BoxDecoration(
                          color: _thickness == t ? context.colors.primary : context.colors.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      ]),
    );
  }

  Widget _typeBody(BuildContext context) {
    final l = context.l10n;
    final name = _name.text.trim();
    return ListView(padding: const EdgeInsets.all(Space.x4), children: [
      TextField(
        key: const ValueKey('sig-name'),
        controller: _name,
        textCapitalization: TextCapitalization.words,
        autocorrect: false,
        decoration: InputDecoration(labelText: l.sigYourName, border: const OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Space.x3),
      for (var i = 0; i < signatureFonts.length; i++)
        Semantics(
          selected: _font == i,
          button: true,
          label: l.sigStyle(i + 1),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () => setState(() => _font = i),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(children: [
                Icon(_font == i ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: _font == i ? context.colors.primary : context.colors.onSurfaceVariant),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Text(
                    name.isEmpty ? l.sigYourName : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: signatureFonts[i], fontSize: 34, color: _typeColour.color),
                  ),
                ),
              ]),
            ),
          ),
        ),
      const SizedBox(height: Space.x3),
      _colourPicker(_typeColour, (c) => setState(() => _typeColour = c)),
    ]);
  }

  Widget _photoBody(BuildContext context) {
    final l = context.l10n;
    return ListView(padding: const EdgeInsets.all(Space.x4), children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: AspectRatio(
          aspectRatio: 2,
          child: Checkerboard(
            child: Center(
              child: _preview != null && !_noInk
                  ? Image.memory(_preview!, fit: BoxFit.contain, gaplessPlayback: true)
                  : (_busy ? const CircularProgressIndicator() : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
      if (_noInk) ...[
        const SizedBox(height: Space.x3),
        InlineBanner(kind: BannerKind.warning, text: l.sigPhotoNone),
      ],
      const SizedBox(height: Space.x4),
      Text(l.sigBgCleanup, style: context.text.titleSmall),
      Slider(
        value: _cleanup.toDouble(),
        max: 100,
        divisions: 100,
        label: '$_cleanup',
        semanticFormatterCallback: (v) => '${l.sigBgCleanup} ${v.round()}',
        onChanged: _jpeg == null ? null : (v) => setState(() => _cleanup = v.round()),
        onChangeEnd: (_) => _refreshPreview(),
      ),
    ]);
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.colour, this.thickness, {this.hint, this.hintStyle});
  final List<InkStroke> strokes;
  final InkColour colour;
  final InkThickness thickness;
  final String? hint;
  final TextStyle? hintStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * 0.72;
    canvas.drawLine(Offset(24, baseline), Offset(size.width - 24, baseline),
        Paint()
          ..color = Colors.black26
          ..strokeWidth = 1);
    if (hint != null) {
      final tp = TextPainter(text: TextSpan(text: hint, style: hintStyle), textDirection: TextDirection.ltr)
        ..layout(maxWidth: size.width - 48);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, baseline + 8));
    }
    final paint = inkPaint(colour, thickness.width);
    for (final s in strokes) {
      canvas.drawPath(smoothStrokePath(s.points), paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}

/// FR-SIG-10: default is **not** saved; at the limit, only "Not now".
Future<bool> showSaveSignatureSheet(BuildContext context, {required bool full}) async {
  final l = context.l10n;
  final r = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x5, 0, Space.x5, Space.x4),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.sigSaveAskTitle, style: ctx.text.titleLarge),
          const SizedBox(height: Space.x2),
          Text(full ? l.sigSavedLimit : l.sigSaveAskBody, style: ctx.text.bodyMedium),
          const SizedBox(height: Space.x4),
          if (!full)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.sigSaveYes),
            ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.sigSaveNo),
          ),
        ]),
      ),
    ),
  );
  return r ?? false;
}
