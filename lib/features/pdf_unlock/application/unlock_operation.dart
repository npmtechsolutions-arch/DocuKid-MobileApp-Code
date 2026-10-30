import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_security.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';

/// [ReturnToTool] reasons; S38 shows each inline (FR-UNL-01/03/05).
abstract final class UnlockReturn {
  static const wrongPassword = 'wrongPassword';
  static const notEncrypted = 'notEncrypted';
  static const ownerOnly = 'ownerOnly';
}

/// History stores `{}` (RELEASE_V1_4 §5.2); the password is wiped when the
/// job ends.
class UnlockOptions extends ToolOptions {
  UnlockOptions(this.password);
  final OneTimePassword password;

  @override
  Map<String, Object?> toJson() => const {};

  @override
  void wipe() => password.wipe();

  @override
  String toString() => 'UnlockOptions()';
}

/// Pages of an unencrypted PDF, checked by opening and rendering it.
typedef PageValidator = Future<int> Function(String path, int expectedPages);

/// S38 · Unlock PDF (RELEASE_V1_4 §4.8, FR-UNL-03…07). Only the password the
/// user typed is tried, once (FR-UNL-04, ADR-053).
class UnlockPdfOperation implements ToolOperation<UnlockOptions> {
  UnlockPdfOperation(this._security, {required PageValidator validatePages, DateTime Function()? clock})
      : _validatePages = validatePages,
        _now = clock ?? DateTime.now;
  final PdfSecurity _security;
  final PageValidator _validatePages;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.pdfUnlock;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, UnlockOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    // A password-protected PDF is what this tool is for.
    if (!f.status.isValid && f.status.error != AppErrorCode.encryptedDocument) {
      throw AppError(f.status.error!, fileDisplayName: f.displayName);
    }
    if (o.password.isWiped) throw const AppError(AppErrorCode.processingFailed);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, UnlockOptions o) => estimateBytes(tool.name, inputs.single.sizeBytes);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, UnlockOptions o) async {
    final input = inputs.single;
    ctx.report(const Indeterminate('stepCheckingPassword'));
    switch (await _security.inspect(input.path)) {
      case PdfProtection.none:
        throw const ReturnToTool(UnlockReturn.notEncrypted);
      case PdfProtection.ownerOnly:
        throw const ReturnToTool(UnlockReturn.ownerOnly);
      case PdfProtection.openPassword:
        break;
    }
    final pages = await _security.openPageCount(input.path, o.password.value);
    if (pages == null) throw const ReturnToTool(UnlockReturn.wrongPassword);
    ctx.cancel.throwIfCancelled();

    ctx.report(const Indeterminate('stepUnlocking'));
    final out = p.join(ctx.workDir.path, 'unlocked.pdf');
    switch (await _security.unlock(input.path, out, password: o.password.value, ctx: ctx)) {
      case Unlocked():
        break;
      case WrongPassword():
        throw const ReturnToTool(UnlockReturn.wrongPassword);
      case NotEncrypted():
        throw const ReturnToTool(UnlockReturn.notEncrypted);
      case OwnerOnly():
        throw const ReturnToTool(UnlockReturn.ownerOnly);
    }
    return RawOutput(
      path: out,
      suggestedName: defaultOutputName(NamingTool.pdfUnlock, firstInputName: input.displayName, now: _now()),
      mime: 'application/pdf',
      flags: {'expectPages': pages},
    );
  }

  /// FR-UNL-06: opens without a password, same pages, first page renders.
  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, UnlockOptions o) async {
    const invalid = AppError(AppErrorCode.outputValidationFailed);
    final f = File(out.path);
    if (!await f.exists() || await f.length() == 0) throw invalid;
    try {
      if (await _security.inspect(out.path) != PdfProtection.none) throw invalid;
      final expected = out.flags['expectPages']! as int;
      final pages = await _validatePages(out.path, expected);
      if (pages != expected) throw invalid;
      return OutputMeta(bytes: await f.length(), pages: pages);
    } on AppError {
      throw invalid;
    }
  }
}

final unlockOperationProvider = Provider<UnlockPdfOperation>((ref) {
  final PdfEngine pdf = ref.watch(pdfEngineProvider);
  return UnlockPdfOperation(
    ref.watch(pdfSecurityProvider),
    validatePages: (path, expected) => validatePdfOutput(pdf, path, expectedPages: expected),
    clock: ref.watch(clockProvider),
  );
});
