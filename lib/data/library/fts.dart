/// Full-text search over My Documents (RELEASE_V1_5 §4.3, ADR-055).
///
/// The tokenizer keeps combining marks (`M*`) inside words, so Devanagari
/// words stay whole (T12.0), and folds Latin diacritics ("cafe" finds "café").
const createLibraryFts = '''
CREATE VIRTUAL TABLE IF NOT EXISTS library_fts USING fts5(
  doc_id UNINDEXED, name, notes, tags, body,
  tokenize = "unicode61 remove_diacritics 2 categories 'L* N* Co M*'"
)''';

const libraryIndexes = [
  'CREATE INDEX IF NOT EXISTS idx_lib_docs_folder ON library_documents (folder_id)',
  'CREATE INDEX IF NOT EXISTS idx_lib_docs_sha ON library_documents (sha256)',
  'CREATE INDEX IF NOT EXISTS idx_lib_docs_expiry ON library_documents (expiry_date)',
  'CREATE INDEX IF NOT EXISTS idx_lib_docs_added ON library_documents (added_at DESC)',
];

/// Recognised / extracted text kept per document (§4.3).
const maxBodyChars = 200000;

/// Name highest, then tags, notes, body (bm25 weights in column order:
/// doc_id, name, notes, tags, body).
const ftsRank = 'bm25(library_fts, 0, 10, 4, 6, 1)';

/// `snippet()` over the body column, matches in [ ].
const ftsSnippet = "snippet(library_fts, 4, '[', ']', '…', 12)";

final _token = RegExp(r'[\p{L}\p{N}\p{M}]+', unicode: true);

/// The user's words → quoted prefix terms, all required: `"pass"* "port"*`.
/// Null when there's nothing to search for. Quoting keeps FTS operators and
/// punctuation in the input from being parsed.
String? ftsMatchQuery(String input) {
  final words = _token.allMatches(input).map((m) => m.group(0)!).toList();
  if (words.isEmpty) return null;
  return words.map((w) => '"$w"*').join(' ');
}

/// A snippet as (text, highlighted) runs: brackets never reach the UI.
List<(String, bool)> snippetRuns(String snippet) {
  final runs = <(String, bool)>[];
  final re = RegExp(r'\[([^\]]*)\]');
  var at = 0;
  for (final m in re.allMatches(snippet)) {
    if (m.start > at) runs.add((snippet.substring(at, m.start), false));
    runs.add((m.group(1)!, true));
    at = m.end;
  }
  if (at < snippet.length) runs.add((snippet.substring(at), false));
  return runs;
}
