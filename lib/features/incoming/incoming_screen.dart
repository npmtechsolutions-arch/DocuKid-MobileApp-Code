import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/bottom_banner.dart';
import '../../core/files/picked_file.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../library/application/add_to_library.dart';
import '../print/application/print_entry.dart';
import '../search/tool_catalog.dart';
import 'incoming_controller.dart';
import 'incoming_matching.dart';

/// S19 · Incoming chooser (RELEASE_V1_1 §3, FR-SHR-05…07): the received
/// files and only the tools that can take them. No banner (a routing screen).
/// Cancel and back delete the temp copies.
class IncomingScreen extends ConsumerWidget {
  const IncomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(incomingProvider);
    final c = ref.read(incomingProvider.notifier);

    Future<void> cancel() async {
      await c.cancel();
      if (context.mounted) context.go('/');
    }

    if (s == null) {
      // Already handed to a tool or cancelled (e.g. back after choosing).
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final sections = s.sections;
    // ADR-072: the main banner (it was ad-free before 1.6).
    return AppBottomBanner(unit: AdUnit.bannerMain, child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: l.actionCancel, icon: const Icon(Icons.close_rounded), onPressed: cancel),
          title: Text(l.incTitle(s.count)),
          actions: [TextButton(onPressed: cancel, child: Text(l.actionCancel))],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: Space.x8),
          children: [
            ContentWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // 1.5 FR-LIB-05: keep the received files instead of using a tool.
                if (sections.isNotEmpty) ...[
                  const SizedBox(height: Space.x3),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      key: const ValueKey('incoming-save-to-library'),
                      minTileHeight: 64,
                      leading: Icon(Icons.folder_special_outlined, color: context.colors.primary),
                      title: Text(l.libSaveTo),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final added = await saveIncomingToLibrary(context, ref, [...s.images, ...s.pdfs]);
                        if (added == 0 || !context.mounted) return;
                        await c.cancel();
                        if (context.mounted) context.go('/library');
                      },
                    ),
                  ),
                ],
                if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.x8),
                    child: EmptyHint(icon: Icons.block_rounded, title: l.incUnsupported),
                  ),
                for (final sec in sections) ...[
                  SectionHeader(sec.kind == IncomingKind.images ? l.incImagesSection(sec.count) : l.incPdfsSection(sec.count)),
                  _FilesPreview(files: sec.kind == IncomingKind.images ? s.images : s.pdfs),
                  if ((sec.kind == IncomingKind.images && s.imagesTruncated) || (sec.kind == IncomingKind.pdfs && s.pdfsTruncated))
                    Padding(
                      padding: const EdgeInsets.only(top: Space.x2),
                      child: InlineBanner(
                        kind: BannerKind.info,
                        text: l.inputsTruncated(sec.kind == IncomingKind.images ? incomingLimits.images : incomingLimits.pdfs),
                      ),
                    ),
                  const SizedBox(height: Space.x2),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(children: [
                      for (final o in sec.options)
                        ListTile(
                          minTileHeight: 64,
                          leading: GradientIconTile(
                              icon: toolById(o.tool).icon, category: toolById(o.tool).category, size: 40, shadow: false),
                          title: Text(toolById(o.tool).title(l)),
                          subtitle: Text(o.needsMore ? l.incMergeNeedsMore : toolById(o.tool).subtitle(l)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            c.handTo(o.tool, sec.kind);
                            // Print goes straight on to S48 with the files (FR-PRN-02).
                            context.pushReplacement(o.tool == ToolId.print ? printPreviewRoute : toolById(o.tool).route);
                          },
                        ),
                    ]),
                  ),
                ],
                if (sections.isNotEmpty && s.unsupported > 0) ...[
                  const SizedBox(height: Space.x4),
                  InlineBanner(kind: BannerKind.warning, text: '${l.batchInvalid(s.unsupported)}. ${l.incUnsupported}'),
                ],
              ]),
            ),
          ],
        ),
      ),
    ));
  }
}

/// The first few received files of a group, with their validation badges.
class _FilesPreview extends StatelessWidget {
  const _FilesPreview({required this.files});
  final List<PickedFile> files;
  static const shown = 4;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final f in files.take(shown))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 40,
            height: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: f.isPdf || !f.status.isValid
                  ? ColoredBox(
                      color: context.colors.surfaceContainerHigh,
                      child: Icon(f.isPdf ? Icons.picture_as_pdf_rounded : Icons.broken_image_outlined,
                          color: context.colors.onSurfaceVariant),
                    )
                  : LocalImageThumb(path: f.path, size: 40),
            ),
          ),
          title: MiddleEllipsisText(f.displayName, style: context.text.bodyLarge),
          subtitle: Row(children: [
            Flexible(child: Text(metaLine(context.l10n, f), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: Space.x2),
            StatusBadge(file: f),
          ]),
        ),
      if (files.length > shown)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text('+${files.length - shown}', style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
    ]);
  }
}
