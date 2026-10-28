import 'dart:math' as math;

import 'package:docukit/app/theme/theme.dart';
import 'package:docukit/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio (UI-REF-03).
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

/// Composites a translucent colour over an opaque one.
Color over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

void main() {
  for (final (name, theme) in [('light', AppTheme.light()), ('dark', AppTheme.dark())]) {
    final s = theme.colorScheme;
    final d = theme.extension<DocuColors>()!;

    group('$name theme', () {
      test('white text on both brand-gradient stops ≥ 4.5:1 (hero, success header, button)', () {
        expect(contrast(Colors.white, d.heroStart), greaterThanOrEqualTo(4.5), reason: 'start ${d.heroStart}');
        expect(contrast(Colors.white, d.heroEnd), greaterThanOrEqualTo(4.5), reason: 'end ${d.heroEnd}');
      });

      test('white text on the glass chip over the gradient ≥ 4.5:1', () {
        expect(contrast(Colors.white, over(d.glassFill, d.heroStart)), greaterThanOrEqualTo(4.5));
        expect(contrast(Colors.white, over(d.glassFill, d.heroEnd)), greaterThanOrEqualTo(4.5));
      });

      test('white glyphs on tool tiles ≥ 3:1 (non-text, WCAG 1.4.11)', () {
        for (final c in [d.imageGradStart, d.imageGradEnd, d.pdfGradStart, d.pdfGradEnd]) {
          expect(contrast(Colors.white, c), greaterThanOrEqualTo(3.0), reason: '$c');
        }
      });

      // v3 categories (FULL_PRODUCT §4.5, ADR-061): scan/secure are icon tiles
      // like image/pdf (3:1); library carries text on the My Documents card.
      test('white glyphs on scan and secure tiles ≥ 3:1', () {
        for (final c in [d.scanGradStart, d.scanGradEnd, d.secureGradStart, d.secureGradEnd]) {
          expect(contrast(Colors.white, c), greaterThanOrEqualTo(3.0), reason: '$c');
        }
      });

      test('white text on both library-gradient stops ≥ 4.5:1', () {
        for (final c in [d.libraryGradStart, d.libraryGradEnd]) {
          expect(contrast(Colors.white, c), greaterThanOrEqualTo(4.5), reason: '$c');
        }
      });

      test('category accents (tile glyphs, strips) on surfaces ≥ 3:1', () {
        for (final a in [d.scanAccent, d.secureAccent, d.libraryAccent]) {
          for (final bg in [s.surface, s.surfaceContainer, s.surfaceContainerHigh]) {
            expect(contrast(a, bg), greaterThanOrEqualTo(3.0), reason: '$a on $bg');
          }
        }
      });

      test('body text on surfaces ≥ 4.5:1', () {
        for (final bg in [s.surface, s.surfaceContainer, s.surfaceContainerHigh]) {
          expect(contrast(s.onSurface, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(s.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5));
        }
      });

      test('primary (links, section headers) on surface ≥ 4.5:1', () {
        expect(contrast(s.primary, s.surface), greaterThanOrEqualTo(4.5));
      });

      test('status colours on their containers ≥ 4.5:1', () {
        expect(contrast(d.success, d.successContainer), greaterThanOrEqualTo(4.5));
        expect(contrast(d.warning, d.warningContainer), greaterThanOrEqualTo(4.5));
        expect(contrast(s.onErrorContainer, s.errorContainer), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
