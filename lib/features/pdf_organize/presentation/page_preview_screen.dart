import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pdf_thumbnail.dart';
import '../../search/tool_catalog.dart';
import '../../tools/tool_inputs.dart';
import '../application/organize_controller.dart';

/// FR-ORG-08 · full-screen page preview with pinch-zoom; swipe between pages.
class PagePreviewScreen extends ConsumerStatefulWidget {
  const PagePreviewScreen({super.key, required this.initial});
  final int initial;

  @override
  ConsumerState<PagePreviewScreen> createState() => _PagePreviewScreenState();
}

class _PagePreviewScreenState extends ConsumerState<PagePreviewScreen> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final file = ref.watch(toolInputsProvider(ToolId.pdfOrganize).select((s) => s.single));
    final pages = ref.watch(organizeProvider.select((s) => s.pages));
    if (file == null || pages.isEmpty) return const Scaffold();
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.orgPreviewTitle(_index + 1, pages.length)),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: pages.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: PdfThumbnail(
                path: file.path,
                pageIndex: pages[i].sourceIndex,
                width: (width - Space.x8).clamp(100, 900),
                quarterTurns: pages[i].rotationQuarterTurns,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
