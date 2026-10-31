import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/common.dart';
import '../../../../data/library/fts.dart';
import '../../../../data/library/library_repository.dart';
import 'library_tiles.dart';

/// One FR-LIB-14 result: thumbnail, name, folder path and, when the match is
/// in recognised text, the snippet with the matched words highlighted.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({super.key, required this.hit, required this.path, required this.onTap});
  final SearchHit hit;
  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    final snippet = hit.snippet;
    return ListTile(
      minTileHeight: 64,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: SizedBox(
          width: 48,
          height: 48,
          child: ColoredBox(color: context.colors.surfaceContainerHigh, child: Center(child: DocThumb(doc: hit.doc, path: path, size: 48))),
        ),
      ),
      title: MiddleEllipsisText(hit.doc.name),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hit.folderPath.isEmpty ? l.libRoot : hit.folderPath.join(' › '), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (snippet != null)
          Text.rich(
            TextSpan(children: [
              for (final (text, hl) in snippetRuns(snippet))
                TextSpan(
                  text: text,
                  style: hl
                      ? TextStyle(fontWeight: FontWeight.w700, backgroundColor: context.colors.primaryContainer, color: context.colors.onPrimaryContainer)
                      : null,
                ),
            ]),
            style: context.text.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ]),
    );
  }
}
