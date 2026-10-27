import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/errors/error_copy.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/validation/input_validator.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('image validation', () {
    const ok = ImageMeta(format: SniffedType.jpeg, width: 100, height: 100);
    test('ok', () => expect(validateImageFile(type: SniffedType.jpeg, sizeBytes: 10, meta: ok).level, ValidationLevel.ok));
    test('too big', () {
      expect(validateImageFile(type: SniffedType.jpeg, sizeBytes: Limits.imageMaxBytes + 1, meta: ok).error,
          AppErrorCode.fileTooLarge);
    });
    test('unsupported', () {
      expect(validateImageFile(type: SniffedType.gif, sizeBytes: 10).error, AppErrorCode.unsupportedFormat);
    });
    test('corrupt when the header fails', () {
      expect(validateImageFile(type: SniffedType.png, sizeBytes: 10, inspectError: AppErrorCode.corruptFile).error,
          AppErrorCode.corruptFile);
    });
    test('over 200 MP', () {
      const huge = ImageMeta(format: SniffedType.jpeg, width: 20000, height: 10001);
      expect(validateImageFile(type: SniffedType.jpeg, sizeBytes: 10, meta: huge).error, AppErrorCode.fileTooLarge);
    });
    test('alpha → warning (still runs)', () {
      const alpha = ImageMeta(format: SniffedType.png, width: 10, height: 10, hasAlpha: true);
      final s = validateImageFile(type: SniffedType.png, sizeBytes: 10, meta: alpha);
      expect(s.level, ValidationLevel.warning);
      expect(s.isValid, isTrue);
      expect(s.warnings, contains(WarningCode.hasAlpha));
    });
  });

  group('pdf validation', () {
    test('encrypted blocks', () {
      final s = validatePdfFile(type: SniffedType.pdf, sizeBytes: 10, inspectError: AppErrorCode.encryptedDocument);
      expect(s.isValid, isFalse);
      expect(s.error, AppErrorCode.encryptedDocument);
    });
    test('zero pages is corrupt', () {
      expect(validatePdfFile(type: SniffedType.pdf, sizeBytes: 10, meta: const PdfMeta(pageCount: 0)).error,
          AppErrorCode.corruptFile);
    });
    test('not a pdf', () {
      expect(validatePdfFile(type: SniffedType.unknown, sizeBytes: 10).error, AppErrorCode.unsupportedFormat);
    });
  });

  group('storage estimate (FEATURE_SPECS §2.3)', () {
    test('multipliers', () {
      expect(estimateBytes('imageCompress', 1000), 1500);
      expect(estimateBytes('imageToPdf', 1000), 1200);
      expect(estimateBytes('pdfMerge', 1000), 2100);
      expect(estimateBytes('pdfOrganize', 1000), 2100);
      expect(estimateBytes('pdfCompress', 1000), 2500);
    });
    test('needs estimate + 50 MB', () {
      expect(hasEnoughSpace(freeBytes: 100 + Limits.freeSpaceMargin, requiredBytes: 100), isTrue);
      expect(hasEnoughSpace(freeBytes: 99 + Limits.freeSpaceMargin, requiredBytes: 100), isFalse);
    });
  });

  test('every error code has copy and a primary action', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    for (final code in AppErrorCode.values) {
      final c = errorCopy(l, AppError(code, limitBytes: 1024, count: 2, neededBytes: 4096));
      expect(c.title, isNotEmpty, reason: code.name);
      expect(c.body, isNotEmpty, reason: code.name);
      expect(errorActionLabel(l, c.primary), isNotEmpty);
    }
  });

  test('error codes round-trip by name', () {
    for (final c in AppErrorCode.values) {
      expect(AppErrorCode.tryParse(c.name), c);
    }
    expect(AppErrorCode.tryParse('nope'), isNull);
  });
}
