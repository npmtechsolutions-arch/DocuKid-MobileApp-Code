import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/print/print_composer.dart';
import '../../../core/print/print_gateway.dart';
import '../../../core/print/print_settings.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pdf_thumbnail.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../application/print_preview_controller.dart';
import 'print_help_sheet.dart';
import 'print_options.dart';

/// S48 · Print preview (RELEASE_PRINT §3): every sheet as it will print,
/// the options, and the hand-off to the system dialog. Bottom banner with the
/// gap (ToolScaffold); no interstitial after printing (§3.5); no D4 on Back —
/// nothing is lost, the settings are remembered.
class PrintPreviewScreen extends ConsumerStatefulWidget {
  const PrintPreviewScreen({super.key});

  @override
  ConsumerState<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends ConsumerState<PrintPreviewScreen> {
  final _pages = PageController();
  final _range = TextEditingController();
  final _printButton = GlobalKey();
  var _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    _range.dispose();
    super.dispose();
  }

  /// The iPad popover anchor: the Print button, in global coordinates.
  Rect? _origin() {
    final box = _printButton.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _goTo(int i) {
    setState(() => _index = i);
    if (_pages.hasClients) {
      _pages.animateToPage(i, duration: Motion.of(context, const Duration(milliseconds: 250)), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = printPreviewProvider(l.rangeEndWord);
    final st = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.outcome), (_, next) {
      // FR-PRN-12: "Sent to printer"; a cancel says nothing; a failure is a banner.
      if (next == PrintOutcome.sent) showAppSnack(context, l.prnSent);
    });
    final request = st.request;
    final out = st.output;
    if (out != null && _index >= out.sheetCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(math.max(0, out.sheetCount - 1));
      });
    }
    final sizes = request != null && request.isPdf && !request.locked ? visualPageSizes(ref, request.files.first) : null;
    final overflows =
        request != null && actualSizeOverflows(request, st.settings, sizes, endWords: {'end', l.rangeEndWord});

    Future<void> print() => ctl.print(origin: _origin());

    final PrimaryActionBar action;
    if (!st.available && request != null) {
      // §4.4: printing switched off (iOS profiles) → Share instead.
      action = PrimaryActionBar(
        key: _printButton,
        label: l.actionShare,
        icon: Icons.ios_share_rounded,
        helper: l.prnUnavailable,
        onPressed: () => ref.read(fileGatewayProvider).share(
              [for (final f in request.files) f.path],
              mime: request.isPdf ? 'application/pdf' : 'image/*',
              origin: _origin(),
            ),
      );
    } else {
      action = PrimaryActionBar(
        key: _printButton,
        label: l.prnPrintBtn(st.sheetCount),
        icon: Icons.print_rounded,
        helper: st.locked
            ? l.prnLocked
            : st.rangeError != null
                ? l.prnFixRange
                : st.noPages
                    ? l.prnNoPages
                    : null,
        onPressed: st.canPrint ? print : null,
      );
    }

    return ToolScaffold(
      title: l.prnPreviewTitle,
      actions: [
        IconButton(
          tooltip: l.prnHelpTitle,
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () => showPrintHelp(context),
        ),
      ],
      action: action,
      primary: [
        const SizedBox(height: Space.x3),
        if (st.locked)
          InlineBanner(kind: BannerKind.error, text: l.prnLocked)
        else if (out != null) ...[
          _SheetView(
            output: out,
            margins: _showsMargins(st) ? st.settings.margins : PrintMargins.none,
            controller: _pages,
            building: st.building,
            progress: st.progress == null ? null : (st.progress!.done, st.progress!.total),
            onCancel: ctl.cancelBuild,
            onPage: (i) => setState(() => _index = i),
          ),
          const SizedBox(height: Space.x2),
          Center(
            child: Semantics(
              liveRegion: true,
              child: Text(l.prnSheetOf(math.min(_index + 1, out.sheetCount), out.sheetCount),
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
          ),
          const SizedBox(height: Space.x2),
          _ThumbStrip(output: out, selected: _index, onTap: _goTo),
        ] else if (st.building)
          SizedBox(
            height: 240,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                if (st.progress case final pr?) ...[
                  const SizedBox(height: Space.x3),
                  Text(l.prnBuilding(math.min(pr.done + 1, pr.total), pr.total)),
                ],
              ]),
            ),
          ),
        if (st.noPages) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.warning, text: l.prnNoPages),
        ],
        if (st.buildFailed) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(
            kind: BannerKind.error,
            text: l.prnBuildFailed,
            actions: [TextButton(onPressed: ctl.retry, child: Text(l.actionTryAgain))],
          ),
        ],
        if (st.outcome == PrintOutcome.failed) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(
            key: const ValueKey('prn-failed'),
            kind: BannerKind.error,
            text: l.prnFailed,
            actions: [
              TextButton(onPressed: () => showPrintHelp(context), child: Text(l.prnHelpTitle)),
              TextButton(onPressed: st.canPrint ? print : null, child: Text(l.actionTryAgain)),
            ],
          ),
        ],
      ],
      secondary: [
        PrintOptions(
          state: st,
          range: _range,
          actualOverflows: overflows,
          onChanged: ctl.update,
        ),
      ],
    );
  }

  /// The dashed margin line is drawn for page grids; the passport sheet's
  /// photos are centred inside the margins and show them themselves.
  static bool _showsMargins(PrintPreviewState st) =>
      !(st.request?.isPdf == false && st.settings.imageLayout == ImageLayout.passportSheet);
}

/// White sheets on grey, swipe between them, pinch to zoom; dimmed with a
/// progress ring and Cancel while a rebuild runs (the last good stays).
class _SheetView extends StatelessWidget {
  const _SheetView({
    required this.output,
    required this.margins,
    required this.controller,
    required this.building,
    required this.progress,
    required this.onCancel,
    required this.onPage,
  });

  final PrintOutput output;
  final PrintMargins margins;
  final PageController controller;
  final bool building;
  final (int, int)? progress;
  final VoidCallback onCancel;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        height: 380,
        color: context.colors.surfaceContainerHighest,
        child: Stack(children: [
          // R74: its own layer, so the spinner's animation never repaints the
          // sheets. (An Opacity here made every frame redraw them offscreen:
          // ~4× slower frames while building on the emulator.)
          RepaintBoundary(
            child: PageView.builder(
              key: const ValueKey('prn-sheets'),
              controller: controller,
              itemCount: output.sheetCount,
              onPageChanged: onPage,
              itemBuilder: (context, i) {
                final size = output.sheetSizesPt[i];
                return InteractiveViewer(
                  maxScale: 4,
                  child: LayoutBuilder(builder: (context, c) {
                    final aspect = size.width / size.height;
                    final width = math.min(c.maxWidth - 2 * Space.x4, (c.maxHeight - 2 * Space.x4) * aspect);
                    final inset = margins.pt * width / size.width;
                    return Center(
                      child: Semantics(
                        image: true,
                        label: l.prnSheetA11y(i + 1),
                        child: Stack(children: [
                          PdfThumbnail(path: output.path, pageIndex: i, width: width, aspect: aspect, elevated: true),
                          if (inset > 0)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(painter: _DashedInset(inset, context.colors.outline)),
                              ),
                            ),
                        ]),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          // Dimmed with a plain scrim (one rect), not an opacity layer.
          if (building) Positioned.fill(child: ColoredBox(color: context.colors.surfaceContainerHighest.withValues(alpha: 0.6))),
          if (building)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const RepaintBoundary(child: CircularProgressIndicator()),
                if (progress case (final done, final total)) ...[
                  const SizedBox(height: Space.x2),
                  Text(l.prnBuilding(math.min(done + 1, total), total), style: context.text.bodyMedium),
                ],
                TextButton(key: const ValueKey('prn-cancel-build'), onPressed: onCancel, child: Text(l.actionCancel)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _DashedInset extends CustomPainter {
  const _DashedInset(this.inset, this.color);
  final double inset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final r = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    const dash = 4.0, gap = 3.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, len), paint);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedInset old) => old.inset != inset || old.color != color;
}

/// Lazy thumbnail strip; tap to jump to a sheet.
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.output, required this.selected, required this.onTap});
  final PrintOutput output;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        key: const ValueKey('prn-thumbs'),
        scrollDirection: Axis.horizontal,
        itemCount: output.sheetCount,
        separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
        itemBuilder: (context, i) {
          final size = output.sheetSizesPt[i];
          final aspect = size.width / size.height;
          return Semantics(
            button: true,
            selected: i == selected,
            label: l.prnSheetA11y(i + 1),
            child: InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(Radii.sm),
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(
                    color: i == selected ? context.colors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ExcludeSemantics(
                  child: PdfThumbnail(path: output.path, pageIndex: i, width: math.min(56, 76 * aspect), aspect: aspect),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
