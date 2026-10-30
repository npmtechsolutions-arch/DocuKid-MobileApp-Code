// T11.7 — SignPdfOperation (RELEASE_V1_4 §4.8, FR-SIG-01, 09, 12), written
// before the implementation, with a fake stamper and validators. The real
// stamper runs in integration_test/sign_operation_test.dart.
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
import 'package:docukit/features/pdf_sign/application/placement.dart';
import 'package:docukit/features/pdf_sign/application/sign_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

class _Stamper implements PdfStamper {
  List<Stamp>? got;
  @override
  Future<void> apply(String inPath, List<Stamp> stamps, String outPath, JobContext ctx) async {
    got = stamps;
    ctx.report(Determinate(0, stamps.map((s) => s.pageIndex).toSet().length, 'stepAddingStamps'));
    File(outPath).writeAsStringSync('%PDF signed');
  }
}

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late _Stamper stamper;
  late PickedFile input;
  var pagesSeen = 6;
  var visible = true;
  final checks = <(int, Rect)>[];
  var runs = 0;

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    stamper = _Stamper();
    pagesSeen = 6;
    visible = true;
    checks.clear();
    final dir = paths.jobIn('draft')..createSync(recursive: true);
    final f = File(p.join(dir.path, 'lease.pdf'))..writeAsStringSync('%PDF source');
    input = PickedFile(
        path: f.path,
        displayName: 'lease_agreement.pdf',
        type: SniffedType.pdf,
        sizeBytes: 11,
        pdf: PdfMeta(pageCount: 6, pageSizes: List.filled(6, (595.0, 842.0))));
  });
  tearDown(() => db.close());

  Placement pl(int page, {double rot = 0, Rect rect = const Rect.fromLTWH(380, 740, 180, 60)}) =>
      Placement(id: 'p$page$rot', pageIndex: page, pngPath: '/sig.png', rect: rect, rotation: rot, kind: PlacementKind.signature);

  Future<List<JobState>> run(List<Placement> placements, {PickedFile? file}) async {
    final states = <JobState>[];
    runs++;
    await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice()).run(
      jobId: 'job-s$runs',
      op: SignPdfOperation(stamper,
          validatePages: (_, expected) async => pagesSeen,
          stampVisible: (_, page, box, size) async {
            checks.add((page, box));
            return visible;
          },
          clock: () => DateTime(2026, 10, 30)),
      inputs: [file ?? input],
      options: SignOptions(placements),
      cancel: CancelToken(),
      emit: states.add,
    );
    return states;
  }

  test('placements become stamps 1:1; <base>_signed.pdf; meta {pages, stamped}; history has counts only', () async {
    final states = await run([pl(2), pl(0, rot: 90), pl(0)]);
    final done = states.last as JobCompleted;
    expect(done.result.outputName, 'lease_agreement_signed.pdf');
    expect(done.result.meta.pages, 6);
    expect(done.result.meta.flags, {'stamped': 2});
    expect(stamper.got!.map((s) => (s.pageIndex, s.rotationDegrees, s.opacity)), [(2, 0.0, 1.0), (0, 90.0, 1.0), (0, 0.0, 1.0)]);
    expect(stamper.got!.first.visualRect, const Rect.fromLTWH(380, 740, 180, 60));
    final row = (await db.select(db.operations).get()).single;
    expect(row.optionsJson, '{"placements":3,"pages":2}');
    expect(row.optionsJson, isNot(contains('sig.png')));
    expect(File(input.path).readAsStringSync(), '%PDF source', reason: 'FR-SIG-12');
  });

  test('validation renders the first stamped page and checks its first stamp; a rotated stamp uses its rotated box',
      () async {
    await run([pl(3, rot: 90, rect: const Rect.fromLTWH(100, 100, 200, 50)), pl(5)]);
    final (page, box) = checks.single;
    expect(page, 3);
    expect(box.center, const Offset(200, 125));
    expect((box.width, box.height), (50.0, 200.0));
  });

  test('a blank stamp box or a page-count change → outputValidationFailed (§4.8)', () async {
    visible = false;
    expect(((await run([pl(0)])).last as JobFailed).error.code, AppErrorCode.outputValidationFailed);
    visible = true;
    pagesSeen = 5;
    expect(((await run([pl(0)])).last as JobFailed).error.code, AppErrorCode.outputValidationFailed);
  });

  test('no placements, or one on a page that doesn\'t exist → invalidInput; a locked PDF → encryptedDocument', () async {
    expect(((await run(const [])).last as JobFailed).error.code, AppErrorCode.invalidInput);
    expect(((await run([pl(6)])).last as JobFailed).error.code, AppErrorCode.invalidInput);
    final locked = PickedFile(
        path: input.path,
        displayName: 'x.pdf',
        type: SniffedType.pdf,
        sizeBytes: 1,
        status: const ValidationStatus.invalid(AppErrorCode.encryptedDocument));
    expect(((await run([pl(0)], file: locked)).last as JobFailed).error.code, AppErrorCode.encryptedDocument);
    expect(stamper.got, isNull);
  });
}
