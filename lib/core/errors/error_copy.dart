import '../../l10n/gen/app_localizations.dart';
import '../formatting/bytes_format.dart';
import '../ocr/ocr_labels.dart';
import '../ocr/text_recognizer.dart';
import 'app_error.dart';

enum ErrorAction { chooseAnother, backToTool, tryAgain, unlockPdf }

class ErrorCopy {
  const ErrorCopy({required this.title, required this.body, required this.primary, this.secondary});
  final String title;
  final String body;
  final ErrorAction primary;
  final ErrorAction? secondary;
}

/// Maps a code to its COPY §4 title/body/actions.
ErrorCopy errorCopy(AppLocalizations l, AppError e) {
  String size(int? b) => b == null ? '' : formatBytes(b);
  switch (e.code) {
    case AppErrorCode.unsupportedFormat:
      return ErrorCopy(
          title: l.errUnsupportedFormatTitle,
          body: l.errUnsupportedFormatBody,
          primary: ErrorAction.chooseAnother,
          secondary: ErrorAction.backToTool);
    case AppErrorCode.invalidInput:
      return ErrorCopy(
          title: l.errInvalidInputTitle, body: l.errInvalidInputBody, primary: ErrorAction.backToTool);
    case AppErrorCode.encryptedDocument:
      return ErrorCopy(
          title: l.errEncryptedDocumentTitle,
          body: l.errEncryptedDocumentBody,
          // "Unlock it first" (RELEASE_V1_4 FR-UNL-08).
          primary: ErrorAction.unlockPdf,
          secondary: ErrorAction.chooseAnother);
    case AppErrorCode.corruptFile:
      return ErrorCopy(
          title: l.errCorruptFileTitle,
          body: l.errCorruptFileBody,
          primary: ErrorAction.chooseAnother,
          secondary: ErrorAction.backToTool);
    case AppErrorCode.fileTooLarge:
      return ErrorCopy(
          title: l.errFileTooLargeTitle,
          body: l.errFileTooLargeBody(size(e.limitBytes)),
          primary: ErrorAction.chooseAnother);
    case AppErrorCode.tooManyFiles:
      return ErrorCopy(
          title: l.errTooManyFilesTitle,
          body: l.errTooManyFilesBody(e.count ?? 0),
          primary: ErrorAction.backToTool);
    case AppErrorCode.notEnoughFiles:
      return ErrorCopy(
          title: l.errNotEnoughFilesTitle,
          body: l.errNotEnoughFilesBody(e.count ?? 0),
          primary: ErrorAction.backToTool);
    case AppErrorCode.insufficientStorage:
      return ErrorCopy(
          title: l.errInsufficientStorageTitle,
          body: l.errInsufficientStorageBody(size(e.neededBytes)),
          primary: ErrorAction.tryAgain,
          secondary: ErrorAction.backToTool);
    case AppErrorCode.permissionLost:
      return ErrorCopy(
          title: l.errPermissionLostTitle, body: l.errPermissionLostBody, primary: ErrorAction.chooseAnother);
    case AppErrorCode.processingFailed:
      return ErrorCopy(
          title: l.errProcessingFailedTitle,
          body: l.errProcessingFailedBody,
          primary: ErrorAction.tryAgain,
          secondary: ErrorAction.backToTool);
    case AppErrorCode.outOfMemory:
      return ErrorCopy(
          title: l.errOutOfMemoryTitle, body: l.errOutOfMemoryBody, primary: ErrorAction.backToTool);
    case AppErrorCode.cancelled:
      return ErrorCopy(title: l.errCancelledTitle, body: l.errCancelledBody, primary: ErrorAction.backToTool);
    case AppErrorCode.outputValidationFailed:
      return ErrorCopy(
          title: l.errOutputValidationFailedTitle,
          body: l.errOutputValidationFailedBody,
          primary: ErrorAction.tryAgain,
          secondary: ErrorAction.backToTool);
    case AppErrorCode.saveFailed:
      return ErrorCopy(title: l.errSaveFailedTitle, body: l.errSaveFailedBody, primary: ErrorAction.tryAgain);
    case AppErrorCode.interrupted:
      return ErrorCopy(title: l.errInterruptedTitle, body: l.errInterruptedBody, primary: ErrorAction.tryAgain);
    case AppErrorCode.ocrModelUnavailable:
      final script = OcrScript.values.asNameMap()[e.script] ?? OcrScript.latin;
      return ErrorCopy(
          title: l.errOcrModelUnavailableTitle,
          body: l.errOcrModelUnavailableBody(ocrScriptLabel(l, script)),
          primary: ErrorAction.backToTool);
  }
}

String errorActionLabel(AppLocalizations l, ErrorAction a) => switch (a) {
      ErrorAction.chooseAnother => l.chooseAnother,
      ErrorAction.backToTool => l.backToTool,
      ErrorAction.tryAgain => l.actionTryAgain,
      ErrorAction.unlockPdf => l.encUnlockAction,
    };
