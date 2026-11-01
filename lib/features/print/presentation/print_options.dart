import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/print/print_settings.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/options.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/print_preview_controller.dart';

String paperLabel(AppLocalizations l, PaperSize p) => switch (p) {
      PaperSize.a4 => l.prnPaperA4,
      PaperSize.letter => l.prnPaperLetter,
      PaperSize.legal => l.prnPaperLegal,
      PaperSize.a5 => l.prnPaperA5,
      PaperSize.in4x6 => l.prnPaper4x6,
      PaperSize.in5x7 => l.prnPaper5x7,
      PaperSize.sameAsDocument => l.prnPaperSame,
    };

/// S48 option cards (RELEASE_PRINT §3): Paper, Orientation, Pages (PDFs),
/// Pages per sheet (PDFs) or Layout (images), Scaling, Margins, and the note
/// that copies, colour and two-sided are set in the system dialog.
class PrintOptions extends StatelessWidget {
  const PrintOptions({
    super.key,
    required this.state,
    required this.onChanged,
    required this.range,
    required this.actualOverflows,
  });

  final PrintPreviewState state;
  final ValueChanged<PrintSettings> onChanged;
  final TextEditingController range;

  /// FR-PRN-07: show the Actual size warning.
  final bool actualOverflows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = state.settings;
    final request = state.request;
    final isPdf = request?.isPdf ?? true;
    final passport = !isPdf && s.imageLayout == ImageLayout.passportSheet;
    final enabled = request != null && !state.locked;

    void set(PrintSettings v) {
      if (enabled) onChanged(v);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OptionsCard(icon: Icons.description_outlined, title: l.prnPaper, children: [
        DropdownButtonFormField<PaperSize>(
          // Rebuilt when the paper changes elsewhere (the passport sheet sets 4 × 6 in).
          key: ValueKey('prn-paper-${s.paper.name}'),
          initialValue: s.paper,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: [for (final p in PaperSize.values) DropdownMenuItem(value: p, child: Text(paperLabel(l, p)))],
          onChanged: enabled ? (p) => set(s.copyWith(paper: p)) : null,
        ),
      ]),
      OptionsCard(icon: Icons.screen_rotation_alt_rounded, title: l.prnOrientation, children: [
        ChoiceSegments<PrintOrientation>(
          value: s.orientation,
          options: [
            (PrintOrientation.auto, l.prnOrientAuto),
            (PrintOrientation.portrait, l.prnOrientPortrait),
            (PrintOrientation.landscape, l.prnOrientLandscape),
          ],
          onChanged: (o) => set(s.copyWith(orientation: o)),
        ),
      ]),
      if (isPdf)
        OptionsCard(icon: Icons.filter_none_rounded, title: l.prnPages, children: [
          ChoiceSegments<PageSelectionMode>(
            value: s.pages.mode,
            options: [
              (PageSelectionMode.all, l.prnPagesAll),
              (PageSelectionMode.range, l.prnPagesRange),
              (PageSelectionMode.odd, l.prnPagesOdd),
              (PageSelectionMode.even, l.prnPagesEven),
            ],
            onChanged: (m) => set(s.copyWith(
              pages: switch (m) {
                PageSelectionMode.all => PageSelection.all,
                PageSelectionMode.odd => PageSelection.odd,
                PageSelectionMode.even => PageSelection.even,
                PageSelectionMode.range => PageSelection.range(range.text),
              },
            )),
          ),
          if (s.pages.mode == PageSelectionMode.range) ...[
            const SizedBox(height: Space.x3),
            TextField(
              key: const ValueKey('prn-range'),
              controller: range,
              enabled: enabled,
              autocorrect: false,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\- \t\p{L}]', unicode: true))],
              decoration: InputDecoration(
                labelText: l.prnPagesRange,
                hintText: l.prnRangeHint,
                errorText: state.rangeError == null ? null : l.prnRangeError,
              ),
              onChanged: (t) => set(s.copyWith(pages: PageSelection.range(t))),
            ),
          ],
        ]),
      if (isPdf)
        OptionsCard(icon: Icons.grid_view_rounded, title: l.prnPerSheet, children: [
          ChoiceSegments<int>(
            value: s.perSheet,
            options: [for (final n in perSheetOptions) (n, '$n')],
            onChanged: (n) => set(s.copyWith(perSheet: n)),
          ),
        ])
      else
        OptionsCard(icon: Icons.photo_library_outlined, title: l.prnLayout, children: [
          Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
            for (final (v, label) in [
              (ImageLayout.fullPage, l.prnLayoutFull),
              (ImageLayout.twoUp, l.prnLayoutTwo),
              (ImageLayout.fourUp, l.prnLayoutFour),
              (ImageLayout.passportSheet, l.prnLayoutPassport),
            ])
              ChoiceChip(
                label: Text(label),
                selected: s.imageLayout == v,
                onSelected: (_) => set(v == ImageLayout.passportSheet && s.imageLayout != v
                    // §3: the passport sheet starts on 4 × 6 in, no margins, actual size.
                    ? s.copyWith(
                        imageLayout: v,
                        paper: PaperSize.in4x6,
                        margins: PrintMargins.none,
                        scaling: PrintScaling.actual,
                      )
                    : s.copyWith(imageLayout: v)),
              ),
          ]),
          if (passport && request != null) ...[
            const SizedBox(height: Space.x3),
            Semantics(
              liveRegion: true,
              child: Text(
                l.prnPassportCount(passportPhotoCount(request, s), paperLabel(l, s.paper)),
                key: const ValueKey('prn-passport-count'),
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          ],
        ]),
      if (!passport)
        OptionsCard(icon: Icons.fit_screen_rounded, title: l.prnScaling, children: [
          ChoiceSegments<PrintScaling>(
            value: s.scaling,
            options: [
              (PrintScaling.fit, l.prnScaleFit),
              (PrintScaling.actual, l.prnScaleActual),
              (PrintScaling.fill, l.prnScaleFill),
            ],
            onChanged: (v) => set(s.copyWith(scaling: v)),
          ),
          if (actualOverflows) ...[
            const SizedBox(height: Space.x3),
            InlineBanner(kind: BannerKind.warning, text: l.prnActualWarning),
          ],
        ]),
      OptionsCard(icon: Icons.border_outer_rounded, title: l.prnMargins, children: [
        ChoiceSegments<PrintMargins>(
          value: s.margins,
          options: [
            (PrintMargins.none, l.prnMarginNone),
            (PrintMargins.narrow, l.prnMarginNarrow),
            (PrintMargins.normal, l.prnMarginNormal),
          ],
          onChanged: (m) => set(s.copyWith(margins: m)),
        ),
      ]),
      const SizedBox(height: Space.x4),
      InlineBanner(kind: BannerKind.info, text: l.prnNextStepNote),
    ]);
  }
}
