// T8.8 — Split PDF (RELEASE_V1_1 FR-SPL-01…08, §4.7, §8.1 split grouping),
// written before the implementation.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/page_image_encoder.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_engine.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_split/application/split_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// "PDFs" are JSON page lists; inspect counts them; rendering always works.
class JsonPdfEngine implements PdfEngine {
  int opened = 0, closed = 0;
  List<int>? failOn;
  @override
  Future<PdfPageExtractor> openExtractor(String input) async {
    opened++;
    return _Extractor(this, (jsonDecode(File(input).readAsStringSync()) as List).length);
  }

  @override
  Future<PdfMeta> inspect(String path) async => PdfMeta(pageCount: (jsonDecode(File(path).readAsStringSync()) as List).length);
  @override
  Future<ui.Image?> renderPage(String path, int index, {required int targetWidthPx}) async {
    final r = ui.PictureRecorder();
    ui.Canvas(r).drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint());
    return r.endRecording().toImageSync(1, 1);
  }

  @override
  Future<void> close(String path) async {}

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Extractor implements PdfPageExtractor {
  _Extractor(this.engine, this.pageCount);
  final JsonPdfEngine engine;
  @override
  final int pageCount;
  @override
  Future<void> extract(List<int> pages, String out) async {
    if (engine.failOn != null && pages.first == engine.failOn!.first) throw const AppError(AppErrorCode.processingFailed);
    File(out).writeAsStringSync(jsonEncode(pages));
  }

  @override
  Future<PagePixels> renderPage(int index, {required int width, required int height, required bool transparent}) =>
      throw UnimplementedError();

  @override
  Future<void> close() async => engine.closed++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // the fake renders a 1×1 ui.Image

  group('grouping (§8.1)', () {
    List<List<int>> groups(SplitOptions o, int pages) => splitGroups(o, pages).groups!;

    test('custom ranges: one output per part, in order, overlaps kept (FR-SPL-02/05)', () {
      expect(groups(const SplitOptions(ranges: '1-3, 5, 8-10, 2-3'), 36), [
        [0, 1, 2],
        [4],
        [7, 8, 9],
        [1, 2],
      ]);
    });
    test('every N: the last file may be shorter (FR-SPL-03)', () {
      final g = groups(const SplitOptions(mode: SplitMode.everyN, everyN: 5), 36);
      expect(g, hasLength(8));
      expect(g.last, [35]);
      expect(g.expand((x) => x), [for (var i = 0; i < 36; i++) i]);
    });
    test('each page (FR-SPL-04)', () => expect(groups(const SplitOptions(mode: SplitMode.each), 3), [[0], [1], [2]]));
    test('each page above 500 pages is refused → suggest Every N', () {
      expect(splitGroups(const SplitOptions(mode: SplitMode.each), 501).error, SplitError.eachCap);
      expect(groups(const SplitOptions(mode: SplitMode.each), 500), hasLength(500));
    });
    test('every N can never make more than 500 files', () {
      expect(minEveryN(2000), 4);
      expect(minEveryN(36), 1);
      expect(groups(const SplitOptions(mode: SplitMode.everyN, everyN: 1), 2000), hasLength(500), reason: 'N raised to the minimum');
    });
    test('a 1-page PDF can\'t be split (FR-SPL-01)', () {
      expect(splitGroups(const SplitOptions(mode: SplitMode.each), 1).error, SplitError.onePage);
    });
    test('a bad range is reported, not split', () {
      final r = splitGroups(const SplitOptions(ranges: '40'), 36);
      expect(r.groups, isNull);
      expect(r.rangeError!.page, 40);
    });
  });

  group('names (FR-SPL-06)', () {
    test('ranges: <base>_p1-3.pdf, <base>_p5.pdf', () {
      expect(splitPartName('report.pdf', const SplitOptions(), [0, 1, 2], 0, 3), 'report_p1-3.pdf');
      expect(splitPartName('report.pdf', const SplitOptions(), [4], 1, 3), 'report_p5.pdf');
    });
    test('every N / each: <base>_part01.pdf, padded to the output count', () {
      const each = SplitOptions(mode: SplitMode.each);
      expect(splitPartName('report.pdf', each, [0], 0, 12), 'report_part01.pdf');
      expect(splitPartName('report.pdf', each, [11], 11, 12), 'report_part12.pdf');
      expect(splitPartName('report.pdf', each, [0], 0, 150), 'report_part001.pdf');
    });
  });

  group('operation', () {
    late AppDatabase db;
    late AppPaths paths;
    late PickedFile input;
    setUp(() async {
      db = memoryDb();
      paths = await tempPaths();
      final dir = paths.jobIn('d')..createSync(recursive: true);
      final f = File(p.join(dir.path, 'report.pdf'))..writeAsStringSync(jsonEncode([for (var i = 0; i < 10; i++) i]));
      input = PickedFile(path: f.path, displayName: 'report.pdf', type: SniffedType.pdf, sizeBytes: 100, pdf: const PdfMeta(pageCount: 10));
    });
    tearDown(() => db.close());

    Future<List<JobState>> run(JsonPdfEngine engine, SplitOptions o, {CancelToken? cancel}) async {
      final states = <JobState>[];
      await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice()).runMulti(
        jobId: 's',
        op: SplitPdfOperation(engine),
        inputs: [input],
        options: o,
        cancel: cancel ?? CancelToken(),
        emit: states.add,
      );
      return states;
    }

    test('each output holds exactly its pages; the source is opened once and closed (§4.7, FR-SPL-07)', () async {
      final engine = JsonPdfEngine();
      final states = await run(engine, const SplitOptions(ranges: '1-3, 5, 8-end'));
      final items = (states.last as JobCompletedMulti).result.output.items.cast<OutputOk>();
      expect(items.map((o) => o.name), ['report_p1-3.pdf', 'report_p5.pdf', 'report_p8-10.pdf']);
      expect(items.map((o) => o.meta.pages), [3, 1, 3]);
      expect(items.map((o) => jsonDecode(File(o.path).readAsStringSync())), [
        [0, 1, 2],
        [4],
        [7, 8, 9],
      ]);
      expect((engine.opened, engine.closed), (1, 1));
      final progress = states.whereType<JobProcessing>().map((s) => s.progress).whereType<Determinate>().first;
      expect(progress.unit, ProgressUnit.files);
    });

    test('a failed part fails alone; the source is still closed', () async {
      final engine = JsonPdfEngine()..failOn = [4];
      final states = await run(engine, const SplitOptions(ranges: '1-3, 5, 8-10'));
      final items = (states.last as JobCompletedMulti).result.output.items;
      expect(items.map((i) => i is OutputFailed), [false, true, false]);
      expect(engine.closed, 1);
    });

    test('cancel closes the source too', () async {
      final engine = JsonPdfEngine();
      final cancel = CancelToken()..cancel();
      final states = await run(engine, const SplitOptions(mode: SplitMode.each), cancel: cancel);
      expect(states.last, isA<JobCancelled>());
      expect(engine.closed, engine.opened);
    });

    test('validation: encrypted blocked (FR-SPL-08), bad ranges and 1-page PDFs refused before running', () async {
      final op = SplitPdfOperation(JsonPdfEngine());
      final locked = PickedFile(
        path: input.path,
        displayName: 'locked.pdf',
        type: SniffedType.pdf,
        sizeBytes: 1,
        status: const ValidationStatus.invalid(AppErrorCode.encryptedDocument),
      );
      await expectLater(op.validateInputs([locked], const SplitOptions(ranges: '1')),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.encryptedDocument)));
      await expectLater(op.validateInputs([input], const SplitOptions(ranges: '5-3')), throwsA(isA<AppError>()));
      final one = PickedFile(path: input.path, displayName: 'one.pdf', type: SniffedType.pdf, sizeBytes: 1, pdf: const PdfMeta(pageCount: 1));
      await expectLater(op.validateInputs([one], const SplitOptions(mode: SplitMode.each)), throwsA(isA<AppError>()));
    });
  });
}
