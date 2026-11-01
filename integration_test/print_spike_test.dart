// T13.0 spike on a device (RELEASE_PRINT §4.2–4.3, ADR-069/070):
// (a) N-up with PDFium form XObjects in pdfrx's worker on Android;
// (b) docukit_native.printPdf → the system print dialog. The host drives it:
//   "SPIKE print dialog open" → pick "Save as PDF", tap the PDF button, then
//   SAVE in the file dialog; the test prints the job's final status.
//
//   flutter test integration_test/print_spike_test.dart -d <android device>
import 'dart:io';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import '../test/helpers/pdf_page_setup.dart';
import '../tool/spikes/print_nup_spike.dart';

const a4W = 595.28, a4H = 841.89;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_print_spike'))..createSync(recursive: true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<String> source(String name, int n, {List<int> turns = const []}) async {
    final doc = pw.Document();
    for (var i = 1; i <= n; i++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(60),
        build: (_) => pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOP${String.fromCharCode(64 + i)}', style: const pw.TextStyle(fontSize: 28)),
          pw.Text('Page $i of $n', style: const pw.TextStyle(fontSize: 18)),
        ]),
      ));
    }
    final raw = p.join(dir.path, 'raw_$name');
    File(raw).writeAsBytesSync(await doc.save());
    if (turns.isEmpty) return raw;
    final out = p.join(dir.path, name);
    expect(await PdfrxEntryFunctions.instance.compute(setupPagesInWorker, PageSetupRequest(raw, out, Pdfrx.pdfiumModulePath, quarterTurns: turns)), '');
    return out;
  }

  Future<String> compose(String input, String name, {int cols = 1, int rows = 1, SpikeScale scale = SpikeScale.fit}) async {
    final out = p.join(dir.path, name);
    final sw = Stopwatch()..start();
    final err = await PdfrxEntryFunctions.instance.compute(
        nupInWorker,
        NupRequest(
            input: input, output: out, modulePath: Pdfrx.pdfiumModulePath, sheetW: a4W, sheetH: a4H, cols: cols, rows: rows, scale: scale));
    // ignore: avoid_print
    print('SPIKE compose $name: ${sw.elapsedMilliseconds} ms, ${File(out).lengthSync()} B');
    expect(err, '');
    return out;
  }

  testWidgets('(a) on Android: 2-up of /Rotate 0/90/180/270 pages; text stays extractable; Fill compose works', (_) async {
    final out = await compose(await source('rot.pdf', 4, turns: [0, 1, 2, 3]), 'two_up.pdf', rows: 2);
    final d = await PdfDocument.openFile(out);
    expect(d.pages.length, 2);
    final texts = [for (final pg in d.pages) (await pg.loadText())?.fullText ?? ''];
    await d.dispose();
    // ignore: avoid_print
    print('SPIKE device text: ${texts.map((t) => t.replaceAll('\n', ' | ')).toList()}');
    for (final tag in ['TOPA', 'TOPB', 'TOPC', 'TOPD']) {
      expect(texts.join(' '), contains(tag), reason: 'vector text kept: $tag');
    }
    final fill = await compose(await source('plain.pdf', 2), 'fill.pdf', rows: 2, scale: SpikeScale.fill);
    expect(File(fill).lengthSync(), greaterThan(0));
  });

  testWidgets('(b) printPdf → system dialog → Save as PDF → "sent" (R69 shape: 10 A4 pages, 1 per sheet)', (_) async {
    final sheets = await compose(await source('ten.pdf', 10), 'R69_ten_pages.pdf');
    final sw = Stopwatch()..start();
    // ignore: avoid_print
    print('SPIKE print dialog open');
    final status = await DocukitNative().printPdf(sheets, jobName: 'R69 ten pages A4', paper: 'a4');
    // ignore: avoid_print
    print('SPIKE print status: $status after ${sw.elapsed.inSeconds} s');
    expect(status, 'sent');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
