import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Flat two-tone illustrations drawn with CustomPainter, so no SVG dependency
/// is needed (UI_REFRESH §7, ADR-032). Colours come from the theme tokens:
/// the category accent + `surfaceContainerHigh`.
enum IllustrationKind { recentEmpty, historyEmpty, pickImages, pickPdf, error, onboarding }

class Illustration extends StatelessWidget {
  const Illustration({super.key, required this.kind, this.size = 120});
  final IllustrationKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = switch (kind) {
      IllustrationKind.pickImages => context.docu.imageAccent,
      IllustrationKind.pickPdf => context.docu.pdfAccent,
      IllustrationKind.error => context.docu.warning,
      _ => context.colors.primary,
    };
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _IllustrationPainter(
          kind: kind,
          accent: accent,
          base: context.colors.surfaceContainerHigh,
          paper: context.colors.surface,
          line: context.colors.outlineVariant,
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({
    required this.kind,
    required this.accent,
    required this.base,
    required this.paper,
    required this.line,
  });
  final IllustrationKind kind;
  final Color accent, base, paper, line;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fill = Paint()..color = base;
    final acc = Paint()..color = accent;
    final soft = Paint()..color = accent.withValues(alpha: 0.18);
    final white = Paint()..color = paper;
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Shared backdrop: a soft blob.
    canvas.drawCircle(Offset(s * 0.5, s * 0.52), s * 0.44, fill);

    RRect page(double l, double t, double w, double h) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(s * l, s * t, s * w, s * h), Radius.circular(s * 0.05));

    switch (kind) {
      case IllustrationKind.recentEmpty:
      case IllustrationKind.historyEmpty:
        // A clock over a short stack of pages.
        canvas.drawRRect(page(0.22, 0.30, 0.40, 0.48), white);
        canvas.drawRRect(page(0.30, 0.24, 0.40, 0.48), white);
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(s * 0.37, s * (0.38 + i * 0.09)),
            Offset(s * 0.6, s * (0.38 + i * 0.09)),
            Paint()
              ..color = line
              ..strokeWidth = s * 0.03
              ..strokeCap = StrokeCap.round,
          );
        }
        final c = Offset(s * 0.68, s * 0.66);
        canvas.drawCircle(c, s * 0.17, acc);
        canvas.drawCircle(c, s * 0.13, white);
        canvas.drawLine(c, c + Offset(0, -s * 0.08), stroke);
        canvas.drawLine(c, c + Offset(s * 0.06, s * 0.03), stroke);
      case IllustrationKind.pickImages:
        // Two photos, one tilted, with a sun and hills.
        canvas.save();
        canvas.translate(s * 0.5, s * 0.5);
        canvas.rotate(-0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(-8, 4), width: s * 0.52, height: s * 0.42),
            Radius.circular(s * 0.05),
          ),
          soft,
        );
        canvas.restore();
        final r = page(0.26, 0.28, 0.50, 0.40);
        canvas.drawRRect(r, white);
        canvas.drawRRect(
          r,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.02,
        );
        canvas.drawCircle(Offset(s * 0.38, s * 0.39), s * 0.05, acc);
        final hills = Path()
          ..moveTo(s * 0.28, s * 0.64)
          ..lineTo(s * 0.43, s * 0.48)
          ..lineTo(s * 0.53, s * 0.58)
          ..lineTo(s * 0.60, s * 0.52)
          ..lineTo(s * 0.74, s * 0.64)
          ..close();
        canvas.drawPath(hills, acc);
      case IllustrationKind.pickPdf:
      case IllustrationKind.onboarding:
        // A document with a folded corner and text lines.
        final p = Path()
          ..moveTo(s * 0.30, s * 0.20)
          ..lineTo(s * 0.58, s * 0.20)
          ..lineTo(s * 0.70, s * 0.32)
          ..lineTo(s * 0.70, s * 0.80)
          ..lineTo(s * 0.30, s * 0.80)
          ..close();
        canvas.drawPath(p, white);
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.58, s * 0.20)
            ..lineTo(s * 0.58, s * 0.32)
            ..lineTo(s * 0.70, s * 0.32)
            ..close(),
          soft,
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(s * 0.37, s * (0.44 + i * 0.1)),
            Offset(s * (i == 2 ? 0.52 : 0.63), s * (0.44 + i * 0.1)),
            Paint()
              ..color = i == 0 ? accent : line
              ..strokeWidth = s * 0.035
              ..strokeCap = StrokeCap.round,
          );
        }
        if (kind == IllustrationKind.onboarding) {
          final c = Offset(s * 0.72, s * 0.74);
          final star = Path();
          for (var i = 0; i < 8; i++) {
            final rad = i.isEven ? s * 0.12 : s * 0.035;
            final a = -math.pi / 2 + i * math.pi / 4;
            final pt = c + Offset(math.cos(a) * rad, math.sin(a) * rad);
            i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(star..close(), acc);
        }
      case IllustrationKind.error:
        // A page with a warning triangle.
        canvas.drawRRect(page(0.26, 0.22, 0.42, 0.52), white);
        final t = Path()
          ..moveTo(s * 0.62, s * 0.46)
          ..lineTo(s * 0.80, s * 0.78)
          ..lineTo(s * 0.44, s * 0.78)
          ..close();
        canvas.drawPath(t, acc);
        canvas.drawLine(
          Offset(s * 0.62, s * 0.58),
          Offset(s * 0.62, s * 0.68),
          Paint()
            ..color = paper
            ..strokeWidth = s * 0.035
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(Offset(s * 0.62, s * 0.735), s * 0.02, white);
    }
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.kind != kind || old.accent != accent || old.base != base || old.paper != paper;
}

/// Empty state with an illustration (replaces the plain icon circle).
class IllustratedEmpty extends StatelessWidget {
  const IllustratedEmpty({super.key, required this.kind, required this.title, this.body, this.action});
  final IllustrationKind kind;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x8, horizontal: Space.x4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Illustration(kind: kind, size: 140),
          const SizedBox(height: Space.x4),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: Space.x2),
            Text(
              body!,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: Space.x4), action!],
        ],
      ),
    );
  }
}
