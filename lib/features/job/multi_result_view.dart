import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ad_slots.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/ads_controller.dart';
import '../../core/ads/bottom_banner.dart';
import '../../core/files/paths.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/operation/job_state.dart';
import '../../core/operation/jobs_controller.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/settings/app_settings.dart';
import '../settings/remove_ads_sheet.dart';
import 'job_screen.dart' show retentionPeriod;
import 'job_visuals.dart';
import 'multi_outputs.dart';
import 'save_flow.dart';

/// S22 · Multi-result (RELEASE_V1_1 §3): header, totals, Save all / Save as
/// ZIP / Share all, the file list, AD-2 and ADMOB_BANNER_MAIN. Done follows
/// AD-3; the whole batch counts as one job (ADR-040).
class MultiResultView extends ConsumerStatefulWidget {
  const MultiResultView({super.key, required this.job, required this.result});
  final LiveJob job;
  final MultiJobResult result;

  @override
  ConsumerState<MultiResultView> createState() => _MultiResultViewState();
}

class _MultiResultViewState extends ConsumerState<MultiResultView> {
  /// Outputs discarded from this screen (their files are already deleted).
  final _discarded = <int>{};
  bool _scrolled = false;

  MultiJobResult get r => widget.result;

  List<OutputEntry> get _entries => [
        for (final item in r.output.items)
          if (!_discarded.contains(item.index)) OutputEntry.fromItem(item),
      ];

  @override
  void initState() {
    super.initState();
    // AD-8 link under AD-2 appears only once a rewarded ad is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adsControllerProvider.notifier).preloadRewarded();
    });
  }

  Future<void> _discard(OutputEntry e) async {
    await deleteQuietly(File(e.path!));
    await ref.read(historyRepositoryProvider).markItemDiscarded(r.jobId, e.index);
    await forgetZip(ref, r.jobId);
    if (!mounted) return;
    setState(() => _discarded.add(e.index));
    showAppSnack(context, context.l10n.discardedSnack);
  }

  void _done() {
    final jobs = ref.read(jobsProvider.notifier);
    final router = GoRouter.of(context);
    // AD-3: may show a capped interstitial first, then goes Home.
    ref.read(adsControllerProvider.notifier).onResultDone(
      tourDone: ref.read(settingsProvider).tourDone,
      navigate: () {
        router.go('/');
        jobs.dismiss(r.jobId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final retention = ref.watch(settingsProvider.select((s) => s.outputRetention));
    final entries = _entries;
    final total = r.output.items.length;
    final failed = r.output.failed;
    final title = failed == 0 ? l.multiHeaderAll : l.multiHeaderSome(total - failed, total);
    final beforeAfter = multiBeforeAfter(entries);
    final hasFiles = entries.any((e) => e.ok);
    final top = MediaQuery.viewPaddingOf(context).top;

    final header = Container(
      decoration: BoxDecoration(
        gradient: context.docu.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.hero)),
      ),
      padding: EdgeInsets.only(top: top, bottom: Space.x6),
      child: ContentWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(64, 48)),
              onPressed: _done,
              child: Text(l.actionDone),
            ),
          ),
          Row(children: [
            const AnimatedCheck(),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.text.titleLarge?.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: Space.x1),
                Text(l.resultChecked, style: context.text.bodyMedium?.copyWith(color: Colors.white)),
              ]),
            ),
          ]),
        ]),
      ),
    );

    final totals = Semantics(
      liveRegion: true,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Row(children: [
            if (beforeAfter != null) ...[
              SavingsRing(before: beforeAfter.$1, after: beforeAfter.$2),
              const SizedBox(width: Space.x5),
            ],
            Expanded(child: Text(multiTotalsLine(context, entries), style: context.text.titleMedium)),
          ]),
        ),
      ),
    );

    final actions = Column(children: [
      Row(children: [
        Expanded(
          child: ResultActionButton(
            primary: true,
            icon: Icons.download_rounded,
            label: l.multiSaveAll,
            onPressed: hasFiles ? () => saveAllOutputs(context, ref, opId: r.jobId, entries: entries) : null,
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: ResultActionButton(
            icon: Icons.folder_zip_outlined,
            label: l.multiSaveZip,
            onPressed: hasFiles ? () => saveOutputsAsZip(context, ref, opId: r.jobId, tool: r.tool, entries: entries) : null,
          ),
        ),
      ]),
      const SizedBox(height: Space.x3),
      Row(children: [
        Expanded(
          child: Builder(
            builder: (anchor) => ResultActionButton(
              icon: Icons.ios_share_rounded,
              label: l.multiShareAll,
              onPressed: hasFiles ? () => shareAllOutputs(anchor, ref, opId: r.jobId, tool: r.tool, entries: entries) : null,
            ),
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: ResultActionButton(icon: Icons.tune_rounded, label: l.resultEditOptions, onPressed: () => context.pop()),
        ),
      ]),
    ]);

    Widget padded(Widget child) => SliverToBoxAdapter(child: ContentWidth(child: child));
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AppBottomBanner(
      unit: AdUnit.bannerMain,
      child: Scaffold(
        body: AnnotatedRegion(
          value: _scrolled && !dark ? darkOverlay : lightOverlay,
          child: Stack(children: [
            NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                final past = n.metrics.pixels > 4;
                if (past != _scrolled) setState(() => _scrolled = past);
                return false;
              },
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: header),
                padded(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: Space.x4),
                  totals,
                  const SizedBox(height: Space.x5),
                  actions,
                  SectionHeader(l.multiFilesHeader),
                ])),
                // Lazy: a batch can hold hundreds of files (Split "each page").
                SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return ContentWidth(
                      child: OutputRow(
                        key: ValueKey('output-${e.index}'),
                        entry: e,
                        onOpen: (anchor) => openWithResult(anchor, ref, path: e.path!, mime: e.mime),
                        onShare: (anchor) => shareResult(anchor, ref, path: e.path!, mime: e.mime),
                        onSave: () => saveResult(context, ref, path: e.path!, name: e.name, mime: e.mime, opId: r.jobId),
                        onDiscard: () => _discard(e),
                      ),
                    );
                  },
                ),
                padded(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: Space.x6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.schedule_rounded, size: 16, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: Space.x1),
                    Flexible(
                      child: Text(
                        retention == Retention.forever
                            ? l.resultRetentionForever
                            : l.resultRetention(retentionPeriod(l, retention)),
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ]),
                  const SizedBox(height: Space.x2),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.verified_user_outlined, size: 16, color: context.docu.success),
                    const SizedBox(width: Space.x1),
                    Flexible(
                      child: Text(l.originalUnchanged,
                          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                    ),
                  ]),
                  // AD-2: same rules as S11.
                  ResultAdSlot(
                    onRemoveAds: () => showRemoveAdsSheet(context),
                    onWatchReward: () =>
                        watchRewardedAd(ProviderScope.containerOf(context), ScaffoldMessenger.of(context), l),
                  ),
                  const SizedBox(height: Space.x8),
                ])),
              ]),
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
          ]),
        ),
      ),
    );
  }
}

/// Screen-reader summary when a multi job finishes.
String multiDoneAnnouncement(BuildContext context, MultiJobResult r) {
  final l = context.l10n;
  final total = r.output.items.length;
  final title = r.output.failed == 0 ? l.multiHeaderAll : l.multiHeaderSome(total - r.output.failed, total);
  return '$title. ${formatBytes(r.output.outputBytes)}';
}
