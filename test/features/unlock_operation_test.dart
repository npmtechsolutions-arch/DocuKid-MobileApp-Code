// T11.4 — Unlock PDF operation (RELEASE_V1_4 FR-UNL-01…07, §4.8), written
// before the implementation. A wrong password, an unprotected or an
// owner-restricted file ends the job with JobReturned and NO history row; the
// password is wiped whatever happens. Real engines: integration_test/unlock_operation_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_unlock/application/unlock_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

class _Security implements PdfSecurity {
  PdfProtection inputProtection = PdfProtection.openPassword;
  String right = 'Test-1234';
  int pages = 4;

  /// What unlock returns even with the right password (null = Unlocked).
  UnlockResult? unlockOverride;

  /// Protection of the written output.
  PdfProtection outputProtection = PdfProtection.none;
  final unlockCalls = <String>[];

  @override
  Future<PdfProtection> inspect(String path) async => path.endsWith('in.pdf') ? inputProtection : outputProtection;

  @override
  Future<int?> openPageCount(String path, String password) async => password == right ? pages : null;

  @override
  Future<UnlockResult> unlock(String inPath, String outPath, {required String password, required JobContext ctx}) async {
    unlockCalls.add(password);
    if (unlockOverride != null) return unlockOverride!;
    if (password != right) return const WrongPassword();
    File(outPath).writeAsStringSync('%PDF open');
    return const Unlocked();
  }

  @override
  Future<void> protect(String inPath, String outPath, {required String userPassword, required JobContext ctx}) =>
      throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late AppPaths paths;
  late _Security sec;
  late PickedFile input;
  var validated = <(String, int)>[];
  var pagesSeen = 4;
  var runs = 0;

  setUp(() async {
    db = memoryDb();
    paths = await tempPaths();
    sec = _Security();
    validated = [];
    pagesSeen = 4;
    final dir = paths.jobIn('draft')..createSync(recursive: true);
    final f = File(p.join(dir.path, 'in.pdf'))..writeAsStringSync('%PDF locked');
    // As picked: a password-protected PDF is "invalid: encryptedDocument" with no page meta.
    input = PickedFile(
        path: f.path,
        displayName: 'statement.pdf',
        type: SniffedType.pdf,
        sizeBytes: 11,
        status: const ValidationStatus.invalid(AppErrorCode.encryptedDocument));
  });
  tearDown(() => db.close());

  Future<List<JobState>> run(UnlockOptions o, {PickedFile? file}) async {
    final states = <JobState>[];
    runs++;
    await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice()).run(
      jobId: 'job-u$runs',
      op: UnlockPdfOperation(sec, validatePages: (path, expected) async {
        validated.add((path, expected));
        return pagesSeen;
      }, clock: () => DateTime(2026, 10, 30)),
      inputs: [file ?? input],
      options: o,
      cancel: CancelToken(),
      emit: states.add,
    );
    return states;
  }

  Future<String> historyDump() async => [
        for (final r in await db.select(db.operations).get()) jsonEncode(r.toJson()),
        for (final r in await db.select(db.operationInputs).get()) jsonEncode(r.toJson()),
        for (final r in await db.select(db.operationOutputs).get()) jsonEncode(r.toJson()),
      ].join('\n');

  test('right password: "Checking password…" → "Removing password…"; <base>_unlocked.pdf; validated; history {}', () async {
    final pw = OneTimePassword('Test-1234');
    final states = await run(UnlockOptions(pw));
    final done = states.last as JobCompleted;
    expect(done.result.outputName, 'statement_unlocked.pdf');
    expect(done.result.meta.pages, 4);
    expect(done.result.meta.flags, isEmpty);
    final steps = states.whereType<JobProcessing>().map((s) => s.progress.stepKey).toList();
    expect(steps.indexOf('stepCheckingPassword'), lessThan(steps.indexOf('stepUnlocking')));
    expect(validated.single.$2, 4, reason: 'pages as opened with the password (FR-UNL-06)');
    expect(pw.isWiped, isTrue);
    expect((await db.select(db.operations).get()).single.optionsJson, '{}');
    expect(await historyDump(), isNot(contains('Test-1234')));
    expect(File(input.path).readAsStringSync(), '%PDF locked', reason: 'the source is never changed');
  });

  test('wrong password → JobReturned(wrongPassword), NO history row, nothing unlocked, password wiped (FR-UNL-03)',
      () async {
    final pw = OneTimePassword('test-1234');
    final states = await run(UnlockOptions(pw));
    expect((states.last as JobReturned).reason, UnlockReturn.wrongPassword);
    expect(states.whereType<JobFailed>(), isEmpty);
    expect(sec.unlockCalls, isEmpty, reason: 'the check fails first; nothing is tried');
    expect(await historyDump(), isEmpty);
    expect(pw.isWiped, isTrue);
  });

  test('unprotected / owner-restricted → JobReturned(notEncrypted / ownerOnly); unlock never called (FR-UNL-01/05)',
      () async {
    final plain = PickedFile(
        path: input.path, displayName: 'statement.pdf', type: SniffedType.pdf, sizeBytes: 11, pdf: const PdfMeta(pageCount: 4));
    for (final (prot, reason) in [
      (PdfProtection.none, UnlockReturn.notEncrypted),
      (PdfProtection.ownerOnly, UnlockReturn.ownerOnly),
    ]) {
      sec.inputProtection = prot;
      final states = await run(UnlockOptions(OneTimePassword('Test-1234')), file: plain);
      expect((states.last as JobReturned).reason, reason);
    }
    expect(sec.unlockCalls, isEmpty);
    expect(await historyDump(), isEmpty);
  });

  test('the engine disagrees after the check (WrongPassword from unlock) → JobReturned too, no output', () async {
    sec.unlockOverride = const WrongPassword();
    final states = await run(UnlockOptions(OneTimePassword('Test-1234')));
    expect((states.last as JobReturned).reason, UnlockReturn.wrongPassword);
    expect(await historyDump(), isEmpty);
  });

  test('FR-UNL-06: output still encrypted, or page count differs → outputValidationFailed (a real failure row)', () async {
    sec.outputProtection = PdfProtection.openPassword;
    expect(((await run(UnlockOptions(OneTimePassword('Test-1234')))).last as JobFailed).error.code,
        AppErrorCode.outputValidationFailed);
    sec.outputProtection = PdfProtection.none;
    pagesSeen = 3;
    expect(((await run(UnlockOptions(OneTimePassword('Test-1234')))).last as JobFailed).error.code,
        AppErrorCode.outputValidationFailed);
    expect((await db.select(db.operations).get()).map((r) => r.status), everyElement('FAILED'));
  });

  test('other invalid inputs are still refused; a wiped password never runs ("Try again")', () async {
    final damaged = PickedFile(
        path: input.path,
        displayName: 'x.pdf',
        type: SniffedType.pdf,
        sizeBytes: 11,
        status: const ValidationStatus.invalid(AppErrorCode.corruptFile));
    expect(((await run(UnlockOptions(OneTimePassword('Test-1234')), file: damaged)).last as JobFailed).error.code,
        AppErrorCode.corruptFile);
    final pw = OneTimePassword('Test-1234')..wipe();
    expect((await run(UnlockOptions(pw))).last, isA<JobFailed>());
    expect(sec.unlockCalls, isEmpty);
  });

  test('options never serialise or print the password', () {
    final o = UnlockOptions(OneTimePassword('Test-1234'));
    expect(o.toJson(), isEmpty);
    expect(o.toString(), isNot(contains('Test')));
  });
}
