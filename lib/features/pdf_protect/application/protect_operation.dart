import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_security.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../search/tool_catalog.dart';

/// FR-PRT-02, counted in characters (Unicode code points).
const minPasswordChars = 6;
const maxPasswordChars = 64;

/// AES-256 (R6) uses at most 127 UTF-8 bytes. Above that PdfBox encrypts with
/// the whole password but PDFium (and so pdfrx, Chrome, most viewers) can't
/// open the file with any form of it — measured in T11.3 — so it's refused.
const maxPasswordBytes = 127;

enum PasswordStrength { weak, ok, strong }

enum PasswordProblem { tooShort, tooLong, tooManyBytes, mismatch }

final _lower = RegExp(r'\p{Ll}', unicode: true);
final _upper = RegExp(r'\p{Lu}', unicode: true);
final _digit = RegExp(r'\p{Nd}', unicode: true);
final _other = RegExp(r'[^\p{Ll}\p{Lu}\p{Nd}]', unicode: true);

/// FR-PRT-03: weak below 8 characters or with one kind of character; strong
/// from 12 characters with at least 3 kinds; OK otherwise. The kinds are
/// lowercase, uppercase, digits and everything else (symbols, letters of
/// scripts without case).
PasswordStrength passwordStrength(String password) {
  final length = password.runes.length;
  final kinds = [_lower, _upper, _digit, _other].where((r) => r.hasMatch(password)).length;
  if (length < 8 || kinds < 2) return PasswordStrength.weak;
  if (length >= 12 && kinds >= 3) return PasswordStrength.strong;
  return PasswordStrength.ok;
}

PasswordProblem? passwordProblem(String password, String confirm) {
  final length = password.runes.length;
  if (length < minPasswordChars) return PasswordProblem.tooShort;
  if (length > maxPasswordChars) return PasswordProblem.tooLong;
  if (utf8.encode(password).length > maxPasswordBytes) return PasswordProblem.tooManyBytes;
  if (password != confirm) return PasswordProblem.mismatch;
  return null;
}

/// History stores `{}` (RELEASE_V1_4 §5.2); the password is wiped when the
/// job ends.
class ProtectOptions extends ToolOptions {
  ProtectOptions(this.password);
  final OneTimePassword password;

  @override
  Map<String, Object?> toJson() => const {};

  @override
  void wipe() => password.wipe();

  @override
  String toString() => 'ProtectOptions()';
}

/// S37 · Protect PDF (RELEASE_V1_4 §4.8, FR-PRT-05…08).
class ProtectPdfOperation implements ToolOperation<ProtectOptions> {
  ProtectPdfOperation(this._security, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final PdfSecurity _security;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.pdfProtect;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ProtectOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    // A wiped password ("Try again" after the job ended) never runs.
    if (o.password.isWiped) throw const AppError(AppErrorCode.processingFailed);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ProtectOptions o) => estimateBytes(tool.name, inputs.single.sizeBytes);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, ProtectOptions o) async {
    final input = inputs.single;
    ctx.report(const Indeterminate('stepEncrypting'));
    // Already protected, or owner-restricted: protecting would replace the
    // creator's restrictions (FR-PRT-01, ADR-053).
    if (await _security.inspect(input.path) != PdfProtection.none) {
      throw AppError(AppErrorCode.encryptedDocument, fileDisplayName: input.displayName);
    }
    final out = p.join(ctx.workDir.path, 'protected.pdf');
    await _security.protect(input.path, out, userPassword: o.password.value, ctx: ctx);
    return RawOutput(
      path: out,
      suggestedName: defaultOutputName(NamingTool.pdfProtect, firstInputName: input.displayName, now: _now()),
      mime: 'application/pdf',
      flags: const {'encrypted': true},
    );
  }

  /// FR-PRT-06: (a) needs a password, (b) opens with it, (c) same pages.
  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ProtectOptions o) async {
    const invalid = AppError(AppErrorCode.outputValidationFailed);
    final f = File(out.path);
    if (!await f.exists() || await f.length() == 0) throw invalid;
    try {
      if (await _security.inspect(out.path) != PdfProtection.openPassword) throw invalid;
      final pages = await _security.openPageCount(out.path, o.password.value);
      if (pages == null || pages != inputs.single.pdf?.pageCount) throw invalid;
      return OutputMeta(bytes: await f.length(), pages: pages, flags: out.flags);
    } on AppError {
      throw invalid;
    }
  }
}

final protectOperationProvider = Provider<ProtectPdfOperation>(
    (ref) => ProtectPdfOperation(ref.watch(pdfSecurityProvider), clock: ref.watch(clockProvider)));

/// FR-PRT-01: what the picked file's security allows, keyed by its path.
final pdfProtectionProvider = FutureProvider.autoDispose.family<PdfProtection, String>(
  (ref, path) => ref.watch(pdfSecurityProvider).inspect(path),
);
