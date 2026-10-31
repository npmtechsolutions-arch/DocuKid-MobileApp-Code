import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../data/library/library_repository.dart';
import '../application/expiry.dart';
import '../application/library_controller.dart';
import 'widgets/library_tiles.dart';

/// FR-LIB-23 · Home's "My Documents" card: the 3 latest documents, "Open
/// library", and the nearest expiry within 30 days (FR-REM-04). Hidden while
/// the library is empty; the locked look comes with the app lock (T12.7).
class HomeLibraryCard extends ConsumerWidget {
  const HomeLibraryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final recent = ref.watch(libraryRecentProvider).value ?? const <LibraryDoc>[];
    if (recent.isEmpty) return const SizedBox.shrink();
    final now = ref.read(clockProvider)();
    final soon = [
      for (final d in ref.watch(libraryExpiringProvider).value ?? const <LibraryDoc>[])
        if (daysUntil(d.expiryDate!, now) <= homeExpiringDays) d,
    ];
    final repo = ref.read(libraryRepositoryProvider);
    void open(LibraryDoc d) => context.push('/library/doc/${d.id}');
    return Padding(
      padding: const EdgeInsets.only(top: Space.x5),
      child: Card(
        key: const ValueKey('home-library-card'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(left: Space.x4, right: Space.x2),
              child: Row(children: [
                Icon(Icons.folder_special_rounded, color: context.colors.primary),
                const SizedBox(width: Space.x3),
                Expanded(child: Text(l.libTitle, style: context.text.titleMedium)),
                TextButton(
                  key: const ValueKey('home-library-open'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => context.push('/library'),
                  child: Text(l.homeLibOpen),
                ),
              ]),
            ),
            if (soon.isNotEmpty)
              ListTile(
                key: const ValueKey('home-library-expiring'),
                minTileHeight: 48,
                leading: Icon(isExpired(soon.first, now) ? Icons.event_busy_rounded : Icons.event_rounded,
                    color: isExpired(soon.first, now) ? context.colors.error : context.docu.warning),
                title: MiddleEllipsisText(soon.first.name),
                subtitle: Text(expiryLabel(l, soon.first.expiryDate!, now),
                    style: TextStyle(color: isExpired(soon.first, now) ? context.colors.error : null)),
                onTap: () => open(soon.first),
              ),
            for (final d in recent)
              ListTile(
                key: ValueKey('home-library-${d.id}'),
                minTileHeight: 56,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ColoredBox(
                        color: context.colors.surfaceContainerHigh,
                        child: Center(child: DocThumb(doc: d, path: repo.absolutePath(d), size: 40))),
                  ),
                ),
                title: MiddleEllipsisText(d.name),
                subtitle: Text(docMeta(d), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => open(d),
              ),
          ]),
        ),
      ),
    );
  }
}
