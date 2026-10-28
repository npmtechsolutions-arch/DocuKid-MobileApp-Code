import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../search/tool_catalog.dart';

// UI_REFRESH §5–§6 visuals for Processing and Result. Built from Icons,
// AnimatedBuilder and CustomPainter only (no Lottie, ADR-032). Every
// animation is off under reduce-motion (UI-REF-04).

/// S10: the tool's gradient tile with a per-tool looping glyph motion.
class ToolGlyph extends StatefulWidget {
  const ToolGlyph({super.key, required this.tool, this.size = 72});
  final ToolDescriptor tool;
  final double size;

  @override
  State<ToolGlyph> createState() => _ToolGlyphState();
}

class _ToolGlyphState extends State<ToolGlyph> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    final s = widget.size;
    final g = gradientFor(context, t.category);
    return ExcludeSemantics(
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(s * 0.29)),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = Curves.easeInOut.transform(_c.value);
            final glyph = Icon(t.icon, color: Colors.white, size: s * 0.46);
            return switch (t.id) {
              // Arrows squeezing: the glyph narrows and widens.
              ToolId.imageCompress || ToolId.pdfCompress =>
                Transform.scale(scaleX: 1 - 0.22 * v, scaleY: 1 + 0.06 * v, child: glyph),
              // Frame stretching to a new size.
              ToolId.imageResize => Transform.scale(scale: 0.86 + 0.18 * v, child: glyph),
              // Photos dropping into a page.
              ToolId.imageToPdf => Transform.translate(offset: Offset(0, -s * 0.08 * (1 - v)), child: glyph),
              // Pages stacking: two sheets slide together.
              ToolId.pdfMerge => Stack(alignment: Alignment.center, children: [
                  Transform.translate(
                    offset: Offset(-s * 0.12 * (1 - v), -s * 0.06 * (1 - v)),
                    child: Icon(Icons.description_rounded, color: Colors.white.withValues(alpha: 0.55), size: s * 0.42),
                  ),
                  Transform.translate(
                    offset: Offset(s * 0.12 * (1 - v), s * 0.06 * (1 - v)),
                    child: Icon(Icons.description_rounded, color: Colors.white, size: s * 0.42),
                  ),
                ]),
              // Pages being turned around.
              ToolId.pdfOrganize => Transform.rotate(angle: (v - 0.5) * 0.35, child: glyph),
              // 1.1 tools: a gentle pulse until each gets its own motion (T8.5 / T8.7 / T8.9).
              ToolId.imageConvert || ToolId.pdfSplit || ToolId.pdfToImages =>
                Transform.scale(scale: 0.92 + 0.08 * v, child: glyph),
            };
          },
        ),
      ),
    );
  }
}

/// S10: rotating tip (every 5 s, fade). Static with reduce-motion.
class TipCard extends StatefulWidget {
  const TipCard({super.key, required this.seed});

  /// Picks the first tip, so different jobs don't always start on tip 1.
  final int seed;

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  late int _i = widget.seed.abs() % 8;
  Timer? _timer;

  static String tip(AppLocalizations l, int i) =>
      [l.tip1, l.tip2, l.tip3, l.tip4, l.tip5, l.tip6, l.tip7, l.tip8][i % 8];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = MediaQuery.of(context).disableAnimations
        ? null
        : Timer.periodic(const Duration(seconds: 5), (_) {
            if (mounted) setState(() => _i = (_i + 1) % 8);
          });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = tip(context.l10n, _i);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      color: context.colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline_rounded, size: 20, color: context.colors.primary),
          const SizedBox(width: Space.x3),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.of(context, const Duration(milliseconds: 300)),
              layoutBuilder: (current, previous) =>
                  Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
              child: Text(
                text,
                key: ValueKey(_i),
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// S11: success check that pops in and draws its stroke (400 ms).
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 400)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Transform.scale(
        scale: 0.6 + 0.4 * Curves.easeOutBack.transform(v.clamp(0, 1)),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: CustomPaint(painter: _CheckPainter(progress: v, color: context.docu.success)),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.36);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress || old.color != color;
}

/// S11: donut whose successGradient arc is the share saved, with the big
/// "−87%" counting up in the centre (500 ms).
class SavingsRing extends StatelessWidget {
  const SavingsRing({super.key, required this.before, required this.after, this.size = 112});
  final int before, after;
  final double size;

  @override
  Widget build(BuildContext context) {
    final saved = before <= 0 ? 0.0 : ((before - after) / before).clamp(0.0, 1.0);
    final pct = (saved * 100).round();
    final smaller = after < before;
    final larger = after > before;
    // A result can be bigger than its input (e.g. Basic on a text PDF): say so
    // in the warning colour rather than showing "0% smaller".
    final grewPct = larger && before > 0 ? percentChange(before, after).abs() : 0;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: saved),
        duration: Motion.of(context, const Duration(milliseconds: 500)),
        curve: Motion.curve,
        builder: (context, v, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              fraction: v,
              track: context.colors.surfaceContainerHigh,
              gradient: context.docu.successGradient,
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  child: Text(
                    smaller ? '−${(v * 100).round().clamp(0, pct)}%' : (larger ? '+$grewPct%' : '0%'),
                    style: context.text.headlineSmall?.copyWith(
                      color: smaller
                          ? context.docu.success
                          : (larger ? context.docu.warning : context.colors.onSurfaceVariant),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(larger ? context.l10n.resultLargerShort : context.l10n.resultSmallerShort,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track, required this.gradient});
  final double fraction;
  final Color track;
  final LinearGradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.track != track;
}

/// S11: a subtle confetti burst (1.2 s, 24 particles). The caller decides
/// whether to show it (savings ≥ 50 %, reduce-motion off, once per session).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  final _particles = List.generate(24, (i) {
    final r = math.Random(i * 7919);
    return (
      angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.1,
      speed: 0.55 + r.nextDouble() * 0.45,
      spin: (r.nextDouble() - 0.5) * 8,
      colour: i % 4,
      w: 5 + r.nextDouble() * 4,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colours = [
      context.docu.heroStart,
      context.docu.heroEnd,
      context.docu.successGradStart,
      context.docu.pdfGradEnd,
    ];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _c.isCompleted
                ? const SizedBox.shrink()
                : CustomPaint(
                    size: Size.infinite,
                    painter: _ConfettiPainter(t: _c.value, particles: _particles, colours: colours),
                  ),
          ),
        ),
      ),
    );
  }
}

typedef _Particle = ({double angle, double speed, double spin, int colour, double w});

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.particles, required this.colours});
  final double t;
  final List<_Particle> particles;
  final List<Color> colours;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.32);
    final reach = size.shortestSide * 0.55;
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    for (final p in particles) {
      final d = reach * p.speed * Curves.easeOutCubic.transform(t);
      final gravity = reach * 0.6 * t * t;
      final pos = origin + Offset(math.cos(p.angle) * d, math.sin(p.angle) * d + gravity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.w * 0.5), const Radius.circular(1.5)),
        Paint()..color = colours[p.colour].withValues(alpha: fade.clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// S11 2×2 grid: large tonal buttons with icons; [primary] uses brandGradient.
class ResultActionButton extends StatelessWidget {
  const ResultActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg));
    final fg = primary ? Colors.white : context.colors.onPrimaryContainer;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: primary ? context.docu.brandGradient : null,
        color: primary ? null : context.colors.primaryContainer,
      ),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size.fromHeight(56),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x3),
          textStyle: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
