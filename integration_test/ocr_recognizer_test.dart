// T10.1 on a device: MlKitTextRecognizer on OCR-01 finds ≥ 95% of the words,
// with boxes in the oriented image's pixels (RELEASE_V1_3 §4.2, §8.2).
//
//   flutter test integration_test/ocr_recognizer_test.dart -d <android device>
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/ocr/mlkit_text_recognizer.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import '../tool/fixtures/ocr_text.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_ocr'))..createSync(recursive: true);
  });

  Future<String> jpg(String name, OcrFixture f) async {
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(img.encodeJpg(img.decodePng(f.png)!, quality: 90));
    return path;
  }

  testWidgets('OCR-01: ≥ 95% of the words, boxes on the words (Latin)', (_) async {
    final f = await drawOcrPage(ocrLatinText);
    final path = await jpg('ocr01.jpg', f);
    final r = MlKitTextRecognizer();
    final sw = Stopwatch()..start();
    final page = await r.recognize(path, OcrScript.latin);
    final ms = sw.elapsedMilliseconds;
    await r.dispose();

    final found = [for (final l in page.lines) for (final w in l.words) ...ocrWords(w.text)];
    final recall = ocrRecall(ocrWords(ocrLatinText), found);
    expect(recall, greaterThanOrEqualTo(0.95));
    expect((page.imageWidth, page.imageHeight), (f.width, f.height));
    var onBox = 0;
    final words = [for (final l in page.lines) ...l.words];
    for (final (text, box) in f.truth) {
      final key = ocrWords(text).join();
      if (words.any((w) => ocrWords(w.text).join() == key && rectIou(w.box, box) >= 0.5)) onBox++;
    }
    expect(onBox / f.truth.length, greaterThanOrEqualTo(0.95), reason: 'word boxes in the image\'s pixels');
    expect(words.where((w) => w.confidence != null), isNotEmpty, reason: 'Android reports confidence');
    // ignore: avoid_print
    print('T10.1 OCR-01 recall=${recall.toStringAsFixed(3)} onBox=${(onBox / f.truth.length).toStringAsFixed(3)} '
        'lines=${page.lines.length} words=${page.wordCount} ms=$ms');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('Devanagari (bundled, ADR-045) and a blank page', (_) async {
    final r = MlKitTextRecognizer();
    expect(await r.availableScripts(), {OcrScript.latin, OcrScript.devanagari});
    final hindi = await r.recognize(await jpg('ocr05.jpg', await drawOcrPage(ocrHindiText, fontSize: 70)),
        OcrScript.devanagari);
    final found = [for (final l in hindi.lines) for (final w in l.words) ...ocrWords(w.text)];
    expect(ocrRecall(ocrWords(ocrHindiText), found), greaterThanOrEqualTo(0.95));
    final blank = await r.recognize(await jpg('ocr06.jpg', await drawOcrPage('')), OcrScript.latin);
    expect(blank.wordCount, 0, reason: 'OCR-06');
    await expectLater(r.recognize(p.join(dir.path, 'missing.jpg'), OcrScript.latin),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.processingFailed)));
    final notImage = File(p.join(dir.path, 'not_image.jpg'))..writeAsStringSync('hello');
    await expectLater(r.recognize(notImage.path, OcrScript.latin),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.corruptFile)));
    await r.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
