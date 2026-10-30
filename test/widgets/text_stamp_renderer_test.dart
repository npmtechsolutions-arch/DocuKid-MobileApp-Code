// T11.5 — text → transparent PNG for watermarks and typed stamps
// (RELEASE_V1_4 §4.3), written before the implementation: 300 dpi of the
// placed height, a 2400 px cap, a transparent background, any script.
import 'dart:io';
import 'dart:ui';

import 'package:docukit/core/pdf/text_stamp_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('text_stamp'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(TextStampImage, img.Image)> render(WidgetTester tester, String text, double heightPt,
      {Color colour = const Color(0xFFD32F2F), bool bold = false}) async {
    final out = p.join(dir.path, '${text.hashCode}_$heightPt.png');
    final r = (await tester.runAsync(
        () => renderTextPng(text, outPath: out, colour: colour, bold: bold, heightPt: heightPt)))!;
    return (r, img.decodePng(File(out).readAsBytesSync())!);
  }

  int inked(img.Image im) => im.where((px) => px.a > 0).length;

  testWidgets('"DRAFT" at 40 pt: about 40/72 × 300 px tall, transparent corners, ink in the stamp colour', (tester) async {
    final (r, im) = await render(tester, 'DRAFT', 40);
    expect(r.pngPath, endsWith('.png'));
    expect((im.width, im.height), (r.widthPx, r.heightPx));
    expect(r.heightPx, inInclusiveRange(150, 230), reason: '40 pt at 300 dpi ≈ 167 px of text plus padding');
    expect(r.widthPt / r.heightPt, closeTo(r.widthPx / r.heightPx, 0.01), reason: 'the placed size keeps the aspect');
    for (final (x, y) in [(0, 0), (im.width - 1, 0), (0, im.height - 1), (im.width - 1, im.height - 1)]) {
      expect(im.getPixel(x, y).a, 0, reason: 'transparent corner ($x, $y)');
    }
    expect(inked(im), greaterThan(im.width * im.height ~/ 20));
    final ink = im.firstWhere((px) => px.a == 255);
    expect((ink.r, ink.g, ink.b), (0xD3, 0x2F, 0x2F));
  });

  testWidgets('Hindi and Arabic text render (non-blank); Arabic lays out right-to-left without error', (tester) async {
    for (final t in ['गोपनीय', 'سري للغاية']) {
      final (_, im) = await render(tester, t, 30);
      expect(inked(im), greaterThan(0), reason: t);
    }
  });

  testWidgets('a long line at a big size is capped at 2400 px on its long side', (tester) async {
    final (r, im) = await render(tester, 'CONFIDENTIAL — DO NOT DISTRIBUTE', 120);
    expect(im.width, lessThanOrEqualTo(2400));
    expect(r.widthPx, lessThanOrEqualTo(2400));
    expect(r.heightPt, closeTo(120, 0.01), reason: 'the placed size is unchanged; only the pixels are fewer');
  });

  testWidgets('empty or blank text is refused', (tester) async {
    final out = p.join(dir.path, 'blank.png');
    // Refused before any rendering, so no runAsync (which would swallow the error).
    await expectLater(renderTextPng('  ', outPath: out, colour: const Color(0xFF000000), heightPt: 20), throwsArgumentError);
    expect(File(out).existsSync(), isFalse);
  });
}
