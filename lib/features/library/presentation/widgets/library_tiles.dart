import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/formatting/bytes_format.dart';
import '../../../../core/formatting/date_format.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/inputs.dart';
import '../../../../core/widgets/pdf_thumbnail.dart';
import '../../../../data/library/library_repository.dart';

/// A document's first page or image, from the library file (live, cached in
/// memory; on-disk thumbnails come with S42 in T12.4).
class DocThumb extends StatelessWidget {
  const DocThumb({super.key, required this.doc, required this.path, required this.size});
  final LibraryDoc doc;
  final String path;
  final double size;

  @override
  Widget build(BuildContext context) => doc.isPdf
      ? PdfThumbnail(path: path, pageIndex: 0, width: size * 0.78)
      : LocalImageThumb(path: path, size: size);
}

String docMeta(LibraryDoc d) => '${formatBytes(d.sizeBytes)} · ${formatDate(d.addedAt)}';

/// S40/S41 document tile (FR-LIB-07…10): tap opens, long-press selects; the ⋮
/// button is the accessible way to the same actions.
class DocTile extends StatelessWidget {
  const DocTile({
    super.key,
    required this.doc,
    required this.path,
    required this.grid,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });
  final LibraryDoc doc;
  final String path;
  final bool grid, selected, selecting;
  final VoidCallback onTap, onLongPress, onMore;

  Widget _more(BuildContext context) => selecting
      ? Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: selected ? context.colors.primary : context.colors.onSurfaceVariant)
      : IconButton(tooltip: context.l10n.libMore, icon: const Icon(Icons.more_vert_rounded), onPressed: onMore);

  @override
  Widget build(BuildContext context) {
    final star = doc.starred ? Icon(Icons.star_rounded, size: 18, color: context.docu.warning, semanticLabel: context.l10n.libStar) : null;
    final body = grid
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Container(
                  color: context.colors.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: LayoutBuilder(builder: (context, c) => DocThumb(doc: doc, path: path, size: c.maxWidth)),
                ),
              ),
            ),
            const SizedBox(height: Space.x1),
            Row(children: [
              Expanded(child: MiddleEllipsisText(doc.name, style: context.text.bodyMedium)),
              ?star,
              SizedBox(width: 40, height: 40, child: Center(child: _more(context))),
            ]),
            Text(docMeta(doc), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ])
        : Row(children: [
            SizedBox(
              width: 48,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: ColoredBox(
                    color: context.colors.surfaceContainerHigh, child: Center(child: DocThumb(doc: doc, path: path, size: 48))),
              ),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MiddleEllipsisText(doc.name, style: context.text.bodyLarge),
                Text(docMeta(doc), style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ]),
            ),
            ?star,
            _more(context),
          ]);
    return Semantics(
      selected: selecting ? selected : null,
      button: true,
      label: doc.name,
      child: Material(
        color: selected ? context.colors.primaryContainer.withValues(alpha: 0.6) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          key: ValueKey('doc-${doc.id}'),
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: const EdgeInsets.all(Space.x2), child: body),
        ),
      ),
    );
  }
}

class FolderTile extends StatelessWidget {
  const FolderTile({super.key, required this.folder, required this.onTap, required this.onMore});
  final LibraryFolder folder;
  final VoidCallback onTap, onMore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: context.colors.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        key: ValueKey('folder-${folder.id}'),
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        onLongPress: onMore,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(children: [
            const SizedBox(width: Space.x3),
            Icon(Icons.folder_rounded, color: context.colors.primary),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                Text(l.libFolderDocs(folder.docCount),
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ]),
            ),
            IconButton(tooltip: l.libMore, icon: const Icon(Icons.more_vert_rounded), onPressed: onMore),
          ]),
        ),
      ),
    );
  }
}
