// T8.9 — PDF to Images (RELEASE_V1_1 FR-P2I-01…07, §4.7, ADR-060), written
// before the implementation.
import 'dart:io';
import 'dart:typed_data';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_engine.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_to_images/application/pdf_to_images_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

class FakePages implements PdfEngine {
  int opened = 0, closed = 0;
  final rendered = <(int, int, int, bool)>[];
  @override
  Future<PdfPageExtractor> openExtractor(String input) async {
    opened++;
    return _Src(this);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Src implements PdfPageExtractor {
  _Src(this.e);
  final FakePages e;
  @override
  int get pageCount => 5;
  @override
  Future<void> extract(List<int> pages, String out) => throw UnimplementedError();
  @override
  Future<PagePixels> renderPage(int index, {required int width, required int height, required bool transparent}) async {
    e.rendered.add((index, width, height, transparent));
    return PagePixels(Uint8List(width * height * 4), width, height);
  }

  @override
  Future<void> close() async => e.closed++;
}

/// Writes a real image with the `image` package at the pixel size it gets.
class DartEncoder implements PageImageEncoder {
  final calls = <(ImageFormat, int, bool)>[];
  @override
  Future<void> encode(PagePixels px, String out, {required ImageFormat format, required int quality, required bool keepAlpha}) async {
    calls.add((format, quality, keepAlpha));
    final im = img.Image(width: px.width, height: px.height);
    await File(out).writeAsBytes(format == ImageFormat.png ? img.encodePng(im) : img.encodeJpg(im));
  }
}

void main() {
  group('pixel size (FR-P2I-04)', () {
    test('pt × dpi / 72: A4 at 72 / 150 / 300 dpi', () {
      expect(pagePixelSize(595.28, 841.89, 72), (595, 842, false));
      expect(pagePixelSize(595.28, 841.89, 150), (1240, 1754, false));
      expect(pagePixelSize(595.28, 841.89, 300), (2480, 3508, false));
    });
    test('capped at 40 MP, keeping the ratio', () {
      final (w, h, capped) = pagePixelSize(2000, 2000, 300); // 8333² ≈ 69 MP
      expect(capped, isTrue);
      expect(w * h, lessThanOrEqualTo(maxPagePixels));
      expect((w - h).abs(), lessThanOrEqualTo(1));
    });
    test('never below 1 px', () => expect(pagePixelSize(0.5, 0.5, 72).$1, 1));
  });

  group('pages (FR-P2I-02)', () {
    test('all pages', () => expect(selectedPages(const PdfToImagesOptions(), 5).pages, [1, 2, 3, 4, 5]));
    test('chosen pages: union of parts, in document order', () {
      expect(selectedPages(const PdfToImagesOptions(allPages: false, ranges: '4-5, 1, 2-4'), 5).pages, [1, 2, 3, 4, 5]);
      expect(selectedPages(const PdfToImagesOptions(allPages: false, ranges: '5, 2'), 5).pages, [2, 5]);
    });
    test('a bad range is reported', () {
      expect(selectedPages(const PdfToImagesOptions(allPages: false, ranges: '9'), 5).error!.page, 9);
    });
  });

  test('names: <base>_page001.jpg, padded to the page count (min 2) (FR-P2I-06)', () {
    expect(pageImageName('brochure.pdf', 3, 24, ImageFormat.jpeg), 'brochure_page03.jpg');
    expect(pageImageName('brochure.pdf', 7, 150, ImageFormat.png), 'brochure_page007.png');
    expect(pageImageName('a.pdf', 1, 5, ImageFormat.jpeg), 'a_page01.jpg');
  });

  test('BMP wrapper: a 32-bit top-down BGRA bitmap any decoder reads (ADR-060)', () async {
    final dir = Directory.systemTemp.createTempSync('bmp');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bgra = Uint8List.fromList([
      0, 0, 255, 255, 0, 255, 0, 255, // row 0: red, green
      255, 0, 0, 255, 255, 255, 255, 255, // row 1: blue, white
    ]);
    final path = p.join(dir.path, 'x.bmp');
    await writeBgraBmp(PagePixels(bgra, 2, 2), path);
    expect(File(path).lengthSync(), 122 + 16);
    final im = img.decodeBmp(File(path).readAsBytesSync())!;
    expect((im.width, im.height), (2, 2));
    final c = im.getPixel(0, 0);
    expect((c.r, c.g, c.b), (255, 0, 0), reason: 'top-down, BGRA → red at top-left');
    final d = im.getPixel(0, 1);
    expect((d.r, d.g, d.b), (0, 0, 255));
  });

  group('operation', () {
    late AppDatabase db;
    late AppPaths paths;
    late PickedFile input;
    var runs = 0;
    setUp(() async {
      db = memoryDb();
      paths = await tempPaths();
      final dir = paths.jobIn('d')..createSync(recursive: true);
      final f = File(p.join(dir.path, 'brochure.pdf'))..writeAsStringSync('%PDF');
      input = PickedFile(
        path: f.path,
        displayName: 'brochure.pdf',
        type: SniffedType.pdf,
        sizeBytes: 100,
        pdf: const PdfMeta(pageCount: 5, pageSizes: [(72, 144), (144, 72), (72, 72), (72, 72), (72, 72)]),
      );
    });
    tearDown(() => db.close());

    Future<List<OutputItem>> run(FakePages engine, DartEncoder enc, PdfToImagesOptions o) async {
      final states = <JobState>[];
      await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice())
          .runMulti(jobId: 'p${++runs}', op: PdfToImagesOperation(engine, enc), inputs: [input], options: o, cancel: CancelToken(), emit: states.add);
      final last = states.last;
      if (last is JobFailed) fail('failed: ${last.error.code}');
      return (last as JobCompletedMulti).result.output.items;
    }

    test('one image per chosen page at its own pixel size; source opened once and closed', () async {
      final engine = FakePages();
      final enc = DartEncoder();
      final items = await run(engine, enc, const PdfToImagesOptions(allPages: false, ranges: '1-2', dpi: 150));
      final ok = items.cast<OutputOk>();
      expect(ok.map((o) => o.name), ['brochure_page01.jpg', 'brochure_page02.jpg']);
      expect(ok.map((o) => (o.meta.width, o.meta.height)), [(150, 300), (300, 150)]);
      expect(engine.rendered.map((r) => r.$1), [0, 1], reason: '0-based page index');
      expect((engine.opened, engine.closed), (1, 1));
      expect(enc.calls.first, (ImageFormat.jpeg, 90, false));
    });

    test('PNG: transparent background only when asked (FR-P2I-07)', () async {
      final engine = FakePages();
      final enc = DartEncoder();
      await run(engine, enc, const PdfToImagesOptions(allPages: false, ranges: '3', format: ImageFormat.png));
      expect(engine.rendered.single.$4, isFalse);
      expect(enc.calls.single.$3, isFalse);
      await run(engine, enc,
          const PdfToImagesOptions(allPages: false, ranges: '3', format: ImageFormat.png, keepTransparent: true));
      expect(engine.rendered.last.$4, isTrue);
      expect(enc.calls.last.$3, isTrue);
    });

    test('JPG never renders transparent, even if the toggle was left on', () async {
      final engine = FakePages();
      await run(engine, DartEncoder(), const PdfToImagesOptions(allPages: false, ranges: '3', keepTransparent: true));
      expect(engine.rendered.single.$4, isFalse);
    });

    test('validation: encrypted blocked; bad ranges refused before running (FR-P2I-01)', () async {
      final op = PdfToImagesOperation(FakePages(), DartEncoder());
      final locked = PickedFile(
        path: input.path,
        displayName: 'x.pdf',
        type: SniffedType.pdf,
        sizeBytes: 1,
        status: const ValidationStatus.invalid(AppErrorCode.encryptedDocument),
      );
      await expectLater(op.validateInputs([locked], const PdfToImagesOptions()), throwsA(isA<AppError>()));
      await expectLater(op.validateInputs([input], const PdfToImagesOptions(allPages: false, ranges: '0')), throwsA(isA<AppError>()));
    });
  });
}
