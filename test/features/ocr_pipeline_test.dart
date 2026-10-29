// T10.5 — OcrPipeline + OcrOperation with fakes (RELEASE_V1_3 §4.3–4.4,
// FR-OCR-01/07/10/11/12/15): progress, cancel, existing-text pages, rotation
// retry, low-text stats, review files and the outputs. Written before the
// implementation.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/ocr/ocr_text_file.dart';
import 'package:docukit/core/ocr/pdf_text_reader.dart';
import 'package:docukit/core/ocr/searchable_pdf_builder.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_engine.dart';
import 'package:docukit/features/ocr/application/ocr_operation.dart';
import 'package:docukit/features/ocr/application/ocr_options.dart';
import 'package:docukit/features/ocr/application/ocr_pipeline.dart';
import 'package:docukit/features/ocr/application/ocr_review_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';
import '../helpers/test_app.dart' show FakePdfEngine;

OcrPage words(int n, {int w = 1000, int h = 1400}) => OcrPage(imageWidth: w, imageHeight: h, lines: [
      for (var i = 0; i < n; i++)
        OcrLine(text: 'word$i', box: Rect.fromLTRB(10, 10.0 + 50 * i, 200, 50.0 + 50 * i), corners: const [], words: [
          OcrWord(text: 'word$i', box: Rect.fromLTRB(10, 10.0 + 50 * i, 200, 50.0 + 50 * i), corners: const []),
        ]),
    ]);

/// Copies the input; reports the oriented size, turned for extraRotation.
class _Images implements ImageEngine {
  final calls = <(String, ImageTransform)>[];
  @override
  bool canEncode(ImageFormat format) => true;
  @override
  Future<ImageMeta> inspect(String path) async => const ImageMeta(format: SniffedType.jpeg, width: 1000, height: 1400);
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    calls.add((p.basename(outPath), t));
    File(outPath).writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    var (w, h) = (meta?.width ?? 1000, meta?.height ?? 1400);
    if (t.extraRotation % 180 != 0) (w, h) = (h, w);
    final long = w > h ? w : h;
    if (t.maxLongEdge != null && long > t.maxLongEdge!) {
      final s = t.maxLongEdge! / long;
      (w, h) = ((w * s).round(), (h * s).round());
    }
    return EncodedImage(path: outPath, bytes: 4, width: w, height: h, format: ImageFormat.jpeg);
  }
}

class _Extractor implements PdfPageExtractor {
  _Extractor(this.pageCount);
  @override
  final int pageCount;
  final renders = <(int, int, int)>[];
  bool closed = false;
  @override
  Future<void> extract(List<int> pages, String out) async {}
  @override
  Future<PagePixels> renderPage(int index, {required int width, required int height, required bool transparent}) async {
    renders.add((index, width, height));
    return PagePixels(Uint8List(4), 1, 1);
  }

  @override
  Future<void> close() async => closed = true;
}

class _Encoder implements PageImageEncoder {
  @override
  Future<void> encode(PagePixels px, String out, {required ImageFormat format, required int quality, required bool keepAlpha}) async =>
      File(out).writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
}

class _Reader implements PdfTextReader {
  _Reader(this.flags);
  final List<bool> flags;
  final textCalls = <int>[];
  @override
  Future<List<bool>> textPages(String path) async => flags;
  @override
  Future<String> pageText(String path, int index) async {
    textCalls.add(index);
    return 'Existing text on page ${index + 1} with plenty of words';
  }
}

void main() {
  late Directory tmp;
  late _Images images;
  late FakeTextRecognizer recognizer;
  late _Extractor extractor;
  late List<SearchablePage> built;
  late List<JobProgress> progress;
  var recognizersMade = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ocr_pipe');
    images = _Images();
    recognizer = FakeTextRecognizer();
    built = [];
    progress = [];
    recognizersMade = 0;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  JobContext ctx({CancelToken? cancel}) {
    final w = Directory(p.join(tmp.path, 'work'))..createSync(recursive: true);
    return JobContext(jobId: 'j', workDir: w, cancel: cancel ?? CancelToken(), report: progress.add);
  }

  OcrPipeline pipeline({List<bool> textPages = const [], int pdfPages = 3, _Reader? reader}) {
    extractor = _Extractor(pdfPages);
    return OcrPipeline(
      images: images,
      encoder: _Encoder(),
      textReader: reader ?? _Reader(textPages),
      recognizer: () {
        recognizersMade++;
        return recognizer;
      },
      openPages: (_) async => extractor,
      buildPdf: (pages, script, out, c) async {
        built.addAll(pages);
        File(out).writeAsStringSync('%PDF');
        return SearchablePdfResult(out, 0);
      },
    );
  }

  PickedFile image(String name, {int w = 1000, int h = 1400}) => PickedFile(
      path: (File(p.join(tmp.path, name))..writeAsBytesSync(const [1])).path,
      displayName: name,
      type: SniffedType.jpeg,
      sizeBytes: 1,
      image: ImageMeta(format: SniffedType.jpeg, width: w, height: h));

  PickedFile pdf({int pages = 3, List<(double, double)>? sizes}) => PickedFile(
      path: (File(p.join(tmp.path, 'scan.pdf'))..writeAsBytesSync(const [1])).path,
      displayName: 'scan.pdf',
      type: SniffedType.pdf,
      sizeBytes: 1,
      pdf: PdfMeta(pageCount: pages, pageSizes: sizes ?? [for (var i = 0; i < pages; i++) (595.28, 841.89)]));

  const all = OcrOptions(searchablePdf: true, review: true, txt: true);

  group('images', () {
    test('one page per image, real progress, PDF built from oriented JPEGs (≤ 4000 px)', () async {
      recognizer.pages = [words(10), words(5, w: 1400, h: 1000)];
      final r = await pipeline().run(ctx(), [image('a.jpg'), image('b.jpg', w: 6000, h: 4000)], all);
      expect(progress.whereType<Determinate>().map((d) => (d.done, d.total, d.stepKey)),
          [(0, 2, ocrStepPage), (1, 2, ocrStepPage)]);
      expect(progress.whereType<Indeterminate>().map((i) => i.stepKey), [ocrStepPreparing, ocrStepBuilding]);
      final prep = images.calls.where((c) => c.$1.startsWith('page_')).toList();
      expect(prep.map((c) => (c.$2.format, c.$2.quality, c.$2.maxLongEdge, c.$2.stripMetadata)),
          [(ImageFormat.jpeg, 85, 1400, true), (ImageFormat.jpeg, 85, 4000, true)]);
      expect(built, hasLength(2));
      final first = built.first as RecognisedPage;
      // "Same as image": 1000×1400 px at 150 dpi → 480×672 pt, image full page.
      expect((first.pageWidth, first.pageHeight), (480, 672));
      expect((first.imageBox.left, first.imageBox.bottom, first.imageBox.right, first.imageBox.top), (0, 0, 480, 672));
      expect((r.pages, r.words, r.lowTextPages), (2, 15, 0));
      expect(File(r.pdfPath!).existsSync(), isTrue);
      expect(await isValidOcrTxt(r.txtPath!, pageCount: 2), isTrue);
      expect(recognizer.disposed, isTrue);
    });

    test('review files: page text in reading order, words, low-text flags, thumbnails', () async {
      recognizer.pages = [words(4), words(2)];
      final r = await pipeline().run(ctx(), [image('a.jpg'), image('b.jpg')], all);
      final review = await OcrReviewFiles.read(r.reviewDir);
      expect(review.pages.map((pg) => (pg.words, pg.lowText, pg.existingText)), [(4, false, false), (2, true, false)]);
      expect(await review.text(0), 'word0\nword1\nword2\nword3');
      expect(File(review.thumbnailPath(1)).existsSync(), isTrue);
      expect(r.lowTextPages, 1, reason: '< 3 words (FR-OCR-11)');
      final thumbs = images.calls.where((c) => c.$1.startsWith('thumb_'));
      expect(thumbs.map((c) => c.$2.maxLongEdge).toSet(), {OcrPipeline.thumbnailLongEdge});
    });

    test('only what was asked for: no PDF, no .txt, no thumbnails without review', () async {
      recognizer.pages = [words(5)];
      final r = await pipeline().run(ctx(), [image('a.jpg')], const OcrOptions(searchablePdf: false, review: false, txt: true));
      expect((r.pdfPath, r.txtPath != null), (null, true));
      expect(built, isEmpty);
      expect(progress.whereType<Indeterminate>().map((i) => i.stepKey), isNot(contains(ocrStepBuilding)));
      expect(images.calls.where((c) => c.$1.startsWith('thumb_')), isEmpty);
    });

    test('cancel takes effect between pages; the recogniser is still closed (FR-OCR-10)', () async {
      final cancel = CancelToken();
      recognizer.byPath = (path) {
        cancel.cancel();
        return words(5);
      };
      await expectLater(pipeline().run(ctx(cancel: cancel), [image('a.jpg'), image('b.jpg')], all),
          throwsA(isA<CancelledException>()));
      expect(recognizer.calls, hasLength(1), reason: 'page 2 never started');
      expect(built, isEmpty);
      expect(recognizer.disposed, isTrue);
    });

    test('the script is checked first; an unavailable one fails the job', () async {
      recognizer.scripts = {OcrScript.latin};
      await expectLater(
          pipeline().run(ctx(), [image('a.jpg')], const OcrOptions(script: OcrScript.korean)),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.ocrModelUnavailable)));
      expect(recognizer.calls, isEmpty);
    });
  });

  group('rotation retry (FR-OCR-15)', () {
    test('< 3 words → tries 90/180/270, keeps the best, and the page image turns with it', () async {
      recognizer.byPath = (path) => switch (p.basename(path)) {
            'page_0.jpg' => words(1),
            'page_0_r90.jpg' => words(40, w: 1400, h: 1000),
            'page_0_r180.jpg' => words(2),
            'page_0_r270.jpg' => words(10, w: 1400, h: 1000),
            _ => null,
          };
      final r = await pipeline().run(ctx(), [image('a.jpg')], all);
      expect(recognizer.calls.map(p.basename), ['page_0.jpg', 'page_0_r90.jpg', 'page_0_r180.jpg', 'page_0_r270.jpg']);
      final page = built.single as RecognisedPage;
      expect(p.basename(page.jpegPath), 'page_0_r90.jpg');
      expect((page.pageWidth, page.pageHeight), (672, 480), reason: 'landscape now');
      expect((r.words, r.lowTextPages), (40, 0));
    });

    test('off when the setting is off, or for jobs over 20 pages', () async {
      recognizer.byPath = (_) => words(0);
      await pipeline().run(ctx(), [image('a.jpg')], const OcrOptions(rotateRetry: false));
      expect(recognizer.calls, hasLength(1));
      recognizer.calls.clear();
      await pipeline().run(ctx(), [for (var i = 0; i < 21; i++) image('i$i.jpg')], const OcrOptions(review: false));
      expect(recognizer.calls, hasLength(21));
    });

    test('no better rotation → the original stays', () async {
      recognizer.byPath = (_) => words(1);
      await pipeline().run(ctx(), [image('a.jpg')], all);
      expect(p.basename((built.single as RecognisedPage).jpegPath), 'page_0.jpg');
    });
  });

  group('PDF input', () {
    test('pages with text are kept unchanged; the others are rendered at 300 dpi and recognised', () async {
      recognizer.pages = [words(30)];
      final reader = _Reader([true, false, true]);
      final r = await pipeline(reader: reader).run(ctx(), [pdf()], all);
      expect(extractor.renders.where((x) => x.$2 > 1000), [(1, 2480, 3508)], reason: 'A4 at 300 dpi');
      expect(recognizer.calls, hasLength(1));
      expect(built.map((b) => b.runtimeType), [KeptPage, RecognisedPage, KeptPage]);
      final rec = built[1] as RecognisedPage;
      expect((rec.pageWidth, rec.pageHeight), (595.28, 841.89), reason: 'original page size in points');
      expect(reader.textCalls, [0, 2], reason: 'existing text read without OCR');
      final review = await OcrReviewFiles.read(r.reviewDir);
      expect(review.pages.map((pg) => pg.existingText), [true, false, true]);
      expect(r.words, 30 + 2 * 9);
      expect(extractor.closed, isTrue);
    });

    test('pages larger than A3 are rendered at 200 dpi', () async {
      recognizer.pages = [words(5)];
      await pipeline(reader: _Reader([false])).run(ctx(), [pdf(pages: 1, sizes: [(1190.55, 1683.78)])], all);
      expect(extractor.renders.first, (0, 3307, 4677));
    });

    test('"Get text": every page has text → no recogniser, no OCR, no PDF', () async {
      final r = await pipeline(reader: _Reader([true, true, true]))
          .run(ctx(), [pdf()], const OcrOptions(searchablePdf: false, review: true, txt: true));
      expect(recognizersMade, 0);
      expect(r.pdfPath, isNull);
      expect(r.pages, 3);
      expect(await isValidOcrTxt(r.txtPath!, pageCount: 3), isTrue);
    });

    test('searchable PDF only: existing text isn\'t even read', () async {
      recognizer.pages = [words(5)];
      final reader = _Reader([true, false, true]);
      await pipeline(reader: reader).run(ctx(), [pdf()], const OcrOptions(searchablePdf: true, review: false, txt: false));
      expect(reader.textCalls, isEmpty);
    });
  });

  group('OcrOperation', () {
    OcrOperation op() => OcrOperation(
        pipeline: pipeline(reader: _Reader([false, false, false])), pdfEngine: FakePdfEngine(), textReader: _Reader(const []));

    test('validation: images or one PDF, limits, an output, password (FR-OCR-01/03)', () async {
      Future<AppErrorCode?> v(List<PickedFile> ins, [OcrOptions o = const OcrOptions()]) async {
        try {
          await op().validateInputs(ins, o);
          return null;
        } on AppError catch (e) {
          return e.code;
        }
      }

      expect(await v([image('a.jpg'), pdf()]), AppErrorCode.invalidInput, reason: 'mixed');
      expect(await v([pdf(), pdf()]), AppErrorCode.invalidInput, reason: 'two PDFs');
      expect(await v([for (var i = 0; i < 51; i++) image('$i.jpg')]), AppErrorCode.tooManyFiles);
      expect(await v([pdf(pages: 301)]), AppErrorCode.invalidInput);
      expect(await v([]), AppErrorCode.notEnoughFiles);
      expect(await v([image('a.jpg')], const OcrOptions(searchablePdf: false, review: false, txt: false)),
          AppErrorCode.invalidInput);
      const locked = PickedFile(
          path: '/x.pdf', displayName: 'x.pdf', type: SniffedType.pdf, sizeBytes: 1, pdf: PdfMeta(pageCount: 1, isEncrypted: true));
      expect(await v([locked]), AppErrorCode.encryptedDocument);
      expect(await v([for (var i = 0; i < 50; i++) image('$i.jpg')]), isNull);
      expect(await v([pdf(pages: 300)]), isNull);
    });

    test('options JSON: outputs and script only, never text (FR-OCR-17, ADR-047)', () {
      const o = OcrOptions(searchablePdf: false, review: true, txt: true, script: OcrScript.devanagari, rotateRetry: false);
      expect(o.toJson(), {
        'outputs': {'pdf': false, 'review': true, 'txt': true},
        'script': 'devanagari',
      });
      final back = OcrOptions.fromJson(o.toJson());
      expect((back.searchablePdf, back.review, back.txt, back.script), (false, true, true, OcrScript.devanagari));
      expect(OcrOptions.fromJson(const {'script': 'klingon'}).script, OcrScript.latin);
      expect(const OcrOptions().toJson()['outputs'], {'pdf': true, 'review': true, 'txt': false}, reason: '§5 defaults');
    });

    test('execute: <base>_searchable.pdf and <base>_text.txt; review kept only when asked', () async {
      recognizer.pages = [words(5), words(5), words(5)];
      final out = await op().execute(ctx(), [pdf()], all);
      expect(out.files.map((f) => (f.suggestedName, f.mime)),
          [('scan_searchable.pdf', 'application/pdf'), ('scan_text.txt', 'text/plain')]);
      expect(out.stats, {'pages': 3, 'words': 15, 'lowTextPages': 0});
      expect(out.reviewDir, isNotNull);
      final noReview = await op().execute(ctx(), [pdf()], const OcrOptions(review: false));
      expect(noReview.reviewDir, isNull);
      expect(noReview.files.single.suggestedName, 'scan_searchable.pdf');
    });

    test('estimate grows with pages and inputs', () {
      expect(op().estimateRequiredBytes([pdf(pages: 100)], all), greaterThan(op().estimateRequiredBytes([pdf(pages: 10)], all)));
    });
  });
}
