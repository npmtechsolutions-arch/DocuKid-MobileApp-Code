import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../job/job_screen.dart' show retentionPeriod;
import '../search/tool_catalog.dart';
import 'tour_controller.dart';
import 'tour_step.dart';
import 'tour_steps.dart';
import 'tour_targets.dart';

/// A transparent modal route: Home stays visible underneath, while the route
/// gives the tour back-button handling, a modal focus/semantics boundary and a
/// scrim that swallows taps (TOUR.md §3–4, ADR-031).
class TourRoute extends PageRoute<void> {
  TourRoute() : super(fullscreenDialog: true);

  @override
  bool get opaque => false;
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      const TourOverlay();

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.of(context).disableAnimations ? child : FadeTransition(opacity: animation, child: child);
}

class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key});

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> with WidgetsBindingObserver {
  Rect? _hole;
  double _holeRadius = Radii.lg;
  int _shownIndex = -1;
  bool _closing = false;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = ref.read(tourControllerProvider.notifier);
      if (!ref.read(tourControllerProvider).active) c.begin(total: _steps().length);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Rotation, split-screen, keyboard: re-measure the target (FR-TOUR-08).
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure(ref.read(tourControllerProvider).index, scroll: false);
    });
  }

  List<TourStep> _steps() {
    final l = context.l10n;
    final retention = ref.read(settingsProvider).outputRetention;
    return buildHomeTourSteps(l: l, targets: ref.read(tourTargetsProvider), period: retentionPeriod(l, retention));
  }

  Duration _d(Duration d) => MediaQuery.of(context).disableAnimations ? Duration.zero : d;

  Future<void> _measure(int index, {bool scroll = true, bool forward = true}) async {
    final gen = ++_gen;
    final steps = _steps();
    if (index < 0 || index >= steps.length) return;
    final target = steps[index].target;
    if (target == null) {
      setState(() => _hole = null);
      return;
    }
    final ctx = target.currentContext;
    if (ctx == null) {
      // Target not built (e.g. no app-bar actions on tablets): skip silently.
      final c = ref.read(tourControllerProvider.notifier);
      forward ? c.next() : c.back();
      return;
    }
    if (scroll) {
      await Scrollable.ensureVisible(ctx, alignment: 0.35, duration: _d(const Duration(milliseconds: 300)));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || gen != _gen || !ctx.mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null || !box.hasSize) return;
    final topLeft = overlayBox.globalToLocal(box.localToGlobal(Offset.zero));
    setState(() {
      _hole = (topLeft & box.size).inflate(8);
      _holeRadius = steps[index].tryTool != null ? Radii.card + 4 : Radii.lg + 4;
    });
  }

  void _announce(TourStep step, int index, int total) {
    final l = context.l10n;
    final text = index == 0 ? '${step.title}. ${step.body}' : l.a11yTourStep(index, total - 1, step.title, step.body);
    SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context));
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  void _tryIt(ToolId id) {
    final router = GoRouter.of(context);
    ref.read(tourControllerProvider.notifier).finish();
    _close();
    router.push(toolById(id).route);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tourControllerProvider);
    final c = ref.read(tourControllerProvider.notifier);
    if (!state.active) {
      if (_shownIndex >= 0) WidgetsBinding.instance.addPostFrameCallback((_) => _close());
      return const SizedBox.shrink();
    }
    final steps = _steps();
    final index = state.index.clamp(0, steps.length - 1);
    final step = steps[index];
    if (index != _shownIndex) {
      final forward = index > _shownIndex;
      _shownIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _measure(index, forward: forward);
        _announce(step, index, steps.length);
      });
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final hole = step.target == null ? null : _hole;
    final scrim = Colors.black.withValues(alpha: dark ? 0.70 : 0.60);

    // Tooltip: below the target with ≥ 220 dp free, otherwise above; centred
    // for the intro and done cards.
    // Room on each side of the target (never cover it).
    final spaceBelow = hole == null ? 0.0 : size.height - hole.bottom - pad.bottom - Space.x6;
    final spaceAbove = hole == null ? 0.0 : hole.top - pad.top - Space.x6;
    final below = spaceBelow >= 220 && spaceBelow >= spaceAbove * 0.6 || spaceBelow >= spaceAbove;
    final tooltip = _Tooltip(
      maxHeight: hole == null ? size.height * 0.8 : (below ? spaceBelow : spaceAbove).clamp(96.0, size.height),
      step: step,
      index: index,
      total: steps.length,
      onSkip: c.skip,
      onBack: index > 1 ? c.back : null,
      onNext: c.next,
      onTry: step.tryTool == null ? null : () => _tryIt(step.tryTool!),
    );
    Widget placed;
    if (hole == null) {
      placed = Center(
        child: Padding(padding: const EdgeInsets.all(Space.x4), child: tooltip),
      );
    } else {
      placed = Positioned(
        left: 0,
        right: 0,
        top: below ? hole.bottom + Space.x3 : null,
        bottom: below ? null : size.height - hole.top + Space.x3,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x4),
            child: tooltip,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        index <= 1 ? c.skip() : c.back(); // FR-TOUR-03
      },
      child: BlockSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Taps on the scrim do nothing (FR-TOUR-08).
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ExcludeSemantics(
                    child: hole == null
                        ? CustomPaint(
                            size: Size.infinite,
                            painter: _ScrimPainter(
                              hole: null,
                              radius: _holeRadius,
                              scrim: scrim,
                              ring: context.colors.primary,
                            ),
                          )
                        : TweenAnimationBuilder<Rect?>(
                            tween: RectTween(end: hole),
                            duration: _d(const Duration(milliseconds: 280)),
                            curve: Curves.easeInOutCubic,
                            builder: (context, r, _) => CustomPaint(
                              size: Size.infinite,
                              painter: _ScrimPainter(
                                hole: r,
                                radius: _holeRadius,
                                scrim: scrim,
                                ring: context.colors.primary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              placed,
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, required this.radius, required this.scrim, required this.ring});
  final Rect? hole;
  final double radius;
  final Color scrim, ring;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, Paint()..color = scrim);
      return;
    }
    final rr = RRect.fromRectAndRadius(hole!, Radius.circular(radius));
    canvas.drawPath(Path.combine(PathOperation.difference, full, Path()..addRRect(rr)), Paint()..color = scrim);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = ring.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.radius != radius || old.scrim != scrim || old.ring != ring;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.maxHeight,
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onNext,
    this.onBack,
    this.onTry,
  });
  final double maxHeight;
  final TourStep step;
  final int index, total;
  final VoidCallback onSkip, onNext;
  final VoidCallback? onBack, onTry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final intro = index == 0;
    final last = index == total - 1;
    final steps = total - 1; // the intro card isn't counted

    final header = Row(
      children: [
        Expanded(
          child: Text(
            intro ? '' : l.tourProgress(index, steps),
            style: context.text.labelLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (!intro) TextButton(onPressed: onSkip, child: Text(l.tourSkip)),
      ],
    );

    final content = <Widget>[
      Semantics(header: true, child: Text(step.title, style: context.text.titleLarge?.copyWith(fontSize: 18))),
      const SizedBox(height: Space.x1),
      Text(step.body, style: context.text.bodyMedium),
      if (step.example != null) ...[
        const SizedBox(height: Space.x3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x2),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: context.colors.onPrimaryContainer),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  step.example!,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
      ],
      if (!intro) ...[
        const SizedBox(height: Space.x3),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 1; i <= steps; i++)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 5),
                  width: i == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == index ? context.colors.primary : context.colors.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    ];

    final next = FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      onPressed: onNext,
      child: Text(intro ? l.tourStart : (last ? l.tourDone : l.tourNext)),
    );
    final buttons = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: intro
          ? [TextButton(onPressed: onSkip, child: Text(l.tourSkip)), next]
          : [
              if (onBack != null) TextButton(onPressed: onBack, child: Text(l.tourBack)) else const SizedBox(width: 1),
              Wrap(
                spacing: Space.x2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onTry != null) TextButton(onPressed: onTry, child: Text(l.tourTry)),
                  next,
                ],
              ),
            ],
    );

    // The buttons stay pinned and the rest scrolls; with very little room
    // (small screen + large text) the whole card scrolls instead of overflowing.
    final tight = maxHeight < 180;
    final Widget body = tight
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(Space.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                ...content,
                const SizedBox(height: Space.x3),
                buttons,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [header, ...content],
                    ),
                  ),
                ),
                const SizedBox(height: Space.x3),
                buttons,
              ],
            ),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 360, maxHeight: maxHeight),
      child: Material(
        color: context.colors.surfaceContainerHigh,
        elevation: 12,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}
