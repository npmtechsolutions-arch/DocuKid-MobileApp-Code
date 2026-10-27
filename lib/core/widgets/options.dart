import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'common.dart';

/// Title + control + helper (DESIGN_SYSTEM §6).
class OptionGroup extends StatelessWidget {
  const OptionGroup({super.key, required this.title, required this.child, this.helper, this.trailing});
  final String title;
  final Widget child;
  final String? helper;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
            ?trailing,
          ]),
          const SizedBox(height: Space.x2),
          child,
          if (helper != null) ...[
            const SizedBox(height: Space.x1),
            Text(helper!, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// UI_REFRESH §4: an option section as a card (r 16) with a small leading
/// icon, instead of a bare section header.
class OptionsCard extends StatelessWidget {
  const OptionsCard({super.key, required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, size: 20, color: context.colors.primary),
              const SizedBox(width: Space.x2),
              Expanded(child: Semantics(header: true, child: Text(title, style: context.text.titleSmall))),
            ]),
            const SizedBox(height: Space.x3),
            ...children,
          ]),
        ),
      ),
    );
  }
}

/// Single-choice SegmentedButton that wraps gracefully at large text sizes.
class ChoiceSegments<T> extends StatelessWidget {
  const ChoiceSegments({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale > 1.4 || options.length > 4) {
      // Large text: chips wrap instead of clipping.
      return Wrap(
        spacing: Space.x2,
        runSpacing: Space.x2,
        children: [
          for (final (v, label) in options)
            ChoiceChip(label: Text(label), selected: v == value, onSelected: (_) => onChanged(v)),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        segments: [for (final (v, label) in options) ButtonSegment(value: v, label: Text(label, maxLines: 1))],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

/// 10–100 step 5, value bubble, "Smaller file / Sharper" end labels.
class QualitySlider extends StatelessWidget {
  const QualitySlider({super.key, required this.value, required this.onChanged, this.min = 10});
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: Semantics(
              value: l.cmpQualityA11y(value),
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: 100,
                divisions: (100 - min) ~/ 5,
                label: '$value',
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: Space.x1),
            decoration: BoxDecoration(color: context.colors.primaryContainer, borderRadius: BorderRadius.circular(Radii.full)),
            child: Text('$value', textAlign: TextAlign.center, style: context.text.titleMedium?.copyWith(color: context.colors.onPrimaryContainer)),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          child: Row(children: [
            Text(l.cmpQualityLow, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            const Spacer(),
            Text(l.cmpQualityHigh, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ]),
        ),
      ],
    );
  }
}
