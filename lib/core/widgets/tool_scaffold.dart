import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../features/favourites/favourites_ui.dart';
import '../../features/search/tool_catalog.dart';
import '../ads/ads_config.dart';
import '../ads/bottom_banner.dart';
import 'common.dart';
import 'dialogs.dart';

/// The tool a screen belongs to (provided by `ToolEntry`), so the shared frame
/// can draw the category strip and icon tile (UI_REFRESH §4).
class CurrentTool extends InheritedWidget {
  const CurrentTool({super.key, required this.id, required super.child});
  final ToolId id;

  static ToolId? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CurrentTool>()?.id;

  @override
  bool updateShouldNotify(CurrentTool oldWidget) => oldWidget.id != id;
}

/// Shared tool-screen frame (DESIGN_SYSTEM §6): app bar with ⓘ, scrollable
/// body, sticky [PrimaryActionBar], and D4 on back when there is work.
class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    super.key,
    required this.title,
    required this.primary,
    required this.action,
    this.info,
    this.hasWork = false,
    this.organizer = false,
    this.onLeave,
    this.actions = const [],
    this.banner,
    this.secondary,
    this.bottomAccessory,
    this.slivers,
  });

  final String title;
  final List<Widget> primary;

  /// On expanded widths, shown in a right-hand column (inputs left, options right).
  final List<Widget>? secondary;
  final PrimaryActionBar action;
  final String? info;
  final bool hasWork;
  final bool organizer;
  final VoidCallback? onLeave;
  final List<Widget> actions;
  final Widget? banner;

  /// Sticky widget above the primary button (e.g. the Organizer selection bar).
  final Widget? bottomAccessory;

  /// Lazy body for long content; replaces [primary]/[secondary] when set.
  final List<Widget>? slivers;

  Future<void> _maybeLeave(BuildContext context) async {
    final nav = Navigator.of(context);
    if (await confirmLeave(context, organizer: organizer)) {
      onLeave?.call();
      if (nav.mounted) nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded && secondary != null;
    Widget column(List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: c);

    final pad = Space.screenPadding(MediaQuery.sizeOf(context).width);
    final toolId = CurrentTool.of(context);
    final tool = toolId == null ? null : toolById(toolId);
    final body = slivers != null
        ? CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, Space.x8),
              sliver: SliverMainAxisGroup(slivers: [
                if (banner != null) SliverToBoxAdapter(child: banner),
                ...slivers!,
              ]),
            ),
          ])
        : wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x3, Space.x8),
                  child: column([?banner, ...primary]),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.x3, 0, Space.x6, Space.x8),
                  child: column(secondary!),
                ),
              ),
            ],
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Space.x8),
            child: ContentWidth(child: column([?banner, ...primary, ...?secondary])),
          );

    return PopScope(
      canPop: !hasWork,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLeave(context);
      },
      child: AppBottomBanner(unit: AdUnit.bannerTools, separated: true, child: Scaffold(
        appBar: AppBar(
          title: tool == null
              ? Text(title)
              : Row(children: [
                  GradientIconTile(icon: tool.icon, category: tool.category, size: 32, shadow: false),
                  const SizedBox(width: Space.x3),
                  Flexible(
                    // T8.11 (owner choice): with ⓘ and ⋮ the full name may not fit on
                    // a phone, so it scales down to fit. Enlarged accessibility text
                    // is never shrunk: it keeps the ellipsis instead.
                    child: MediaQuery.textScalerOf(context).scale(1) > 1.3
                        ? Text(title, overflow: TextOverflow.ellipsis)
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(title, maxLines: 1),
                          ),
                  ),
                ]),
          bottom: tool == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: Container(height: 4, decoration: BoxDecoration(gradient: gradientFor(context, tool.category))),
                ),
          actions: [
            ...actions,
            // FR-FAV-01: every tool screen's ⋮ can pin the tool.
            if (CurrentTool.of(context) case final id?) FavouriteMenuButton(tool: id),
            if (info != null)
              IconButton(
                tooltip: l.actionInfo,
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => showInfoSheet(context, title: l.actionInfo, body: info!),
              ),
          ],
        ),
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: bottomAccessory == null
            ? action
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Material(
                  color: context.colors.surface,
                  child: ContentWidth(
                    child: Padding(padding: const EdgeInsets.only(top: Space.x2), child: bottomAccessory),
                  ),
                ),
                action,
              ]),
      )),
    );
  }
}

/// Sticky full-width primary button with an optional helper line above it.
class PrimaryActionBar extends StatelessWidget {
  const PrimaryActionBar({super.key, required this.label, required this.onPressed, this.helper, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final String? helper;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      color: context.colors.surface,
      elevation: 3,
      surfaceTintColor: context.colors.surfaceTint,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: ContentWidth(
        child: Padding(
          padding: EdgeInsets.only(top: Space.x3, bottom: bottom > Space.x4 ? bottom : Space.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (helper != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x2),
                  child: Text(
                    helper!,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              // UI_REFRESH §4: full-width gradient pill; disabled = surfaceContainerHigh.
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  gradient: onPressed == null ? null : context.docu.brandGradient,
                  color: onPressed == null ? context.colors.surfaceContainerHigh : null,
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: context.colors.onSurfaceVariant,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: onPressed,
                  icon: Icon(icon ?? Icons.arrow_forward_rounded),
                  label: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
