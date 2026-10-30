// T11.3 — Protect PDF operation (RELEASE_V1_4 FR-PRT-02/03/05…08, §4.8,
// §8.1 strength / validation / hygiene), written before the implementation.
// PdfSecurity is faked; the real engines run in
// integration_test/protect_operation_test.dart.
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
import 'package:docukit/features/pdf_protect/application/protect_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// Writes a marker file; [outputProtection]/[pages] drive validation.
class _Security implements PdfSecurity {
  final protected = <String>[];
  PdfProtection inputProtection = PdfProtection.none;
  PdfProtection outputProtection = PdfProtection.openPassword;
  int pages = 3;
  bool failProtect = false;
  void Function()? onProtect;

  @override
  Future<void> protect(String inPath, String outPath, {required String userPassword, required JobContext ctx}) async {
    onProtect?.call();
    if (failProtect) throw const AppError(AppErrorCode.processingFailed);
    protected.add(userPassword);
    File(outPath).writeAsStringSync('%PDF locked');
  }

  @override
  Future<PdfProtection> inspect(String path) async => path.endsWith('in.pdf') ? inputProtection : outputProtection;

  @override
  Future<int?> openPageCount(String path, String password) async => password == protected.lastOrNull ? pages : null;

  @override
  Future<UnlockResult> unlock(String inPath, String outPath, {required String password, required JobContext ctx}) =>
      throw UnimplementedError();
}

void main() {
  group('strength (FR-PRT-03): weak < 8 chars or one kind; strong ≥ 12 chars and ≥ 3 kinds; else OK', () {
    for (final (pw, s) in [
      ('abcdef', PasswordStrength.weak),
      ('abcdefgh', PasswordStrength.weak), // one kind
      ('12345678901234', PasswordStrength.weak), // one kind, long
      ('Abcdef1', PasswordStrength.weak), // 7 chars
      ('abcdefg1', PasswordStrength.ok), // 8 chars, 2 kinds
      ('Abcdefgh1234', PasswordStrength.strong), // 12 chars, 3 kinds
      ('abcdefgh1234', PasswordStrength.ok), // 12 chars, 2 kinds
      ('Abcdefgh123', PasswordStrength.ok), // 11 chars, 3 kinds
      ('पासवर्ड-2026-ok', PasswordStrength.strong), // other scripts count as their own kind
    ]) {
      test('"$pw" → ${s.name}', () => expect(passwordStrength(pw), s));
    }
  });

  group('validation (FR-PRT-02): 6–64 characters; confirm must match', () {
    test('boundaries', () {
      expect(passwordProblem('12345', '12345'), PasswordProblem.tooShort);
      expect(passwordProblem('123456', '123456'), isNull);
      expect(passwordProblem('a' * 64, 'a' * 64), isNull);
      expect(passwordProblem('a' * 65, 'a' * 65), PasswordProblem.tooLong);
      expect(passwordProblem('123456', '123457'), PasswordProblem.mismatch);
    });
    test('characters, not UTF-16 units; and at most 127 UTF-8 bytes (T11.3 measurement)', () {
      final hindi42 = 'प' * 42, hindi43 = 'प' * 43; // 126 / 129 bytes
      expect(passwordProblem(hindi42, hindi42), isNull);
      expect(passwordProblem(hindi43, hindi43), PasswordProblem.tooManyBytes);
      expect(passwordProblem('🔒' * 31, '🔒' * 31), isNull, reason: '31 code points, 124 bytes');
      expect(passwordProblem('🔒' * 32, '🔒' * 32), PasswordProblem.tooManyBytes);
      expect(passwordProblem('é' * 63, 'é' * 63), isNull, reason: '126 bytes');
      expect(passwordProblem('é' * 64, 'é' * 64), PasswordProblem.tooManyBytes);
      expect(passwordProblem('🔒' * 65, '🔒' * 65), PasswordProblem.tooLong, reason: 'characters are checked first');
    });
  });

  group('operation + runner', () {
    late AppDatabase db;
    late AppPaths paths;
    late _Security sec;
    late PickedFile input;

    setUp(() async {
      db = memoryDb();
      paths = await tempPaths();
      sec = _Security();
      final dir = paths.jobIn('draft')..createSync(recursive: true);
      final f = File(p.join(dir.path, 'in.pdf'))..writeAsStringSync('%PDF source');
      input = PickedFile(
          path: f.path, displayName: 'bank_statement.pdf', type: SniffedType.pdf, sizeBytes: 11, pdf: const PdfMeta(pageCount: 3));
    });
    tearDown(() => db.close());

    var runs = 0;
    Future<List<JobState>> run(ProtectOptions o, {CancelToken? cancel}) async {
      final states = <JobState>[];
      runs++;
      await JobRunner(paths: paths, history: HistoryRepository(db), outputs: OutputsRepository(paths), device: FakeDevice()).run(
        jobId: runs == 1 ? 'job-p' : 'job-p$runs',
        op: ProtectPdfOperation(sec, clock: () => DateTime(2026, 10, 30)),
        inputs: [input],
        options: o,
        cancel: cancel ?? CancelToken(),
        emit: states.add,
      );
      return states;
    }

    Future<String> historyDump() async => [
          for (final r in await db.select(db.operations).get()) jsonEncode(r.toJson()),
          for (final r in await db.select(db.operationOutputs).get()) jsonEncode(r.toJson()),
        ].join('\n');

    test('success: <base>_protected.pdf, "Adding password…", {"pages","encrypted"}; optionsJson {} and no password anywhere',
        () async {
      final pw = OneTimePassword('Secret-Pw-42');
      final states = await run(ProtectOptions(pw));
      final done = states.last as JobCompleted;
      expect(done.result.outputName, 'bank_statement_protected.pdf');
      expect(done.result.meta.pages, 3);
      expect(done.result.meta.flags['encrypted'], true);
      expect(states.whereType<JobProcessing>().map((s) => s.progress.stepKey), contains('stepEncrypting'));
      expect(sec.protected, ['Secret-Pw-42']);
      expect(pw.isWiped, isTrue, reason: 'cleared when the job ends (FR-PRT-07)');
      final row = (await db.select(db.operations).get()).single;
      expect(row.optionsJson, '{}');
      expect(await historyDump(), isNot(contains('Secret-Pw-42')));
      expect(File(input.path).readAsStringSync(), '%PDF source', reason: 'FR-PRT-08');
    });

    test('FR-PRT-06 (a): output opens without a password → outputValidationFailed, nothing adopted', () async {
      sec.outputProtection = PdfProtection.none;
      final pw = OneTimePassword('Secret-Pw-42');
      final e = (await run(ProtectOptions(pw))).last as JobFailed;
      expect(e.error.code, AppErrorCode.outputValidationFailed);
      expect(pw.isWiped, isTrue);
      expect(Directory(p.join(paths.outputsRoot.path, 'job-p')).existsSync(), isFalse);
    });

    test('FR-PRT-06 (b)/(c): wrong page count with the password → outputValidationFailed', () async {
      sec.pages = 2;
      expect(((await run(ProtectOptions(OneTimePassword('Secret-Pw-42')))).last as JobFailed).error.code,
          AppErrorCode.outputValidationFailed);
    });

    test('an owner-restricted or locked input is refused: encryptedDocument, protect never called (ADR-053)', () async {
      for (final prot in [PdfProtection.ownerOnly, PdfProtection.openPassword]) {
        sec.inputProtection = prot;
        final pw = OneTimePassword('Secret-Pw-42');
        expect(((await run(ProtectOptions(pw))).last as JobFailed).error.code, AppErrorCode.encryptedDocument);
        expect(pw.isWiped, isTrue);
      }
      expect(sec.protected, isEmpty);
    });

    test('failure and cancel also wipe the password; "Try again" with a wiped one fails without protecting', () async {
      sec.failProtect = true;
      final pw = OneTimePassword('Secret-Pw-42');
      expect((await run(ProtectOptions(pw))).last, isA<JobFailed>());
      expect(pw.isWiped, isTrue);

      sec.failProtect = false;
      final c = CancelToken();
      sec.onProtect = c.cancel;
      final pw2 = OneTimePassword('Secret-Pw-42');
      expect((await run(ProtectOptions(pw2), cancel: c)).last, isA<JobCancelled>());
      expect(pw2.isWiped, isTrue);

      sec.onProtect = null;
      expect((await run(ProtectOptions(pw))).last, isA<JobFailed>(), reason: 'the restart closure reuses wiped options');
      expect(sec.protected, ['Secret-Pw-42'], reason: 'only the cancelled run reached protect');
    });

    test('options never serialise the password', () {
      final o = ProtectOptions(OneTimePassword('Secret-Pw-42'));
      expect(o.toJson(), isEmpty);
      expect(o.toString(), isNot(contains('Secret')));
    });
  });
}
