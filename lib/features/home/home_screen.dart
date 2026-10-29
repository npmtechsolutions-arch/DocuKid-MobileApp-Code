import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ad_slots.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/ads_controller.dart';
import '../../core/ads/bottom_banner.dart';
import '../../core/ads/remove_ads.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/operation/jobs_controller.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/illustrations.dart';
import '../../l10n/gen/app_localizations.dart';
import '../favourites/favourites_controller.dart';
import '../favourites/favourites_ui.dart';
import '../history/history_providers.dart';
import '../job/save_flow.dart';
import '../search/tool_catalog.dart';
import '../tour/tour_controller.dart';
import '../tour/tour_targets.dart';
import 'quick_actions.dart';

/// S01 · Home.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Past the blue header: show a surface scrim behind the status bar and
  /// switch its icons to dark so they stay readable.
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    // Auto-start the tour once, after onboarding (TOUR.md FR-TOUR-01).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Onboarding → consent form → tour (ADS.md §5): consent starts first and
      // the tour waits for it to settle.
      unawaited(ref.read(adsControllerProvider.notifier).startOnce());
      ref.read(removeAdsProvider); // listens for purchases/restores from app start
      ref.read(tourControllerProvider.notifier).maybeAutoStart(context);
    });
  }

  /// Settings → "Take the tour" pops back to this Home: wait until the route
  /// transition has finished so the spotlight measures the settled layout.
  Future<void> _replayWhenVisible() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || (route.isCurrent && (route.secondaryAnimation?.isDismissed ?? true))) break;
    }
    if (mounted && ref.read(tourControllerProvider).replayPending) {
      ref.read(tourControllerProvider.notifier).start(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tourControllerProvider.select((s) => s.replayPending), (_, pending) {
      if (pending) _replayWhenVisible();
    });
    final l = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final rail = width >= Breakpoints.expanded;
    // Large text on a phone: one card per row (full-width, horizontal), so
    // titles like "Image Compressor" never break mid-word.
    final bigText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final cols = width >= Breakpoints.expanded
        ? 4
        : (width >= Breakpoints.medium ? 3 : (bigText ? 1 : 2));
    final lastTool = ref.watch(settingsProvider.select((s) => s.lastTool));
    final active = ref.watch(jobsProvider.select((m) => m.values.where((j) => j.isRunning).firstOrNull));
    final recents = ref.watch(recentProvider);
    final targets = ref.watch(tourTargetsProvider);
    final images = toolCatalog.where((t) => t.category == ToolCategory.image).toList();
    final pdfs = toolCatalog.where((t) => t.category == ToolCategory.pdf).toList();
    final scans = toolCatalog.where((t) => t.category == ToolCategory.scan).toList();
    final secure = toolCatalog.where((t) => t.category == ToolCategory.secure).toList();
    final animate = HomeEntrance.shouldPlay(context);

    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.viewPaddingOf(context).top;
    var entranceIndex = 0;
    Widget enter(Widget child) => animate ? HomeEntrance(index: entranceIndex++, child: child) : child;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _scrolled && !dark ? darkOverlay : lightOverlay,
      child: AppBottomBanner(unit: AdUnit.bannerMain, child: Scaffold(
        body: Stack(
          children: [
            NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                final past = n.metrics.pixels > 220;
                if (past != _scrolled) setState(() => _scrolled = past);
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Hero(showActions: !rail)),
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (active != null) ...[
                            const SizedBox(height: Space.x4),
                            Material(
                              color: context.colors.primaryContainer,
                              borderRadius: BorderRadius.circular(Radii.lg),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
                                leading: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
                                ),
                                title: Text(l.homeJobRunning),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => context.push('/job/${active.id}'),
                              ),
                            ),
                          ],
                          if (lastTool != null) ...[
                            const SizedBox(height: Space.x4),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ActionChip(
                                avatar: Icon(Icons.play_arrow_rounded, color: context.colors.onPrimaryContainer),
                                backgroundColor: context.colors.primaryContainer,
                                side: BorderSide.none,
                                label: Text(
                                  l.homeContinue(toolById(lastTool).title(l)),
                                  style: TextStyle(color: context.colors.onPrimaryContainer),
                                ),
                                onPressed: () => context.push(toolById(lastTool).route),
                              ),
                            ),
                          ],
                          // FR-FAV-02: above Quick actions, only when something is pinned.
                          KeyedSubtree(key: targets.favourites, child: const FavouritesRow()),
                          SectionHeader(l.homeQuickActions, top: Space.x5),
                          const _QuickActionsRow(),
                          SectionHeader(l.homeSectionImage, top: Space.x5),
                          _ToolGrid(tools: images, cols: cols, keyOf: targets.toolKey, wrap: enter),
                          SectionHeader(l.homeSectionPdf, top: Space.x5),
                          _ToolGrid(tools: pdfs, cols: cols, keyOf: targets.toolKey, wrap: enter),
                          // FR-SCN-23 (FULL_PRODUCT §3): Scan & Text after PDF.
                          SectionHeader(l.homeSectionScan, top: Space.x5),
                          _ToolGrid(tools: scans, cols: cols, keyOf: targets.toolKey, wrap: enter),
                          // FR-SEC-01 (1.4): Secure & Sign after Scan & text.
                          KeyedSubtree(key: targets.secureSection, child: SectionHeader(l.homeSectionSecure, top: Space.x5)),
                          _ToolGrid(tools: secure, cols: cols, keyOf: targets.toolKey, wrap: enter),
                          const HomeAdSlot(),
                          KeyedSubtree(
                            key: targets.recent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionHeader(
                                  l.homeSectionRecent,
                                  top: Space.x6,
                                  trailing: (recents.value?.isNotEmpty ?? false)
                                      ? TextButton(
                                          onPressed: () => context.push('/history'),
                                          child: Text('${l.homeSeeAll} ›'),
                                        )
                                      : null,
                                ),
                                switch (recents) {
                                  AsyncData(:final value) when value.isEmpty => Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(Space.x4),
                                      child: Row(
                                        children: [
                                          const Illustration(kind: IllustrationKind.recentEmpty, size: 72),
                                          const SizedBox(width: Space.x4),
                                          Expanded(
                                            child: Text(
                                              l.homeRecentEmpty,
                                              style: context.text.bodyMedium?.copyWith(
                                                color: context.colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  AsyncData(:final value) => Card(
                                    child: Column(
                                      children: [
                                        for (var i = 0; i < value.length; i++) ...[
                                          if (i > 0) const Divider(indent: 68),
                                          HistoryTile(
                                            record: value[i],
                                            onTap: () => context.push('/history/${value[i].id}'),
                                            onLongPress: () => _recentSheet(context, ref, value[i].id),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  _ => const _SkeletonRows(),
                                },
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.x6),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => context.push('/settings/privacy'),
                              icon: Icon(Icons.lock_rounded, size: 18, color: context.docu.success),
                              label: Text(l.privacyPromise, style: TextStyle(color: context.colors.onSurfaceVariant)),
                            ),
                          ),
                          SizedBox(height: Space.x6 + MediaQuery.viewPaddingOf(context).bottom),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _scrolled ? 1 : 0,
                  duration: Motion.of(context, Motion.medium),
                  child: ColoredBox(color: context.colors.surface.withValues(alpha: 0.96)),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Future<void> _recentSheet(BuildContext context, WidgetRef ref, String id) async {
    final l = context.l10n;
    final rec = await ref.read(historyRepositoryProvider).get(id);
    if (rec == null || !context.mounted) return;
    final rel = rec.row.outputRelPath;
    final available = rec.outputRecorded && await ref.read(outputsRepositoryProvider).exists(rel);
    if (!context.mounted) return;
    final path = rel == null ? null : ref.read(outputsRepositoryProvider).absolute(rel);
    await showAppSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            enabled: available,
            leading: const Icon(Icons.open_in_new_rounded),
            title: Text(l.actionOpenWith),
            onTap: () {
              Navigator.pop(ctx);
              openWithResult(context, ref, path: path!, mime: rec.row.outputMime ?? '*/*');
            },
          ),
          ListTile(
            enabled: available,
            leading: const Icon(Icons.ios_share_rounded),
            title: Text(l.actionShare),
            onTap: () {
              Navigator.pop(ctx);
              shareResult(context, ref, path: path!, mime: rec.row.outputMime ?? '*/*');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(l.detRemoveEntry),
            onTap: () async {
              Navigator.pop(ctx);
              await ref.read(outputsRepositoryProvider).deleteFor(id);
              await ref.read(historyRepositoryProvider).remove(id);
            },
          ),
          const SizedBox(height: Space.x4),
        ],
      ),
    );
  }
}

/// Greeting by local time (UI_REFRESH §2).
String greetingFor(AppLocalizations l, DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return l.homeGreetingMorning;
  if (h >= 12 && h < 17) return l.homeGreetingAfternoon;
  return l.homeGreetingEvening;
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.showActions});
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final top = MediaQuery.viewPaddingOf(context).top;
    final targets = ref.watch(tourTargetsProvider);
    final saved = ref.watch(settingsProvider.select((s) => s.statsTotalSavedBytes));
    final now = ref.watch(clockProvider)();
    const iconColor = Colors.white;
    final help = IconButton(
      tooltip: l.homeHelpTooltip,
      color: iconColor,
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => ref.read(tourControllerProvider.notifier).start(context),
    );
    return Container(
      decoration: BoxDecoration(
        gradient: context.docu.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.hero)),
      ),
      child: Stack(
        children: [
          // Soft decorative shapes (pure decoration, excluded from semantics).
          const PositionedDirectional(
            top: -40,
            end: -30,
            child: ExcludeSemantics(child: _Blob(size: 180, opacity: 0.10)),
          ),
          const PositionedDirectional(
            bottom: -50,
            start: -40,
            child: ExcludeSemantics(child: _Blob(size: 160, opacity: 0.07)),
          ),
          ContentWidth(
            child: Padding(
              padding: EdgeInsets.only(top: top + Space.x2, bottom: Space.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _LogoMark(),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Text(l.appName, style: context.text.titleLarge?.copyWith(color: Colors.white)),
                      ),
                      if (showActions)
                        KeyedSubtree(
                          key: targets.appBarActions,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              help,
                              IconButton(
                                tooltip: l.homeHistoryTooltip,
                                color: iconColor,
                                icon: const Icon(Icons.history_rounded),
                                onPressed: () => context.push('/history'),
                              ),
                              IconButton(
                                tooltip: l.homeSettingsTooltip,
                                color: iconColor,
                                icon: const Icon(Icons.settings_outlined),
                                onPressed: () => context.push('/settings'),
                              ),
                            ],
                          ),
                        )
                      else
                        help,
                    ],
                  ),
                  const SizedBox(height: Space.x4),
                  Text(
                    greetingFor(l, now),
                    style: context.text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    header: true,
                    child: Text(
                      l.homeGreeting,
                      style: context.text.headlineSmall?.copyWith(color: Colors.white, height: 1.2),
                    ),
                  ),
                  const SizedBox(height: Space.x4),
                  KeyedSubtree(key: targets.search, child: const _SearchBarButton()),
                  if (saved > 0) ...[const SizedBox(height: Space.x3), _SavingsChip(bytes: saved)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});
  final double size, opacity;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.md)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.description_rounded, color: context.docu.heroStart, size: 22),
            PositionedDirectional(
              end: 5,
              bottom: 5,
              child: Icon(Icons.auto_awesome_rounded, size: 11, color: context.docu.pdfAccent),
            ),
          ],
        ),
      ),
    );
  }
}

/// "You've saved 48.2 MB so far" — local counter, counts up once per session.
class _SavingsChip extends StatelessWidget {
  const _SavingsChip({required this.bytes});
  final int bytes;
  static bool _countedThisSession = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final countUp = !_countedThisSession && !MediaQuery.of(context).disableAnimations;
    _countedThisSession = true;
    return Semantics(
      label: l.homeSavedSoFar(sizeForA11y(l, bytes)),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: 6),
        decoration: BoxDecoration(
          color: context.docu.glassFill,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: context.docu.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: countUp ? 0 : bytes.toDouble(), end: bytes.toDouble()),
                duration: countUp ? Motion.countUp : Duration.zero,
                curve: Motion.curve,
                builder: (context, v, _) => Text(
                  l.homeSavedSoFar(formatBytes(v.round())),
                  style: context.text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass search field on the gradient; acts as a button. The placeholder
/// rotates three examples every 4 s (static with reduce-motion).
class _SearchBarButton extends StatefulWidget {
  const _SearchBarButton();

  @override
  State<_SearchBarButton> createState() => _SearchBarButtonState();
}

class _SearchBarButtonState extends State<_SearchBarButton> {
  Timer? _timer;
  int _i = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!MediaQuery.of(context).disableAnimations) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => setState(() => _i = (_i + 1) % 3));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final examples = [l.homeSearchExample1, l.homeSearchExample2, l.homeSearchExample3];
    return Hero(
      tag: 'search',
      child: Material(
        color: context.docu.glassFill,
        shape: StadiumBorder(side: BorderSide(color: context.docu.glassBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => context.push('/search'),
          child: Semantics(
            button: true,
            label: l.searchFieldHint,
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.white),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.slow),
                      child: Text(
                        examples[_i],
                        key: ValueKey(_i),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick actions row (UI_REFRESH §2.1, FR-HOME-06).
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: quickActions.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
        itemBuilder: (context, i) => QuickActionChip(action: quickActions[i], label: quickActions[i].label(l)),
      ),
    );
  }
}

class QuickActionChip extends StatelessWidget {
  const QuickActionChip({super.key, required this.action, required this.label});
  final QuickAction action;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(context, toolById(action.tool).category);
    return Center(
      child: Material(
        color: context.colors.surface,
        shape: StadiumBorder(side: BorderSide(color: context.colors.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(action.location);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: Space.x2),
                  Text(label, style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools, required this.cols, required this.keyOf, required this.wrap});
  final List<ToolDescriptor> tools;
  final int cols;
  final GlobalKey Function(ToolId) keyOf;
  final Widget Function(Widget) wrap;

  @override
  Widget build(BuildContext context) {
    // Never leave empty slots in a row: 3 tools on a 4-column tablet → 3 columns.
    final cols = math.min(this.cols, tools.length);
    // Equal-height rows; a lone card (odd last one, or one column) spans the
    // row in the horizontal layout.
    final rows = <List<ToolDescriptor>>[
      for (var i = 0; i < tools.length; i += cols) tools.sublist(i, (i + cols).clamp(0, tools.length)),
    ];
    Widget card(ToolDescriptor t, {bool wide = false}) => KeyedSubtree(
      key: keyOf(t.id),
      child: wrap(ToolCard(tool: t, wide: wide)),
    );
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : Space.x3),
            child: rows[r].length == 1
                ? card(rows[r].single, wide: true)
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < cols; i++) ...[
                          if (i > 0) const SizedBox(width: Space.x3),
                          Expanded(child: i < rows[r].length ? card(rows[r][i]) : const SizedBox()),
                        ],
                      ],
                    ),
                  ),
          ),
      ],
    );
  }
}

/// ToolCard v2 (UI_REFRESH §3): gradient tile, Jakarta title, press scale
/// 0.97 + light haptic. [wide] lays it out horizontally for a full-width row.
class ToolCard extends ConsumerStatefulWidget {
  const ToolCard({super.key, required this.tool, this.wide = false});
  final ToolDescriptor tool;
  final bool wide;

  @override
  ConsumerState<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends ConsumerState<ToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tool = widget.tool;
    final texts = [
      Text(tool.title(l), style: context.text.titleMedium),
      const SizedBox(height: 2),
      Text(
        tool.subtitle(l),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    ];
    final chevron = Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant);
    final pinned = ref.watch(favouritesProvider).contains(tool.id);
    return Semantics(
      button: true,
      label: '${tool.title(l)}. ${tool.subtitle(l)}',
      excludeSemantics: true,
      // FR-FAV-01: screen readers reach the long-press toggle as an action.
      customSemanticsActions: {
        CustomSemanticsAction(label: pinned ? l.favRemove : l.favAdd): () => toggleFavourite(context, ref, tool.id),
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: Motion.of(context, const Duration(milliseconds: 100)),
        child: Material(
          color: context.colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onHighlightChanged: (v) => setState(() => _pressed = v),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(tool.route);
            },
            onLongPress: () => showToolSheet(context, tool),
            child: Container(
              constraints: BoxConstraints(minHeight: widget.wide ? 96 : 136),
              padding: const EdgeInsets.all(Space.x4),
              child: widget.wide
                  ? Row(
                      children: [
                        GradientIconTile(icon: tool.icon, category: tool.category, size: 52),
                        const SizedBox(width: Space.x4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: texts,
                          ),
                        ),
                        chevron,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GradientIconTile(icon: tool.icon, category: tool.category, size: 52),
                            const Spacer(),
                            chevron,
                          ],
                        ),
                        const SizedBox(height: Space.x3),
                        ...texts,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// First Home build per launch: cards fade + slide up 12 dp, staggered 40 ms
/// (≤ 400 ms in total). Off with reduce-motion; never replays (UI_REFRESH §2.3).
class HomeEntrance extends StatefulWidget {
  const HomeEntrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  static bool _played = false;
  static bool shouldPlay(BuildContext context) {
    if (_played || MediaQuery.of(context).disableAnimations) {
      _played = true;
      return false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _played = true);
    return true;
  }

  @override
  State<HomeEntrance> createState() => _HomeEntranceState();
}

class _HomeEntranceState extends State<HomeEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: (widget.index * 40).clamp(0, 240));
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Motion.curve);
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(
      width: w,
      height: 12,
      decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(6)),
    );
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [bar(160), const SizedBox(height: 8), bar(100)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
