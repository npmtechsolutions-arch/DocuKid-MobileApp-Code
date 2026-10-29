// T10.2 — RELEASE_V1_3 §4.5: image pixels (top-left origin) → PDF points
// (bottom-left origin), skew angle, and reading order. Written before the
// implementation.
import 'dart:math' as math;
import 'dart:ui';

import 'package:docukit/core/ocr/ocr_layout.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLine line(String text, double l, double t, double r, double b, {List<Offset> corners = const []}) => OcrLine(
      text: text,
      box: Rect.fromLTRB(l, t, r, b),
      corners: corners,
      words: [for (final w in text.split(' ')) OcrWord(text: w, box: Rect.fromLTRB(l, t, r, b), corners: const [])],
    );

Matcher closeBox(double l, double b, double r, double t) => isA<PdfBox>()
    .having((x) => x.left, 'left', closeTo(l, 1e-6))
    .having((x) => x.bottom, 'bottom', closeTo(b, 1e-6))
    .having((x) => x.right, 'right', closeTo(r, 1e-6))
    .having((x) => x.top, 'top', closeTo(t, 1e-6));

void main() {
  group('toPdfBox', () {
    // A 1000×2000 px image drawn full-page on a 500×1000 pt page: 0.5 pt/px.
    const page = PdfBox(left: 0, bottom: 0, right: 500, top: 1000);

    test('corners: image top-left → page top-left; bottom-right → bottom-right', () {
      expect(toPdfBox(const Rect.fromLTRB(0, 0, 1000, 2000), imageWidth: 1000, imageHeight: 2000, page: page),
          closeBox(0, 0, 500, 1000));
      expect(toPdfBox(const Rect.fromLTRB(0, 0, 10, 10), imageWidth: 1000, imageHeight: 2000, page: page),
          closeBox(0, 995, 5, 1000));
      expect(toPdfBox(const Rect.fromLTRB(990, 1990, 1000, 2000), imageWidth: 1000, imageHeight: 2000, page: page),
          closeBox(495, 0, 500, 5));
    });

    test('y is flipped: a box near the top of the image is near the top of the page', () {
      final b = toPdfBox(const Rect.fromLTRB(100, 200, 300, 260), imageWidth: 1000, imageHeight: 2000, page: page);
      expect(b, closeBox(50, 870, 150, 900));
      expect((b.width, b.height), (100, 30));
      expect(b.top, greaterThan(b.bottom));
    });

    test('page offsets and margins: the image rect inside the page shifts and scales', () {
      // Image drawn into (40, 60)–(440, 860): 400×800 pt for 1000×2000 px = 0.4 pt/px.
      const inset = PdfBox(left: 40, bottom: 60, right: 440, top: 860);
      expect(toPdfBox(const Rect.fromLTRB(0, 0, 1000, 2000), imageWidth: 1000, imageHeight: 2000, page: inset),
          closeBox(40, 60, 440, 860));
      expect(toPdfBox(const Rect.fromLTRB(100, 200, 300, 260), imageWidth: 1000, imageHeight: 2000, page: inset),
          closeBox(80, 756, 160, 780));
    });

    test('landscape (rotated) page: the upright image is W > H; the same rule holds', () {
      const land = PdfBox(left: 0, bottom: 0, right: 842, top: 595);
      final b = toPdfBox(const Rect.fromLTRB(0, 0, 1684, 119), imageWidth: 3368, imageHeight: 2380, page: land);
      expect(b, closeBox(0, 565.25, 421, 595));
    });

    test('non-uniform scale (stretched image) maps x and y separately', () {
      const wide = PdfBox(left: 0, bottom: 0, right: 200, top: 100);
      expect(toPdfBox(const Rect.fromLTRB(50, 50, 100, 100), imageWidth: 100, imageHeight: 100, page: wide),
          closeBox(100, 0, 200, 50));
    });

    test('points map the same way (for skewed lines)', () {
      final o = toPdfPoint(const Offset(100, 200), imageWidth: 1000, imageHeight: 2000, page: page);
      expect((o.dx, o.dy), (50, 900));
    });
  });

  group('skew', () {
    test('angle from the top edge; 0 without corners', () {
      expect(imageAngle(const []), 0);
      expect(imageAngle(const [Offset(0, 0), Offset(100, 0), Offset(100, 20), Offset(0, 20)]), 0);
      final a = imageAngle(const [Offset(0, 0), Offset(100, 10), Offset(98, 30), Offset(-2, 20)]);
      expect(a, closeTo(math.atan2(10, 100), 1e-9));
    });

    test('PDF angle is the negated image angle (y flipped); skewed above 2°', () {
      final a = math.atan2(10, 100); // ≈ 5.7°
      expect(pdfAngle(a), -a);
      expect(isSkewed(a), isTrue);
      expect(isSkewed(1.5 * math.pi / 180), isFalse);
      expect(isSkewed(-3 * math.pi / 180), isTrue);
    });
  });

  group('reading order', () {
    test('top to bottom', () {
      final out = readingOrder([line('c', 0, 300, 100, 340), line('a', 0, 100, 100, 140), line('b', 0, 200, 100, 240)]);
      expect(out.map((l) => l.text), ['a', 'b', 'c']);
    });

    test('same row (vertical overlap > 50% of the smaller height) → left to right', () {
      final out = readingOrder([
        line('Total', 600, 105, 800, 145), // a little lower, same row
        line('Name', 100, 100, 300, 140),
        line('next', 100, 200, 300, 240),
      ]);
      expect(out.map((l) => l.text), ['Name', 'Total', 'next']);
    });

    test('overlap of 50% or less starts a new row', () {
      // Heights 40; the second starts 20 px lower → overlap 20 = 50% → new row.
      final out = readingOrder([line('right', 600, 120, 800, 160), line('left', 100, 100, 300, 140)]);
      expect(out.map((l) => l.text), ['left', 'right']);
      final out2 = readingOrder([line('right', 600, 121, 800, 161), line('left', 700, 100, 900, 140)]);
      expect(out2.map((l) => l.text), ['left', 'right'], reason: 'different rows: top first even if further right');
    });

    test('the smaller height counts: a small label beside a tall heading shares its row', () {
      final out = readingOrder([line('label', 600, 140, 700, 160), line('HEADING', 100, 100, 500, 200)]);
      expect(out.map((l) => l.text), ['HEADING', 'label']);
    });

    test('an empty page and a single line pass through', () {
      expect(readingOrder(const []), isEmpty);
      expect(readingOrder([line('a', 0, 0, 1, 1)]).single.text, 'a');
    });

    test('sortedPage keeps sizes and words, reorders lines', () {
      final p = OcrPage(imageWidth: 10, imageHeight: 20, lines: [line('b', 0, 200, 100, 240), line('a', 0, 100, 100, 140)]);
      final s = sortedPage(p);
      expect((s.imageWidth, s.imageHeight, s.wordCount, s.text), (10, 20, 2, 'a\nb'));
    });
  });
}
