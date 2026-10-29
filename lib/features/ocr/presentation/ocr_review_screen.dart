import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/tokens.dart';
import '../../../core/files/file_gateway.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../job/save_flow.dart';
import '../application/ocr_review_controller.dart';
import '../application/ocr_review_files.dart';

/// S31 · Review text `/job/:jobId/text` (RELEASE_V1_3 §3.3, FR-OCR-08): one
/// page at a time, edit, Copy page / Copy all, Share, Save .txt. No ads
/// (FULL_PRODUCT §4.4: a full-screen editor). Leaving with edits asks first.
class OcrReviewScreen extends ConsumerStatefulWidget {
  const OcrReviewScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  final _pager = PageController();
  int _index = 0;

  OcrReviewController get _ctrl => ref.read(ocrReviewProvider(widget.jobId).notifier);

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showAppSnack(context, context.l10n.ocrCopied);
  }

  Future<void> _share(BuildContext anchor) async {
    final l = context.l10n;
    final gateway = ref.read(fileGatewayProvider);
    final s = await _ctrl.shareable();
    if (!anchor.mounted) return;
    final ShareOutcome outcome;
    if (s.text != null) {
      outcome = await gateway.shareText(s.text!, origin: originOf(anchor));
    } else {
      outcome = await gateway.share([s.filePath!], mime: 'text/plain', origin: originOf(anchor));
      if (anchor.mounted && outcome != ShareOutcome.failed) showAppSnack(anchor, l.ocrSharedAsFile);
    }
    if (outcome == ShareOutcome.failed && anchor.mounted) showAppSnack(anchor, l.saveFailed);
  }

  Future<void> _saveTxt() async {
    final path = await _ctrl.writeTxt();
    if (!mounted) return;
    await saveResult(context, ref, path: path, name: p.basename(path), mime: 'text/plain', opId: widget.jobId);
  }

  void _go(int i) => _pager.animateToPage(i, duration: Motion.of(context, Motion.medium), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(ocrReviewProvider(widget.jobId));
    final appBar = AppBar(
      title: Text(l.ocrReview),
      actions: [
        if (s.files != null)
          TextButton.icon(
            onPressed: () async => _copy(await _ctrl.allText()),
            icon: const Icon(Icons.copy_all_rounded),
            label: Text(l.ocrCopyAll),
          ),
      ],
    );
    if (s.loading) return Scaffold(appBar: appBar, body: const Center(child: CircularProgressIndicator.adaptive()));
    if (s.unavailable) return Scaffold(appBar: appBar, body: Center(child: Text(l.itemUnavailable)));
    final pages = s.files!.pages;
    final n = pages.length;

    return PopScope(
      canPop: !s.edited,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmLeave(context, copy: (l.ocrDiscardEdits, l.ocrDiscardEditsBody));
        // Navigator.pop doesn't ask PopScope again (context.pop would).
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: appBar,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            ContentWidth(
              child: Row(children: [
                IconButton(
                  tooltip: l.ocrPrevPage,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _index > 0 ? () => _go(_index - 1) : null,
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(l.orgPreviewTitle(_index + 1, n), textAlign: TextAlign.center, style: context.text.titleSmall),
                  ),
                ),
                if (s.isEdited(_index))
                  Text('${l.ocrEdited} •', style: context.text.labelMedium?.copyWith(color: context.colors.primary)),
                IconButton(
                  tooltip: l.ocrNextPage,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _index < n - 1 ? () => _go(_index + 1) : null,
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: n,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _ReviewPage(key: ValueKey(i), jobId: widget.jobId, index: i, info: pages[i]),
              ),
            ),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, Space.x2, 0, Space.x3),
              child: Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async => _copy(await _ctrl.textOf(_index)),
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(l.ocrCopyPage, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Builder(
                    builder: (anchor) => FilledButton.tonalIcon(
                      onPressed: () => _share(anchor),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l.ocrShareText, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _saveTxt,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(l.ocrSaveTxt, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// One page: its picture (tap to enlarge), its text, a low-text note.
class _ReviewPage extends ConsumerStatefulWidget {
  const _ReviewPage({super.key, required this.jobId, required this.index, required this.info});
  final String jobId;
  final int index;
  final OcrReviewPage info;

  @override
  ConsumerState<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<_ReviewPage> {
  final _text = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ref.read(ocrReviewProvider(widget.jobId).notifier).textOf(widget.index).then((t) {
      if (!mounted) return;
      setState(() {
        _text.text = t;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _enlarge(File thumb) => showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(thumb))),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(ocrReviewProvider(widget.jobId));
    final thumb = File(OcrReviewFiles.thumbPath(s.files!.dir, widget.index));
    final height = MediaQuery.sizeOf(context).height * 0.25;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: Space.x2),
      child: ContentWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            button: true,
            label: l.ocrViewPage(widget.index + 1),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () => _enlarge(thumb),
              child: SizedBox(
                height: height,
                // No thumbnail (none was made): just the space.
                child: Image.file(thumb, fit: BoxFit.contain, excludeFromSemantics: true, errorBuilder: (_, _, _) => const SizedBox()),
              ),
            ),
          ),
          const SizedBox(height: Space.x3),
          if (_loaded)
            TextField(
              controller: _text,
              readOnly: s.tooLong,
              maxLines: null,
              minLines: 6,
              keyboardType: TextInputType.multiline,
              style: context.text.bodyLarge?.copyWith(fontSize: 16),
              decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l.orgPreviewTitle(widget.index + 1, s.files!.pages.length)),
              onChanged: (t) => ref.read(ocrReviewProvider(widget.jobId).notifier).editChecked(widget.index, t),
            )
          else
            const Padding(padding: EdgeInsets.all(Space.x6), child: Center(child: CircularProgressIndicator.adaptive())),
          if (s.tooLong) ...[
            const SizedBox(height: Space.x2),
            Text(l.ocrTooLongToEdit, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
          if (widget.info.lowText) ...[
            const SizedBox(height: Space.x3),
            InlineBanner(kind: BannerKind.warning, text: l.ocrLowTextPage(widget.index + 1)),
          ],
        ]),
      ),
    );
  }
}
