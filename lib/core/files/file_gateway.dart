import 'dart:ui' show Rect;

import 'picked_file.dart';

class PickResult {
  const PickResult(this.files, {this.truncated = false, this.rejectedTooLarge = 0}) : lowStorageNeededBytes = null;
  const PickResult.cancelled()
      : files = const [],
        truncated = false,
        rejectedTooLarge = 0,
        lowStorageNeededBytes = null;

  /// Nothing came back and the device is nearly full (R16).
  const PickResult.lowStorage(int neededBytes)
      : files = const [],
        truncated = false,
        rejectedTooLarge = 0,
        lowStorageNeededBytes = neededBytes;
  final List<PickedFile> files;

  /// More than the max were picked; only the first N were kept.
  final bool truncated;

  /// Files refused before copying because they exceed the size limit.
  final int rejectedTooLarge;

  /// Set when the pick most likely failed for lack of space: show
  /// insufficientStorage with this amount instead of staying silent.
  final int? lowStorageNeededBytes;

  bool get isEmpty => files.isEmpty;
}

sealed class SaveOutcome {
  const SaveOutcome();
}

final class Saved extends SaveOutcome {
  const Saved([this.displayName]);
  final String? displayName;
}

final class SaveCancelled extends SaveOutcome {
  const SaveCancelled();
}

final class SaveFailed extends SaveOutcome {
  const SaveFailed();
}

final class PhotosAccessDenied extends SaveOutcome {
  const PhotosAccessDenied();
}

/// [tooMany]: more than `Limits.maxShareFiles`; nothing was shown (FR-BAT-04
/// offers a ZIP instead).
enum ShareOutcome { shared, dismissed, failed, tooMany }

/// One output to write with [FileGateway.saveManyToFolder].
class SaveItem {
  const SaveItem({required this.path, required this.name, required this.mime});
  final String path, name, mime;
}

sealed class SaveManyOutcome {
  const SaveManyOutcome();
}

/// [failed] files couldn't be written ("Saved 15 of 16"). [folderName] is the
/// picked folder's display name (Android), when known.
final class SavedMany extends SaveManyOutcome {
  const SavedMany({required this.saved, required this.failed, this.failedIndexes = const [], this.folderName});
  final int saved, failed;

  /// Items (by position in the request) that failed, when the OS says
  /// (Android); a retry sends only these.
  final List<int> failedIndexes;
  final String? folderName;
}

final class SaveManyCancelled extends SaveManyOutcome {
  const SaveManyCancelled();
}

final class SaveManyFailed extends SaveManyOutcome {
  const SaveManyFailed();
}

/// Every file-system and picker interaction (ARCHITECTURE §6.2). Widgets never
/// call plugins directly.
abstract interface class FileGateway {
  /// Copies picked images into `jobs/<draftId>/in` and inspects them.
  Future<PickResult> pickImages({required String draftId, required int max});

  Future<PickResult> pickPdfs({required String draftId, required bool multiple, int max = 20});

  /// Re-inspects files that were already copied (draft restore, incoming).
  Future<List<PickedFile>> reinspect(List<PickedFile> files);

  Future<SaveOutcome> saveAs(String path, {required String suggestedName, required String mime});
  Future<SaveOutcome> saveToPhotos(String path);

  /// FR-BAT-02: the user picks a folder once and every item is written there
  /// (Android `ACTION_OPEN_DOCUMENT_TREE`; iOS export picker with all files).
  /// Names are made safe and unique; the folder may still add " (1)".
  Future<SaveManyOutcome> saveManyToFolder(List<SaveItem> items);

  /// At most `Limits.maxShareFiles` files; more returns [ShareOutcome.tooMany].
  Future<ShareOutcome> share(List<String> paths, {required String mime, Rect? origin});

  /// Plain text to the share sheet (OCR Review, RELEASE_V1_3 §3.3).
  Future<ShareOutcome> shareText(String text, {Rect? origin});
  Future<bool> openWith(String path, {required String mime, Rect? origin});
  Future<bool> exists(String path);

  /// FR-SHR-04: moves received files into `jobs/<draftId>/in/` and inspects
  /// them like picked files. [sourceDir] (the native temp folder) is removed.
  Future<List<PickedFile>> adoptIncoming(List<({String path, String name})> files, {required String draftId, String? sourceDir});

  /// Deletes a draft's in/ copies (never the user's originals).
  Future<void> discardDraft(String draftId);
}
