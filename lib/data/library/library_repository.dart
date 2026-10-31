import 'dart:io';

import '../../core/errors/app_error.dart';
import '../../features/search/tool_catalog.dart';

/// Where a library document came from (RELEASE_V1_5 §4.3 `source`).
enum DocSource { result, import, scan, incoming, backup }

/// OCR / text indexing state (§4.6).
enum IndexState { none, queued, indexing, done, failed, notNeeded }

/// FR-LIB-06: deleting a non-empty folder.
enum FolderDeleteMode { moveContentsUp, deleteEverything }

/// FR-LIB-09.
enum LibrarySort { name, added, size, expiry }

enum LibraryErrorCode { folderTooDeep, folderNameInvalid, folderNameTaken, invalidMove, nameTaken, notFound, notesTooLong }

/// A library rule the user ran into (shown inline, not on the error screen).
class LibraryException implements Exception {
  const LibraryException(this.code);
  final LibraryErrorCode code;

  @override
  String toString() => 'LibraryException(${code.name})';
}

/// Nesting limit (FR-LIB-06): folder → subfolder → sub-subfolder.
const maxFolderDepth = 3;
const maxFolderNameChars = 60;
const maxNotesChars = 2000;
const maxTags = 10, maxTagChars = 30;

class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.parentId,
    required this.name,
    required this.depth,
    required this.createdAt,
    this.docCount = 0,
  });
  final String id;
  final String? parentId;
  final String name;

  /// 1–3.
  final int depth;
  final DateTime createdAt;

  /// Documents directly in this folder.
  final int docCount;
}

class LibraryDoc {
  const LibraryDoc({
    required this.id,
    required this.folderId,
    required this.name,
    required this.relPath,
    required this.mime,
    required this.sizeBytes,
    required this.sha256,
    required this.source,
    required this.addedAt,
    this.sourceTool,
    this.pageCount,
    this.width,
    this.height,
    this.openedAt,
    this.starred = false,
    this.notes = '',
    this.tags = const [],
    this.expiryDate,
    this.reminderOffsets = const [],
    this.reminderMinuteOfDay,
    this.indexState = IndexState.none,
    this.indexedAt,
  });
  final String id;
  final String? folderId;

  /// Display name incl. extension; unique in its folder (ignoring case).
  final String name;

  /// `library/<id>/<file>`, relative to app support.
  final String relPath;
  final String mime;
  final int sizeBytes;
  final String sha256;
  final DocSource source;
  final ToolId? sourceTool;
  final int? pageCount, width, height;
  final DateTime addedAt;
  final DateTime? openedAt;
  final bool starred;
  final String notes;
  final List<String> tags;

  /// A local calendar date (midnight), or null.
  final DateTime? expiryDate;

  /// Days before [expiryDate], e.g. [30, 7, 0].
  final List<int> reminderOffsets;

  /// null = the Settings default time.
  final int? reminderMinuteOfDay;
  final IndexState indexState;
  final DateTime? indexedAt;

  bool get isPdf => mime == 'application/pdf';
}

sealed class AddResult {
  const AddResult();
}

final class Added extends AddResult {
  const Added(this.doc);
  final LibraryDoc doc;
}

/// FR-LIB-21: the same bytes (SHA-256) are already in the library.
final class Duplicate extends AddResult {
  const Duplicate(this.existing);
  final LibraryDoc existing;
}

final class AddFailed extends AddResult {
  const AddFailed(this.error);
  final AppError error;
}

class FolderDeleteSummary {
  const FolderDeleteSummary({required this.foldersDeleted, required this.docsMoved, required this.docsDeleted});
  final int foldersDeleted, docsMoved, docsDeleted;
}

class SearchHit {
  const SearchHit({required this.doc, required this.folderPath, this.snippet});
  final LibraryDoc doc;

  /// Folder names from the root; empty for the root.
  final List<String> folderPath;

  /// Recognised text around the match, matches in [ ] (render with
  /// `snippetRuns`); null when the match wasn't in recognised text.
  final String? snippet;
}

class LibraryStats {
  const LibraryStats({required this.docCount, required this.totalBytes});
  final int docCount, totalBytes;

  @override
  bool operator ==(Object other) => other is LibraryStats && other.docCount == docCount && other.totalBytes == totalBytes;
  @override
  int get hashCode => Object.hash(docCount, totalBytes);
  @override
  String toString() => 'LibraryStats($docCount, $totalBytes)';
}

enum LibraryChangeKind { added, updated, moved, deleted, folders }

/// Emitted after every write (§4.4): the reminder scheduler and the indexer
/// listen to it.
class LibraryChange {
  const LibraryChange(this.kind, this.ids);
  final LibraryChangeKind kind;
  final List<String> ids;
}

/// My Documents storage (RELEASE_V1_5 §4.4). Export/import ZIP arrive in T12.8.
abstract interface class LibraryRepository {
  Stream<LibraryChange> get changes;

  // Folders
  Stream<List<LibraryFolder>> watchFolders({String? parentId});
  Future<LibraryFolder?> folder(String id);

  /// Every folder (the S43 picker builds its tree from this).
  Future<List<LibraryFolder>> allFolders();
  Future<List<String>> folderPath(String? id);
  Future<LibraryFolder> createFolder(String name, {String? parentId});
  Future<void> renameFolder(String id, String name);
  Future<bool> canMoveFolder(String id, String? newParentId);
  Future<void> moveFolder(String id, String? newParentId);
  Future<FolderDeleteSummary> deleteFolder(String id, {required FolderDeleteMode mode});

  /// Documents and subfolders anywhere below [id] (the delete dialog's counts).
  Future<({int docs, int folders})> folderContents(String id);

  // Documents
  /// [folderId] null = the root. [starredOnly] / [tag] search all folders.
  Stream<List<LibraryDoc>> watchDocs({String? folderId, bool starredOnly = false, String? tag, LibrarySort sort = LibrarySort.added});
  Stream<List<LibraryDoc>> watchExpiringSoon({int days = 60});
  Future<LibraryDoc?> get(String id);
  String absolutePath(LibraryDoc doc);
  Future<AddResult> addFile(
    String sourcePath, {
    required String displayName,
    required DocSource source,
    required String mime,
    String? folderId,
    ToolId? sourceTool,
    int? pageCount,
    int? width,
    int? height,
    bool allowDuplicate = false,
  });
  Future<void> rename(String id, String name);
  Future<void> move(List<String> ids, String? folderId);
  Future<void> setStarred(List<String> ids, bool starred);
  Future<void> setNotes(String id, String notes);
  Future<void> setTags(String id, List<String> tags);

  /// Every tag in use, once (ignoring case), A–Z: chip suggestions and the
  /// S40 tag filter (FR-LIB-13).
  Future<List<String>> allTags();
  Future<void> setExpiry(String id, DateTime? date, List<int> offsets, int? minuteOfDay);
  Future<void> markOpened(String id);
  Future<void> delete(List<String> ids);

  /// A copy in [jobInDir] for a tool (FR-LIB-11): never the library file.
  Future<String> copyForTool(String id, Directory jobInDir);

  // Search & index
  Stream<List<SearchHit>> search(String query, {String? folderId});
  Future<void> setIndexedText(String id, String text, {required IndexState state});

  /// The queue's bookkeeping (queued / indexing / failed); the text is kept.
  Future<void> setIndexState(String id, IndexState state);

  /// Documents in [states], oldest first (the index queue, §4.6).
  Future<List<LibraryDoc>> docsWithIndexState(Set<IndexState> states);

  Future<LibraryStats> stats();

  /// Launch sweep (§4.3): library dirs without a row, `.part` files, import staging.
  Future<int> sweepOrphans();
}
