import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/sweeps.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ads/ad_slots.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/ads/ads_controller.dart';
import '../../../core/ads/bottom_banner.dart';
import '../../../core/files/paths.dart';
import '../../../core/operation/job_state.dart';
import '../../../core/operation/jobs_controller.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pdf_thumbnail.dart';
import '../../../data/library/library_repository.dart';
import '../../../data/settings/app_settings.dart';
import '../../job/job_screen.dart' show retentionPeriod;
import '../../job/job_visuals.dart';
import '../../job/multi_outputs.dart';
import '../../job/save_flow.dart';
import '../../library/application/add_to_library.dart';
import '../../search/tool_catalog.dart';
import '../../settings/remove_ads_sheet.dart';
import '../application/ocr_review_controller.dart';

/// S32 · Result for Text Recognition (RELEASE_V1_3 §3.4): the first page
/// (or the first lines of text), "{pages} pages · {words} words found",
/// Review text and Copy text (FR-OCR-16), and each file with Save / Share /
/// Open with. Ads as S11/S22: AD-2, AD-3 on Done, the Main banner. Leaving
/// this screen deletes the job's review text (ADR-066).
class OcrResultView extends ConsumerStatefulWidget {
  const OcrResultView({super.key, required this.job, required this.result});
  final LiveJob job;
  final MultiJobResult result;

  @override
  ConsumerState<OcrResultView> createState() => _OcrResultViewState();
}

class _OcrResultViewState extends ConsumerState<OcrResultView> {
  final _discarded = <int>{};
  late final AppPaths _paths;

  MultiJobResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    _paths = ref.read(appPathsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adsControllerProvider.notifier).preloadRewarded();
    });
  }

  @override
  void dispose() {
    // Back, Done or Edit options: the review text goes with this screen.
    unawaited(deleteReview(_paths, r.jobId));
    super.dispose();
  }

  List<OutputEntry> get _entries => [
        for (final item in r.output.items)
          if (!_discarded.contains(item.index)) OutputEntry.fromItem(item),
      ];

  String? get _reviewDir => r.reviewAvailable ? _paths.reviewDir(r.jobId).path : null;

  Future<void> _discard(OutputEntry e) async {
    await deleteQuietly(File(e.path!));
    await ref.read(historyRepositoryProvider).markItemDiscarded(r.jobId, e.index);
    if (!mounted) return;
    setState(() => _discarded.add(e.index));
    showAppSnack(context, context.l10n.discardedSnack);
  }

  Future<void> _copyText(String? txtPath) async {
    final text = await ocrTextForCopy(reviewDir: _reviewDir, txtPath: txtPath);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showAppSnack(context, context.l10n.ocrCopied);
  }

  void _done() {
    final jobs = ref.read(jobsProvider.notifier);
    final router = GoRouter.of(context);
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
    final pdf = entries.where((e) => e.ok && e.mime == 'application/pdf').firstOrNull;
    final txt = entries.where((e) => e.ok && e.mime == 'text/plain').firstOrNull;
    final pages = r.stats['pages'] as int? ?? 0;
    final words = r.stats['words'] as int? ?? 0;
    final low = r.stats['lowTextPages'] as int? ?? 0;
    final hasText = r.reviewAvailable || txt != null;
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
                Semantics(header: true, child: Text(l.resultDone, style: context.text.titleLarge?.copyWith(color: Colors.white))),
                const SizedBox(height: Space.x1),
                Text(l.resultChecked, style: context.text.bodyMedium?.copyWith(color: Colors.white)),
              ]),
            ),
          ]),
        ]),
      ),
    );

    final stats = Semantics(
      liveRegion: true,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: l.ocrResultStats(pages, words)),
          if (low > 0) ...[
            const TextSpan(text: ' · '),
            TextSpan(text: l.ocrResultLowPages(low), style: TextStyle(color: context.docu.warning)),
          ],
        ]),
        style: context.text.titleMedium,
      ),
    );

    final preview = pdf != null
        ? Center(child: PdfThumbnail(path: pdf.path!, pageIndex: 0, width: 180, elevated: true))
        : hasText
            ? Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(Space.x4),
                  child: ref.watch(ocrTextPreviewProvider((reviewDir: _reviewDir, txtPath: txt?.path))).when(
                        data: (t) => Text(t, maxLines: 6, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                        loading: () => const SizedBox(height: 60),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                ),
              )
            : const SizedBox.shrink();

    final actions = Row(children: [
      if (r.reviewAvailable) ...[
        Expanded(
          child: ResultActionButton(
            primary: true,
            icon: Icons.article_outlined,
            label: l.ocrReview,
            onPressed: () => context.push('/job/${r.jobId}/text'),
          ),
        ),
        const SizedBox(width: Space.x3),
      ],
      if (hasText)
        Expanded(
          child: ResultActionButton(
            primary: !r.reviewAvailable,
            icon: Icons.copy_rounded,
            label: l.ocrCopyText,
            onPressed: () => _copyText(txt?.path),
          ),
        ),
    ]);

    Widget padded(Widget child) => SliverToBoxAdapter(child: ContentWidth(child: child));

    return AppBottomBanner(
      unit: AdUnit.bannerMain,
      child: Scaffold(
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: header),
          padded(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: Space.x4),
            stats,
            if (pages > 0 && low == pages) ...[
              const SizedBox(height: Space.x3),
              InlineBanner(kind: BannerKind.warning, text: l.ocrLowTextAll),
            ],
            const SizedBox(height: Space.x4),
            preview,
            const SizedBox(height: Space.x5),
            if (hasText) actions,
            if (entries.isNotEmpty) SectionHeader(l.multiFilesHeader),
          ])),
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
                  // The searchable PDF only: a .txt isn't a library document.
                  onSaveToLibrary: e.mime == 'application/pdf'
                      ? () => saveToLibrary(context, ref, path: e.path!, name: e.name, mime: e.mime, source: DocSource.result, sourceTool: ToolId.ocr)
                      : null,
                  onDiscard: () => _discard(e),
                ),
              );
            },
          ),
          padded(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: Space.x6),
            if (entries.isNotEmpty)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.schedule_rounded, size: 16, color: context.colors.onSurfaceVariant),
                const SizedBox(width: Space.x1),
                Flexible(
                  child: Text(
                    retention == Retention.forever ? l.resultRetentionForever : l.resultRetention(retentionPeriod(l, retention)),
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ]),
            const SizedBox(height: Space.x2),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.verified_user_outlined, size: 16, color: context.docu.success),
              const SizedBox(width: Space.x1),
              Flexible(
                child: Text(l.originalUnchanged, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ),
            ]),
            ResultAdSlot(
              onRemoveAds: () => showRemoveAdsSheet(context),
              onWatchReward: () => watchRewardedAd(ProviderScope.containerOf(context), ScaffoldMessenger.of(context), l),
            ),
            const SizedBox(height: Space.x8),
          ])),
        ]),
      ),
    );
  }
}

/// Screen-reader summary when an OCR job finishes.
String ocrDoneAnnouncement(BuildContext context, MultiJobResult r) {
  final l = context.l10n;
  return '${l.resultDone}. ${l.ocrResultStats(r.stats['pages'] as int? ?? 0, r.stats['words'] as int? ?? 0)}';
}
