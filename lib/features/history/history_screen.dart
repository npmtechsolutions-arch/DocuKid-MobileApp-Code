import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ad_policy.dart';
import '../../core/ads/ad_slots.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/bottom_banner.dart';
import '../../core/formatting/date_format.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/illustrations.dart';
import '../../data/repositories/history_repository.dart';
import '../job/job_screen.dart' show retentionPeriod;
import 'history_providers.dart';

class HistoryQuery {
  const HistoryQuery({this.filter = HistoryFilter.all, this.sort = HistorySort.newest, this.limit = 50, this.completedOnly = false});
  final HistoryFilter filter;
  final HistorySort sort;
  final int limit;
  final bool completedOnly;

  HistoryQuery copyWith({HistoryFilter? filter, HistorySort? sort, int? limit, bool? completedOnly}) => HistoryQuery(
        filter: filter ?? this.filter,
        sort: sort ?? this.sort,
        limit: limit ?? this.limit,
        completedOnly: completedOnly ?? this.completedOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is HistoryQuery &&
      other.filter == filter &&
      other.sort == sort &&
      other.limit == limit &&
      other.completedOnly == completedOnly;

  @override
  int get hashCode => Object.hash(filter, sort, limit, completedOnly);
}

final historyPageProvider = StreamProvider.autoDispose.family<List<OperationRecord>, HistoryQuery>(
  (ref, q) => ref.watch(historyRepositoryProvider).watchPage(
        limit: q.limit,
        filter: q.filter,
        sort: q.sort,
        onlyCompleted: q.completedOnly,
      ),
);

/// S14 · Recent activity.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  var _q = const HistoryQuery();

  Future<void> _clear() async {
    final l = context.l10n;
    final (ok, alsoFiles) = await confirmDestructive(
      context,
      title: l.histClearTitle,
      body: l.histClearBody,
      confirmLabel: l.histClearOk,
      checkboxLabel: l.histClearAlsoFiles,
    );
    if (!ok) return;
    if (alsoFiles) await ref.read(outputsRepositoryProvider).deleteAll();
    await ref.read(historyRepositoryProvider).clear();
    if (mounted) showAppSnack(context, l.setHistoryCleared);
  }

  Future<void> _sortSheet() async {
    final l = context.l10n;
    var sort = _q.sort;
    var completed = _q.completedOnly;
    var failed = _q.filter == HistoryFilter.failed;
    final apply = await showAppSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget radio(String label, bool selected, VoidCallback onTap) => ListTile(
              leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? ctx.colors.primary : null),
              title: Text(label),
              onTap: onTap,
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.x2, 0, Space.x2, Space.x4),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: Text(l.histSortTitle, style: ctx.text.titleLarge)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: SectionHeader(l.histSortLabel, top: Space.x4)),
            radio(l.histSortNewest, sort == HistorySort.newest, () => setS(() => sort = HistorySort.newest)),
            radio(l.histSortOldest, sort == HistorySort.oldest, () => setS(() => sort = HistorySort.oldest)),
            radio(l.histSortSaving, sort == HistorySort.saving, () => setS(() => sort = HistorySort.saving)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: SectionHeader(l.histStatusLabel, top: Space.x2)),
            radio(l.histStatusAll, !completed && !failed, () => setS(() {
                  completed = false;
                  failed = false;
                })),
            radio(l.histStatusCompleted, completed, () => setS(() {
                  completed = true;
                  failed = false;
                })),
            radio(l.histStatusFailed, failed, () => setS(() {
                  failed = true;
                  completed = false;
                })),
            const SizedBox(height: Space.x2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.actionApply)),
            ),
          ]),
        );
      }),
    );
    if (apply == true) {
      setState(() => _q = _q.copyWith(
            sort: sort,
            completedOnly: completed,
            filter: failed ? HistoryFilter.failed : (_q.filter == HistoryFilter.failed ? HistoryFilter.all : _q.filter),
          ));
    }
  }

  Future<void> _remove(OperationRecord r) async {
    final l = context.l10n;
    // Soft-remove with undo: delete the row after the snackbar closes.
    final history = ref.read(historyRepositoryProvider);
    final outputs = ref.read(outputsRepositoryProvider);
    var undone = false;
    _hidden.add(r.id);
    setState(() {});
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    final ctrl = m.showSnackBar(SnackBar(
      content: Text(l.histRemovedUndo),
      action: SnackBarAction(label: l.actionUndo, onPressed: () => undone = true),
    ));
    await ctrl.closed;
    if (undone) {
      if (mounted) setState(() => _hidden.remove(r.id));
      return;
    }
    await outputs.deleteFor(r.id);
    await history.remove(r.id);
    _hidden.remove(r.id);
  }

  final _hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final page = ref.watch(historyPageProvider(_q));
    final retention = ref.watch(settingsProvider.select((s) => s.outputRetention));
    final now = ref.watch(clockProvider)();

    Widget filterChip(String label, HistoryFilter f) => FilterChip(
          label: Text(label),
          selected: _q.filter == f,
          showCheckmark: false,
          onSelected: (_) => setState(() => _q = _q.copyWith(filter: f, limit: 50)),
        );

    return AppBottomBanner(unit: AdUnit.bannerMain, child: Scaffold(
      appBar: AppBar(
        title: Text(l.histTitle),
        actions: [
          IconButton(tooltip: l.histSortTooltip, icon: const Icon(Icons.sort_rounded), onPressed: _sortSheet),
          IconButton(tooltip: l.histClearTooltip, icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clear),
        ],
      ),
      body: ContentWidth(
        padded: false,
        child: Column(children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x2),
              children: [
                filterChip(l.histFilterAll, HistoryFilter.all),
                const SizedBox(width: Space.x2),
                filterChip(l.histFilterImages, HistoryFilter.images),
                const SizedBox(width: Space.x2),
                filterChip(l.histFilterPdfs, HistoryFilter.pdfs),
                const SizedBox(width: Space.x2),
                filterChip(l.histFilterFailed, HistoryFilter.failed),
              ],
            ),
          ),
          Expanded(
            child: switch (page) {
              AsyncData(:final value) => () {
                  final rows = value.where((r) => !_hidden.contains(r.id)).toList();
                  if (rows.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        child: IllustratedEmpty(
                          kind: IllustrationKind.historyEmpty,
                          title: l.histEmptyTitle,
                          body: l.histEmpty(retentionPeriod(l, retention)),
                        ),
                      ),
                    );
                  }
                  final items = <Widget>[];
                  DayBucket? lastBucket;
                  String? lastDate;
                  final groupByDay = _q.sort != HistorySort.saving;
                  // AD-4: in-feed after the 3rd row, then every historyAdInterval rows;
                  // a separate list item, so it's never part of swipe-to-remove.
                  final adAfter = const AdPolicy().historyAdSlots(rows.length).toSet();
                  var shown = 0;
                  for (final r in rows) {
                    if (groupByDay) {
                      final b = dayBucket(r.createdAt, now);
                      final date = b == DayBucket.older ? formatDate(r.createdAt) : null;
                      if (b != lastBucket || date != lastDate) {
                        items.add(Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                          child: SectionHeader(
                            switch (b) {
                              DayBucket.today => l.histToday,
                              DayBucket.yesterday => l.histYesterday,
                              DayBucket.older => date!,
                            },
                            top: items.isEmpty ? Space.x2 : Space.x5,
                          ),
                        ));
                        lastBucket = b;
                        lastDate = date;
                      }
                    }
                    items.add(Dismissible(
                      key: ValueKey(r.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsets.symmetric(horizontal: Space.x6),
                        color: context.colors.errorContainer,
                        child: Icon(Icons.delete_outline_rounded, color: context.colors.onErrorContainer),
                      ),
                      onDismissed: (_) => unawaited(_remove(r)),
                      child: HistoryTile(record: r, onTap: () => context.push('/history/${r.id}')),
                    ));
                    shown++;
                    if (adAfter.contains(shown)) {
                      items.add(const Padding(
                        padding: EdgeInsets.symmetric(horizontal: Space.x4),
                        child: HistoryAdCard(),
                      ));
                    }
                  }
                  if (value.length >= _q.limit) {
                    items.add(Padding(
                      padding: const EdgeInsets.all(Space.x4),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _q = _q.copyWith(limit: _q.limit + 50)),
                        child: Text(l.histLoadMore),
                      ),
                    ));
                  }
                  return ListView(padding: const EdgeInsets.only(bottom: Space.x8), children: items);
                }(),
              AsyncError() => EmptyHint(icon: Icons.error_outline_rounded, title: l.errProcessingFailedTitle),
              _ => const Center(child: CircularProgressIndicator.adaptive()),
            },
          ),
        ]),
      ),
    ));
  }
}
