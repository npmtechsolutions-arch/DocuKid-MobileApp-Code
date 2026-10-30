// T11.2 — PdfSecurity (RELEASE_V1_4 §4.5, FR-PRT-05/07, FR-UNL-03…05,
// ADR-049/053) with a fake channel and fake PDFium ops. Written before the
// implementation. The real engines run in integration_test/pdf_security_test.dart.
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Native extends DocukitNative {
  final protects = <Map<String, Object?>>[];
  final unlocks = <String>[];
  Map<String, Object?> protectResult = const {'status': 'ok'};
  Map<String, Object?> unlockResult = const {'status': 'ok'};

  @override
  Future<Map<String, Object?>> protectPdf({
    required String inPath,
    required String outPath,
    required String userPassword,
    required String ownerPassword,
    bool debugRestrict = false,
  }) async {
    protects.add({'user': userPassword, 'owner': ownerPassword});
    if (protectResult['status'] == 'ok') File(outPath).writeAsStringSync('%PDF protected');
    return protectResult;
  }

  @override
  Future<Map<String, Object?>> unlockPdf({required String inPath, required String outPath, required String password}) async {
    unlocks.add(password);
    if (unlockResult['status'] == 'ok') File(outPath).writeAsStringSync('%PDF native-unlocked');
    return unlockResult;
  }
}

/// PDFium stand-in: protection per path; what removeSecurity does.
class _Ops implements PdfiumSecurityOps {
  final protection = <String, PdfProtection>{};
  String removeResult = 'ok';

  /// Protection of the file removeSecurity writes (none = really unlocked).
  PdfProtection outputProtection = PdfProtection.none;
  final removes = <String>[];

  @override
  Future<PdfProtection> inspect(String path) async {
    if (protection[path] case final p?) return p;
    final f = File(path);
    if (!f.existsSync()) throw const AppError(AppErrorCode.corruptFile);
    return f.readAsStringSync().contains('pdfium') ? outputProtection : PdfProtection.none;
  }

  @override
  Future<String> removeSecurity(String inPath, String outPath, String password) async {
    removes.add(password);
    if (removeResult == 'ok') File(outPath).writeAsStringSync('%PDF pdfium-unlocked');
    return removeResult;
  }
}

void main() {
  late Directory dir;
  late _Native native;
  late _Ops ops;
  late String input, out;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pdfsec');
    native = _Native();
    ops = _Ops();
    input = (File(p.join(dir.path, 'in.pdf'))..writeAsStringSync('%PDF')).path;
    out = p.join(dir.path, 'out.pdf');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  JobContext ctx({CancelToken? cancel}) =>
      JobContext(jobId: 'j', workDir: dir, cancel: cancel ?? CancelToken(), report: (_) {});
  PdfSecurity sec({bool nativeUnlock = true}) => NativePdfSecurity(native, ops, nativeUnlock: nativeUnlock);

  group('protect (FR-PRT-05)', () {
    test('the user password as given; a random 32-byte owner password, new every time, never the user\'s', () async {
      await sec().protect(input, out, userPassword: 'Test-1234', ctx: ctx());
      await sec().protect(input, out, userPassword: 'Test-1234', ctx: ctx());
      final (a, b) = (native.protects[0], native.protects[1]);
      expect(a['user'], 'Test-1234');
      expect((a['owner']! as String).length, 44, reason: 'base64 of 32 bytes');
      expect(a['owner'], isNot(b['owner']));
      expect(a['owner'], isNot(a['user']));
    });

    test('failures map to AppErrors; an already-protected input → encryptedDocument; no output left', () async {
      native.protectResult = const {'status': 'failed', 'code': 'encrypted'};
      await expectLater(sec().protect(input, out, userPassword: 'x12345', ctx: ctx()),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.encryptedDocument)));
      native.protectResult = const {'status': 'failed', 'code': 'unsupported'};
      await expectLater(sec().protect(input, out, userPassword: 'x12345', ctx: ctx()),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.processingFailed)));
      expect(File(out).existsSync(), isFalse);
    });

    test('cancel before starting → CancelledException, nothing called', () async {
      final c = CancelToken()..cancel();
      await expectLater(sec().protect(input, out, userPassword: 'x12345', ctx: ctx(cancel: c)), throwsA(isA<CancelledException>()));
      expect(native.protects, isEmpty);
    });
  });

  group('unlock (FR-UNL-03…05, ADR-053)', () {
    test('not encrypted → NotEncrypted; nothing removed', () async {
      expect(await sec().unlock(input, out, password: 'x', ctx: ctx()), isA<NotEncrypted>());
      expect(ops.removes, isEmpty);
      expect(native.unlocks, isEmpty);
    });

    test('owner-only (opens without a password) → OwnerOnly; NEVER removed, by any path', () async {
      ops.protection[input] = PdfProtection.ownerOnly;
      expect(await sec().unlock(input, out, password: 'anything', ctx: ctx()), isA<OwnerOnly>());
      expect(ops.removes, isEmpty);
      expect(native.unlocks, isEmpty);
      expect(File(out).existsSync(), isFalse);
    });

    test('PDFium first: wrong password → WrongPassword, no output, no other attempt', () async {
      ops.protection[input] = PdfProtection.openPassword;
      ops.removeResult = 'wrongPassword';
      expect(await sec().unlock(input, out, password: 'nope', ctx: ctx()), isA<WrongPassword>());
      expect(ops.removes, ['nope'], reason: 'only the given password, once');
      expect(native.unlocks, isEmpty);
      expect(File(out).existsSync(), isFalse);
    });

    test('PDFium unlocks and the output is really unencrypted → Unlocked', () async {
      ops.protection[input] = PdfProtection.openPassword;
      expect(await sec().unlock(input, out, password: 'Test-1234', ctx: ctx()), isA<Unlocked>());
      expect(native.unlocks, isEmpty);
      expect(File(out).readAsStringSync(), contains('pdfium'));
    });

    test('PDFium output still encrypted, or PDFium failed → the native path (Android)', () async {
      ops.protection[input] = PdfProtection.openPassword;
      ops.outputProtection = PdfProtection.openPassword;
      expect(await sec().unlock(input, out, password: 'Test-1234', ctx: ctx()), isA<Unlocked>());
      expect(native.unlocks, ['Test-1234']);
      expect(File(out).readAsStringSync(), contains('native'));
      ops.removeResult = 'failed';
      native.unlocks.clear();
      expect(await sec().unlock(input, out, password: 'Test-1234', ctx: ctx()), isA<Unlocked>());
      expect(native.unlocks, ['Test-1234']);
    });

    test('native says wrong password → WrongPassword; no native path (iOS for now) → processingFailed', () async {
      ops.protection[input] = PdfProtection.openPassword;
      ops.removeResult = 'failed';
      native.unlockResult = const {'status': 'wrongPassword'};
      expect(await sec().unlock(input, out, password: 'x', ctx: ctx()), isA<WrongPassword>());
      await expectLater(sec(nativeUnlock: false).unlock(input, out, password: 'x', ctx: ctx()),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.processingFailed)));
      expect(File(out).existsSync(), isFalse);
    });
  });

  test('inspect is PDFium\'s (both platforms)', () async {
    ops.protection[input] = PdfProtection.ownerOnly;
    expect(await sec().inspect(input), PdfProtection.ownerOnly);
  });

  test('the owner password generator: 32 random bytes, base64', () {
    final a = randomOwnerPassword(), b = randomOwnerPassword();
    expect((a.length, b.length), (44, 44));
    expect(a, isNot(b));
  });
}
