/// Page-range grammar (RELEASE_V1_1 §4.6) for Split and PDF to Images. One
/// parser returns the parts in the order written; each tool post-processes
/// them (C-12): Split keeps them as written, PDF to Images takes [pageUnion].
///
///   input  := ws part (ws "," ws part)* ws
///   part   := number | number ws "-" ws number | number ws "-" ws "end" | "end"
///   number := [1-9][0-9]*      ws := [ \t]*
library;

/// More parts than this is an error (and more outputs than Split allows).
const maxRangeParts = 500;

/// Inclusive, 1-based.
class PageRange {
  const PageRange(this.first, this.last);
  final int first, last;

  List<int> get pages => [for (var p = first; p <= last; p++) p];

  @override
  bool operator ==(Object other) => other is PageRange && other.first == first && other.last == last;
  @override
  int get hashCode => Object.hash(first, last);
}

enum PageRangeErrorKind { empty, zero, pageMissing, reversed, chars, tooMany }

class PageRangeError {
  const PageRangeError(this.kind, this.position, {this.page});
  final PageRangeErrorKind kind;

  /// Index in the input where the problem starts.
  final int position;

  /// The missing page, for [PageRangeErrorKind.pageMissing].
  final int? page;
}

class PageRangeResult {
  const PageRangeResult.ok(List<PageRange> this.parts) : error = null;
  const PageRangeResult.fail(PageRangeError this.error) : parts = null;
  final List<PageRange>? parts;
  final PageRangeError? error;
}

final _letter = RegExp(r'\p{L}', unicode: true);

/// Parses [input] for a PDF of [pageCount] pages. [endWords] are the words
/// for the last page ("end" plus the ARB alias), matched ignoring case. The
/// first error found, left to right, is returned.
PageRangeResult parsePageRanges(String input, int pageCount, {Set<String> endWords = const {'end'}}) {
  final ends = {for (final w in endWords) w.toLowerCase()};
  var i = 0;
  bool isWs(int at) => at < input.length && (input[at] == ' ' || input[at] == '\t');
  void skipWs() {
    while (isWs(i)) {
      i++;
    }
  }

  bool isDigit(int at) => at < input.length && input.codeUnitAt(at) >= 0x30 && input.codeUnitAt(at) <= 0x39;

  // A number or an end word at i: (value, start), or an error.
  (int, int)? term(void Function(PageRangeError) fail) {
    final start = i;
    if (isDigit(i)) {
      while (isDigit(i)) {
        i++;
      }
      final text = input.substring(start, i);
      if (text.startsWith('0')) {
        // "0" is a page number that can't exist; "05" isn't a number at all.
        fail(PageRangeError(text.length == 1 ? PageRangeErrorKind.zero : PageRangeErrorKind.chars, start));
        return null;
      }
      return (int.parse(text), start);
    }
    while (i < input.length && _letter.hasMatch(input[i])) {
      i++;
    }
    if (i > start && ends.contains(input.substring(start, i).toLowerCase())) return (pageCount, start);
    fail(PageRangeError(PageRangeErrorKind.chars, start));
    return null;
  }

  skipWs();
  if (i >= input.length) return const PageRangeResult.fail(PageRangeError(PageRangeErrorKind.empty, 0));

  final parts = <PageRange>[];
  PageRangeError? error;
  void fail(PageRangeError e) => error ??= e;

  while (true) {
    final partStart = i;
    if (parts.length == maxRangeParts) return PageRangeResult.fail(PageRangeError(PageRangeErrorKind.tooMany, partStart));
    final a = term(fail);
    if (a == null) return PageRangeResult.fail(error!);
    if (a.$1 > pageCount) return PageRangeResult.fail(PageRangeError(PageRangeErrorKind.pageMissing, a.$2, page: a.$1));
    var last = a.$1;
    skipWs();
    if (i < input.length && input[i] == '-') {
      i++;
      skipWs();
      final b = term(fail);
      if (b == null) return PageRangeResult.fail(error!);
      if (b.$1 > pageCount) return PageRangeResult.fail(PageRangeError(PageRangeErrorKind.pageMissing, b.$2, page: b.$1));
      if (b.$1 < a.$1) return PageRangeResult.fail(PageRangeError(PageRangeErrorKind.reversed, partStart));
      last = b.$1;
      skipWs();
    }
    parts.add(PageRange(a.$1, last));
    if (i >= input.length) return PageRangeResult.ok(parts);
    if (input[i] != ',') return PageRangeResult.fail(PageRangeError(PageRangeErrorKind.chars, i));
    i++;
    skipWs();
  }
}

/// PDF to Images (C-12): every page in any part, ascending, once.
List<int> pageUnion(List<PageRange> parts) => ({for (final r in parts) ...r.pages}.toList()..sort());
