import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'search_ranking.dart';
import 'tool_catalog.dart';

/// S02 · Search tools. Ranking runs on every keystroke (local, no debounce).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _q = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _open(ToolId id) => context.pushReplacement(toolById(id).route);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = _q.text;
    final hits = searchTools(query, (id) => toolById(id).title(l));
    final empty = query.trim().isEmpty;

    Widget row(ToolDescriptor t, {String? subtitle}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x1),
          leading: ToolIconTile(icon: t.icon, color: accentFor(context, t.category)),
          title: Text(t.title(l), style: context.text.titleMedium),
          subtitle: Text(subtitle ?? t.subtitle(l)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _open(t.id),
        );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Hero(
          tag: 'search',
          child: Material(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.full),
            child: TextField(
              controller: _q,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (hits.isNotEmpty) _open(hits.first.tool);
              },
              decoration: InputDecoration(
                hintText: l.searchFieldHint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.searchClear,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_q.clear),
                      ),
              ),
            ),
          ),
        ),
        actions: const [SizedBox(width: Space.x4)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.x8),
        children: [
          if (empty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.x4, Space.x4, Space.x4, Space.x2),
              child: Text(l.searchHintEmpty, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
                for (final s in [l.searchChipCompress, l.searchChipCombine, l.searchChipPassport, l.searchChipRotate])
                  ActionChip(
                    avatar: const Icon(Icons.north_west_rounded, size: 16),
                    label: Text(s),
                    onPressed: () => setState(() {
                      _q.text = s;
                      _q.selection = TextSelection.collapsed(offset: s.length);
                    }),
                  ),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: SectionHeader(l.searchAllTools)),
            for (final t in toolCatalog) row(t),
          ] else if (hits.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Semantics(liveRegion: true, child: Text(l.searchNoResults(query), style: context.text.titleMedium)),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: Space.x4), child: SectionHeader(l.searchAllTools, top: 0)),
            for (final t in toolCatalog) row(t),
          ] else
            for (final h in hits)
              row(toolById(h.tool), subtitle: h.matchedPhrase == null ? null : l.searchMatches(h.matchedPhrase!)),
        ],
      ),
    );
  }
}
