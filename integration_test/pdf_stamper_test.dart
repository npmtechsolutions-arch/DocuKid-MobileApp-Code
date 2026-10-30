// T11.5 on a device (RELEASE_V1_4 §8.3 rows 5–6, §4.3): PdfiumStamper's
// accuracy on PDF-04 rotated_pages.pdf (/Rotate 0/90/180/270) and PDF-15
// cropbox_offset.pdf (crop box inset 36 pt) — a coloured marker square lands
// at the editor's position ±1 pt at 72 dpi — and a text stamp rendered with
// the phone's fonts (Latin + Hindi) is non-blank in its box.
//
//   flutter test integration_test/pdf_stamper_test.dart -d <android device>
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_stamper.dart';
import 'package:docukit/core/pdf/text_stamp_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import '../test/helpers/pdf_page_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stamper = PdfiumStamper();
  late Directory dir;
  late String marker;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_stamper'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    // A signature-like PNG: transparent, with a green marker square in its top-left.
    final im = img.Image(width: 400, height: 200, numChannels: 4);
    for (var y = 0; y < 50; y++) {
      for (var x = 0; x < 100; x++) {
        im.setPixelRgba(x, y, 0, 200, 0, 255);
      }
    }
    marker = p.join(dir.path, 'marker.png');
    File(marker).writeAsBytesSync(img.encodePng(im));
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  JobContext ctx() => JobContext(jobId: 'it_stamp', workDir: dir, cancel: CancelToken(), report: (_) {});

  /// White A4 pages with text, then /Rotate and the crop box (corpus PDF-04 / PDF-15).
  Future<String> corpus(String name, {List<int> turns = const [], double crop = 0}) async {
    final doc = pw.Document();
    for (var i = 0; i < 4; i++) {
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Text('Agreement page ${i + 1}')));
    }
    final raw = p.join(dir.path, 'raw_$name');
    File(raw).writeAsBytesSync(await doc.save());
    final out = p.join(dir.path, name);
    expect(
        await PdfrxEntryFunctions.instance.compute(setupPagesInWorker,
            PageSetupRequest(raw, out, Pdfrx.pdfiumModulePath, quarterTurns: turns, cropInset: crop)),
        '');
    return out;
  }

  /// The page rendered at 72 dpi (1 px per point) in visual space.
  Future<(int, int, Uint8List)> render(String path, int page) async {
    final d = await PdfDocument.openFile(path);
    try {
      final pg = d.pages[page];
      final w = pg.width.round(), h = pg.height.round();
      final im = (await pg.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
      final px = Uint8List.fromList(im.pixels);
      im.dispose();
      return (w, h, px);
    } finally {
      await d.dispose();
    }
  }

  /// The bounding box of green marker pixels (BGRA).
  Rect? markerBox((int, int, Uint8List) r) {
    final (w, h, px) = r;
    int? x0, y0, x1, y1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (px[i + 1] > 150 && px[i] < 90 && px[i + 2] < 90) {
          x0 = x0 == null || x < x0 ? x : x0;
          y0 = y0 == null || y < y0 ? y : y0;
          x1 = x1 == null || x > x1 ? x : x1;
          y1 = y1 == null || y > y1 ? y : y1;
        }
      }
    }
    return x0 == null ? null : Rect.fromLTRB(x0.toDouble(), y0!.toDouble(), x1! + 1.0, y1! + 1.0);
  }

  for (final (name, turns, crop) in [
    ('rotated_pages.pdf', const [0, 1, 2, 3], 0.0),
    ('cropbox_offset.pdf', const [0, 1, 2, 3], 36.0),
  ]) {
    testWidgets('$name: the marker lands where the editor put it on every rotation (±1 pt)', (_) async {
      final input = await corpus(name, turns: turns, crop: crop);
      final out = p.join(dir.path, 'signed_$name');
      // A 160×80 pt signature at visual (72, 120): its marker is the top-left 40×20 pt.
      const rect = Rect.fromLTWH(72, 120, 160, 80);
      await stamper.apply(input, [for (var i = 0; i < 4; i++) Stamp(pageIndex: i, pngPath: marker, visualRect: rect)], out, ctx());
      for (var i = 0; i < 4; i++) {
        final box = markerBox(await render(out, i));
        // ignore: avoid_print
        print('T11.5 $name page ${turns[i] * 90}°: marker $box (want 72,120 → 112,140)');
        expect(box, isNotNull, reason: 'page ${turns[i] * 90}°');
        for (final (got, want) in [(box!.left, 72.0), (box.top, 120.0), (box.right, 112.0), (box.bottom, 140.0)]) {
          expect(got, closeTo(want, 1.0), reason: 'page ${turns[i] * 90}° ($name)');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  testWidgets('a text stamp (Latin + Hindi) rendered with the phone\'s fonts is non-blank in its box', (tester) async {
    final input = await corpus('text.pdf', turns: const [1]);
    final out = p.join(dir.path, 'text_out.pdf');
    for (final (i, t) in [(0, 'Approved'), (1, 'स्वीकृत')]) {
      final r = (await tester.runAsync(() => renderTextPng(t,
          outPath: p.join(dir.path, 'text_$i.png'), colour: const Color(0xFF1565C0), heightPt: 24, bold: true)))!;
      await stamper.apply(i == 0 ? input : out, [Stamp(pageIndex: 0, pngPath: r.pngPath,
          visualRect: Rect.fromLTWH(100, 200.0 + i * 60, r.widthPt, r.heightPt))], i == 0 ? out : p.join(dir.path, 'text_out2.pdf'), ctx());
    }
    final (w, _, px) = await render(p.join(dir.path, 'text_out2.pdf'), 0);
    int ink(double top) {
      var n = 0;
      for (var y = top.toInt(); y < top + 24; y++) {
        for (var x = 100; x < 300; x++) {
          final i = (y * w + x) * 4;
          if (px[i] > 150 && px[i + 2] < 120) n++; // blue ink (BGRA)
        }
      }
      return n;
    }

    // ignore: avoid_print
    print('T11.5 text stamps ink px: Latin ${ink(200)}, Hindi ${ink(260)}');
    expect(ink(200), greaterThan(100));
    expect(ink(260), greaterThan(100));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
