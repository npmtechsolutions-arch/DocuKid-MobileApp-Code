import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/ads/bottom_banner.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../application/index_queue.dart';

/// S46 My Documents settings (RELEASE_V1_5 §3). T12.5 adds "Make documents
/// searchable" (FR-LIB-15/16); reminders, lock and storage join in T12.6–T12.8.
class LibrarySettingsScreen extends ConsumerWidget {
  const LibrarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final status = ref.watch(indexStatusProvider).value ?? const IndexStatus();
    final state = status.waiting == 0
        ? l.libIndexIdle
        : switch (status.paused) {
            IndexPause.user => l.libIndexPausedUser,
            IndexPause.battery => l.libIndexPausedBattery,
            IndexPause.busy => l.libIndexBusy,
            // Not visible while backgrounded; shown as waiting.
            IndexPause.background || null => status.working ? l.libIndexing(status.waiting) : l.libIndexWaiting(status.waiting),
          };
    final detail = status.waiting > 0 && status.paused != null ? '${l.libIndexWaiting(status.waiting)} · $state' : state;

    // A Settings sub-page: the Settings banner (§3.2).
    return AppBottomBanner(
      unit: AdUnit.bannerSettings,
      child: Scaffold(
        appBar: AppBar(title: Text(l.setLibTitle)),
        body: ContentWidth(
          child: ListView(padding: const EdgeInsets.only(bottom: Space.x8), children: [
            SectionHeader(l.setLibSearchable),
            Card(
              child: Column(children: [
                SwitchListTile.adaptive(
                  key: const ValueKey('set-lib-scans'),
                  secondary: const Icon(Icons.document_scanner_outlined),
                  title: Text(l.setLibScans),
                  value: s.libIndexScans,
                  onChanged: (v) => c.update((x) => x.copyWith(libIndexScans: v)),
                ),
                SwitchListTile.adaptive(
                  key: const ValueKey('set-lib-other'),
                  secondary: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l.setLibOther),
                  value: s.libIndexOther,
                  onChanged: (v) => c.update((x) => x.copyWith(libIndexOther: v)),
                ),
                ListTile(
                  key: const ValueKey('set-lib-status'),
                  leading: Icon(status.paused == null ? Icons.manage_search_rounded : Icons.pause_circle_outline_rounded),
                  title: Text(detail),
                  subtitle: Text(l.setLibSearchNote),
                  trailing: TextButton(
                    key: const ValueKey('set-lib-pause'),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => c.update((x) => x.copyWith(libIndexPaused: !x.libIndexPaused)),
                    child: Text(s.libIndexPaused ? l.libIndexResume : l.libIndexPause),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
