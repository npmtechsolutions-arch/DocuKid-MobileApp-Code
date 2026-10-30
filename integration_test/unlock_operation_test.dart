// T11.4 on a device (RELEASE_V1_4 R55, FR-UNL-03…07, §8.3 rows 3–4): Protect,
// then the Unlock job through JobRunner with the real engines — a wrong
// password returns with no history row and no output; the right one gives a
// copy that opens without a password and renders.
//
//   flutter test integration_test/unlock_operation_test.dart -d <android device>
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit/core/pdf/pdfium_security_ops.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/core/validation/output_validator.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_unlock/application/unlock_operation.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final native = DocukitNative();
  final security = NativePdfSecurity(native, const PdfrxSecurityOps(), nativeUnlock: Platform.isAndroid);
  final engine = PdfrxPdfEngine();
  late AppPaths paths;
  late AppDatabase db;
  late JobRunner runner;
  late Directory dir;
  late String plain;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    db = AppDatabase(NativeDatabase.memory());
    runner = JobRunner(
        paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: NativeDeviceServices(native));
    dir = paths.jobIn('it_unlock')..createSync(recursive: true);
    final doc = pw.Document();
    for (var i = 1; i <= 6; i++) {
      doc.addPage(pw.Page(build: (_) => pw.Text('Statement page $i')));
    }
    plain = p.join(dir.path, 'plain.pdf');
    File(plain).writeAsBytesSync(await doc.save());
  });

  /// As the picker reports a password-protected PDF.
  PickedFile picked(String path, {bool locked = true}) => PickedFile(
        path: path,
        displayName: 'statement.pdf',
        type: SniffedType.pdf,
        sizeBytes: File(path).lengthSync(),
        pdf: locked ? null : const PdfMeta(pageCount: 6),
        status: locked ? const ValidationStatus.invalid(AppErrorCode.encryptedDocument) : const ValidationStatus.ok(),
      );

  Future<JobState> run(String id, PickedFile f, String password) async {
    final states = <JobState>[];
    await runner.run(
      jobId: id,
      op: UnlockPdfOperation(security,
          validatePages: (path, expected) => validatePdfOutput(engine, path, expectedPages: expected)),
      inputs: [f],
      options: UnlockOptions(OneTimePassword(password)),
      cancel: CancelToken(),
      emit: states.add,
    );
    return states.last;
  }

  Future<String> historyDump() async => [
        for (final x in await db.select(db.operations).get()) jsonEncode(x.toJson()),
        for (final x in await db.select(db.operationInputs).get()) jsonEncode(x.toJson()),
        for (final x in await db.select(db.operationOutputs).get()) jsonEncode(x.toJson()),
      ].join('\n');

  testWidgets('R55: wrong password → returned, no row, no output; right → an unlocked copy that opens and renders',
      (_) async {
    final locked = p.join(dir.path, 'locked.pdf');
    await security.protect(plain, locked, userPassword: 'Test-1234',
        ctx: JobContext(jobId: 'p', workDir: dir, cancel: CancelToken(), report: (_) {}));
    final lockedSha = sha(locked);

    final wrong = await run('it-unlock-1', picked(locked), 'test-1234');
    expect((wrong as JobReturned).reason, UnlockReturn.wrongPassword);
    expect(await historyDump(), isEmpty);
    expect(Directory(p.join(paths.outputsRoot.path, 'it-unlock-1')).existsSync(), isFalse);

    final done = await run('it-unlock-2', picked(locked), 'Test-1234');
    expect(done, isA<JobCompleted>(), reason: '$done');
    final r = (done as JobCompleted).result;
    expect((r.outputName, r.meta.pages), ('statement_unlocked.pdf', 6));
    final d = await PdfDocument.openFile(r.outputPath);
    expect(d.pages.length, 6);
    await d.dispose();
    expect(sha(locked), lockedSha, reason: 'the source is never changed');
    final rows = await db.select(db.operations).get();
    expect((rows.single.status, rows.single.optionsJson), ('SUCCESS', '{}'));
    expect(await historyDump(), isNot(contains('Test-1234')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('§8.3: owner-restricted and unprotected files return with their reason; nothing is written', (_) async {
    final owner = p.join(dir.path, 'owner_only.pdf');
    final r = await native.protectPdf(
        inPath: plain, outPath: owner, userPassword: '', ownerPassword: randomOwnerPassword(), debugRestrict: true);
    expect(r['status'], 'ok');
    expect(((await run('it-unlock-3', picked(owner, locked: false), 'x')) as JobReturned).reason, UnlockReturn.ownerOnly);
    expect(((await run('it-unlock-4', picked(plain, locked: false), 'x')) as JobReturned).reason, UnlockReturn.notEncrypted);
    expect((await db.select(db.operations).get()).length, 1, reason: 'only the earlier success');
  }, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() async {
    await db.close();
    dir.deleteSync(recursive: true);
    final d = Directory(p.join(paths.outputsRoot.path, 'it-unlock-2'));
    if (d.existsSync()) d.deleteSync(recursive: true);
  });
}
