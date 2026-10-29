// T10.3 on a device: existing-text detection with Android's PDFium, and the
// badge each fixture gets (RELEASE_V1_3 §4.6, OCR-07/08/09).
//
//   flutter test integration_test/ocr_text_detection_test.dart -d <android device>
import 'dart:io';
import 'dart:ui';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/ocr/ocr_labels.dart';
import 'package:docukit/core/ocr/pdf_text_reader.dart';
import 'package:docukit/core/ocr/pdfrx_text_reader.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import '../tool/fixtures/ocr_text.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppLocalizations l;
  const reader = PdfrxTextReader();

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_ocr_detect'))..createSync(recursive: true);
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<String> pdf(String name, List<pw.Page> pages) async {
    final doc = pw.Document();
    pages.forEach(doc.addPage);
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(await doc.save());
    return path;
  }

  testWidgets('OCR-07 / 08 / 09 → No text yet / Text on 1 of 3 pages / Already has text', (_) async {
    // Image pages are photos of text: there is text to see, but none to extract.
    final photo = img.encodeJpg(img.decodePng((await drawOcrPage(ocrLatinText)).png)!, quality: 80);
    pw.Page imagePage() => pw.Page(build: (_) => pw.Image(pw.MemoryImage(photo), fit: pw.BoxFit.contain));
    pw.Page textPage() => pw.Page(build: (_) => pw.Text(ocrLatinText));

    final cases = {
      'ocr07.pdf': ([imagePage(), imagePage(), imagePage()], [false, false, false], 'No text yet'),
      'ocr08.pdf': ([textPage(), imagePage(), imagePage()], [true, false, false], 'Text on 1 of 3 pages'),
      'ocr09.pdf': ([textPage(), textPage()], [true, true], 'Already has text'),
    };
    for (final MapEntry(key: name, value: (pages, flags, badge)) in cases.entries) {
      final path = await pdf(name, pages);
      final sw = Stopwatch()..start();
      final got = await reader.textPages(path);
      expect(got, flags, reason: name);
      expect(ocrTextBadge(l, PdfTextSummary.of(got)), badge, reason: name);
      // ignore: avoid_print
      print('T10.3 $name flags=$got ${sw.elapsedMilliseconds}ms');
    }
    expect(await reader.pageText(p.join(dir.path, 'ocr08.pdf'), 0), contains('spring planning session'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('300 pages are checked quickly (text extraction only, no rendering)', (_) async {
    final path = await pdf('ocr_300.pdf', [
      for (var i = 0; i < 300; i++) pw.Page(build: (_) => pw.Text(i.isEven ? 'Page $i: $ocrLatinText' : '$i')),
    ]);
    final sw = Stopwatch()..start();
    final flags = await reader.textPages(path);
    final ms = sw.elapsedMilliseconds;
    expect(flags, hasLength(300));
    expect(PdfTextSummary.of(flags).withText, 150);
    // ignore: avoid_print
    print('T10.3 300 pages ${ms}ms');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
