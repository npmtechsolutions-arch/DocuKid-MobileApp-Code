// RELEASE_V1_1 §4.6 page-range grammar (Split, PDF to Images; C-12), written
// before the implementation. Every listed test case is here.
import 'package:docukit/core/pdf/page_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<(int, int)> ok(String s, int pages) {
    final r = parsePageRanges(s, pages);
    expect(r.error, isNull, reason: '"$s" should parse');
    return [for (final p in r.parts!) (p.first, p.last)];
  }

  PageRangeError err(String s, int pages) {
    final r = parsePageRanges(s, pages);
    expect(r.parts, isNull, reason: '"$s" should fail');
    return r.error!;
  }

  group('valid (§4.6 cases)', () {
    test('"1-3, 5, 8-10"', () => expect(ok('1-3, 5, 8-10', 36), [(1, 3), (5, 5), (8, 10)]));
    test('" 2 "', () => expect(ok(' 2 ', 36), [(2, 2)]));
    test('"7-end"', () => expect(ok('7-end', 36), [(7, 36)]));
    test('"end" alone', () => expect(ok('end', 36), [(36, 36)]));
    test('"1,1": duplicates kept, in order', () => expect(ok('1,1', 36), [(1, 1), (1, 1)]));
    test('"36" on a 36-page PDF', () => expect(ok('36', 36), [(36, 36)]));
    test('spaces and tabs around dashes and commas', () => expect(ok('\t2 -\t4 ,6', 10), [(2, 4), (6, 6)]));
    test('overlaps allowed, order as written', () => expect(ok('5-8, 1-6', 10), [(5, 8), (1, 6)]));
    test('"END" and a localised alias', () {
      expect(ok('3-END', 9), [(3, 9)]);
      final r = parsePageRanges('2-fin', 9, endWords: const {'end', 'fin'});
      expect(r.parts!.single.last, 9);
    });
    test('a single-page range "4-4"', () => expect(ok('4-4', 9), [(4, 4)]));
  });

  group('errors (§4.6)', () {
    test('"5-3" → reversed', () => expect(err('5-3', 36).kind, PageRangeErrorKind.reversed));
    test('"0" → zero', () => expect(err('0', 36).kind, PageRangeErrorKind.zero));
    test('"1-0" → zero', () => expect(err('1-0', 36).kind, PageRangeErrorKind.zero));
    test('"1-" → syntax', () => expect(err('1-', 36).kind, PageRangeErrorKind.chars));
    test('"a" → syntax', () => expect(err('a', 36).kind, PageRangeErrorKind.chars));
    test('"1-3,,5" → syntax', () => expect(err('1-3,,5', 36).kind, PageRangeErrorKind.chars));
    test('"37" on a 36-page PDF → page doesn\'t exist, with the page', () {
      final e = err('37', 36);
      expect((e.kind, e.page), (PageRangeErrorKind.pageMissing, 37));
    });
    test('"1-40" → the range end is checked too', () => expect(err('1-40', 36).page, 40));
    test('empty / blank → empty', () {
      expect(err('', 36).kind, PageRangeErrorKind.empty);
      expect(err('   ', 36).kind, PageRangeErrorKind.empty);
    });
    test('leading zero is not a number ("05")', () => expect(err('05', 36).kind, PageRangeErrorKind.chars));
    test('more than 500 parts → too many', () {
      final s = List.filled(501, '1').join(',');
      expect(err(s, 36).kind, PageRangeErrorKind.tooMany);
      expect(ok(List.filled(500, '1').join(','), 36), hasLength(500));
    });
    test('the first error wins, with its position', () {
      final e = err('1-3, 50, 7-2', 36);
      expect(e.kind, PageRangeErrorKind.pageMissing);
      expect(e.position, 5, reason: 'index of "50"');
    });
  });

  group('post-processing (C-12)', () {
    test('Split keeps parts as written; PDF to Images takes the sorted union', () {
      final parts = parsePageRanges('8-10, 1-3, 2, 9', 36).parts!;
      expect([for (final p in parts) p.pages], [[8, 9, 10], [1, 2, 3], [2], [9]]);
      expect(pageUnion(parts), [1, 2, 3, 8, 9, 10]);
    });
  });
}
