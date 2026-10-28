import 'package:docukit/core/image/resize_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('half-up rounding is deterministic', () {
    expect(roundHalfUp(2.5), 3);
    expect(roundHalfUp(2.4999), 2);
    expect(roundHalfUp(0.5), 1);
  });

  test('locked ratio', () {
    expect(lockedHeightFor(1080, 3000, 4000), 1440);
    expect(lockedWidthFor(1440, 3000, 4000), 1080);
    expect(lockedHeightFor(1, 10000, 1), 1); // never 0
  });

  test('percent dims', () {
    expect(percentDims(50, 3000, 4000), (1500, 2000));
    expect(percentDims(1, 50, 50), (1, 1)); // 0.5 → 1
    expect(percentDims(400, 100, 30), (400, 120));
    expect(percentDims(1, 10, 10), (1, 1)); // max(1, …)
  });

  test('validation limits', () {
    expect(validateDims(1, 1), isNull);
    expect(validateDims(12000, 8000), isNull);
    expect(validateDims(0, 10), DimsError.range);
    expect(validateDims(-1, 10), DimsError.range);
    expect(validateDims(12001, 10), DimsError.range);
    expect(validateDims(null, 10), DimsError.range);
    expect(validateDims(12000, 9000), DimsError.megapixels); // 108 MP
    expect(validateDims(10000, 10000), isNull); // exactly 100 MP
  });

  test('ratio differs threshold', () {
    expect(ratioDiffers(1080, 1440, 3000, 4000), isFalse);
    expect(ratioDiffers(413, 531, 3000, 4000), isTrue);
  });

  group('fitRect', () {
    test('stretch fills the canvas', () {
      expect(fitRect(FitMode.stretch, 100, 50, 400, 400), const FitRect(0, 0, 100, 50));
    });
    test('contain centres inside', () {
      expect(fitRect(FitMode.contain, 100, 50, 400, 400), const FitRect(25, 0, 50, 50));
    });
    test('cover overflows and centres', () {
      expect(fitRect(FitMode.cover, 100, 50, 400, 400), const FitRect(0, -25, 100, 100));
    });
  });

  test('passport preset size', () {
    expect(BuiltInPreset.passport.width, 413);
    expect(BuiltInPreset.passport.height, 531);
  });

  group('fitInsideDims (FR-BAT-12, ADR-062: shrink only)', () {
    test('landscape into a square box keeps its ratio', () => expect(fitInsideDims(1080, 1080, 4000, 3000), (1080, 810)));
    test('portrait into a square box', () => expect(fitInsideDims(1080, 1080, 3000, 4000), (810, 1080)));
    test('the tighter side wins', () => expect(fitInsideDims(1920, 1080, 4000, 3000), (1440, 1080)));
    test('already smaller: unchanged, never enlarged', () => expect(fitInsideDims(1080, 1080, 800, 600), (800, 600)));
    test('one side over, one under: scales down to fit', () => expect(fitInsideDims(1000, 1000, 2000, 500), (1000, 250)));
    test('never exceeds the box after rounding', () {
      for (final (ow, oh) in [(1000, 333), (999, 1001), (4032, 3024), (7, 3)]) {
        final (w, h) = fitInsideDims(300, 100, ow, oh);
        expect(w, lessThanOrEqualTo(300));
        expect(h, lessThanOrEqualTo(100));
        expect(w >= 1 && h >= 1, isTrue);
      }
    });
    test('extreme ratios keep at least 1 px', () => expect(fitInsideDims(100, 100, 10000, 10), (100, 1)));
  });
}
