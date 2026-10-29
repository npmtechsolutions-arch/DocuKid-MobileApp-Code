import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ad_slots.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/bottom_banner.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_copy.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/formatting/date_format.dart';
import '../../core/ocr/ocr_labels.dart';
import '../../core/ocr/text_recognizer.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/pdf_thumbnail.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/history_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../job/multi_outputs.dart';
import '../job/save_flow.dart';
import '../search/tool_catalog.dart';
import '../tools/options_draft.dart';
import 'history_providers.dart';

final operationProvider = StreamProvider.autoDispose.family<OperationRecord?, String>(
  (ref, id) => ref.watch(historyRepositoryProvider).watch(id),
);

/// S15 · Operation details.
class DetailsScreen extends ConsumerWidget {
  const DetailsScreen({super.key, required this.opId});
  final String opId;

  String _settingsLine(AppLocalizations l, OperationRecord r) {
    final o = r.options;
    final parts = <String>[];
    if (o['quality'] case final int q) parts.add('${l.cmpModeQuality} $q');
    if (o['format'] case final String f when f != 'same') {
      parts.add(switch (f) {
        'png' => l.fmtPng,
        'webp' => l.fmtWebp,
        'heic' => l.fmtHeic,
        _ => l.fmtJpeg,
      });
    }
    if (o['maxLongEdge'] case final int e) parts.add('${l.cmpMaxSize} ${l.cmpMaxPx(e)}');
    if (o['targetBytes'] case final int t when o['mode'] == 'targetSize') parts.add('${l.cmpTargetLabel} ${formatBytes(t)}');
    if (o['strip'] == true) parts.add(l.cmpStripMeta);
    if (o['size'] case final String s) {
      parts.add(switch (s) {
        'letter' => l.i2pSizeLetter,
        'legal' => l.i2pSizeLegal,
        'image' => l.i2pSizeImage,
        _ => l.i2pSizeA4,
      });
    }
    // Text Recognition (FR-OCR-17): the outputs and the language, never text.
    if (o['outputs'] case final Map<String, Object?> out) {
      parts.addAll([
        if (out['pdf'] == true) l.ocrOutPdf,
        if (out['review'] == true) l.ocrOutReview,
        if (out['txt'] == true) l.ocrOutTxt,
      ]);
      if (OcrScript.values.asNameMap()[o['script']] case final s?) parts.add(ocrScriptLabel(l, s));
    }
    if (o['level'] case final String lv) {
      parts.add(switch (lv) {
        'basic' => l.redBasicT,
        'strong' => l.redStrongT,
        _ => l.redBalancedT,
      });
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rec = ref.watch(operationProvider(opId));
    return AppBottomBanner(unit: AdUnit.bannerMain, child: Scaffold(
      appBar: AppBar(title: Text(l.detTitle)),
      body: switch (rec) {
        AsyncData(value: final r?) => _body(context, ref, r),
        AsyncData() => EmptyHint(icon: Icons.link_off_rounded, title: l.itemUnavailable),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    ));
  }

  Widget _body(BuildContext context, WidgetRef ref, OperationRecord r) {
    final l = context.l10n;
    final tool = r.tool;
    final d = tool == null ? null : toolById(tool);
    final available = r.completed && recordAvailable(ref, r);
    // Multi-output jobs list their files instead of one preview (S22 rows).
    final files = r.isMulti ? (ref.watch(multiOutputsProvider(r.id)).value ?? const <OutputEntry>[]) : null;
    final outputs = ref.read(outputsRepositoryProvider);
    final path = r.row.outputRelPath == null ? null : outputs.absolute(r.row.outputRelPath!);
    final mime = r.row.outputMime ?? '*/*';
    final retention = ref.watch(settingsProvider.select((s) => s.outputRetention));
    final finished = r.finishedAt;
    final keptUntil = r.row.outputDeletedAt != null
        ? l.detDeleted
        : (retention.duration == null || finished == null)
            ? l.detForever
            : formatDate(finished.add(retention.duration!));
    final failedCode = r.status == OpStatus.failed || r.status == OpStatus.interrupted
        ? (AppErrorCode.tryParse(r.row.errorCode) ?? AppErrorCode.interrupted)
        : null;
    final outMeta = r.outputMeta;

    Widget row(String k, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 104, child: Text(k, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant))),
            Expanded(child: DefaultTextStyle.merge(style: context.text.bodyLarge, child: v)),
          ]),
        );

    String inputLine(OperationInputRow i) => '${i.displayName} · ${formatBytes(i.sizeBytes)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Space.x8),
      child: ContentWidth(
        // AD-6: below the last button; not on failed entries, and only when the
        // content is taller than the ad (never fills blank space).
        child: DetailsAdBelow(
          enabled: failedCode == null,
          content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (available && path != null && files == null) ...[
            const SizedBox(height: Space.x2),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xl),
              child: Container(
                height: 220,
                color: context.colors.surfaceContainer,
                child: Center(
                  child: mime == 'application/pdf'
                      ? PdfThumbnail(path: path, pageIndex: 0, width: 130, elevated: true)
                      : Checkerboard(child: LocalImageThumb(path: path, size: 220, fit: BoxFit.contain)),
                ),
              ),
            ),
          ],
          const SizedBox(height: Space.x4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Column(children: [
                row(
                  l.detStatus,
                  Wrap(spacing: Space.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusIcon(r.status, label: statusLabel(l, r)),
                    Text(statusLabel(l, r)),
                    Text(
                      '· ${formatDateTime(r.createdAt)}${r.row.durationMs == null ? '' : ' · ${l.detTook(formatDuration(l, Duration(milliseconds: r.row.durationMs!)))}'}',
                      style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ]),
                ),
                if (d != null) row(l.detTool, Text(d.title(l))),
                row(
                  l.detInputs,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final i in r.inputs) Text(inputLine(i)),
                  ]),
                ),
                if (files != null && files.isNotEmpty) row(l.detOutput, Text(multiTotalsLine(context, files))),
                if (r.row.outputName != null && files == null)
                  row(
                    l.detOutput,
                    Text([
                      r.row.outputName!,
                      if (r.row.outputBytes != null) formatBytes(r.row.outputBytes!),
                      if (outMeta['w'] != null) l.metaDims(outMeta['w'] as int, outMeta['h'] as int),
                      if (outMeta['pages'] != null) l.metaPages(outMeta['pages'] as int),
                    ].join(' · ')),
                  ),
                if (_settingsLine(l, r).isNotEmpty) row(l.detSettings, Text(_settingsLine(l, r))),
                if (r.completed) ...[
                  row(l.detSaved, Text(r.row.savedExternally ? l.detSavedYes : l.detNotSaved)),
                  if (!isTextOnly(r)) row(l.detKeptUntil, Text(available ? keptUntil : l.histUnavailable)),
                ],
              ]),
            ),
          ),
          if (failedCode != null) ...[
            const SizedBox(height: Space.x4),
            InlineBanner(
              kind: BannerKind.error,
              text: '${errorCopy(l, AppError(failedCode)).title}. ${errorCopy(l, AppError(failedCode)).body}',
            ),
          ],
          const SizedBox(height: Space.x6),
          if (available && files != null && files.isNotEmpty && tool != null) ...[
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => saveAllOutputs(context, ref, opId: r.id, entries: files),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l.multiSaveAll),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => saveOutputsAsZip(context, ref, opId: r.id, tool: tool, entries: files),
                  icon: const Icon(Icons.folder_zip_outlined),
                  label: Text(l.multiSaveZip),
                ),
              ),
            ]),
            const SizedBox(height: Space.x3),
            Builder(
              builder: (anchor) => OutlinedButton.icon(
                onPressed: () => shareAllOutputs(anchor, ref, opId: r.id, tool: tool, entries: files),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(l.multiShareAll),
              ),
            ),
            SectionHeader(l.multiFilesHeader),
            for (final e in files)
              OutputRow(
                key: ValueKey('output-${e.index}'),
                entry: e,
                onOpen: (anchor) => openWithResult(anchor, ref, path: e.path!, mime: e.mime),
                onShare: (anchor) => shareResult(anchor, ref, path: e.path!, mime: e.mime),
                onSave: () => saveResult(context, ref, path: e.path!, name: e.name, mime: e.mime, opId: r.id),
              ),
            const SizedBox(height: Space.x3),
          ],
          if (available && path != null && files == null) ...[
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => saveResult(context, ref, path: path, name: r.row.outputName!, mime: mime, opId: r.id),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l.actionSave),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Builder(
                  builder: (anchor) => FilledButton.tonalIcon(
                    onPressed: () => shareResult(anchor, ref, path: path, mime: mime),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(l.actionShare),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: Space.x3),
            Builder(
              builder: (anchor) => OutlinedButton.icon(
                onPressed: () => openWithResult(anchor, ref, path: path, mime: mime),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(l.actionOpenWith),
              ),
            ),
            const SizedBox(height: Space.x3),
          ],
          if (d != null)
            OutlinedButton.icon(
              onPressed: () {
                ref.read(runAgainProvider).set(d.id, r.options.cast<String, dynamic>());
                context.push(d.route);
              },
              icon: Icon(failedCode != null ? Icons.refresh_rounded : Icons.replay_rounded),
              label: Text(failedCode != null ? l.actionTryAgain : l.detRunAgain),
            ),
          Padding(
            padding: const EdgeInsets.only(top: Space.x1),
            child: Text(l.detRepickHint, textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          const SizedBox(height: Space.x6),
          if (available)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              onPressed: () async {
                final confirm = ref.read(settingsProvider).confirmDestructive;
                if (confirm) {
                  final (ok, _) = await confirmDestructive(context, title: l.detDeleteCopyTitle, body: l.detDeleteCopyBody, confirmLabel: l.detDeleteCopy);
                  if (!ok) return;
                }
                await outputs.deleteFor(r.id);
                await ref.read(historyRepositoryProvider).markOutputDeleted(r.id, ref.read(clockProvider)());
                ref.invalidate(outputAvailableProvider(r.row.outputRelPath));
                ref.invalidate(outputDirAvailableProvider(r.id));
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l.detDeleteCopy),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            onPressed: () async {
              final confirm = ref.read(settingsProvider).confirmDestructive;
              if (confirm) {
                final (ok, _) = await confirmDestructive(context, title: l.detRemoveTitle, body: l.detRemoveBody, confirmLabel: l.detRemoveEntry);
                if (!ok) return;
              }
              await outputs.deleteFor(r.id);
              await ref.read(historyRepositoryProvider).remove(r.id);
              if (context.mounted && context.canPop()) context.pop();
            },
            icon: const Icon(Icons.playlist_remove_rounded),
            label: Text(l.detRemoveEntry),
          ),
          ]),
        ),
      ),
    );
  }
}
