# DocuKit 1.5 — My Documents, Expiry Reminders, App Lock

> Conventions: `docs/FULL_PRODUCT.md` §4. Prefixes **FR-LIB / FR-REM / FR-LCK**, tasks **T12.x** (milestone M12), screens **S39–S46**, regressions **R59–R68**, ADRs **ADR-054–059**. Gate: 1.3 shipped (search uses OCR text from `TextRecognizer`).

---

## 1. Summary and scope

DocuKit 1.0–1.4 is a set of tools: results live in **Recent** for a limited time (7 days by default) and then disappear. Version 1.5 adds a place to **keep** documents: **My Documents**, a private library inside the app. Users can file their passport scan, certificates, insurance papers and payslips in folders, find them by searching their contents, get a reminder before the passport expires, and lock the library with their fingerprint or face.

**In scope**
- My Documents library: add from Result screens, Import, Scanner and Share-in; folders (max 3 levels); rename, move, delete, star; sort; grid/list; multi-select actions; "Open in tool…".
- Document detail: preview, info, name, notes, tags (P1), expiry date, reminders, actions.
- Search over names, notes, tags and recognised text (FTS5), with background OCR indexing.
- Expiry reminders: local notifications, "Expiring soon" on Library home and a Home card.
- Optional app lock (device biometrics/passcode) for My Documents.
- Storage used, ZIP export/import backup, backup exclusion by default.

**Out of scope (later)**
- Cloud sync, multi-device library, sharing folders with other people.
- Our own PIN/password vault and file-level encryption beyond what the OS provides (ADR-056).
- Editing documents in place (tools always create copies; the library keeps the result if the user saves it).
- Auto-detecting expiry dates from OCR text (P2 idea, §11).

**Key principles**
1. **Library files never leave the device** unless the user shares, saves or exports them.
2. **Library files are the user's**: they never auto-delete (unlike Recent).
3. Tools never modify a library file; "Open in tool" passes a **copy** (same rule as all inputs).
4. Reminders and the lock work fully offline.

---

## 2. Requirements

### 2.1 Library (FR-LIB)

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-LIB-01 | P0 | Library entry points | App-bar 📁 icon on Home, the "My Documents" card on Home, Settings → My Documents, and deep link `/library`; all open S40 (or S39 on first visit) |
| FR-LIB-02 | P0 | First-visit intro | S39 explains: files stay on this phone, aren't included in cloud backups by default, and are deleted if the app is uninstalled; [Get started] marks `lib_intro_seen` |
| FR-LIB-03 | P0 | Save from any Result | Every single-file Result screen (and each item in multi-output results) shows **Save to My Documents**; opens the folder picker (S43) with "My Documents" root preselected; the copy is made into the library; Snack "Saved to My Documents · View" |
| FR-LIB-04 | P0 | Import files | "+ Import" picks PDFs/images (JPG, PNG, WebP, HEIC) via the existing pickers; each is copied in; the same limits as tools (PDF ≤ 500 MB, image ≤ 100 MB); unsupported types refused with the standard copy |
| FR-LIB-05 | P0 | Add from Scanner and Share-in | The Scanner result offers Save to My Documents (default folder: "Scans", created on demand); S19 Incoming chooser gains a **Save to My Documents** row |
| FR-LIB-06 | P0 | Folders | Create, rename, delete folders; nesting ≤ 3 levels (root counts as level 0, so folder → subfolder → sub-subfolder); names 1–60 chars, unique per parent (case-insensitive); delete of a non-empty folder needs D2 with counts and offers "Move contents to parent" (default) or "Delete everything" |
| FR-LIB-07 | P0 | Rename, move, delete documents | Rename via D3 (extension shown, not editable); move via S43; delete via D2 ("Delete 'Passport.pdf'? This can't be undone.") with Undo snackbar for 5 s for single deletes |
| FR-LIB-08 | P0 | Star / favourite | Star toggle on tiles and detail; "Starred" filter chip on S40 |
| FR-LIB-09 | P0 | Sort and view | Sort: Name (A–Z), Date added (newest), Size (largest), Expiry (soonest; documents with no expiry last); Grid/List toggle; both remembered |
| FR-LIB-10 | P0 | Multi-select | Long-press enters selection; actions: Move, Delete, Share (system sheet, many files), Star, **Open in tool…** (filtered to compatible tools with the selection, e.g. 2+ PDFs → Merge; images → Images to PDF/Compress/Resize/Convert) |
| FR-LIB-11 | P0 | Open in tool | Copies the selected file(s) into the tool's job input dir (never passes the library path itself); the tool screen opens with inputs preloaded |
| FR-LIB-12 | P0 | Document detail (S42) | Preview (first page / image, tap → full viewer), name (editable), type, size, pages or dimensions, date added, folder, notes (≤ 2,000 chars), expiry, reminders; actions Share, Save to device, Open with, Open in tool…, Move, Delete |
| FR-LIB-13 | P1 | Tags | Free-text tags (≤ 10 per doc, ≤ 30 chars each), chip input with suggestions from existing tags; filter by tag on S40 |
| FR-LIB-14 | P0 | Search | One search field on S40 searches name, notes, tags and recognised text across all folders; results show the folder path and a highlighted snippet when the match is in recognised text; results update as you type (debounce 150 ms) |
| FR-LIB-15 | P0 | Make documents searchable | Setting "Make documents searchable" with two switches: **Scans** (default ON) and **Other PDFs and images** (default OFF) (ADR-055). When on, newly added docs are queued for OCR indexing; a per-document "Make searchable now" action exists regardless |
| FR-LIB-16 | P0 | Background indexing | One document at a time; resumable after app restart; paused when battery < 20% and not charging, or when the app is backgrounded on iOS; progress shown as "Indexing 3 of 12" in Library settings; documents that already contain text (vector PDFs) are indexed from their text layer without OCR |
| FR-LIB-17 | P0 | Storage used | Library settings show total size and document count; Settings → Storage used shows Recent and My Documents separately |
| FR-LIB-18 | P0 | Export library | Exports everything (or a selected folder) as a ZIP preserving folders, plus `docukit-library.json` (names, notes, tags, expiry, reminders); saved via the system Save dialog; progress + cancel |
| FR-LIB-19 | P0 | Import backup | Picks a DocuKit ZIP; validates `docukit-library.json` version; merges into the library; duplicates (same SHA-256) are skipped and counted; folder paths recreated; reminders re-scheduled |
| FR-LIB-20 | P0 | Backup exclusion | Library files are excluded from iCloud backup and Android Auto Backup by default (ADR-054); explained on S39 and S46 |
| FR-LIB-21 | P0 | Duplicate detection | On add, if a doc with the same SHA-256 exists, ask: "This file is already in My Documents (Folder/Name). Add another copy?" [Open existing] [Add copy] |
| FR-LIB-22 | P0 | No auto-delete | Library documents are never removed by the Recent retention sweep; Clear history never touches the library |
| FR-LIB-23 | P1 | Home card | Home shows a "My Documents" card with the 3 most recently added/opened docs and "Open library"; hidden when the library is empty or locked (shows a lock icon + "Unlock to view") |

### 2.2 Expiry reminders (FR-REM)

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-REM-01 | P0 | Expiry date | Any document can have an expiry date (date only, local calendar); quick presets in S44: "1 year from today", "5 years", "10 years", or a date picker |
| FR-REM-02 | P0 | Reminder offsets | Multi-select: 30 days before, 7 days before, 1 day before, on the day; default selection 30 + 7 + on the day; fire time 09:00 local (setting: 08:00–21:00) |
| FR-REM-03 | P0 | Permission on first use | Notification permission is requested only when the user saves the first reminder (Android 13+ `POST_NOTIFICATIONS`; iOS authorization). If denied: the expiry date is still saved, reminders show "Off — notifications are blocked" with [Open Settings] |
| FR-REM-04 | P0 | Expiring soon | S40 shows "Expiring soon" (expired + next 60 days, soonest first, expired in red with "Expired 3 days ago"); Home card shows the nearest one when within 30 days |
| FR-REM-05 | P0 | Notification privacy | Default text is generic: title "Document expiring", body "A document expires in 7 days." Setting "Show document names in reminders" (default OFF) switches to "Passport.pdf expires in 7 days" |
| FR-REM-06 | P0 | Tap to open | Tapping a notification opens `/library/doc/:id` (through the app lock if enabled); if the doc was deleted, opens S40 with snackbar "That document is no longer in My Documents" |
| FR-REM-07 | P0 | Reliable scheduling | Reminders survive app restart, device reboot, app update and time-zone change; past offsets are skipped (never fire a backlog); changing/removing expiry cancels old notifications |
| FR-REM-08 | P0 | iOS 64 limit | iOS keeps at most 64 pending local notifications per app; DocuKit schedules only the **nearest 60** across all docs and tops up on every app launch/resume and after each change |
| FR-REM-09 | P1 | Snooze | Notification action "Remind me tomorrow" (Android action button; iOS category action) schedules a one-off for +1 day 09:00 |
| FR-REM-10 | P0 | Deleted/exported docs | Deleting a doc cancels its notifications; importing a backup re-schedules reminders for future dates only |

### 2.3 App lock (FR-LCK)

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-LCK-01 | P0 | Optional lock | Library settings → "Lock My Documents" switch (default OFF). Turning it on requires one successful authentication |
| FR-LCK-02 | P0 | Device credentials only | Uses biometrics with the device PIN/pattern/passcode as fallback via `local_auth`; DocuKit stores no PIN or password of its own (ADR-056). If the device has no screen lock, the switch is disabled with "Set up a screen lock on your phone first" + [Open Settings] |
| FR-LCK-03 | P0 | What's locked | Default scope: **My Documents only** (S40–S46, Home "My Documents" card, reminders' deep links, library search). Option: "Lock the whole app" (ADR-057). Tools, Recent and Settings stay open in Library-only mode |
| FR-LCK-04 | P0 | Re-lock timing | Lock after leaving the app for: Immediately / 1 minute (default) / 5 minutes; also on device screen-off longer than the timeout; locked state survives process death (always locked on cold start) |
| FR-LCK-05 | P0 | App-switcher privacy | When locked scope is active, the app-switcher snapshot is blurred/covered: iOS overlay on `sceneWillResignActive`; Android `FLAG_SECURE` on library routes **only when** "Hide in recent apps" is ON (default ON with the lock; tooltip: also blocks screenshots on those screens) |
| FR-LCK-06 | P0 | Lock screen (S45) | Shows the app logo, "My Documents is locked", [Unlock]; auto-prompts biometrics once on appear; failure → stays locked with retry; cancel → back to Home (Library-only scope) or stays (whole-app scope); no ads |
| FR-LCK-07 | P0 | Changing biometrics | If authentication becomes unavailable (biometrics removed, no screen lock), the user can still unlock with the device passcode; if no credential exists at all, show "Your phone's screen lock was removed" and require turning the lock off (one confirmation) — documents are never made inaccessible by the lock |
| FR-LCK-08 | P0 | Notifications respect the lock | When locked, notification taps go to S45 first, then the document |

---

## 3. Screens

All library screens use `ToolScaffold`-style app bars, the design tokens and the `library` category gradient (`FULL_PRODUCT.md` §4.5). Bottom banners follow §4.4.

### S39 · Library intro / empty state (`/library`, first visit)

```
┌──────────────────────────────────────┐
│ ←  My Documents                       │
├──────────────────────────────────────┤
│        [illustration: folder+lock]    │
│  Keep important documents here        │  headlineSmall
│  • Stored only on this phone          │  bodyLarge, 3 bullets with icons
│  • Not included in cloud backups      │
│    (you can export a backup anytime)  │
│  • Deleted if you uninstall DocuKit   │
│                                       │
│  [        Get started        ]        │  FilledButton → sets lib_intro_seen
│  Learn about backups ›                │  → S46 backup section
├──────────────────────────────────────┤
│ [ banner ADMOB_BANNER_MAIN ]          │
└──────────────────────────────────────┘
```
After the intro, an **empty library** shows: illustration, "No documents yet", buttons [Import files] [Scan a document] and the hint "Tip: tap 'Save to My Documents' on any result."

### S40 · Library home (`/library`)

```
┌──────────────────────────────────────┐
│ ←  My Documents        🔍  ⋮          │  ⋮: Sort, Grid/List, Select, Library settings
├──────────────────────────────────────┤
│ [🔍 Search names, notes and text…]    │  search field (expands into results mode)
│ [All] [★ Starred] [#tags ▾]           │  filter chips
│ EXPIRING SOON  (sentence case header) │  section, hidden if none
│ ┌──────────────────────────────────┐ │
│ │ 🛂 Passport.pdf   Expires in 12 d │ │  ExpiryRow: amber ≤30 d, red if expired
│ │ 🚗 Licence.jpg    Expired 3 d ago │ │
│ └──────────────────────────────────┘ │
│ Folders                               │
│ [📁 IDs (4)] [📁 Bills (12)] [📁 Scans]│  FolderTile grid / list
│ Documents                             │
│ ┌────┐ ┌────┐ ┌────┐                  │  DocTile: thumbnail, name (middle-ellipsis),
│ │thumb│ │thumb│ │thumb│                │  meta (size · date), ★, expiry badge
│ └────┘ └────┘ └────┘                  │
│ ...                                   │
│ ┌─ Ad ──────────────────────────────┐ │  native in-feed card after the 5th item
│ └───────────────────────────────────┘ │  (ADMOB_NATIVE_HISTORY), list/grid both
│                                [+]    │  FAB: Import files · Scan · New folder
├──────────────────────────────────────┤
│ [ banner ADMOB_BANNER_MAIN ]          │
└──────────────────────────────────────┘
```
- **Search mode:** results list mixing folders and documents; each doc row shows the folder path ("IDs › Travel") and, if matched in recognised text, a snippet with the match in bold (`snippet()` from FTS5). Empty: "No documents match 'xyz'."
- **Selection mode:** top bar shows "3 selected" with actions Move · Share · Star · Delete · ⋮ Open in tool…; the FAB hides; the native ad card stays but is excluded from selection.
- **FAB placement:** the FAB sits above the bottom banner with ≥ 24 dp gap (same rule as tool buttons).
- **States:** loading (skeleton tiles ≤ 300 ms), empty (S39 empty state), locked (S45), indexing (subtle "Making 3 documents searchable…" line under the search field, tap → S46), storage low on import (standard insufficientStorage error).

### S41 · Folder view (`/library/folder/:id`)

```
←  IDs › Travel                ⋮        breadcrumb title (tap a segment to jump up)
[🔍 Search in this folder…]
Folders (subfolders, hidden at level 3 — "New folder" disabled with tooltip "Folders can be 3 levels deep")
Documents (same tiles, sort, selection as S40)
+ FAB: Import here · Scan here · New folder
[ banner ADMOB_BANNER_MAIN ]
```
Folder ⋮: Rename, Move, Export folder as ZIP, Delete folder. Native in-feed card rule as S40 (after the 5th item, only when ≥ 6 items).

### S42 · Document detail (`/library/doc/:id`)

```
┌──────────────────────────────────────┐
│ ←                         ★   ⋮       │  ⋮: Rename, Move, Make searchable now, Delete
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │   [preview: page 1 / image]       │ │  tap → full viewer (pdfrx viewer / InteractiveViewer)
│ └──────────────────────────────────┘ │
│ Passport.pdf                     ✎    │  titleLarge; D3 rename
│ PDF · 2 pages · 1.4 MB · Added 12 Oct │
│ Folder: IDs › Travel            Move ›│
│ ─────────────────────────────────── │
│ Expires   15 Mar 2031     Change ›    │  opens S44
│ Reminders 30 d, 7 d before, on the day│
│ ─────────────────────────────────── │
│ Notes                                 │
│ [ Passport number on page 2…      ]   │  multiline, autosave (debounce 600 ms)
│ Tags  [travel] [id] [+ Add]     (P1)  │
│ Searchable ✓ Text recognised          │  or "Not searchable · Make searchable"
│ ─────────────────────────────────── │
│ [ Share ] [ Save to device ]          │
│ [ Open with… ] [ Open in tool… ]      │
├──────────────────────────────────────┤
│ [ banner ADMOB_BANNER_MAIN ]          │
└──────────────────────────────────────┘
```
- **Open in tool…** sheet: compatible tools only (from `toolCatalog` input kinds); selecting copies the file into a new job draft and opens the tool.
- **Missing file** (file deleted outside the app, e.g. storage corruption): preview shows "File missing", actions disabled except Delete; metadata kept until deleted.
- **Full viewer:** no ads (full-screen viewer, same rule as page preview).

### S43 · Move / folder picker (bottom sheet)

```
Move 3 items to…                         ✕
[🔍 Find folder]
📁 My Documents (root)                 ●
  📁 IDs                               ○
    📁 Travel                          ○
  📁 Bills                             ○
[+ New folder]
[ Cancel ]            [ Move here ]
```
Tree view, expandable; disabled targets: the item's current folder (for a single item), a folder into itself or its own descendants, and any target that would exceed 3 levels. Used for Save to My Documents (title "Save to…", button "Save here"). No ads (sheet).

### S44 · Expiry & reminders (bottom sheet)

```
Expiry date                               ✕
[ 15 Mar 2031          📅 ]
Quick: [1 year] [5 years] [10 years] [No expiry]
Remind me
 ☑ 30 days before   ☑ 7 days before
 ☐ 1 day before     ☑ On the day
At 09:00 ›  (time picker; default from settings)
Next reminder: 13 Feb 2031, 09:00
[ Remove expiry ]           [ Save ]
```
- First save with reminders → permission request (FR-REM-03). If denied: inline banner "Notifications are blocked, so reminders won't appear. [Open Settings]"; the expiry still saves.
- Dates in the past are allowed (marks the document Expired); reminders for past offsets aren't scheduled.
- No ads (sheet).

### S45 · App lock screen

```
┌──────────────────────────────────────┐
│                                      │
│            [DocuKit logo]             │
│      My Documents is locked           │
│  Use your fingerprint, face or        │
│  screen lock to continue.             │
│        [   🔓 Unlock   ]              │
│        Back to Home                    │  (Library-only scope)
└──────────────────────────────────────┘
```
Shown as a full-screen route above locked routes. Auto-triggers `authenticate` once when shown (not again on failure, to avoid loops). **No ads, no banner.** Semantics: focus on [Unlock]; announces "My Documents is locked".

### S46 · Library settings (`/settings/library`)

```
←  My Documents settings
Make documents searchable
  Scans                                  [on]
  Other PDFs and images                  [off]
  Status: 2 waiting · Indexing paused (low battery)   [Pause/Resume]
Reminders
  Reminder time                          09:00 ›
  Show document names in reminders       [off]
  Notifications                          Allowed ✓ / Blocked [Open Settings]
Lock
  Lock My Documents                      [off]
  What to lock         My Documents only ›  (or Whole app)
  Lock after leaving   1 minute ›
  Hide in recent apps                    [on]  (Android: also blocks screenshots)
Storage and backup
  My Documents uses   214 MB · 37 documents
  Export library (ZIP)                   ›
  Import backup (ZIP)                    ›
  ⓘ My Documents isn't included in iCloud or Google backups. Export a backup before
    changing or resetting your phone. Uninstalling DocuKit deletes these documents.
[ banner ADMOB_BANNER_SETTINGS ]   (it's a Settings sub-page; same unit as Settings)
```

### 3.1 Changes to existing screens
| Screen | Change |
|---|---|
| S01 Home | App-bar 📁 icon; "My Documents" card (FR-LIB-23); "Expiring soon" mini-row inside the card when ≤ 30 days |
| S11 Result (and 1.1 multi-result) | **Save to My Documents** button in the secondary action group (2×2 grid becomes 2×3 on phones) |
| S16 Settings | New row "My Documents" → S46; Storage used shows Recent and My Documents separately |
| S19 Incoming | "Save to My Documents" row above the tool list |
| Scanner result (1.2) | "Save to My Documents" (default folder "Scans") |
| S17 Privacy & About | New section "My Documents and reminders" (copy §7) |

### 3.2 Ad placement summary
| Screen | Bottom banner | Native card | Notes |
|---|---|---|---|
| S39 intro/empty | MAIN | — | |
| S40 Library home | MAIN | after 5th item (`ADMOB_NATIVE_HISTORY`) | never two native cards visible; hidden while locked |
| S41 Folder view | MAIN | after 5th item when ≥ 6 items | |
| S42 Document detail | MAIN | — | |
| S43, S44 sheets | — | — | sheets never have ads |
| S45 Lock | — | — | **no ads** |
| S46 Library settings | SETTINGS | — | |
| Full viewer | — | — | full-screen viewer |

### 3.3 Platform notes
- **iOS:** document preview uses pdfrx (consistent with the app), not Quick Look; Face ID requires `NSFaceIDUsageDescription`; the resign-active overlay is a plain colour + logo view installed by `docukit_native`.
- **Android:** `FLAG_SECURE` toggled per route via `docukit_native.setSecure(bool)` (verify there's no existing plugin need); predictive back from S45 = "Back to Home" in Library-only scope.
- **Tablets:** S40 two-pane at ≥ 840 dp (folder tree left, contents right); S42 opens as a right-hand pane.

---

## 4. Implementation

### 4.1 Packages

| Package | Licence | Purpose | Notes |
|---|---|---|---|
| `flutter_local_notifications` | BSD-3 | Local notifications, scheduling, actions | **verify** current major version and API names (`zonedSchedule`, `AndroidScheduleMode.inexactAllowWhileIdle`, `DarwinNotificationCategory`); Android needs desugaring (`coreLibraryDesugaringEnabled`) — verify |
| `timezone` + `flutter_timezone` | BSD-2 / Apache-2.0 | `TZDateTime` for zoned scheduling; read the device zone | **verify** `flutter_timezone` maintenance; alternative: native call in `docukit_native` |
| `local_auth` | BSD-3 | Biometrics / device credential | Android: `FlutterFragmentActivity` required as MainActivity base (**verify** current requirement); iOS `NSFaceIDUsageDescription` |
| `archive` | MIT | ZIP export/import | already added in 1.1 (`ZipBuilder`); use streaming `ZipFileEncoder` for large libraries (**verify** API) |
| `crypto` | BSD-3 | SHA-256 for duplicates | already a dev dependency → move to dependencies |
| drift FTS5 | (drift, MIT) | Full-text search | SQLite build must include FTS5: `sqlite3_flutter_libs` bundles it (**verify**) |

No new network-capable packages. CI ads-import check unaffected.

### 4.2 File layout

```
appSupport/
  outputs/<jobId>/...            (Recent, retention-managed — unchanged)
  library/
    <docId>/<safeFileName>       one folder per document (uuid v7), original extension
    _thumbs/<docId>.jpg          256 px longest edge, regenerated if missing
    _import_tmp/                 import staging; swept at launch
```
- Folders are **virtual** (DB rows), not directories: moves are DB updates only, so they're instant and atomic.
- `excludedFromBackup`: iOS — set `isExcludedFromBackup = true` on `library/` (and re-apply at launch, since restored or newly created dirs may lose it); file protection `completeUntilFirstUserAuthentication`. Android — `android:fullBackupContent` / `dataExtractionRules` (Android 12+) exclude `files/library/` and the DB's library tables can't be separated, so **exclude the whole app database from Auto Backup** too (history is device-local anyway) (ADR-054).
- Adding a document: copy source → `library/<docId>/<name>.part` → fsync → rename to final name → insert DB row in the same transaction as the FTS row; on any failure delete the `.part`.

### 4.3 Data model (drift) — schema migration v(N) → v(N+1)

```dart
class LibraryFolders extends Table {
  TextColumn get id => text()();                         // uuid v7
  TextColumn get parentId => text().nullable().references(LibraryFolders, #id)(); // null = root
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn  get depth => integer()();                   // 1..3
  IntColumn  get createdAt => integer()();
  IntColumn  get sortIndex => integer().withDefault(const Constant(0))();
  @override Set<Column> get primaryKey => {id};
}

class LibraryDocuments extends Table {
  TextColumn get id => text()();                         // uuid v7 (= folder name on disk)
  TextColumn get folderId => text().nullable().references(LibraryFolders, #id)();
  TextColumn get name => text()();                       // display name incl. extension
  TextColumn get relPath => text()();                    // 'library/<id>/<file>'
  TextColumn get mime => text()();
  IntColumn  get sizeBytes => integer()();
  IntColumn  get pageCount => integer().nullable()();
  IntColumn  get width => integer().nullable()();
  IntColumn  get height => integer().nullable()();
  TextColumn get sha256 => text()();                     // hex; index
  TextColumn get source => text()();                     // result|import|scan|incoming|backup
  TextColumn get sourceTool => textEnum<ToolId>().nullable()();
  IntColumn  get addedAt => integer()();
  IntColumn  get openedAt => integer().nullable()();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn  get expiryDate => integer().nullable()();   // days since epoch (local date), not ms
  TextColumn get reminderOffsets => text().withDefault(const Constant('[]'))(); // JSON [30,7,0]
  IntColumn  get reminderMinuteOfDay => integer().nullable()(); // null = use setting
  TextColumn get indexState => text().withDefault(const Constant('none'))();
     // none|queued|indexing|done|failed|notNeeded
  IntColumn  get indexedAt => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}

class LibraryTags extends Table {                        // P1
  TextColumn get docId => text().references(LibraryDocuments, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text().withLength(min: 1, max: 30)();
  @override Set<Column> get primaryKey => {docId, tag};
}
```

FTS5 virtual table (created in the migration with `customStatement`, **verify** drift's recommended FTS pattern):
```sql
CREATE VIRTUAL TABLE library_fts USING fts5(
  doc_id UNINDEXED, name, notes, tags, body,
  tokenize = 'unicode61 remove_diacritics 2'
);
```
- `body` = recognised/extracted text, capped at 200,000 characters per document (keep the first 200k; record truncation).
- Keep `library_fts` in sync inside repository transactions (not triggers, so the body text can be written separately by the indexer).
- Query: user input → tokens → each token quoted and suffixed with `*` (prefix match): `"pass"* "port"*`; rank with `bm25(library_fts, 0, 10, 4, 6, 1)` (name weighted highest); snippets via `snippet(library_fts, 4, '[', ']', '…', 12)` → rendered bold in UI (brackets replaced, never shown raw).
- Indexes: `library_documents(folderId)`, `(sha256)`, `(expiryDate)`, `(addedAt DESC)`.

**Migration:** bump the drift `schemaVersion` by one; `onUpgrade` creates the three tables, the FTS table and indexes. No changes to `operations`. Commit a new schema snapshot; migration test from every previous snapshot.

Deleting a folder with "Delete everything": delete documents (files + rows + fts rows + notifications) depth-first in one transaction, then files after commit (a launch sweep deletes orphan `library/<id>` dirs with no row).

### 4.4 LibraryRepository

```dart
abstract interface class LibraryRepository {
  // Folders
  Stream<List<LibraryFolder>> watchFolders({String? parentId});
  Future<LibraryFolder> createFolder(String name, {String? parentId});   // throws depth/dup errors
  Future<void> renameFolder(String id, String name);
  Future<void> moveFolder(String id, String? newParentId);
  Future<FolderDeleteSummary> deleteFolder(String id, {required FolderDeleteMode mode});

  // Documents
  Stream<List<LibraryDoc>> watchDocs({String? folderId, LibraryFilter filter, LibrarySort sort});
  Stream<List<LibraryDoc>> watchExpiringSoon({int days = 60});
  Future<LibraryDoc?> get(String id);
  Future<AddResult> addFile(String sourcePath, {required String displayName, String? folderId,
      required DocSource source, ToolId? sourceTool, bool allowDuplicate = false});
      // AddResult: added(doc) | duplicate(existing) | failed(AppError)
  Future<void> rename(String id, String name);
  Future<void> move(List<String> ids, String? folderId);
  Future<void> setStarred(List<String> ids, bool starred);
  Future<void> setNotes(String id, String notes);
  Future<void> setTags(String id, List<String> tags);                    // P1
  Future<void> setExpiry(String id, LocalDate? date, List<int> offsets, int? minuteOfDay);
  Future<void> delete(List<String> ids);
  Future<String> copyForTool(String id, Directory jobInDir);             // returns the copy path

  // Search & index
  Stream<List<SearchHit>> search(String query, {String? folderId});
  Future<void> setIndexedText(String id, String text, {required IndexState state});

  // Storage & backup
  Future<LibraryStats> stats();
  Future<void> exportZip(String outPath, {String? folderId, required JobContext ctx});
  Future<ImportSummary> importZip(String zipPath, {required JobContext ctx});
}
```
All writes emit a `LibraryChanged` event the reminder scheduler and indexer listen to. Every method is unit-tested against an in-memory DB + temp directory.

### 4.5 Adding documents (flows)

```
saveFromResult(outputPath, displayName):
  folder = await showFolderPicker(S43, mode: save)    # null → cancelled
  r = repo.addFile(outputPath, displayName, folderId: folder, source: result, sourceTool)
  if r is duplicate → dialog FR-LIB-21 → Open existing | Add copy (allowDuplicate: true)
  if r is added → snack "Saved to My Documents · View"; enqueue indexing per §4.6 policy
import(files) → same, source: import, one by one with Determinate progress for > 1 file
```
SHA-256 computed while copying (stream through `crypto` sha256 sink) — no second read.

### 4.6 Background indexing queue (OCR)

Policy (ADR-055):
| Source | Default |
|---|---|
| scan | queue OCR (setting "Scans" default ON) |
| result/import/incoming/backup, image or PDF | queue only if "Other PDFs and images" ON |
| any PDF with an existing text layer | always index its text **without OCR** (cheap) → `indexState = done` |
| Manual "Make searchable now" | always queue at the front |

```
IndexQueue (single worker, app process only):
  start on app launch (after first frame + 5 s) and on LibraryChanged(added)
  loop:
    if paused(user) or battery < 20% && !charging (battery_plus? → prefer docukit_native.batteryState) → wait for change
    if a tool job is running (JobRunner busy) → wait (never compete with user work)
    doc = next where indexState in (queued) order by manual-first, addedAt asc
    mark indexing
    text = isPdf ? extractTextLayer(doc) (pdfrx page text, verify API) : ''
    if text.trim().length < 40 (likely image-only) && ocrAllowed:
        for each page/image (render page at 200 dpi via pdfrx; images direct):
           text += TextRecognizer.recognize(pageImage).text + '\n'
           yield between pages; check pause/cancel; persist progress (pageDone) for resume
    repo.setIndexedText(doc.id, text.cap(200k), state: done)
    on error → state failed (retry once on next launch; then manual only)
iOS: the worker stops when the app goes to background (no background tasks for indexing);
     it resumes on foreground. Android: same (no WorkManager in 1.5 — ADR-058).
```
`TextRecognizer` is the 1.3 interface (`core/ocr/`). Respect its script setting. Never log text.

### 4.7 Reminder scheduling

Notification IDs: deterministic 31-bit int from `hash(docId + offset)` with collision check (store mapping in `reminder_ids` table or compute + verify uniqueness in the pending list).

```
ReminderScheduler.reconcile(now):                     # called on: launch, resume, LibraryChanged, tz change,
  if !notificationsAllowed → cancel all ours; return  #            permission change, boot (plugin reschedules), settings change
  wanted = []
  for doc in docs where expiryDate != null:
     for off in doc.offsets:
        fire = localDate(doc.expiryDate) - off days @ (doc.minute ?? setting.minute) in tz.local
        if fire > now + 60 s: wanted.add((doc, off, fire))
  wanted.sortBy(fire)
  limit = Platform.isIOS ? 60 : 500                   # iOS hard limit 64 pending; leave headroom for snoozes
  wanted = wanted.take(limit)
  pending = plugin.pendingNotificationRequests()     # only our 'rem:' payloads
  cancel pending not in wanted; schedule wanted not in pending
     zonedSchedule(id, title, body, TZDateTime, details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,   # verify enum name
        payload: 'rem:<docId>')
```
- **Text:** generic unless "Show document names" ON; days computed at fire time are fixed in the scheduled text, so reconcile reschedules when the setting changes.
- **Channel (Android):** `doc_reminders`, importance default, name "Document reminders", description "Reminders before documents expire".
- **Reboot:** the plugin's boot receiver reschedules **verify**; also reconcile on next launch regardless.
- **Time-zone change:** listen via `docukit_native` (Android `ACTION_TIMEZONE_CHANGED` → event; iOS `NSSystemTimeZoneDidChange`) and on every resume compare `tz.local` with the stored zone.
- **Inexact delivery:** Android may deliver within a window; acceptable for day-level reminders; copy never promises an exact minute.
- **Tap handling:** `onDidReceiveNotificationResponse` + `getNotificationAppLaunchDetails` on cold start → route `/library/doc/:id` through the lock guard. Snooze action (P1) → reconcile with an extra one-off entry stored in `reminder_snoozes`.

### 4.8 App-lock state machine **[unit]**

```
States: Disabled | Locked | Unlocking | Unlocked(since) 
Events: enable(authOk) | disable(authOk) | appBackground(t) | appForeground(t) | coldStart | authSuccess | authFail | routeEnter(lockedRoute)

coldStart → enabled ? Locked : Disabled
appBackground(t) → remember bgAt = t; if timeout == immediate → Locked
appForeground(t) → if Unlocked && t - bgAt >= timeout → Locked
routeEnter(lockedRoute) && Locked → push S45 (guard via go_router redirect)
S45 shown → Unlocking → local_auth.authenticate(biometricOnly: false, stickyAuth: true — verify option names)
   success → Unlocked(now) → continue to target route
   fail/cancel → Locked (no auto-retry loop)
```
- go_router `redirect` checks `lockController.isLocked && route.isLockScoped` → `/lock?next=<encoded>`. `next` is validated against the route table (no open redirect).
- Lock scope: Library-only (routes `/library*`, `/settings/library`, Home card hidden content) or Whole app (all routes except `/lock`, `/onboarding`).
- **Interaction with system flows:** returning from the system picker/share sheet/save dialog/purchase/consent does **not** count as leaving the app (same flag as the app-open-ad rule in ADS.md §4.2).
- **Snapshot cover:** iOS `docukit_native` adds an overlay window on `willResignActive` when `lockEnabled` (any scope), removes it on `didBecomeActive`; Android `setSecure(true)` while a lock-scoped route is visible and "Hide in recent apps" is ON.
- **No custom credential storage:** we store only `lock_enabled`, `lock_scope`, `lock_timeout`, `lock_hide_recents` booleans/enums in settings.

### 4.9 Export / import backup

**Export:** stream entries with `ZipFileEncoder` (verify) to a temp file in `cache/jobs/<id>/work`, then system Save dialog (`FileGateway.saveAs`). Layout:
```
DocuKit-Backup-20261028/
  docukit-library.json        {"format":"docukit-library","version":1,"exportedAt":...,
                               "folders":[{id,parentId,name}], "documents":[{id,folderId,name,file,
                               sha256,notes,tags,expiryDate,reminderOffsets,starred,addedAt}]}
  files/IDs/Travel/Passport.pdf      (human-readable paths; name collisions get " (2)")
```
Recognised text is **not** exported (re-indexed after import) — keeps backups smaller and avoids duplicating content.

**Import:** validate JSON (`format`, `version ≤ 1`), stream-extract to `library/_import_tmp/`, verify each file's SHA-256 against the manifest (mismatch → skip + count), recreate folders (merge by path + name, respecting depth), skip docs whose SHA-256 already exists, insert rows, queue indexing per policy, reconcile reminders. Summary dialog: "Imported 34 · Skipped 3 duplicates · 1 damaged file". Storage pre-check: free ≥ uncompressed size + 50 MB.

### 4.10 Deep links and routes

| Route | Screen | Lock-scoped |
|---|---|---|
| `/library` | S39/S40 | yes |
| `/library/folder/:id` | S41 | yes |
| `/library/doc/:id` | S42 | yes |
| `/settings/library` | S46 | yes |
| `/lock?next=` | S45 | — |
Unknown ids → `/library` with snackbar "That item is no longer in My Documents."

### 4.11 Folder layout (`lib/`)
```
lib/features/library/
  application/ library_controller.dart, folder_controller.dart, doc_detail_controller.dart,
               search_controller.dart, index_queue.dart, reminder_scheduler.dart
  presentation/ library_intro_screen.dart, library_home_screen.dart, folder_screen.dart,
                doc_detail_screen.dart, folder_picker_sheet.dart, expiry_sheet.dart,
                library_settings_screen.dart, widgets/ (doc_tile, folder_tile, expiry_row, ...)
lib/features/lock/ lock_controller.dart, lock_screen.dart, lock_guard.dart
lib/data/library/ library_repository.dart, library_repository_impl.dart, library_tables.dart, fts.dart
lib/core/notifications/ notification_service.dart (interface + impl)
packages/docukit_native: + setSecure, privacy overlay, timezoneChanged stream, batteryState
```

---

## 5. Data model and settings keys

New drift tables: `library_folders`, `library_documents`, `library_tags` (P1), `library_fts` (FTS5), `reminder_snoozes` (P1). Schema version +1.

| Settings key | Type | Default |
|---|---|---|
| `lib_intro_seen` | bool | false |
| `lib_view` | `grid|list` | grid |
| `lib_sort` | `name|added|size|expiry` | added |
| `lib_index_scans` | bool | true |
| `lib_index_other` | bool | false |
| `lib_index_paused` | bool | false |
| `rem_minute_of_day` | int | 540 (09:00) |
| `rem_show_names` | bool | false |
| `rem_last_tz` | string | device zone |
| `lock_enabled` | bool | false |
| `lock_scope` | `library|app` | library |
| `lock_timeout` | `immediate|m1|m5` | m1 |
| `lock_hide_recents` | bool | true |
| `home_lib_card` | bool | true |

---

## 6. Permissions, privacy and store impact

| Item | Android | iOS |
|---|---|---|
| Notifications | `POST_NOTIFICATIONS` (13+), runtime request on first reminder | Authorization request on first reminder |
| Boot reschedule | `RECEIVE_BOOT_COMPLETED` (added by the plugin — verify manifest merge) | — |
| Biometrics | `USE_BIOMETRIC` (merged by `local_auth`) | `NSFaceIDUsageDescription` = "DocuKit uses Face ID to unlock My Documents." |
| Exact alarms | **Not used** (inexact scheduling; no `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`) | — |
| Backup | `dataExtractionRules` / `fullBackupContent` exclude library + DB | `isExcludedFromBackup` on `library/` |
| Privacy manifest | — | Re-check required-reason APIs (file timestamps already declared; UserDefaults already) |

**Play Data safety / App Store label:** no new data collection — documents, notes, tags, OCR text and reminders stay on the device. **Privacy policy additions:** "If you save documents to My Documents, they're stored only on your device, aren't included in cloud backups, and are deleted when you delete them or uninstall DocuKit. Reminders are local notifications created on your device."

**Store listing:** add "Keep your documents in folders, find them by searching their text, and get reminders before they expire" to the description; one new screenshot (Library with Expiring soon — no ads, no real personal documents).

---

## 7. Copy

| Key | Text |
|---|---|
| lib_title | My Documents |
| lib_intro_title | Keep important documents here |
| lib_intro_b1 | Stored only on this phone |
| lib_intro_b2 | Not included in cloud backups. You can export a backup anytime. |
| lib_intro_b3 | Deleted if you uninstall DocuKit |
| lib_intro_cta | Get started |
| lib_intro_backup_link | Learn about backups |
| lib_empty_title / body | No documents yet / Tip: tap "Save to My Documents" on any result. |
| lib_import / scan / new_folder | Import files / Scan a document / New folder |
| lib_search_hint | Search names, notes and text |
| lib_filter_all / starred | All / Starred |
| lib_section_expiring / folders / documents | Expiring soon / Folders / Documents |
| lib_expires_in | Expires in {days, plural, =0{today} =1{1 day} other{# days}} |
| lib_expired_ago | Expired {days, plural, =0{today} =1{1 day ago} other{# days ago}} |
| lib_save_to | Save to My Documents |
| lib_saved_snack / view | Saved to My Documents / View |
| lib_dup_title / body | Already in My Documents / This file is already saved as {name} in {folder}. Add another copy? |
| lib_dup_open / add | Open existing / Add copy |
| lib_move_title / here / save_here | Move {count, plural, =1{1 item} other{# items}} to… / Move here / Save here |
| lib_root | My Documents |
| lib_folder_depth | Folders can be 3 levels deep |
| lib_folder_name_taken | A folder with this name already exists here |
| lib_delete_doc_title / body | Delete "{name}"? / This can't be undone. |
| lib_delete_folder_title | Delete folder "{name}"? |
| lib_delete_folder_body | It contains {docs} documents and {folders} folders. |
| lib_delete_folder_move / all | Move contents up / Delete everything |
| lib_open_in_tool | Open in tool… |
| lib_notes_hint | Add notes (only you can see them) |
| lib_searchable_yes / no / now | Searchable · Text recognised / Not searchable / Make searchable now |
| lib_indexing | Making {count} documents searchable… |
| lib_index_paused_battery | Paused while the battery is low |
| lib_file_missing | File missing |
| lib_gone | That document is no longer in My Documents. |
| rem_title / quick_1y / 5y / 10y / none | Expiry date / 1 year / 5 years / 10 years / No expiry |
| rem_remind_me / d30 / d7 / d1 / d0 | Remind me / 30 days before / 7 days before / 1 day before / On the day |
| rem_at_time | At {time} |
| rem_next | Next reminder: {date} |
| rem_remove | Remove expiry |
| rem_blocked | Notifications are blocked, so reminders won't appear. |
| rem_notif_title | Document expiring |
| rem_notif_body_generic | A document expires {days, plural, =0{today} =1{tomorrow} other{in # days}}. |
| rem_notif_body_named | {name} expires {days, plural, =0{today} =1{tomorrow} other{in # days}}. |
| rem_snooze | Remind me tomorrow |
| rem_channel_name / desc | Document reminders / Reminders before documents expire |
| lck_title / body | My Documents is locked / Use your fingerprint, face or screen lock to continue. |
| lck_unlock / back_home | Unlock / Back to Home |
| lck_reason | Unlock My Documents |
| lck_no_screen_lock | Set up a screen lock on your phone first. |
| lck_removed | Your phone's screen lock was removed. Turn off the DocuKit lock to keep using My Documents. |
| set_lib_* | My Documents settings / Make documents searchable / Scans / Other PDFs and images / Reminder time / Show document names in reminders / Lock My Documents / What to lock / My Documents only / Whole app / Lock after leaving / Immediately / 1 minute / 5 minutes / Hide in recent apps / Also blocks screenshots on these screens / Export library / Import backup |
| set_lib_backup_note | My Documents isn't included in iCloud or Google backups. Export a backup before changing or resetting your phone. Uninstalling DocuKit deletes these documents. |
| exp_done / imp_summary | Library exported / Imported {added} · Skipped {dups} duplicates{bad, plural, =0{} =1{ · 1 damaged file} other{ · # damaged files}} |
| priv_lib_h / p | My Documents and reminders / Documents you save to My Documents stay on this phone. They aren't included in cloud backups and are deleted if you uninstall DocuKit. Reminders are notifications created on your phone. |

---

## 8. Tests

| Area | Tests | Type |
|---|---|---|
| Migration | From every committed schema snapshot to the new version; existing `operations` rows intact; FTS table exists | Unit (drift `SchemaVerifier`) |
| Repository | add (copy, hash, `.part` cleanup on failure), duplicate detection, rename uniqueness, move (incl. invalid targets), folder depth limits, delete modes (move up / delete all), orphan sweep, copyForTool returns a new path | Unit (in-memory DB + temp dir) |
| FTS search | prefix matching, diacritics ("cafe" finds "café"), ranking (name > notes > body), snippet bracket rendering, folder-scoped search, deleted doc disappears from results | Unit |
| Index queue | ordering (manual first), resume after "process death" (state persisted), pause on low battery (fake battery), waits while a job runs, text-layer PDFs skip OCR, 200k cap, failure → retry once | Unit (fake TextRecognizer, fake clock) |
| Reminder scheduler | fire-time computation across DST boundaries and time zones (Europe/London, America/New_York, Asia/Kolkata), past offsets skipped, iOS limit 60 nearest, reconcile cancels/adds correctly, names setting changes text, permission denied → nothing scheduled | Unit (fake clock + fake plugin) |
| Lock state machine | all transitions in §4.8, timeout values, cold start locked, system-flow returns don't lock, redirect `next` validation | Unit |
| Backup | export → import round-trip equals original (names, folders, notes, tags, expiry, starred); duplicates skipped; corrupted file skipped and counted; version > 1 refused; storage pre-check | Unit + integration |
| Screens | S39–S46 states (empty, loading, populated, search results, selection mode, locked), 200% text, dark mode, tablet two-pane | Widget + golden |
| Ads | banner on S39–S42 (MAIN), S46 (SETTINGS); native card after 5th item only when ≥ 6 items; none on S43–S45 or full viewer; none while locked | Widget |
| Notifications on device | real notification fires (schedule +2 min in a debug build), tap opens the doc through the lock | Manual (both OSes) |

**Regression additions (TESTING.md §4):**

| # | Steps | Expected |
|---|---|---|
| R59 | First open of My Documents | Intro S39 with backup and uninstall warnings |
| R60 | Compress an image → Save to My Documents → folder "IDs" (create) | Saved; appears in IDs; original Recent result unchanged |
| R61 | Import 5 PDFs incl. one duplicate | Duplicate prompt; folder counts correct |
| R62 | Folders 3 levels deep; try a 4th; move a folder into its child | 4th blocked with message; invalid move disabled |
| R63 | Scan a document (1.2) with "Scans" indexing ON → search a word printed on it | Found with snippet |
| R64 | Set expiry today + 2 days with "1 day before" in a debug build that shortens offsets to minutes | Notification arrives; generic text; tap opens doc |
| R65 | Change time zone / reboot device with reminders pending | Reminders still fire at local 09:00 |
| R66 | Enable lock (Library only) → leave app 2 min → open Library | S45; unlock with biometrics/passcode; tools usable without unlocking |
| R67 | Export library → uninstall → reinstall → import backup | Everything restored except recognised text (re-indexed) |
| R68 | Airplane mode + low battery (< 20%) with 10 docs queued | All library features work; indexing pauses and resumes when charging |

---

## 9. Tasks (M12)

- [x] 🔬 **T12.0 Spike (1 day).** Verify: drift + FTS5 availability on both platforms with `sqlite3_flutter_libs`; `flutter_local_notifications` current API (`zonedSchedule`, inexact mode, boot reschedule, iOS categories, cold-start launch details); `local_auth` options and the `FlutterFragmentActivity` requirement; iOS `isExcludedFromBackup` on a directory; Android `dataExtractionRules` excluding `files/library`; pdfrx page-text extraction API for text-layer PDFs. *Accept:* DECISIONS entries for ADR-054–058 with exact API names and versions. — *Android done 2026-10-31 (ADR-054…058, ADR-068):* FTS5 present in the shipped SQLite 3.53.4 (no `sqlite3_flutter_libs`), English and Hindi search work (tokenizer choice for T12.1); pdfrx `loadText().fullText`; `flutter_local_notifications` 22.3.3 + `timezone` 0.11.2 schedule and deliver (inexact, 20 s → 35 s), boot receivers added, desugaring on; `local_auth` 3.0.2 with `FlutterFragmentActivity` + AppCompat launch theme (no crash; emulator has no screen lock → unsupported, as specified); `docukit_native.deviceTimeZone()` → `Asia/Kolkata`; +354 KB; activity-dependent device suites re-run green. `integration_test/library_spike_test.dart`. ⚠️ iOS (categories, launch details, Face ID string, `isExcludedFromBackup` on `library/`) waits for Xcode.
- [x] **T12.1 Schema + repository.** Tables, FTS, migration, `LibraryRepository` (folders, documents, duplicates, copyForTool, stats) + tests. *Accept:* §8 migration/repository/FTS tests pass. — *Done 2026-10-31:* schema **v4** (`lib/data/library/library_tables.dart`: `LibraryFolders`, `LibraryDocuments`, `LibraryTags`; FTS5 `library_fts` with `unicode61 remove_diacritics 2 categories 'L* N* Co M*'` + 4 indexes, `fts.dart`); migration from v1/v2/v3 equals a fresh v4, history rows intact (`schema_v3.sql` dumped from 1.4); `LibraryRepository` + `LibraryRepositoryImpl` (folders ≤ 3 deep, names 1–60 unique per parent ignoring case, safe moves incl. subtree depths, delete modes move-up / delete-everything; documents: add = copy to `.part` + SHA-256 in one isolate pass + fsync + rename + row and FTS row in one transaction, `.part` cleaned on failure; duplicates by SHA-256; a taken name gets " (2)" on add/move and is refused on rename (owner-approved); star, notes ≤ 2,000, tags ≤ 10 × 30, expiry as a local date + offsets + minute; delete removes rows, FTS rows, files, thumbnail; `copyForTool` returns a new path; stats; orphan sweep; `changes` stream; search with quoted prefix terms, bm25 name > tags > notes > body, snippets only for recognised text, folder scope incl. subfolders; recognised text capped at 200k). Export/import ZIP come in T12.8 (owner-approved). Tests: 7 migration, 17 repository, 7 FTS (host), `integration_test/library_repository_test.dart` on the emulator (device SQLite: English, café, Hindi whole-word highlight).
- [x] **T12.2 Library UI: S39, S40, S41, S43.** Intro, home (grid/list, sort, filters, selection mode, FAB), folder view, folder picker sheet; ads per §3.2. *Accept:* FR-LIB-01, 02, 06–11 (minus Open in tool), widget + golden tests. — *Android done 2026-10-31:* `lib/features/library/` — `library_controller.dart` (view, sort — remembered as `lib_view` / `lib_sort` — starred filter, selection, single delete with a 5 s Undo), S39 `library_intro_screen.dart` (`lib_intro_seen`), S40/S41 `LibraryScreen` (folders, documents grid/list, sort, Starred chip, selection with Move / Share / Star / Delete, breadcrumb, New folder FAB disabled with an explanation at level 3, folder menu with rename / move / delete with counts and the two modes, the empty state; banner MAIN; one native card after the 5th document only with ≥ 6, never selectable), S43 `folder_picker_sheet.dart` (tree, find, new folder, disabled targets: the current place, the moving folder and its subtree, too deep), `folder_name_dialog.dart`, `library_tiles.dart`; Home 📁 action; `/library` and `/library/folder/:id`; repository `allFolders` / `folderContents`. **Fixed while finishing:** folder tiles overflowed with larger text (fixed-height grid → list); "More options" labelled three different menus (now Folder options / Document options); moving a folder offered its current place; tablets (≥ 840 dp, navigation rail) had no way into My Documents (rail destination added, FR-LIB-01). Tests: 10 widget (`library_screens_test.dart`), goldens for S39 and S40 light/dark compact/expanded; Home goldens regenerated for the 📁 action and the rail item — the changed pixels checked to be only the app-bar actions (compact) and the rail (expanded). Import / Scan in the FAB come with T12.3; search (T12.5), Expiring soon (T12.6), Open in tool (T12.4) as planned.
- [x] **T12.3 Adding documents.** Save to My Documents on S11 and multi-result, Import, Scanner hook, S19 row, duplicate dialog. *Accept:* FR-LIB-03, 04, 05, 21; R60–R61. — *Android done 2026-10-31:* `lib/features/library/application/add_to_library.dart` — `saveToLibrary` (S43 "Save to…", then "Saved to My Documents · View"), `askDuplicate` (FR-LIB-21: Open existing / Add copy), `importToLibrary` + `chooseImport` (PDF files / Photos and images through the tools' pickers and limits; the pick draft is discarded afterwards), `addAllToLibrary` ("Adding 2 of 5…" for more than one file; password-protected PDFs are kept, other invalid files are skipped and counted), `saveIncomingToLibrary`. Entry points: Result (S11) full-width "Save to My Documents" under the 2×2 grid (becomes the 2×3 grid when Print arrives); S22 row menu; OCR result (PDF entries); S19 row above the tools (then the batch ends and My Documents opens); S40/S41 + now opens Import files · Scan a document · New folder (New folder disabled with the 3-level note), the empty state gets [Import files] [Scan a document]. Scans preselect a root "Scans" folder (created on demand, removed again if the user cancels and it's empty), or the folder the scan was started from (`scanTargetFolderProvider`, used once). Tests: 8 widget (`test/widgets/add_to_library_test.dart`), `library_screens_test.dart` updated for the + sheet; goldens regenerated for Result (the new row) and S40 (the + icon) — diffs checked to be only those. R60/R61 on the emulator (`integration_test/add_to_library_test.dart`, real encoder, file system and SQLite): passed. The system picker part of R61 (choosing 5 PDFs) is a manual check on a phone.
- [ ] **T12.4 Document detail S42 + Open in tool.** Preview, full viewer, info, notes autosave, tags (P1), actions. *Accept:* FR-LIB-11, 12, 13.
- [ ] **T12.5 Search + indexing.** Search UI with snippets; index queue with policy, pause/resume, battery; settings section. *Accept:* FR-LIB-14–16; R63, R68.
- [ ] **T12.6 Reminders.** S44, notification service, scheduler with iOS limit, tap routing, time-zone/boot handling, Expiring soon sections, Home card. *Accept:* FR-REM-01–10; R64–R65; scheduler unit tests.
- [ ] **T12.7 App lock.** S45, lock controller + router guard, scopes, timeouts, snapshot cover, FLAG_SECURE, settings. *Accept:* FR-LCK-01–08; R66; state-machine tests.
- [ ] **T12.8 Storage, backup exclusion, export/import.** S46 storage/backup section, ZIP export/import, backup exclusion on both OSes, launch sweeps. *Accept:* FR-LIB-17–20, 22; R67.
- [ ] **T12.9 Privacy, copy, store.** Privacy & About section, privacy policy text, store listing line, permissions review, tour step for My Documents (`tour_version` bump). *Accept:* RELEASE checklist re-run for 1.5.
- [ ] **T12.10 Regression.** R1–R68 on Android emulator + a real phone; iOS once Xcode is available.

Order: T12.0 → T12.1 → T12.2 → T12.3 → T12.4 → T12.5 → T12.6 → T12.7 → T12.8 → T12.9 → T12.10.

---

## 10. Claude Code prompts

**P12-A — Spike (T12.0)**
```
Task T12.0 from docs/features/RELEASE_V1_5.md. Time box: 1 day. Build a throwaway debug screen under lib/debug/ (kDebugMode only) that verifies each item listed in T12.0 on the Android emulator (and lists what must be checked on iOS later).
For each: PASS/FAIL, the exact package version and API names that worked. Update the DECISIONS.md entries ADR-054–058. Don't build production code.
```

**P12-B — Data layer (T12.1)**
```
Task T12.1. Implement the drift tables, FTS5 table and migration from RELEASE_V1_5.md §4.3, and LibraryRepository (§4.4) with the add flow in §4.2/§4.5.
Write the migration, repository and FTS tests (§8) first. Commit a new schema snapshot. Never log file names, notes or text.
Report the commands you ran and their real results.
```

**P12-C — Library UI and adding documents (T12.2–T12.4)**
```
Tasks T12.2, T12.3, T12.4, one commit each. Build S39–S43 and S42 exactly per RELEASE_V1_5.md §3, with ads per §3.2 (ADMOB_BANNER_MAIN on library screens, the native in-feed card after the 5th item via ADMOB_NATIVE_HISTORY, no ads on sheets or the full viewer).
Add "Save to My Documents" to every Result screen, Import, the Scanner hook and the Incoming chooser row. Open in tool must pass COPIES, never library paths.
Widget and golden tests for every state, 200% text and dark mode. Report results.
```

**P12-D — Search and reminders (T12.5–T12.6)**
```
Tasks T12.5 and T12.6. Implement search with snippets and the background index queue (§4.6), then reminders (§4.7): S44, NotificationService, ReminderScheduler with the iOS 60-nearest limit, tap routing, time-zone and boot handling, Expiring soon sections and the Home card.
Unit-test the scheduler with a fake clock across DST and three time zones before wiring the UI. Request notification permission only on the first saved reminder.
Add a debug-only switch that shortens reminder offsets to minutes so I can test on my phone.
```

**P12-E — Lock, backup, privacy (T12.7–T12.9)**
```
Tasks T12.7, T12.8, T12.9. Implement the app lock (§4.8) with local_auth only — no DocuKit PIN storage — then storage/backup (§4.9, backup exclusion on both OSes) and the privacy/store updates.
Write the lock state-machine and backup round-trip tests first. The lock screen must never show ads.
Then build a debug APK to ~/Desktop/DocuKit-debug.apk (check free disk space first; stop if under 5 GB).
```

**P12-F — Regression (T12.10)**
```
Task T12.10: run R1–R68 on the emulator, report pass/fail per step, fix only clear bugs (each with a failing test first), list anything needing my decision, and update TASKS.md statuses.
```

---

## 11. Risks and decisions

| Risk | Impact | Mitigation |
|---|---|---|
| Users lose documents when changing phones (no cloud backup) | Data loss, bad reviews | Intro + settings warnings, prominent Export; consider a once-a-month "Back up your library" reminder (P2) |
| Notifications delayed by OEM battery savers (Xiaomi, Samsung, etc.) | Missed reminders | Day-level reminders with 30/7-day offsets give slack; "Reminders may be delayed by battery saver" help text with a link to app battery settings |
| iOS 64-notification limit | Later reminders not scheduled | Nearest-60 strategy + top-up on every launch (FR-REM-08) |
| OCR indexing drains battery | Complaints | Off by default for non-scans, battery pause, never runs during user jobs or in background |
| FTS5 missing on some SQLite builds | Search broken | Spike T12.0; fallback LIKE search over name/notes only with a "Text search unavailable" note |
| Lock makes documents inaccessible | Data access loss | Device credential fallback; lock can always be turned off after one device-credential check (FR-LCK-07) |
| Large libraries (thousands of docs) | Slow lists | Paged queries (50), thumbnails cached on disk, FTS for search |
| Storage growth | Full disk | Storage shown; pre-checks on add/import; Export then delete flow |

**Decisions (merged into DECISIONS.md as ADR-054–059):**

- **ADR-054 — Library excluded from cloud backups by default · Accepted.** Keeps the "files never leave your phone" promise literal. Android Auto Backup and iCloud backup exclude the library and the app database. *Consequence:* users must export a ZIP to move phones; the app warns clearly. Revisit if users ask for an opt-in "Include in device backup" switch (P2).
- **ADR-055 — Searchability policy: scans ON, other files OFF by default · Accepted.** OCR is CPU- and battery-heavy; scans are image-only and benefit most, while most other PDFs already contain text (indexed for free from the text layer). Manual "Make searchable now" available for any document.
- **ADR-056 — Device credentials only; no DocuKit PIN · Accepted.** Avoids storing secrets, avoids a forgotten-PIN lockout, uses OS-level security. *Consequence:* the lock needs a device screen lock; otherwise the option is disabled.
- **ADR-057 — Lock scope defaults to My Documents only · Accepted.** Tools and Recent stay quick to use; users who want everything locked can choose "Whole app".
- **ADR-058 — No WorkManager/background tasks for indexing in 1.5 · Accepted.** Indexing runs only while the app is open (foreground), keeping behaviour identical on both OSes and avoiding background-execution policies. Revisit if large libraries index too slowly.
- **ADR-059 (P2 idea) — Suggest expiry dates from OCR text.** Detect "Date of expiry" patterns in recognised text and offer to set the expiry. Not in 1.5.
