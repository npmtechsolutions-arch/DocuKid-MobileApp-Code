import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:docukit_native/docukit_native.dart';

import '../errors/app_error.dart';
import '../files/paths.dart';
import '../operation/tool_operation.dart';

/// What a PDF's security allows (RELEASE_V1_4 §4.5).
enum PdfProtection {
  none,

  /// Needs a password to open (Unlock; the "Unlock it first" banner).
  openPassword,

  /// Opens without a password but has restrictions set by its creator; DocuKit
  /// keeps them (FR-UNL-05).
  ownerOnly,
}

sealed class UnlockResult {
  const UnlockResult();
}

final class Unlocked extends UnlockResult {
  const Unlocked();
}

/// Not an error: S38 shows it inline (FR-UNL-03).
final class WrongPassword extends UnlockResult {
  const WrongPassword();
}

final class NotEncrypted extends UnlockResult {
  const NotEncrypted();
}

/// Owner-restricted: never "unlocked" (FR-UNL-05, ADR-053).
final class OwnerOnly extends UnlockResult {
  const OwnerOnly();
}

/// Protect and Unlock PDF (RELEASE_V1_4 §4.5, ADR-049). Passwords are used
/// for the one call and never stored or logged (FR-PRT-07).
abstract interface class PdfSecurity {
  /// AES-256 with [userPassword]; the owner password is random and discarded.
  Future<void> protect(String inPath, String outPath, {required String userPassword, required JobContext ctx});

  /// Removes the password only with the right one; tries nothing else.
  Future<UnlockResult> unlock(String inPath, String outPath, {required String password, required JobContext ctx});

  Future<PdfProtection> inspect(String path);

  /// Pages when opened with [password]; null if the password is wrong
  /// (FR-PRT-06 b/c). Throws `AppError(corruptFile)`.
  Future<int?> openPageCount(String path, String password);
}

/// A password for one job (FR-PRT-07): never in `toJson`/`toString`; the
/// runner [wipe]s it when the job ends, so "Try again" can't reuse it.
class OneTimePassword {
  OneTimePassword(String value) : _value = value;
  String? _value;

  bool get isWiped => _value == null;

  /// Throws once wiped.
  String get value => _value ?? (throw const AppError(AppErrorCode.processingFailed));

  void wipe() => _value = null;

  @override
  String toString() => 'OneTimePassword(•••)';
}

/// The PDFium side (`pdfium_raw_ops.dart`, in pdfrx's worker), behind a seam
/// so the security logic is unit-tested.
abstract interface class PdfiumSecurityOps {
  /// Throws `AppError(corruptFile)` for a file PDFium can't open.
  Future<PdfProtection> inspect(String path);

  /// Opens with [password] and saves without security: `ok | wrongPassword | failed`.
  Future<String> removeSecurity(String inPath, String outPath, String password);

  /// Pages when opened with [password]; -1 for a wrong password. Throws
  /// `AppError(corruptFile)`.
  Future<int> pageCount(String path, String password);
}

/// FR-PRT-05: 32 random bytes from a secure source, base64.
String randomOwnerPassword() {
  final r = Random.secure();
  return base64.encode([for (var i = 0; i < 32; i++) r.nextInt(256)]);
}

/// Protect: native (PdfBox-Android; PDFKit on iOS in the Xcode round).
/// Unlock: PDFium first (`FPDF_REMOVE_SECURITY`, both platforms), checked to
/// be really unencrypted, then the native path where there is one.
class NativePdfSecurity implements PdfSecurity {
  NativePdfSecurity(this._native, this._pdfium, {required this.nativeUnlock});

  final DocukitNative _native;
  final PdfiumSecurityOps _pdfium;

  /// Android has PdfBox for Unlock; iOS doesn't yet (Xcode round).
  final bool nativeUnlock;

  @override
  Future<void> protect(String inPath, String outPath, {required String userPassword, required JobContext ctx}) async {
    ctx.cancel.throwIfCancelled();
    final r = await _native.protectPdf(
        inPath: inPath, outPath: outPath, userPassword: userPassword, ownerPassword: randomOwnerPassword());
    if (r['status'] == 'ok') return;
    await deleteQuietly(File(outPath));
    throw AppError(r['code'] == 'encrypted' ? AppErrorCode.encryptedDocument : AppErrorCode.processingFailed);
  }

  @override
  Future<UnlockResult> unlock(String inPath, String outPath, {required String password, required JobContext ctx}) async {
    ctx.cancel.throwIfCancelled();
    switch (await _pdfium.inspect(inPath)) {
      case PdfProtection.none:
        return const NotEncrypted();
      case PdfProtection.ownerOnly:
        return const OwnerOnly();
      case PdfProtection.openPassword:
        break;
    }
    final r = await _pdfium.removeSecurity(inPath, outPath, password);
    if (r == 'wrongPassword') {
      await deleteQuietly(File(outPath));
      return const WrongPassword();
    }
    if (r == 'ok' && await _unencrypted(outPath)) return const Unlocked();
    await deleteQuietly(File(outPath));
    if (!nativeUnlock) throw const AppError(AppErrorCode.processingFailed);

    ctx.cancel.throwIfCancelled();
    final n = await _native.unlockPdf(inPath: inPath, outPath: outPath, password: password);
    switch (n['status']) {
      case 'ok' when await _unencrypted(outPath):
        return const Unlocked();
      case 'wrongPassword':
        await deleteQuietly(File(outPath));
        return const WrongPassword();
      case 'notEncrypted':
        return const NotEncrypted();
      default:
        await deleteQuietly(File(outPath));
        throw const AppError(AppErrorCode.processingFailed);
    }
  }

  Future<bool> _unencrypted(String path) async {
    try {
      return await _pdfium.inspect(path) == PdfProtection.none;
    } on AppError {
      return false;
    }
  }

  @override
  Future<PdfProtection> inspect(String path) => _pdfium.inspect(path);

  @override
  Future<int?> openPageCount(String path, String password) async {
    final n = await _pdfium.pageCount(path, password);
    return n < 0 ? null : n;
  }
}
