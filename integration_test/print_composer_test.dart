// T13.2 / T13.3 on a device (RELEASE_PRINT R70, R72, ADR-070): the real composer in
// pdfrx's PDFium worker on Android, then the system dialog → Save as PDF.
// The host drives the dialog: "PRINT dialog open" → pick Save as PDF, tap
// the PDF button, then SAVE; the saved file is checked on the host.
//
//   flutter test integration_test/print_composer_test.dart -d <android device> --plain-name R70   (or R72)
import 'dart:io';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/print/print_composer.dart';
import 'package:docukit/core/print/print_settings.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_print'))..createSync(recursive: true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  testWidgets('R70: Range "2-4, 7", 2 per sheet, Landscape → 2 sheets (2, 3 | 4, 7) → Save as PDF → sent', (_) async {
    final doc = pw.Document();
    for (var i = 1; i <= 10; i++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(60),
        build: (_) => pw.Center(child: pw.Text('PAGE${String.fromCharCode(64 + i)}', style: const pw.TextStyle(fontSize: 48))),
      ));
    }
    final src = p.join(dir.path, 'ten.pdf');
    File(src).writeAsBytesSync(await doc.save());
    final work = Directory(p.join(dir.path, 'work'))..createSync();
    final sw = Stopwatch()..start();
    final out = await const PdfiumPrintComposer().compose(
      PdfPrintSource(src),
      const PrintSettings(pages: PageSelection.range('2-4, 7'), perSheet: 2, orientation: PrintOrientation.landscape),
      JobContext(jobId: 'r70', workDir: work, cancel: CancelToken(), report: (_) {}),
    );
    // ignore: avoid_print
    print('PRINT composed ${out.sheetCount} sheets in ${sw.elapsedMilliseconds} ms: ${out.sheetSizesPt}');
    expect(out.sheetCount, 2);
    final d = await PdfDocument.openFile(out.path);
    final texts = [for (final pg in d.pages) (await pg.loadText())?.fullText ?? ''];
    await d.dispose();
    // ignore: avoid_print
    print('PRINT sheet text: ${texts.map((t) => t.replaceAll('\n', ' ')).toList()}');
    expect(texts[0], allOf(contains('PAGEB'), contains('PAGEC')));
    expect(texts[1], allOf(contains('PAGED'), contains('PAGEG')));

    // ignore: avoid_print
    print('PRINT dialog open');
    final status = await DocukitNative().printPdf(out.path, jobName: 'R70 range two per sheet', paper: 'a4', landscape: true);
    // ignore: avoid_print
    print('PRINT status: $status');
    expect(status, 'sent');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('R72: passport sheet on 4×6 in, no margins, from a 413 × 531 px photo → 8 photos → Save as PDF → sent', (_) async {
    // A stand-in passport photo: green with a red band across the top third.
    final im = img.Image(width: 413, height: 531)..clear(img.ColorRgb8(40, 160, 60));
    img.fillRect(im, x1: 0, y1: 0, x2: 412, y2: 176, color: img.ColorRgb8(210, 40, 40));
    final src = p.join(dir.path, 'passport.jpg');
    File(src).writeAsBytesSync(img.encodeJpg(im, quality: 95));
    const engine = NativeImageEngine();
    final meta = await engine.inspect(src);
    final work = Directory(p.join(dir.path, 'work72'))..createSync();
    final sw = Stopwatch()..start();
    final out = await PdfiumPrintComposer(images: engine, pdf: PdfrxPdfEngine()).compose(
      ImagesPrintSource([
        PickedFile(path: src, displayName: 'passport.jpg', type: SniffedType.jpeg, sizeBytes: File(src).lengthSync(), image: meta),
      ]),
      const PrintSettings(imageLayout: ImageLayout.passportSheet, paper: PaperSize.in4x6, margins: PrintMargins.none),
      JobContext(jobId: 'r72', workDir: work, cancel: CancelToken(), report: (_) {}),
    );
    // ignore: avoid_print
    print('PRINT composed ${out.sheetCount} sheet in ${sw.elapsedMilliseconds} ms: ${out.sheetSizesPt}');
    expect(out.sheetCount, 1);
    expect(out.sheetSizesPt.single.width, closeTo(432, 0.5));
    expect(out.sheetSizesPt.single.height, closeTo(288, 0.5));

    // ignore: avoid_print
    print('PRINT dialog open');
    final status = await DocukitNative().printPdf(out.path, jobName: 'R72 passport sheet', paper: 'in4x6', landscape: true);
    // ignore: avoid_print
    print('PRINT status: $status');
    expect(status, 'sent');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
