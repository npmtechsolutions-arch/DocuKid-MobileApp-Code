import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../search/tool_catalog.dart';
import 'favourites_controller.dart';

/// Pin or unpin [id]; a 7th pin shows the limit message (FR-FAV-02).
void toggleFavourite(BuildContext context, WidgetRef ref, ToolId id) {
  final r = ref.read(favouritesProvider.notifier).toggle(id);
  if (r == PinResult.limit && context.mounted) showAppSnack(context, context.l10n.favLimit);
}

/// Long-press on a ToolCard (S01 update): name, description, Add/Remove
/// favourites, Open.
Future<void> showToolSheet(BuildContext context, ToolDescriptor tool) {
  final l = context.l10n;
  return showAppSheet<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final pinned = ref.watch(favouritesProvider).contains(tool.id);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: GradientIconTile(icon: tool.icon, category: tool.category, size: 44, shadow: false),
            title: Text(tool.title(l), style: ctx.text.titleMedium),
            subtitle: Text(tool.subtitle(l)),
          ),
          const Divider(),
          ListTile(
            leading: Icon(pinned ? Icons.star_rounded : Icons.star_outline_rounded),
            title: Text(pinned ? l.favRemove : l.favAdd),
            onTap: () {
              Navigator.pop(ctx);
              toggleFavourite(context, ref, tool.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded),
            title: Text(l.resultOpen),
            onTap: () {
              Navigator.pop(ctx);
              context.push(tool.route);
            },
          ),
          const SizedBox(height: Space.x2),
        ]);
      },
    ),
  );
}

/// S26 · Favourites edit sheet: reorder (drag, or Move up/down), remove, Done.
/// No ads (sheet).
Future<void> showFavouritesEditSheet(BuildContext context) {
  final l = context.l10n;
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final favs = ref.watch(favouritesProvider);
        final c = ref.read(favouritesProvider.notifier);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.x4, Space.x2, Space.x2, 0),
            child: Row(children: [
              Expanded(child: Semantics(header: true, child: Text(l.favHeader, style: ctx.text.titleLarge))),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.actionDone)),
            ]),
          ),
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              itemCount: favs.length,
              onReorderItem: c.reorder, // newIndex already adjusted for the removed item
              itemBuilder: (ctx, i) {
                final t = toolById(favs[i]);
                return ListTile(
                  key: ValueKey(t.id),
                  leading: GradientIconTile(icon: t.icon, category: t.category, size: 40, shadow: false),
                  title: Text(t.title(l)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    PopupMenuButton<int>(
                      tooltip: l.orgMore,
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (v) => switch (v) {
                        0 => c.move(t.id, -1),
                        1 => c.move(t.id, 1),
                        _ => c.unpin(t.id),
                      },
                      itemBuilder: (_) => [
                        if (i > 0) PopupMenuItem(value: 0, child: Text(l.favMoveUp)),
                        if (i < favs.length - 1) PopupMenuItem(value: 1, child: Text(l.favMoveDown)),
                        PopupMenuItem(value: 2, child: Text(l.favRemove)),
                      ],
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Tooltip(
                        message: l.dragHandle,
                        child: const SizedBox(width: 40, height: 48, child: Icon(Icons.drag_indicator_rounded)),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: Space.x3),
        ]);
      },
    ),
  );
}

/// S01 · Favourites row above Quick actions; hidden when nothing is pinned.
class FavouritesRow extends ConsumerWidget {
  const FavouritesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favouritesProvider);
    if (favs.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(
        l.favHeader,
        top: Space.x5,
        trailing: TextButton(onPressed: () => showFavouritesEditSheet(context), child: Text(l.favEdit)),
      ),
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: favs.length,
          separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
          itemBuilder: (context, i) => FavouriteChip(tool: toolById(favs[i])),
        ),
      ),
    ]);
  }
}

/// ToolCard v2 compact: 64 dp tall, gradient tile + name.
class FavouriteChip extends StatelessWidget {
  const FavouriteChip({super.key, required this.tool});
  final ToolDescriptor tool;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      button: true,
      label: tool.title(l),
      excludeSemantics: true,
      child: Material(
        color: context.colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(tool.route);
          },
          onLongPress: () => showToolSheet(context, tool),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.x2, Space.x2, Space.x4, Space.x2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GradientIconTile(icon: tool.icon, category: tool.category, size: 44, shadow: false),
              const SizedBox(width: Space.x3),
              Text(tool.title(l), style: context.text.titleSmall),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tool screen ⋮ (FR-FAV-01): the same pin toggle as the long-press sheet.
class FavouriteMenuButton extends ConsumerWidget {
  const FavouriteMenuButton({super.key, required this.tool});
  final ToolId tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pinned = ref.watch(favouritesProvider).contains(tool);
    return PopupMenuButton<void>(
      tooltip: l.orgMore,
      icon: const Icon(Icons.more_vert_rounded),
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: () => toggleFavourite(context, ref, tool),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(pinned ? Icons.star_rounded : Icons.star_outline_rounded),
            const SizedBox(width: Space.x3),
            Flexible(child: Text(pinned ? l.favRemove : l.favAdd)),
          ]),
        ),
      ],
    );
  }
}
