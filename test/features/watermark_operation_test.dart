// T11.8 — WatermarkPdfOperation (RELEASE_V1_4 §4.8, FR-WMK-01, 05, 06, 09)
// with a fake stamper, written before the implementation.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_stamper.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_watermark/application/watermark_layout.dart';
import 'package:docukit/features/pdf_watermark/application/watermark_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

class _Stamper implements PdfStamper {
  List<Stamp>? got;
  @override
  Future<void> apply(String inPath, List<Stamp> stamps, String outPath, JobContext ctx) async {
    got = stamps;
    File(outPath).writeAsStringSync('%PDF marked');
  }
}

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late _Stamper stamper;
  late PickedFile input;
  final checks = <(int, Rect)>[];
  var visible = true;
  var runs = 0;
  const sizes = [Size(595, 842), Size(842, 595), Size(595, 842), Size(595, 842), Size(595, 842)];

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    stamper = _Stamper();
    checks.clear();
    visible = true;
    final f = File(p.join((paths.jobIn('d')..createSync(recursive: true)).path, 'report.pdf'))..writeAsStringSync('%PDF');
    input = PickedFile(
        path: f.path, displayName: 'report.pdf', type: SniffedType.pdf, sizeBytes: 4, pdf: const PdfMeta(pageCount: 5));
  });
  tearDown(() => db.close());

  WatermarkOptions opts({
    WatermarkPosition position = WatermarkPosition.diagonal,
    PageMode mode = PageMode.all,
    List<int>? pages,
    int opacity = 25,
    bool image = false,
  }) =>
      WatermarkOptions(
        pngPath: '/wm.png',
        aspect: 4,
        image: image,
        position: position,
        sizePct: 60,
        opacityPct: opacity,
        rotation: defaultRotation(position),
        pageMode: mode,
        pages: pages ?? selectPages(mode, '', 5)!,
        pageSizes: sizes,
      );

  Future<List<JobState>> run(WatermarkOptions o) async {
    final states = <JobState>[];
    runs++;
    await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice()).run(
      jobId: 'job-w$runs',
      op: WatermarkPdfOperation(stamper,
          validatePages: (_, e) async => e,
          stampVisible: (_, page, box, size) async {
            checks.add((page, box));
            return visible;
          },
          clock: () => DateTime(2026, 10, 30)),
      inputs: [input],
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    return states;
  }

  test('diagonal on all pages: one stamp per page from the layout, opacity 25% → 0.25; <base>_watermarked.pdf',
      () async {
    final done = (await run(opts())).last as JobCompleted;
    expect(done.result.outputName, 'report_watermarked.pdf');
    expect(done.result.meta.flags['stamped'], 5);
    expect(stamper.got!.length, 5);
    expect(stamper.got!.every((s) => s.opacity == 0.25 && s.rotationDegrees == -35), isTrue);
    final landscape = stamper.got!.firstWhere((s) => s.pageIndex == 1);
    expect(landscape.visualRect.center, const Offset(421, 297.5), reason: 'page 2 is landscape');
  });

  test('tile × odd pages → 12 stamps on each of pages 1, 3, 5; nothing on 2 and 4', () async {
    await run(opts(position: WatermarkPosition.tile, mode: PageMode.odd));
    expect(stamper.got!.map((s) => s.pageIndex).toSet(), {0, 2, 4});
    expect(stamper.got!.where((s) => s.pageIndex == 2).length, 12);
  });

  test('validation: the first selected page and its first stamp\'s rotated box; blank → outputValidationFailed', () async {
    await run(opts(mode: PageMode.even));
    expect(checks.single.$1, 1);
    visible = false;
    expect(((await run(opts())).last as JobFailed).error.code, AppErrorCode.outputValidationFailed);
  });

  test('history: the style only — never the text or the image path', () async {
    await run(opts(position: WatermarkPosition.bottomRight, mode: PageMode.odd, image: true, opacity: 40));
    final row = (await db.select(db.operations).get()).single;
    expect(row.optionsJson,
        '{"kind":"image","position":"bottomRight","size":60,"opacity":40,"rotation":0.0,"pages":"odd"}');
    expect(row.optionsJson, isNot(contains('wm.png')));
  });

  test('no pages, a page outside the PDF, or opacity outside 10–80% → invalidInput', () async {
    for (final o in [opts(pages: const []), opts(pages: const [7]), opts(opacity: 90)]) {
      expect(((await run(o)).last as JobFailed).error.code, AppErrorCode.invalidInput);
    }
    expect(stamper.got, isNull);
  });

  test('the style JSON for settings (FR-WMK-10) round-trips and never includes images', () {
    const s = WatermarkTextStyle(
        text: 'CONFIDENTIAL', colour: 0xFFD32F2F, bold: true, position: WatermarkPosition.tile, sizePct: 50, opacityPct: 30, rotation: -35);
    final back = WatermarkTextStyle.fromJson(s.toJson())!;
    expect((back.text, back.colour, back.bold, back.position, back.sizePct, back.opacityPct, back.rotation),
        ('CONFIDENTIAL', 0xFFD32F2F, true, WatermarkPosition.tile, 50, 30, -35.0));
    expect((jsonDecode(s.toJson()) as Map).keys, unorderedEquals(['text', 'colour', 'bold', 'position', 'size', 'opacity', 'rotation']));
    expect(WatermarkTextStyle.fromJson('{bad'), isNull);
  });
}
