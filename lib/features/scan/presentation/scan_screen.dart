import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/scan_controller.dart';

/// S27 · Scan tool entry (RELEASE_V1_2 §3). Opens the system scanner (S28);
/// once pages come back the route becomes the Review screen (S29, T9.5).
/// The scanned pages live in the shared page model (`ToolInputs`).
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.autostart = false});

  /// `?autostart=1` (Quick action, launcher shortcut): scan after the first frame.
  final bool autostart;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  static const tool = ToolId.scanDocument;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  Future<void> _afterFirstFrame() async {
    if (!mounted) return;
    // FR-SCN-20: a scan that finished after Android killed the app.
    final draftId = ref.read(toolInputsProvider(tool)).draftId;
    final restored = await ref.read(scanControllerProvider.notifier).takeRestored(draftId);
    if (!mounted) return;
    if (restored != null) {
      await ref.read(toolInputsProvider(tool).notifier).addPages(restored);
      return;
    }
    if (widget.autostart && ref.read(toolInputsProvider(tool)).isEmpty) await _scan();
  }

  Future<void> _scan() async {
    final inputs = ref.read(toolInputsProvider(tool));
    final pages =
        await ref.read(scanControllerProvider.notifier).scan(draftId: inputs.draftId, existing: inputs.files.length);
    if (!mounted || pages.isEmpty) return;
    await ref.read(toolInputsProvider(tool).notifier).addPages(pages);
  }

  void _choosePhotos() => context.pushReplacement(toolById(ToolId.imageToPdf).route);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final inputs = ref.watch(toolInputsProvider(tool));
    final flow = ref.watch(scanControllerProvider);
    final ctl = ref.read(scanControllerProvider.notifier);
    final preparing = flow.phase == ScanPhase.preparing;

    final choosePhotos = TextButton(onPressed: _choosePhotos, child: Text(l.scnChoosePhotos));
    final tryAgain = TextButton(onPressed: flow.busy ? null : _scan, child: Text(l.actionTryAgain));
    final problem = switch (flow.banner) {
      null => null,
      ScanBanner.moduleOffline => (BannerKind.warning, l.scnErrModuleOffline, [tryAgain]),
      ScanBanner.noPlayServices => (BannerKind.error, l.scnErrUnavailableAndroid, [choosePhotos]),
      ScanBanner.unsupported => (BannerKind.error, l.scnErrUnavailableIos, [choosePhotos]),
      ScanBanner.cameraDenied => (
          BannerKind.warning,
          l.scnErrCameraDenied,
          [
            TextButton(onPressed: () => ref.read(deviceServicesProvider).openAppSettings(), child: Text(l.openSettings)),
            choosePhotos,
          ],
        ),
      ScanBanner.storage => (BannerKind.error, l.errInsufficientStorageTitle, <Widget>[]),
      ScanBanner.unknown => (BannerKind.error, l.scnErrUnknown, [tryAgain]),
    };
    final notice = switch (flow.notice) {
      null => null,
      ScanNotice.truncated => l.scnTruncated(ScanController.maxPages),
      ScanNotice.limitReached => l.scnLimitReached(ScanController.maxPages),
    };

    return ToolScaffold(
      title: l.toolScanTitle,
      hasWork: !inputs.isEmpty,
      // No ad while "Getting the scanner ready…" shows (RELEASE_V1_2 §3).
      showAd: !preparing,
      banner: const RestoredBanner(tool: tool),
      primary: [
        const SizedBox(height: Space.x4),
        if (inputs.isEmpty) ...[
          if (preparing)
            _PreparingCard(onCancel: ctl.cancelPreparing)
          else
            _EntryCard(busy: flow.busy, onStart: _scan),
        ] else ...[
          // T9.5 replaces this with the Review grid and options (S29).
          SectionHeader(l.scnPages(inputs.files.length)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: flow.busy || inputs.files.length >= ScanController.maxPages ? null : _scan,
              icon: const Icon(Icons.add_rounded),
              label: Text(l.scnAddPages),
            ),
          ),
        ],
        if (problem case (final kind, final text, final actions)) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: kind, text: text, actions: actions, onDismiss: ctl.dismissBanner),
        ],
        if (notice != null) ...[
          const SizedBox(height: Space.x3),
          InlineBanner(kind: BannerKind.info, text: notice, onDismiss: ctl.dismissNotice),
        ],
        if (inputs.isEmpty && !preparing) ...[
          const SizedBox(height: Space.x5),
          Text(l.scnHavePhotos, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _choosePhotos,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(l.scnChoosePhotos),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

/// The PickerDropCard variant with the scan gradient icon (S27).
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.busy, required this.onStart});
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accent = context.docu.scanAccent;
    return Material(
      color: accent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x8, horizontal: Space.x4),
        child: Column(children: [
          const GradientIconTile(icon: Icons.document_scanner_rounded, category: ToolCategory.scan, size: 72),
          const SizedBox(height: Space.x4),
          Text(l.scnEntryTitle, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Space.x1),
          Text(
            l.scnEntryBody,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.x5),
          FilledButton.icon(
            key: const ValueKey('scan-start'),
            onPressed: busy ? null : onStart,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.photo_camera_rounded),
            label: Text(l.scnStart),
          ),
        ]),
      ),
    );
  }
}

/// "Getting the scanner ready…" while Play services downloads the module
/// (FR-SCN-07): indeterminate, with Cancel. No ad meanwhile.
class _PreparingCard extends StatelessWidget {
  const _PreparingCard({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.x5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(liveRegion: true, child: Text(l.scnPreparing, style: context.text.titleMedium)),
          const SizedBox(height: Space.x4),
          const LinearProgressIndicator(),
          const SizedBox(height: Space.x2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: onCancel, child: Text(l.actionCancel)),
          ),
        ]),
      ),
    );
  }
}
