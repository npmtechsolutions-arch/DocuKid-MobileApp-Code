// T10.4 — the pure parts of SearchablePdfBuilder (RELEASE_V1_3 §4.7–4.8):
// chunks and kept-page runs, line placement, and font runs. The PDF itself is
// checked on real PDFium (pdf_engine_host_test) and on the device. Written
// before the implementation.
import 'dart:math' as math;
import 'dart:ui';

import 'package:docukit/core/ocr/ocr_layout.dart';
import 'package:docukit/core/ocr/searchable_pdf_builder.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

RecognisedPage r(int i) => RecognisedPage(
    jpegPath: '/w/p$i.jpg',
    ocrPath: '/w/p$i.json',
    pageWidth: 100,
    pageHeight: 100,
    imageBox: const PdfBox(left: 0, bottom: 0, right: 100, top: 100));

OcrLine line(String text, Rect box, {List<Offset> corners = const []}) =>
    OcrLine(text: text, box: box, corners: corners, words: [OcrWord(text: text, box: box, corners: const [])]);

void main() {
  group('planSegments', () {
    test('recognised pages in chunks of 20, in order', () {
      final s = planSegments([for (var i = 0; i < 45; i++) r(i)]);
      expect(s.map((x) => (x is BuiltSegment, x.pages.length)), [(true, 20), (true, 20), (true, 5)]);
      expect(s.first.pages.first, 0);
      expect(s.last.pages, [40, 41, 42, 43, 44]);
    });

    test('kept pages from the same source are one run; order is kept (OCR-08)', () {
      final s = planSegments([
        const KeptPage('/in/a.pdf', 0),
        r(1),
        r(2),
        const KeptPage('/in/a.pdf', 3),
        const KeptPage('/in/a.pdf', 4),
        r(5),
      ]);
      expect(s.map((x) => x.runtimeType), [KeptSegment, BuiltSegment, KeptSegment, BuiltSegment]);
      expect((s[0] as KeptSegment).sourcePages, [0]);
      expect((s[2] as KeptSegment).sourcePages, [3, 4]);
      expect(s[1].pages, [1, 2]);
      expect(s[3].pages, [5]);
    });

    test('a different source starts a new run; empty → nothing', () {
      final s = planSegments([const KeptPage('/a.pdf', 0), const KeptPage('/b.pdf', 0)]);
      expect(s, hasLength(2));
      expect(planSegments(const []), isEmpty);
    });
  });

  group('placeLine (§4.7)', () {
    // 1000×1000 px image on a 500×500 pt box: 0.5 pt/px. Font em: ascent 1.0, descent −0.25.
    const box = PdfBox(left: 0, bottom: 0, right: 500, top: 500);
    LinePlacement place(OcrLine l, {double natural = 4}) => placeLine(l,
        imageWidth: 1000, imageHeight: 1000, imageBox: box, naturalWidthEm: natural, ascent: 1.0, descent: -0.25);

    test('straight line: the em box fills the line box; scaled to its width', () {
      // 400×50 px at (100, 100) → 200×25 pt, bottom-left (50, 425).
      final p = place(line('Meeting notes', const Rect.fromLTRB(100, 100, 500, 150)), natural: 10);
      expect(p.size, closeTo(25 / 1.25, 1e-9), reason: '(ascent − descent) × size = line height');
      expect(p.origin.dx, closeTo(50, 1e-9));
      expect(p.origin.dy, closeTo(425, 1e-9));
      expect(p.baseline, closeTo(0.25 * p.size, 1e-9), reason: 'baseline above the bottom by the descent');
      expect(p.scale, closeTo(200 / (10 * p.size), 1e-9));
      expect(p.angle, 0);
    });

    test('horizontal scale is clamped to 0.5–2; no width → 1', () {
      expect(place(line('x', const Rect.fromLTRB(0, 0, 1000, 10)), natural: 0.1).scale, 2.0);
      expect(place(line('x', const Rect.fromLTRB(0, 0, 10, 100)), natural: 10).scale, 0.5);
      expect(place(line('x', const Rect.fromLTRB(0, 0, 10, 10)), natural: 0).scale, 1.0);
    });

    test('size is clamped to 4–200 pt', () {
      expect(place(line('x', const Rect.fromLTRB(0, 0, 10, 2))).size, 4);
      expect(place(line('x', const Rect.fromLTRB(0, 0, 10, 1000))).size, 200);
    });

    test('skewed > 2°: placed along the corners, rotated (y flipped)', () {
      // Top edge (100,100)→(500,140): ≈ 5.7° down-right in the image.
      const c = [Offset(100, 100), Offset(500, 140), Offset(495, 190), Offset(95, 150)];
      final p = place(line('tilted', const Rect.fromLTRB(95, 100, 500, 190), corners: c), natural: 10);
      final a = math.atan2(40, 400);
      expect(p.angle, closeTo(-a, 1e-9));
      expect(p.origin.dx, closeTo(47.5, 1e-9), reason: 'bottom-left corner (95,150) → (47.5, 425)');
      expect(p.origin.dy, closeTo(425, 1e-9));
      final height = 0.5 * math.sqrt(5 * 5 + 50 * 50);
      expect(p.size, closeTo(height / 1.25, 1e-9));
      final width = 0.5 * math.sqrt(400 * 400 + 40 * 40);
      expect(p.scale, closeTo(width / (10 * p.size), 1e-9));
    });

    test('≤ 2° stays axis-aligned', () {
      const c = [Offset(100, 100), Offset(500, 110), Offset(500, 160), Offset(100, 150)];
      expect(place(line('flat', const Rect.fromLTRB(100, 100, 500, 160), corners: c)).angle, 0);
    });
  });

  group('splitRuns (§4.8)', () {
    bool deva(int r) => r >= 0x0900 && r <= 0x097F || r == 0x20;
    bool latin(int r) => r < 0x0250;

    test('one font when it covers everything', () {
      final s = splitRuns('Hello world', [latin]);
      expect(s.runs, [(0, 'Hello world')]);
      expect(s.missing, 0);
    });

    test('Devanagari with Latin digits: falls back per character, merged into runs', () {
      final s = splitRuns('कुल 250 रुपये', [deva, latin]);
      expect(s.runs, [(0, 'कुल '), (1, '250'), (0, ' रुपये')]);
      expect(s.missing, 0);
    });

    test('characters no font has become the replacement in the primary font, counted', () {
      final s = splitRuns('Price 中文', [latin]);
      expect(s.runs, [(0, 'Price \uFFFD\uFFFD')]);
      expect(s.missing, 2);
      expect(splitRuns('中', [latin], replacement: 0x3F).runs, [(0, '?')]);
    });
  });

  group('placeWordsSeparately (§4.7 P1)', () {
    OcrLine words(List<double> lefts, {double width = 50}) => OcrLine(
        text: 'x',
        box: Rect.fromLTRB(lefts.first, 0, lefts.last + width, 40),
        corners: const [],
        words: [for (final l in lefts) OcrWord(text: 'w', box: Rect.fromLTRB(l, 0, l + width, 40), corners: const [])]);

    test('more than 12 words → per word', () {
      expect(placeWordsSeparately(words([for (var i = 0; i < 12; i++) i * 60.0])), isFalse);
      expect(placeWordsSeparately(words([for (var i = 0; i < 13; i++) i * 60.0])), isTrue);
    });

    test('uneven gaps (one gap > 2× the median) → per word; even → per line', () {
      expect(placeWordsSeparately(words([0, 60, 120, 180])), isFalse, reason: 'gaps 10, 10, 10');
      expect(placeWordsSeparately(words([0, 60, 120, 400])), isTrue, reason: 'gaps 10, 10, 230');
      expect(placeWordsSeparately(words([0])), isFalse);
    });
  });

  group('separateWords', () {
    test('overlapping or touching boxes are pulled apart around their midpoint', () {
      // OCR-01 on the emulator: "planning" 856–1047, "session." 1045–1224.
      final s = separateWords(const [Rect.fromLTRB(856, 0, 1047, 47), Rect.fromLTRB(1045, 0, 1224, 47)], minGap: 9);
      expect(s[0].right, closeTo(1046 - 4.5, 1e-9));
      expect(s[1].left, closeTo(1046 + 4.5, 1e-9));
      expect((s[0].left, s[1].right), (856, 1224));
    });

    test('gaps already wide enough are kept', () {
      const boxes = [Rect.fromLTRB(0, 0, 100, 40), Rect.fromLTRB(120, 0, 200, 40), Rect.fromLTRB(230, 0, 300, 40)];
      expect(separateWords(boxes, minGap: 9), boxes);
      expect(separateWords(const [], minGap: 9), isEmpty);
    });
  });
}
