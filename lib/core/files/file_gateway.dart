import 'dart:ui' show Rect;

import 'picked_file.dart';

class PickResult {
  const PickResult(this.files, {this.truncated = false, this.rejectedTooLarge = 0});
  const PickResult.cancelled()
      : files = const [],
        truncated = false,
        rejectedTooLarge = 0;
  final List<PickedFile> files;

  /// More than the max were picked; only the first N were kept.
  final bool truncated;

  /// Files refused before copying because they exceed the size limit.
  final int rejectedTooLarge;

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

enum ShareOutcome { shared, dismissed, failed }

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
  Future<ShareOutcome> share(List<String> paths, {required String mime, Rect? origin});
  Future<bool> openWith(String path, {required String mime, Rect? origin});
  Future<bool> exists(String path);

  /// Deletes a draft's in/ copies (never the user's originals).
  Future<void> discardDraft(String draftId);
}
