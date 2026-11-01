import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/ads/bottom_banner.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pdf_thumbnail.dart';
import '../application/library_controller.dart';

/// S42 full viewer: pages (swipe, pinch-zoom) or the image (pinch-zoom).
/// Full screen, so no ads (RELEASE_V1_5 §3.2).
class DocViewerScreen extends ConsumerStatefulWidget {
  const DocViewerScreen({super.key, required this.docId});
  final String docId;

  @override
  ConsumerState<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends ConsumerState<DocViewerScreen> {
  final _pc = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(libraryDocProvider(widget.docId)).value?.doc;
    final bar = AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white);
    if (d == null) return Scaffold(backgroundColor: Colors.black, appBar: bar);
    final path = ref.read(libraryRepositoryProvider).absolutePath(d);
    final width = (MediaQuery.sizeOf(context).width - Space.x8).clamp(100.0, 900.0);
    final pages = d.pageCount ?? 1;
    // ADR-072: the main banner, in reserved space below the page area —
    // never over the page.
    return AppBottomBanner(unit: AdUnit.bannerMain, child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: d.isPdf && pages > 1 ? Text(l.orgPreviewTitle(_index + 1, pages)) : MiddleEllipsisText(d.name),
      ),
      body: d.isPdf
          ? PageView.builder(
              controller: _pc,
              itemCount: pages,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.x4),
                    child: PdfThumbnail(path: path, pageIndex: i, width: width),
                  ),
                ),
              ),
            )
          : InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.file(File(path), fit: BoxFit.contain, semanticLabel: d.name)),
            ),
    ));
  }
}
