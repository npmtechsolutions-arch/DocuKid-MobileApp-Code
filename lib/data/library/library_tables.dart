import 'package:drift/drift.dart';

/// My Documents (RELEASE_V1_5 §4.3). Folders are rows, not directories: moves
/// are DB updates only.
@DataClassName('LibraryFolderRow')
class LibraryFolders extends Table {
  TextColumn get id => text()(); // uuid v7
  TextColumn get parentId => text().nullable().references(LibraryFolders, #id)(); // null = root
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get depth => integer()(); // 1..3
  IntColumn get createdAt => integer()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LibraryDocRow')
class LibraryDocuments extends Table {
  TextColumn get id => text()(); // uuid v7 = folder name on disk
  TextColumn get folderId => text().nullable().references(LibraryFolders, #id)();
  TextColumn get name => text()(); // display name incl. extension
  TextColumn get relPath => text()(); // 'library/<id>/<file>'
  TextColumn get mime => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get pageCount => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get sha256 => text()(); // hex
  TextColumn get source => text()(); // result|import|scan|incoming|backup
  TextColumn get sourceTool => text().nullable()(); // ToolId.name, as in `operations.tool`
  IntColumn get addedAt => integer()();
  IntColumn get openedAt => integer().nullable()();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get expiryDate => integer().nullable()(); // days since epoch (local date), not ms
  TextColumn get reminderOffsets => text().withDefault(const Constant('[]'))(); // JSON [30, 7, 0]
  IntColumn get reminderMinuteOfDay => integer().nullable()(); // null = use the setting
  TextColumn get indexState => text().withDefault(const Constant('none'))();
  IntColumn get indexedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// P1 (FR-LIB-13).
@DataClassName('LibraryTagRow')
class LibraryTags extends Table {
  TextColumn get docId => text().references(LibraryDocuments, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text().withLength(min: 1, max: 30)();

  @override
  Set<Column<Object>> get primaryKey => {docId, tag};
}
