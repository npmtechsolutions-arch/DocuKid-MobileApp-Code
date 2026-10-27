import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ad_slots.dart';
import '../../core/ads/ads_controller.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_copy.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/operation/job_state.dart';
import '../../core/operation/jobs_controller.dart';
import '../../core/operation/tool_operation.dart';
import '../../core/pdf/image_to_pdf_builder.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/illustrations.dart';
import '../../core/widgets/pdf_thumbnail.dart';
import '../../data/settings/app_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../image_to_pdf/application/image_to_pdf_controller.dart';
import '../search/tool_catalog.dart';
import '../settings/remove_ads_sheet.dart';
import '../tools/tool_inputs.dart';
import 'job_visuals.dart';
import 'save_flow.dart';

String retentionPeriod(AppLocalizations l, Retention r) => switch (r) {
      Retention.h24 => l.periodH24,
      Retention.d7 => l.periodD7,
      Retention.d30 => l.periodD30,
      Retention.forever => l.periodForever,
    };

String stepLabel(AppLocalizations l, String key) => switch (key) {
      'stepReading' => l.stepReading,
      'stepCompressing' => l.stepCompressing,
      'stepResizing' => l.stepResizing,
      'stepBuildingPdf' => l.stepBuildingPdf,
      'stepMerging' => l.stepMerging,
      'stepSavingPages' => l.stepSavingPages,
      'stepOptimizing' => l.stepOptimizing,
      'stepChecking' => l.stepChecking,
      _ => l.stepPreparing,
    };

/// `/job/:jobId` — S10 Processing → S11 Result / S18 Error on one route.
class JobScreen extends ConsumerStatefulWidget {
  const JobScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends ConsumerState<JobScreen> {
  /// Last known job, so the screen doesn't flash "unavailable" while it
  /// animates out after the job is dismissed (Done / Back to tool).
  LiveJob? _last;

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobsProvider.select((m) => m[widget.jobId])) ?? _last;
    _last = job;
    ref.listen(jobsProvider.select((m) => m[widget.jobId]?.state), (prev, next) {
      if (next is JobCancelled) {
        final l = context.l10n;
        if (context.canPop()) context.pop();
        showAppSnack(context, l.cancelledSnack);
        ref.read(jobsProvider.notifier).dismiss(widget.jobId);
      } else if (next is JobCompleted && prev is! JobCompleted) {
        HapticFeedback.lightImpact();
        final l = context.l10n;
        SemanticsService.sendAnnouncement(
          View.of(context),
          '${l.resultDone}. ${l.resultA11ySummary(sizeForA11y(l, next.result.inputBytes), sizeForA11y(l, next.result.meta.bytes))}',
          Directionality.of(context),
        );
      }
    });
    if (job == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(context.l10n.itemUnavailable)));
    }
    final state = job.state;
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium),
      child: switch (state) {
        JobCompleted(:final result) => _ResultView(key: const ValueKey('result'), job: job, result: result),
        JobFailed(:final error) => _ErrorView(key: const ValueKey('error'), job: job, error: error),
        _ => _ProcessingView(key: const ValueKey('processing'), job: job),
      },
    );
  }
}

// ---------------------------------------------------------------- S10

class _ProcessingView extends ConsumerStatefulWidget {
  const _ProcessingView({super.key, required this.job});
  final LiveJob job;

  @override
  ConsumerState<_ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends ConsumerState<_ProcessingView> {
  DateTime _lastAnnounce = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastPct = -100;

  Future<void> _confirmCancel() async {
    final l = context.l10n;
    final yes = await askAdaptive(
      context,
      title: l.cancelConfirmTitle,
      body: l.cancelConfirmBody,
      no: l.cancelConfirmKeep,
      yes: l.cancelConfirmYes,
    );
    if (yes) ref.read(jobsProvider.notifier).cancel(widget.job.id);
  }

  void _announce(String text, double? fraction) {
    final now = DateTime.now();
    final pct = fraction == null ? -1 : (fraction * 100).round();
    if (now.difference(_lastAnnounce) < const Duration(seconds: 5) && (pct - _lastPct).abs() < 10) return;
    _lastAnnounce = now;
    _lastPct = pct;
    SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = widget.job.state;
    final progress = s is JobProcessing ? s.progress : null;
    final step = switch (s) {
      JobValidatingOutput() => l.stepChecking,
      JobProcessing(:final progress) => stepLabel(l, progress.stepKey),
      _ => l.stepPreparing,
    };
    String? count;
    double? fraction;
    if (progress is Determinate && progress.total > 0) {
      final done = (progress.done + 1).clamp(1, progress.total);
      count = switch (progress.unit) {
        ProgressUnit.pages => l.progressPages(done, progress.total),
        ProgressUnit.images => l.progressImages(done, progress.total),
        ProgressUnit.files => l.progressFiles(done, progress.total),
      };
      fraction = progress.done / progress.total;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _announce(count == null ? step : '$step $count', fraction);
    });
    final tool = toolById(widget.job.tool);
    final accent = accentFor(context, tool.category);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(tooltip: l.jobCancelTooltip, icon: const Icon(Icons.close_rounded), onPressed: _confirmCancel),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.x6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        color: accent,
                      ),
                    ),
                    ToolGlyph(tool: tool),
                  ]),
                ),
                const SizedBox(height: Space.x6),
                Text(step, style: context.text.titleLarge, textAlign: TextAlign.center),
                if (count != null) ...[
                  const SizedBox(height: Space.x2),
                  Text(count, style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant)),
                ],
                const SizedBox(height: Space.x4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_rounded, size: 14, color: context.docu.success),
                  const SizedBox(width: Space.x1),
                  Text(l.jobOnDevice, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                ]),
                const SizedBox(height: Space.x6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TipCard(seed: widget.job.id.hashCode),
                ),
                if (widget.job.isLarge) ...[
                  const SizedBox(height: Space.x6),
                  InlineBanner(kind: BannerKind.info, text: l.keepOpen),
                ],
                const SizedBox(height: Space.x6),
                if (s is! JobValidatingOutput) TextButton(onPressed: _confirmCancel, child: Text(l.actionCancel)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- S11

class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({super.key, required this.job, required this.result});
  final LiveJob job;
  final JobResult result;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  final _shareKey = GlobalKey();
  final _openKey = GlobalKey();
  bool _keptAnyway = false;
  bool? _celebrate;
  bool _scrolled = false;

  JobResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    // AD-8 link under AD-2 appears only once a rewarded ad is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adsControllerProvider.notifier).preloadRewarded();
    });
  }

  Future<void> _rename() async {
    final name = await renameDialog(context, currentName: r.outputName);
    if (name == null || name == r.outputName) return;
    final outputs = ref.read(outputsRepositoryProvider);
    final rec = await ref.read(historyRepositoryProvider).get(r.jobId);
    final rel = rec?.row.outputRelPath;
    if (rel == null) return;
    final (abs, newRel) = await outputs.rename(rel, name);
    await ref.read(historyRepositoryProvider).rename(r.jobId, name: abs.split(Platform.pathSeparator).last, relPath: newRel);
    ref.read(jobsProvider.notifier).updateResult(r.jobId, r.renamed(abs, abs.split(Platform.pathSeparator).last));
  }

  Future<void> _discard() async {
    final l = context.l10n;
    await ref.read(outputsRepositoryProvider).deleteFor(r.jobId);
    await ref.read(historyRepositoryProvider).markOutputDeleted(r.jobId, ref.read(clockProvider)());
    if (!mounted) return;
    ref.read(jobsProvider.notifier).dismiss(r.jobId);
    if (context.canPop()) context.pop();
    showAppSnack(context, l.discardedSnack);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final retention = ref.watch(settingsProvider.select((s) => s.outputRetention));
    final isPdf = r.mime == 'application/pdf';
    final notSmaller = r.notSmaller && !_keptAnyway && (r.tool == ToolId.imageCompress || r.tool == ToolId.pdfCompress);
    final showSizes = r.tool == ToolId.imageCompress || r.tool == ToolId.pdfCompress || r.tool == ToolId.imageResize;

    final meta = <String>[
      if (r.inputWidth != null && r.meta.width != null)
        '${l.metaDims(r.inputWidth!, r.inputHeight!)} → ${l.metaDims(r.meta.width!, r.meta.height!)}',
      if (r.meta.pages != null) l.metaPages(r.meta.pages!),
      if (r.meta.flags['format'] case final String f)
        switch (f) {
          'png' => l.fmtPng,
          'webp' => l.fmtWebp,
          'heic' => l.fmtHeic,
          _ => l.fmtJpeg,
        },
      if (r.meta.flags['quality'] case final int q when r.isImage) 'q$q',
      if (!showSizes) formatBytes(r.meta.bytes),
    ].join(' · ');

    final saved = r.inputBytes <= 0 ? 0 : (r.inputBytes - r.meta.bytes) / r.inputBytes;
    // Decided once per Result, so rebuilds don't cut the burst short.
    final celebrate = _celebrate ??= () {
      final yes = showSizes && saved >= 0.5 && !MediaQuery.of(context).disableAnimations && !_celebratedThisSession;
      if (yes) _celebratedThisSession = true;
      return yes;
    }();
    final sizeLine = r.meta.width != null
        ? l.metaDims(r.meta.width!, r.meta.height!)
        : (r.meta.pages != null ? l.metaPages(r.meta.pages!) : null);
    final summary = r.meta.bytes < r.inputBytes
        ? '${l.resultA11ySummary(sizeForA11y(l, r.inputBytes), sizeForA11y(l, r.meta.bytes))} '
            '${l.resultSmaller(percentChange(r.inputBytes, r.meta.bytes).abs())}'
        : l.resultA11ySummary(sizeForA11y(l, r.inputBytes), sizeForA11y(l, r.meta.bytes));

    Widget sizeRow(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x1),
          child: Row(children: [
            Expanded(child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant))),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: (strong ? context.text.titleMedium : context.text.bodyLarge)
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ]),
        );

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
              onPressed: () {
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
              },
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
                  child: Text(isPdf ? l.resultDonePdf : l.resultDoneImage,
                      style: context.text.titleLarge?.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: Space.x1),
                Text(l.resultChecked, style: context.text.bodyMedium?.copyWith(color: Colors.white)),
              ]),
            ),
          ]),
        ]),
      ),
    );

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnnotatedRegion(
        value: _scrolled && !dark ? darkOverlay : lightOverlay,
        child: Stack(children: [
          NotificationListener<ScrollUpdateNotification>(
            onNotification: (n) {
              // Content must never run under the status bar icons (as on Home).
              final past = n.metrics.pixels > 4;
              if (past != _scrolled) setState(() => _scrolled = past);
              return false;
            },
            child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Space.x8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header,
              ContentWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: Space.x4),
                  if (showSizes)
                    Semantics(
                      liveRegion: true,
                      label: summary,
                      excludeSemantics: true,
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
                        child: Padding(
                          padding: const EdgeInsets.all(Space.x4),
                          child: Row(children: [
                            SavingsRing(before: r.inputBytes, after: r.meta.bytes),
                            const SizedBox(width: Space.x5),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                sizeRow(l.resultBefore, formatBytes(r.inputBytes)),
                                sizeRow(l.resultAfter, formatBytes(r.meta.bytes), strong: true),
                                if (sizeLine != null) sizeRow(l.resultSize, sizeLine),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  const SizedBox(height: Space.x4),
                  Semantics(
                    label: l.resultPreviewA11y,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.card),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          color: context.colors.surfaceContainer,
                          child: isPdf
                              ? Stack(children: [
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(Space.x4),
                                      child: PdfThumbnail(path: r.outputPath, pageIndex: 0, width: 180, elevated: true),
                                    ),
                                  ),
                                  if (r.meta.pages != null)
                                    PositionedDirectional(
                                      top: Space.x3,
                                      end: Space.x3,
                                      child: Chip(
                                        avatar: const Icon(Icons.description_outlined, size: 16),
                                        label: Text(l.metaPages(r.meta.pages!)),
                                      ),
                                    ),
                                ])
                              : _ImagePreview(before: r.firstInputPath, after: r.outputPath),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x4),
                  Row(children: [
                    Expanded(child: MiddleEllipsisText(r.outputName, style: context.text.titleMedium)),
                    IconButton(tooltip: l.actionRename, icon: const Icon(Icons.edit_outlined), onPressed: _rename),
                  ]),
                  if (meta.isNotEmpty)
                    Text(meta, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                  if (notSmaller) ...[
                    const SizedBox(height: Space.x4),
                    InlineBanner(
                      kind: BannerKind.warning,
                      text: r.tool == ToolId.pdfCompress ? l.resultNotSmallerPdf : l.resultNotSmallerImg,
                      actions: r.tool == ToolId.pdfCompress
                          ? [
                              TextButton(onPressed: () => setState(() => _keptAnyway = true), child: Text(l.actionKeepAnyway)),
                              FilledButton.tonal(onPressed: _discard, child: Text(l.actionDiscard)),
                            ]
                          : [
                              TextButton(onPressed: _discard, child: Text(l.resultKeepOriginal)),
                              FilledButton.tonal(onPressed: () => context.pop(), child: Text(l.resultTryLower)),
                            ],
                    ),
                  ],
                  if (r.targetMissed && r.targetBytes != null) ...[
                    const SizedBox(height: Space.x4),
                    InlineBanner(
                      kind: BannerKind.info,
                      text: l.resultTargetMissed(formatBytes(r.meta.bytes), formatBytes(r.targetBytes!)),
                    ),
                  ],
                  const SizedBox(height: Space.x5),
                  // UI_REFRESH §6: 2×2 grid of large tonal actions.
                  Row(children: [
                    Expanded(
                      child: ResultActionButton(
                        primary: true,
                        icon: Icons.download_rounded,
                        label: l.actionSave,
                        onPressed: () =>
                            saveResult(context, ref, path: r.outputPath, name: r.outputName, mime: r.mime, opId: r.jobId),
                      ),
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Builder(
                        key: _shareKey,
                        builder: (anchor) => ResultActionButton(
                          icon: Icons.ios_share_rounded,
                          label: l.actionShare,
                          onPressed: () => shareResult(anchor, ref, path: r.outputPath, mime: r.mime),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: Space.x3),
                  Row(children: [
                    Expanded(
                      child: Builder(
                        key: _openKey,
                        builder: (anchor) => ResultActionButton(
                          icon: Icons.open_in_new_rounded,
                          label: l.actionOpenWith,
                          onPressed: () => openWithResult(anchor, ref, path: r.outputPath, mime: r.mime),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: ResultActionButton(
                        icon: Icons.tune_rounded,
                        label: l.resultEditOptions,
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ]),
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
                  // AD-2: not on the "result is larger" warning state.
                  if (!notSmaller)
                    ResultAdSlot(
                      onRemoveAds: () => showRemoveAdsSheet(context),
                      onWatchReward: () =>
                          watchRewardedAd(ProviderScope.containerOf(context), ScaffoldMessenger.of(context), l),
                    ),
                ]),
              ),
            ]),
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
          if (celebrate) const Positioned.fill(child: ConfettiBurst()),
        ]),
      ),
    );
  }
}

/// UI_REFRESH §6: the celebration plays at most once per app session.
bool _celebratedThisSession = false;

/// FR-IMG-10: draggable before/after split at the same zoom.
class _ImagePreview extends StatefulWidget {
  const _ImagePreview({required this.before, required this.after});
  final String? before;
  final String after;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasBefore = widget.before != null && File(widget.before!).existsSync();
    Widget img(String path) => Image.file(File(path), fit: BoxFit.contain, cacheWidth: 1600, gaplessPlayback: true);
    if (!hasBefore) return Checkerboard(child: InteractiveViewer(maxScale: 5, child: Center(child: img(widget.after))));
    return LayoutBuilder(builder: (context, c) {
      return GestureDetector(
        onHorizontalDragUpdate: (d) => setState(() => _split = (_split + d.delta.dx / c.maxWidth).clamp(0.0, 1.0)),
        child: Semantics(
          label: l.resultCompareA11y,
          slider: true,
          value: '${(_split * 100).round()}%',
          onIncrease: () => setState(() => _split = (_split + 0.1).clamp(0.0, 1.0)),
          onDecrease: () => setState(() => _split = (_split - 0.1).clamp(0.0, 1.0)),
          child: Checkerboard(
            child: Stack(fit: StackFit.expand, children: [
              Center(child: img(widget.after)),
              ClipRect(
                clipper: _LeftClipper(_split),
                child: Container(color: context.colors.surfaceContainer, child: Center(child: img(widget.before!))),
              ),
              Positioned(
                left: c.maxWidth * _split - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              Positioned(
                left: c.maxWidth * _split - 18,
                top: c.maxHeight / 2 - 18,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, color: Colors.black87),
                ),
              ),
              PositionedDirectional(start: Space.x3, top: Space.x3, child: _Tag(l.resultBefore)),
              PositionedDirectional(end: Space.x3, top: Space.x3, child: _Tag(l.resultAfter)),
            ]),
          ),
        ),
      );
    });
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.f);
  final double f;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * f, size.height);
  @override
  bool shouldReclip(_LeftClipper old) => old.f != f;
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(Radii.full)),
        child: Text(text, style: context.text.labelSmall?.copyWith(color: Colors.white)),
      );
}

// ---------------------------------------------------------------- S18

class _ErrorView extends ConsumerWidget {
  const _ErrorView({super.key, required this.job, required this.error});
  final LiveJob job;
  final AppError error;

  void _act(BuildContext context, WidgetRef ref, ErrorAction a) {
    final jobs = ref.read(jobsProvider.notifier);
    switch (a) {
      case ErrorAction.tryAgain:
        try {
          final id = job.restart();
          jobs.dismiss(job.id);
          context.pushReplacement('/job/$id');
        } on JobBusyException {
          showAppSnack(context, context.l10n.busySnack);
        }
      case ErrorAction.backToTool:
        jobs.dismiss(job.id);
        if (context.canPop()) context.pop();
      case ErrorAction.chooseAnother:
        jobs.dismiss(job.id);
        if (context.canPop()) context.pop();
        final single = toolById(job.tool).maxInputs == 1;
        ref.read(toolInputsProvider(job.tool).notifier).pick(replace: single);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final copy = errorCopy(l, error);
    final itemFailed = error is ImageItemFailed ? error as ImageItemFailed : null;
    final severe = error.code == AppErrorCode.outputValidationFailed || error.code == AppErrorCode.processingFailed;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.backToTool,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _act(context, ref, ErrorAction.backToTool),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.x6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (error.code != AppErrorCode.encryptedDocument)
                  const Center(child: Illustration(kind: IllustrationKind.error, size: 132))
                else
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: severe ? context.colors.errorContainer : context.docu.warningContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      error.code == AppErrorCode.encryptedDocument ? Icons.lock_rounded : Icons.warning_amber_rounded,
                      size: 44,
                      color: severe ? context.colors.error : context.docu.warning,
                    ),
                  ),
                ),
                const SizedBox(height: Space.x6),
                Semantics(
                  liveRegion: true,
                  child: Text(copy.title, style: context.text.headlineSmall, textAlign: TextAlign.center),
                ),
                const SizedBox(height: Space.x3),
                Text(copy.body, style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
                if (error.fileDisplayName != null) ...[
                  const SizedBox(height: Space.x3),
                  Text(l.errFileLabel(error.fileDisplayName!), style: context.text.bodyMedium, textAlign: TextAlign.center),
                ],
                const SizedBox(height: Space.x8),
                if (itemFailed != null && job.tool == ToolId.imageToPdf)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.x3),
                    child: FilledButton(
                      onPressed: () {
                        ref.read(jobsProvider.notifier).dismiss(job.id);
                        ref.read(toolInputsProvider(ToolId.imageToPdf).notifier).remove(itemFailed.index);
                        ref.read(imageToPdfAutoRunProvider.notifier).request();
                        if (context.canPop()) context.pop();
                      },
                      child: Text(l.i2pRemoveAndContinue),
                    ),
                  ),
                FilledButton(onPressed: () => _act(context, ref, copy.primary), child: Text(errorActionLabel(l, copy.primary))),
                if (copy.secondary != null) ...[
                  const SizedBox(height: Space.x3),
                  OutlinedButton(onPressed: () => _act(context, ref, copy.secondary!), child: Text(errorActionLabel(l, copy.secondary!))),
                ],
                const SizedBox(height: Space.x6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: context.docu.success),
                  const SizedBox(width: Space.x2),
                  Flexible(child: Text(l.originalUnchanged, style: context.text.bodyMedium)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
