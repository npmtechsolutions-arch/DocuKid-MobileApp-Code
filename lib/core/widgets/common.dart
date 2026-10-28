import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../../features/search/tool_catalog.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatting/bytes_format.dart';

/// Light status-bar icons over the brand gradient, keeping the Android
/// navigation bar transparent (edge-to-edge). `SystemUiOverlayStyle.light`
/// alone would paint the navigation bar black.
const lightOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

/// Dark status-bar icons for light surfaces, navigation bar transparent.
const darkOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Sizes read in words for screen readers (DESIGN_SYSTEM §9).
String sizeForA11y(AppLocalizations l, int bytes) {
  final s = splitBytes(bytes);
  return l.a11ySizeWords(s.value, s.unit);
}

/// Centres content at max 720 dp on wide screens with responsive padding.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.padded = true});
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // heightFactor 1: never expand vertically (e.g. in a Scaffold's bottom bar slot).
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Space.contentMaxWidth),
        child: Padding(
          padding: padded ? EdgeInsetsDirectional.symmetric(horizontal: Space.screenPadding(w)) : EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing, this.top = Space.x6, this.color});
  final String label;
  final Widget? trailing;
  final double top;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(top: top, bottom: Space.x2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label,
                // Sentence case, Jakarta 600 (UI_REFRESH §1).
                style: context.text.titleSmall?.copyWith(color: color ?? context.colors.onSurface),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Category gradient for a tool tile (UI_REFRESH §1).
LinearGradient gradientFor(BuildContext context, ToolCategory c) => switch (c) {
      ToolCategory.image => context.docu.imageGradient,
      ToolCategory.pdf => context.docu.pdfGradient,
      ToolCategory.scan => context.docu.scanGradient,
    };

/// ToolCard v2 tile: category gradient, white glyph, soft tinted shadow.
class GradientIconTile extends StatelessWidget {
  const GradientIconTile({super.key, required this.icon, required this.category, this.size = 56, this.shadow = true});
  final IconData icon;
  final ToolCategory category;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final g = gradientFor(context, category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: g,
        borderRadius: BorderRadius.circular(size * 0.29),
        boxShadow: shadow
            ? [BoxShadow(color: g.colors.first.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
            : null,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.46),
    );
  }
}

/// Category accent for a tool (icon tiles and category headers only).
Color accentFor(BuildContext context, ToolCategory c) => switch (c) {
      ToolCategory.image => context.docu.imageAccent,
      ToolCategory.pdf => context.docu.pdfAccent,
      ToolCategory.scan => context.docu.scanAccent,
    };

/// 40 dp rounded-square icon tile: accent at 12% with the glyph in the accent.
class ToolIconTile extends StatelessWidget {
  const ToolIconTile({super.key, required this.icon, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
        ),
      ),
      child: Icon(icon, color: color, size: size * 0.6),
    );
  }
}

/// File names with a middle ellipsis: `IMG_2041…ressed.jpg`.
class MiddleEllipsisText extends StatelessWidget {
  const MiddleEllipsisText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final style = this.style ?? DefaultTextStyle.of(context).style;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width <= c.maxWidth || text.length < 8) {
        return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      }
      var keep = text.length;
      String candidate = text;
      while (keep > 6) {
        keep -= math.max(1, (keep * 0.08).round());
        final head = (keep * 0.55).round();
        final tail = keep - head;
        candidate = '${text.substring(0, head)}…${text.substring(text.length - tail)}';
        painter.text = TextSpan(text: candidate, style: style);
        painter.layout();
        if (painter.width <= c.maxWidth) break;
      }
      return Text(candidate, style: style, maxLines: 1, overflow: TextOverflow.clip, semanticsLabel: text);
    });
  }
}

enum BannerKind { info, warning, error, success }

class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key, required this.kind, required this.text, this.actions = const [], this.onDismiss});
  final BannerKind kind;
  final String text;
  final List<Widget> actions;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (kind) {
      BannerKind.info => (context.colors.primaryContainer, context.colors.onPrimaryContainer, Icons.info_outline_rounded),
      BannerKind.warning => (context.docu.warningContainer, context.docu.warning, Icons.warning_amber_rounded),
      BannerKind.error => (context.colors.errorContainer, context.colors.onErrorContainer, Icons.error_outline_rounded),
      BannerKind.success => (context.docu.successContainer, context.docu.success, Icons.check_circle_outline_rounded),
    };
    return Semantics(
      liveRegion: kind != BannerKind.info,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.x3, Space.x3, Space.x2, Space.x2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1, bottom: Space.x2),
                    child: Text(text, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurface)),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: context.l10n.actionClose,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (actions.isNotEmpty)
              Align(alignment: AlignmentDirectional.centerEnd, child: Wrap(spacing: Space.x2, children: actions)),
          ],
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
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
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: context.colors.primaryContainer.withValues(alpha: 0.6), shape: BoxShape.circle),
            child: Icon(icon, size: 44, color: context.colors.primary),
          ),
          const SizedBox(height: Space.x4),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: Space.x2),
            Text(body!, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: Space.x4), action!],
        ],
      ),
    );
  }
}

/// Neutral checkerboard behind transparent images (both themes).
class Checkerboard extends StatelessWidget {
  const Checkerboard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CheckerPainter(context.docu.checkerA, context.docu.checkerB), child: child);
}

class _CheckerPainter extends CustomPainter {
  _CheckerPainter(this.a, this.b);
  final Color a, b;

  @override
  void paint(Canvas canvas, Size size) {
    const s = 8.0;
    final pa = Paint()..color = a;
    final pb = Paint()..color = b;
    for (var y = 0.0; y < size.height; y += s) {
      for (var x = 0.0; x < size.width; x += s) {
        final even = ((x / s).floor() + (y / s).floor()).isEven;
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), even ? pa : pb);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.a != a || old.b != b;
}

void showAppSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 4),
    // Flutter keeps a snackbar with an action open until dismissed; ours
    // always time out, so an "Undo" never outlives the screen it belongs to.
    persist: false,
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}

/// Global rect of the widget behind [context] — the iPad share/open popover anchor.
Rect? originOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
