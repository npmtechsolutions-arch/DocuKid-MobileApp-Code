// T9.6 — ScanOperation (RELEASE_V1_2 §4.4, §8: PDF page count == pages;
// fitToScan page size maths; JPG multi-output count and decode;
// makeSearchable), written before the implementation; T10.8 adds the
// searchable path.
import 'dart:io';
import 'dart:ui';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/ocr/pdf_text_reader.dart';
import 'package:docukit/core/ocr/searchable_pdf_builder.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/image_to_pdf_layout.dart';
import 'package:docukit/core/pdf/pdf_engine.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:docukit/core/scan/scan_options.dart';
import 'package:docukit/features/ocr/application/ocr_pipeline.dart';
import 'package:docukit/features/scan/application/scan_operation.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// Writes a real JPEG of the size the transform asks for and records the call.
class _RecordingEngine implements ImageEngine {
  final calls = <ImageTransform>[];
  @override
  bool canEncode(ImageFormat format) => true;
  @override
  Future<ImageMeta> inspect(String path) async => const ImageMeta(format: SniffedType.jpeg, width: 3000, height: 4000);
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    calls.add(t);
    final quarter = (t.extraRotation ~/ 90).isOdd;
    var (w, h) = quarter ? (meta!.height, meta.width) : (meta!.width, meta.height);
    final cap = t.maxLongEdge;
    if (cap != null && (w > cap || h > cap)) {
      final s = cap / (w > h ? w : h);
      (w, h) = ((w * s).round(), (h * s).round());
    }
    final bytes = img.encodeJpg(img.Image(width: w, height: h), quality: 10);
    File(outPath).writeAsBytesSync(bytes);
    return EncodedImage(path: outPath, bytes: bytes.length, width: w, height: h, format: ImageFormat.jpeg);
  }
}

class _Pdf implements PdfEngine {
  _Pdf({this.pages = 3});
  int pages;
  @override
  Future<PdfMeta> inspect(String path) async => PdfMeta(pageCount: pages);
  @override
  Future<void> close(String path) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A real context whose progress reports are kept for the test.
class _Ctx extends JobContext {
  _Ctx._(Directory dir, this.reports) : super(jobId: 'job', workDir: dir, cancel: CancelToken(), report: reports.add);
  factory _Ctx(Directory dir) => _Ctx._(dir, <JobProgress>[]);
  final List<JobProgress> reports;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('scan_op'));
  tearDown(() => tmp.deleteSync(recursive: true));

  PickedFile page(int i, {bool valid = true, int bytes = 1000}) => PickedFile(
        path: p.join(tmp.path, 'page_${i + 1}.jpg'),
        displayName: 'page_${i + 1}.jpg',
        type: SniffedType.jpeg,
        sizeBytes: bytes,
        image: const ImageMeta(format: SniffedType.jpeg, width: 3000, height: 4000),
        status: valid ? const ValidationStatus.ok() : const ValidationStatus.invalid(AppErrorCode.corruptFile),
      );

  group('PDF settings (FR-SCN-14, 15)', () {
    test('page size, margin none, fit, quality preset', () {
      final a4 = scanPdfSettings(const ScanOptions());
      expect((a4.size, a4.margin, a4.fit, a4.orientation, a4.quality),
          (PdfPageSize.a4, PdfMargin.none, PdfFit.fit, PdfOrientation.auto, PdfImageQuality.high));
      expect(scanPdfSettings(const ScanOptions(pageSize: ScanPageSize.letter)).size, PdfPageSize.letter);
      final compact = scanPdfSettings(const ScanOptions(quality: ScanQuality.compact)).quality;
      expect((compact.jpegQuality, compact.dpiCap), (65, 150));
      expect((PdfImageQuality.high.jpegQuality, PdfImageQuality.high.dpiCap), (85, 200));
    });

    test('Fit to scan: the page is the scan at 200 dpi (pt = px × 72 / 200)', () {
      final s = scanPdfSettings(const ScanOptions(pageSize: ScanPageSize.fitToScan));
      expect((s.size, s.imageDpi), (PdfPageSize.image, 200));
      final lay = layoutImagePage(
        imageWidth: 2000,
        imageHeight: 1000,
        size: s.size,
        orientation: s.orientation,
        fit: s.fit,
        margin: s.margin,
        dpiCap: s.quality.dpiCap,
        imageDpi: s.imageDpi,
      );
      expect((lay.pageWidth, lay.pageHeight), (720.0, 360.0));
      expect((lay.drawWidth, lay.drawHeight), (720.0, 360.0));
    });

    test('Same as image (Images to PDF) stays at 150 dpi', () {
      final lay = layoutImagePage(
        imageWidth: 1500,
        imageHeight: 1500,
        size: PdfPageSize.image,
        orientation: PdfOrientation.auto,
        fit: PdfFit.fit,
        margin: PdfMargin.none,
        dpiCap: 200,
      );
      expect(lay.pageWidth, 720.0);
    });
  });

  group('validation and estimate', () {
    final op = ScanPdfOperation(_RecordingEngine(), _Pdf());

    test('1–50 pages, each valid', () async {
      await expectLater(op.validateInputs([], const ScanOptions()),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.notEnoughFiles)));
      await expectLater(op.validateInputs([for (var i = 0; i < 51; i++) page(i)], const ScanOptions()),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.tooManyFiles)));
      await expectLater(op.validateInputs([page(0), page(1, valid: false)], const ScanOptions()),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.corruptFile)));
      await op.validateInputs([page(0)], const ScanOptions());
    });

    test('estimate: Σ page bytes × 1.3', () {
      expect(op.estimateRequiredBytes([page(0, bytes: 1000), page(1, bytes: 3000)], const ScanOptions()), 5200);
    });
  });

  group('PDF (FR-SCN-13, 17)', () {
    test('one JPEG per page with its rotation, at the quality preset; name Scan_….pdf', () async {
      final engine = _RecordingEngine();
      final op = ScanPdfOperation(engine, _Pdf(), clock: () => DateTime(2026, 10, 28, 14, 5));
      final ctx = _Ctx(Directory(p.join(tmp.path, 'work'))..createSync());
      final out = await op.execute(ctx, [page(0), page(1), page(2)],
          const ScanOptions(quality: ScanQuality.compact, rotations: [0, 1, 3]));
      expect(engine.calls.map((c) => c.extraRotation), [0, 90, 270]);
      expect(engine.calls.every((c) => c.quality == 65 && c.format == ImageFormat.jpeg && c.stripMetadata), isTrue);
      expect(out.suggestedName, 'Scan_20261028_1405.pdf');
      expect(out.mime, 'application/pdf');
      expect(String.fromCharCodes(File(out.path).readAsBytesSync().take(4)), '%PDF');
      expect(ctx.reports.whereType<Indeterminate>().map((r) => r.stepKey), contains('stepSavingScan'));
    });

    test('a renamed scan keeps its name', () async {
      final op = ScanPdfOperation(_RecordingEngine(), _Pdf());
      final out = await op.execute(_Ctx(Directory(p.join(tmp.path, 'w2'))..createSync()), [page(0)],
          const ScanOptions(baseName: 'Receipts'));
      expect(out.suggestedName, 'Receipts.pdf');
    });

    test('output check: page count must equal the pages', () async {
      final pdf = _Pdf(pages: 2);
      final op = ScanPdfOperation(_RecordingEngine(), pdf);
      final f = File(p.join(tmp.path, 'x.pdf'))..writeAsStringSync('%PDF-1.4');
      const out = RawOutput(path: '', suggestedName: 'x.pdf', mime: 'application/pdf');
      await expectLater(
        op.validateOutput(RawOutput(path: f.path, suggestedName: out.suggestedName, mime: out.mime), [page(0), page(1), page(2)],
            const ScanOptions()),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.outputValidationFailed)),
      );
    });
  });

  group('JPG (FR-SCN-13, 17)', () {
    test('one item per page; q85 / cap 2339 px (A4 at 200 dpi); names _p01.jpg…', () async {
      final engine = _RecordingEngine();
      final op = ScanJpgOperation(engine, clock: () => DateTime(2026, 10, 28, 14, 5));
      final pages = [page(0), page(1)];
      const o = ScanOptions(format: ScanOutputFormat.jpg, rotations: [1, 0]);
      expect(op.itemCount(pages, o), 2);
      final ctx = _Ctx(Directory(p.join(tmp.path, 'work'))..createSync());
      final first = await op.executeItem(ctx, 0, pages, o);
      final second = await op.executeItem(ctx, 1, pages, o);
      expect((first.suggestedName, second.suggestedName), ('Scan_20261028_1405_p01.jpg', 'Scan_20261028_1405_p02.jpg'));
      expect(engine.calls.map((c) => (c.quality, c.maxLongEdge, c.extraRotation)), [(85, 2339, 90), (85, 2339, 0)]);
      final meta = await op.validateItem(first, 0, o);
      expect((meta.width, meta.height), (2339, 1754));
      expect(op.itemStepKey, 'stepSavingScan');
    });

    test('Compact: q65, cap 1754 px (A4 at 150 dpi)', () async {
      final engine = _RecordingEngine();
      final op = ScanJpgOperation(engine);
      await op.executeItem(_Ctx(Directory(p.join(tmp.path, 'w'))..createSync()), 0, [page(0)],
          const ScanOptions(format: ScanOutputFormat.jpg, quality: ScanQuality.compact));
      expect((engine.calls.single.quality, engine.calls.single.maxLongEdge), (65, 1754));
    });

    test('a small scan is never enlarged', () async {
      final engine = _RecordingEngine();
      final small = PickedFile(
        path: p.join(tmp.path, 's.jpg'),
        displayName: 's.jpg',
        type: SniffedType.jpeg,
        sizeBytes: 10,
        image: const ImageMeta(format: SniffedType.jpeg, width: 800, height: 600),
      );
      await ScanJpgOperation(engine).executeItem(_Ctx(Directory(p.join(tmp.path, 'w3'))..createSync()), 0, [small],
          const ScanOptions(format: ScanOutputFormat.jpg));
      expect(engine.calls.single.maxLongEdge, 800);
    });

    test('a broken page fails alone', () async {
      final op = ScanJpgOperation(_RecordingEngine());
      await expectLater(
        op.executeItem(_Ctx(tmp), 0, [page(0, valid: false)], const ScanOptions(format: ScanOutputFormat.jpg)),
        throwsA(isA<AppError>()),
      );
    });
  });

  test('scans are new content: they never add to "saved" (§5)', () {
    expect(countsAsSaving(ToolId.scanDocument), isFalse);
    expect(countsAsSaving(ToolId.imageCompress), isTrue);
  });

  test('history JSON: no page names; "Make searchable" only when on, with its script (1.3, FR-OCR-13)', () {
    expect(const ScanOptions(baseName: 'Secret').toJson().keys, ['format', 'pageSize', 'quality']);
    expect(const ScanOptions(makeSearchable: true, ocrScript: OcrScript.devanagari).toJson(),
        {'format': 'pdf', 'pageSize': 'a4', 'quality': 'high', 'searchable': true, 'script': 'devanagari'});
    final back = ScanOptions.fromJson(const {'searchable': true, 'script': 'devanagari'}, const ScanOptions());
    expect((back.makeSearchable, back.ocrScript), (true, OcrScript.devanagari));
    expect(ScanOptions.fromJson(const {}, const ScanOptions()).makeSearchable, isFalse);
  });

  group('Make searchable (T10.8, FR-OCR-13)', () {
    late _RecordingEngine images;
    late FakeTextRecognizer recognizer;
    late List<SearchablePage> built;

    ScanPdfOperation op() {
      images = _RecordingEngine();
      recognizer = FakeTextRecognizer()..pages = [for (var i = 0; i < 3; i++) _words(8)];
      built = [];
      return ScanPdfOperation(
        images,
        _Pdf(),
        clock: () => DateTime(2026, 10, 29, 9, 30),
        ocr: OcrPipeline(
          images: images,
          encoder: _NoEncoder(),
          textReader: _NoText(),
          recognizer: () => recognizer,
          openPages: (_) => throw UnimplementedError(),
          buildPdf: (pages, script, out, ctx) async {
            built.addAll(pages);
            File(out).writeAsStringSync('%PDF');
            return SearchablePdfResult(out, 0);
          },
        ),
      );
    }

    test('off: the plain scan PDF, no recognition', () async {
      final o = op();
      for (var i = 0; i < 3; i++) {
        File(page(i).path).writeAsBytesSync(const [1]);
      }
      await o.execute(_Ctx(tmp), [for (var i = 0; i < 3; i++) page(i)], const ScanOptions());
      expect(recognizer.calls, isEmpty);
    });

    test('on: every page recognised with the chosen script, laid out like the scan (A4, fit, rotation, quality)', () async {
      final o = op();
      final ctx = _Ctx(tmp);
      final out = await o.execute(ctx, [for (var i = 0; i < 3; i++) page(i)],
          const ScanOptions(makeSearchable: true, ocrScript: OcrScript.devanagari, rotations: [0, 1, 0]));
      expect(recognizer.calls, hasLength(3));
      expect(recognizer.ensured, [OcrScript.devanagari]);
      final pages = built.cast<RecognisedPage>();
      // A4 portrait for portrait scans; the turned page is landscape A4.
      expect(pages.map((pg) => (pg.pageWidth.round(), pg.pageHeight.round())), [(595, 842), (842, 595), (595, 842)]);
      final prep = images.calls.where((t) => t.maxLongEdge != null).toList();
      expect(prep.map((t) => (t.extraRotation, t.quality)), [(0, 85), (90, 85), (0, 85)]);
      // High = 200 dpi at the image's drawn size, as the plain scan PDF: a 3:4
      // scan fit on A4 is 595.28 × 793.7 pt → 793.7 / 72 × 200 = 2205 px.
      expect(prep.first.maxLongEdge, 2205);
      expect(ctx.reports.whereType<Determinate>().map((d) => d.stepKey).toSet(), {'stepOcrPage'});
      expect((out.suggestedName, out.mime), ('Scan_20261029_0930.pdf', 'application/pdf'));
      expect(out.flags['expectedPages'], 3);
      expect(out.flags['words'], 24);
    });

    test('Fit to scan + Compact: the scan\'s own page at 200 dpi, q65', () async {
      final o = op();
      await o.execute(_Ctx(tmp), [page(0)],
          const ScanOptions(makeSearchable: true, pageSize: ScanPageSize.fitToScan, quality: ScanQuality.compact));
      final pg = built.single as RecognisedPage;
      final prep = images.calls.firstWhere((t) => t.maxLongEdge != null);
      expect(prep.quality, 65);
      // 3000×4000 px capped for Compact, then 200 dpi: the page has the scan's aspect.
      expect(pg.pageWidth / pg.pageHeight, closeTo(0.75, 0.01));
    });
  });
}

OcrPage _words(int n) => OcrPage(imageWidth: 1000, imageHeight: 1400, lines: [
      OcrLine(text: 'w', box: const Rect.fromLTRB(0, 0, 10, 10), corners: const [], words: [
        for (var i = 0; i < n; i++) const OcrWord(text: 'w', box: Rect.fromLTRB(0, 0, 10, 10), corners: []),
      ]),
    ]);

class _NoEncoder implements PageImageEncoder {
  @override
  Future<void> encode(PagePixels px, String out, {required ImageFormat format, required int quality, required bool keepAlpha}) async {}
}

class _NoText implements PdfTextReader {
  @override
  Future<String> pageText(String path, int index) async => '';
  @override
  Future<List<bool>> textPages(String path) async => const [];
}
