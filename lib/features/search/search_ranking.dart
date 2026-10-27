import 'synonyms.dart';
import 'tool_catalog.dart';

/// Tool search ranking (FEATURE_SPECS §1.2). Pure; unit-tested.
class SearchHit {
  const SearchHit(this.tool, this.score, this.matchedPhrase);
  final ToolId tool;
  final int score;

  /// The keyword that gave the largest single increment, if any.
  final String? matchedPhrase;
}

const _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ç': 'c', 'č': 'c', 'è': 'e', 'é': 'e',
  'ê': 'e', 'ë': 'e', 'ē': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o',
  'õ': 'o', 'ö': 'o', 'ø': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'š': 's', 'ž': 'z',
  'ß': 'ss', 'œ': 'oe', 'æ': 'ae',
};

final _nonAlnum = RegExp(r'[^a-z0-9 ]');
final _spaces = RegExp(r' +');

String normalizeQuery(String s) {
  final lower = s.toLowerCase();
  final sb = StringBuffer();
  for (final ch in lower.split('')) {
    sb.write(_diacritics[ch] ?? ch);
  }
  return sb.toString().replaceAll(_nonAlnum, ' ').replaceAll(_spaces, ' ').trim();
}

const _imageHints = {'photo', 'image', 'picture', 'jpg', 'png'};

SearchHit scoreTool(ToolId tool, String title, String query) {
  if (query.trim().isEmpty) return SearchHit(tool, 0, null);
  final qn = normalizeQuery(query);
  if (qn.isEmpty) return SearchHit(tool, 0, null);
  final tokens = qn.split(' ');
  final nt = normalizeQuery(title);
  var s = 0;
  if (nt.startsWith(qn)) s += 100;
  if (nt.contains(qn)) s += 60;

  final keywords = toolKeywords[tool] ?? const [];
  var bestInc = 0;
  String? bestPhrase;
  final kwTokens = <String>{};
  for (final kw in keywords) {
    final k = normalizeQuery(kw);
    kwTokens.addAll(k.split(' '));
    var inc = 0;
    if (k == qn) {
      inc = 90;
    } else if (k.startsWith(qn)) {
      inc = 50;
    } else if (qn.contains(k) && k.length >= 3) {
      inc = 40;
    }
    s += inc;
    if (inc > bestInc) {
      bestInc = inc;
      bestPhrase = kw;
    }
  }
  var tokenHits = 0;
  for (final t in tokens) {
    if (t.length >= 2 && kwTokens.any((k) => k.startsWith(t))) tokenHits++;
  }
  s += 10 * tokenHits;

  final isPdfTool = toolById(tool).category == ToolCategory.pdf;
  if (tokens.contains('pdf') && isPdfTool) s += 15;
  if (tokens.any(_imageHints.contains) && !isPdfTool) s += 15;
  return SearchHit(tool, s, bestPhrase);
}

/// Ranked results; ties keep catalogue order.
List<SearchHit> searchTools(String query, String Function(ToolId) titleOf) {
  final hits = <SearchHit>[];
  for (final t in toolCatalog) {
    final h = scoreTool(t.id, titleOf(t.id), query);
    if (h.score > 0) hits.add(h);
  }
  final order = {for (var i = 0; i < toolCatalog.length; i++) toolCatalog[i].id: i};
  hits.sort((a, b) {
    final c = b.score.compareTo(a.score);
    return c != 0 ? c : order[a.tool]!.compareTo(order[b.tool]!);
  });
  return hits;
}
