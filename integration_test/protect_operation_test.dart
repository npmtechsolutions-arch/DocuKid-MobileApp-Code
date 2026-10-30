// T11.3 on a device (RELEASE_V1_4 FR-PRT-05…08, R54 / R57 in code): the
// Protect PDF job through JobRunner with the real engines — PdfBox protects,
// PDFium validates — and a history row with no password in it.
//
//   flutter test integration_test/protect_operation_test.dart -d <android device>
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit/core/pdf/pdfium_security_ops.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_protect/application/protect_operation.dart';
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
  late AppPaths paths;
  late AppDatabase db;
  late JobRunner runner;
  late PickedFile input;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    db = AppDatabase(NativeDatabase.memory());
    runner = JobRunner(
        paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: NativeDeviceServices(native));
    final dir = paths.jobIn('it_protect')..createSync(recursive: true);
    final doc = pw.Document();
    for (var i = 1; i <= 10; i++) {
      doc.addPage(pw.Page(build: (_) => pw.Text('Bank statement page $i: balance 1,250.00')));
    }
    final f = File(p.join(dir.path, 'bank_statement.pdf'))..writeAsBytesSync(await doc.save());
    input = PickedFile(
        path: f.path,
        displayName: 'bank_statement.pdf',
        type: SniffedType.pdf,
        sizeBytes: f.lengthSync(),
        pdf: const PdfMeta(pageCount: 10));
  });

  Future<JobState> run(String id, String password) async {
    final states = <JobState>[];
    await runner.run(
      jobId: id,
      op: ProtectPdfOperation(security),
      inputs: [input],
      options: ProtectOptions(OneTimePassword(password)),
      cancel: CancelToken(),
      emit: states.add,
    );
    return states.last;
  }

  Future<int> pages(String path, {String? password}) async {
    final d = await PdfDocument.openFile(path, passwordProvider: password == null ? null : () => password);
    try {
      return d.pages.length;
    } finally {
      await d.dispose();
    }
  }

  testWidgets('Protect job: validated output needs the password, opens with it, 10 pages; source unchanged; history clean',
      (_) async {
    final before = sha(input.path);
    final done = await run('it-protect-1', 'Test-1234');
    expect(done, isA<JobCompleted>(), reason: '$done');
    final r = (done as JobCompleted).result;
    expect(r.outputName, 'bank_statement_protected.pdf');
    expect((r.meta.pages, r.meta.flags['encrypted']), (10, true));
    await expectLater(pages(r.outputPath), throwsA(isA<PdfPasswordException>()));
    expect(await pages(r.outputPath, password: 'Test-1234'), 10);
    expect(sha(input.path), before);

    final rows = [
      for (final x in await db.select(db.operations).get()) jsonEncode(x.toJson()),
      for (final x in await db.select(db.operationOutputs).get()) jsonEncode(x.toJson()),
      for (final x in await db.select(db.operationInputs).get()) jsonEncode(x.toJson()),
    ].join('\n');
    expect(rows, isNot(contains('Test-1234')));
    expect((await db.select(db.operations).get()).single.optionsJson, '{}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('the longest Hindi password allowed (42 chars, 126 UTF-8 bytes) protects and opens; 43 is refused',
      (_) async {
    String hindi(int n) => ('पासवर्ड' * 10).runes.take(n).map(String.fromCharCode).join();
    final h42 = hindi(42), h43 = hindi(43);
    expect((utf8.encode(h42).length, passwordProblem(h43, h43)), (126, PasswordProblem.tooManyBytes));
    final done = await run('it-protect-2', h42);
    expect(done, isA<JobCompleted>(), reason: '$done');
    final out = (done as JobCompleted).result.outputPath;
    expect(await pages(out, password: h42), 10);
  }, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() async {
    await db.close();
    for (final id in ['it-protect-1', 'it-protect-2']) {
      final d = Directory(p.join(paths.outputsRoot.path, id));
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });
}
