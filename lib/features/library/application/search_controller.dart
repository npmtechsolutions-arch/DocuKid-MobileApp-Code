import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/library/library_repository.dart';

/// How long S40/S41 wait after the last keystroke before searching (FR-LIB-14).
const searchDebounce = Duration(milliseconds: 150);

class LibrarySearchQuery {
  const LibrarySearchQuery(this.text, {this.folderId});
  final String text;

  /// S41: this folder and its subfolders; null = everything.
  final String? folderId;

  @override
  bool operator ==(Object other) => other is LibrarySearchQuery && other.text == text && other.folderId == folderId;
  @override
  int get hashCode => Object.hash(text, folderId);
}

/// Names, notes, tags and recognised text (FR-LIB-14); live, so a document
/// that finishes indexing appears while the results are open.
final librarySearchProvider = StreamProvider.autoDispose.family<List<SearchHit>, LibrarySearchQuery>(
    (ref, q) => ref.watch(libraryRepositoryProvider).search(q.text, folderId: q.folderId));
