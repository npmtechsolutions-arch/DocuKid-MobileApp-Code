# DocuKit — Architecture

> Read with `PRD.md` (what) and `FEATURE_SPECS.md` (how each tool works). The reasons behind each choice are in `DECISIONS.md`.

## 1. Stack at a glance

| Concern | Choice | Licence | Notes |
|---|---|---|---|
| Framework | **Flutter** (latest stable at project start; 3.47.x at the time of writing) + Dart 3 | BSD-3 | One UI codebase for Android and iOS (ADR-001) |
| UI kit | Material 3, with adaptive widgets on iOS (`Switch.adaptive`, `showAdaptiveDialog`, Cupertino back-swipe page transitions) | — | See `DESIGN_SYSTEM.md §8` |
| State | `flutter_riverpod` 3.x (`Notifier`/`AsyncNotifier`, **no codegen**) | MIT | ADR-003 |
| Routing | `go_router` | BSD-3 | Typed route constants in `app/router.dart` |
| Database | `drift` + `drift_flutter` (SQLite) | MIT | Metadata only — never file bytes |
| Preferences | `shared_preferences` (`SharedPreferencesWithCache`) | BSD-3 | Wrapped by `SettingsRepository` |
| Image pick | `image_picker` (`pickMultiImage`, `pickImage`) → Android Photo Picker / iOS PHPicker | Apache-2.0 | **Spike T1.2:** confirm it returns original bytes with no re-encode; otherwise use `file_picker` `FileType.image` |
| File pick | `file_picker` (custom extensions: `pdf`) → SAF `OPEN_DOCUMENT` / `UIDocumentPickerViewController` | MIT | Copies to cache, which matches FR-FILE-05 |
| Image encode/decode | `flutter_image_compress` (native encoders: JPEG/PNG/WebP/HEIC, downsampled decode, rotation) | MIT | Heavy work on native threads |
| Image metadata | `dart:ui` `ImageDescriptor` (dimensions without a full decode) + `exif` (orientation, GPS presence) | MIT | |
| Pixel ops in Dart | `image` (only for PDF image recompression and padding/crop fallbacks) | MIT | Always inside `Isolate.run` |
| PDF render / inspect / combine / encode | `pdfrx` (PDFium) | MIT + PDFium BSD-3 | `PdfDocument.createNew`, `pages = [...]`, `encodePdf()`, `createFromJpegData` (verified in pub docs, Oct 2026). Rotation and image replacement: verify in **spike T3.0** |
| PDF authoring (Image→PDF) | `pdf` (dart) | Apache-2.0 | Embeds JPEG bytes without decoding them |
| Share | `share_plus` | BSD-3 | `ShareParams(files: [XFile(path, mimeType)])`, plus the iPad `sharePositionOrigin` |
| Save to Photos | `gal` | BSD-3 | iOS `NSPhotoLibraryAddUsageDescription`; Android API 26–28 needs `WRITE_EXTERNAL_STORAGE` with `maxSdkVersion="28"` |
| Save As / Open with / free space / background task | **Local plugin `packages/docukit_native`** (Kotlin + Swift, about 300 lines) | own | Streams from a file path (no bytes over the channel). ADR-006 |
| Receive shared files (P1) | `receive_sharing_intent` or the `docukit_native` intent handler | Apache-2.0 | Verify maintenance at M4 |
| Reorderable grids | `reorderable_grid_view` (Organizer, Image→PDF grid) — or a custom `LongPressDraggable` grid if it's unmaintained; lists use Flutter's `ReorderableListView` | MIT | Verify at T2.6 |
| Icons | Built-in `Icons.*_rounded` (no dependency); `material_symbols_icons` only if a glyph is missing | Apache-2.0 | |
| Misc | `path_provider`, `path`, `uuid` (v7), `intl`, `package_info_plus`, `url_launcher` (mailto), `crypto` (tests) | BSD/MIT | |
| Lints/tests | `flutter_lints` (strict) or `very_good_analysis`, `flutter_test`, `integration_test`, `mocktail` | | |
| Ads (v2.1) | `google_mobile_ads` (with the bundled UMP consent SDK) | Apache-2.0 | Only `lib/core/ads/` may import it (ADR-028, CLAUDE.md rule 5). Pin after checking pub.dev; verify UMP method names in the pinned version |
| Remove ads (v2.1, P1) | `in_app_purchase` | BSD-3 | Non-consumable `remove_ads` (ADR-030); only the Remove ads code may import it |
| Illustrations (v2.1, optional) | `flutter_svg` | MIT | Only if illustrations ship as SVG; otherwise `CustomPainter` (ADR-032, UI_REFRESH §7) |
| Heading font (v2.1) | Plus Jakarta Sans (SemiBold 600 + Bold 700, bundled asset) | SIL OFL | Headings only; add a licence entry (ADR-032) |

**v3 additions (app versions 1.1–1.5; each verified in its release spike — see `docs/features/RELEASE_V1_x.md` §4):**

| Release | Concern | Choice | Licence | Notes |
|---|---|---|---|---|
| 1.1 | ZIP for multi-output jobs | `archive` (`ZipFileEncoder`, STORE) — or a small store-only writer if it doesn't stream (ADR-039) | MIT | Verify streaming from disk in T8.0 |
| 1.1 | Receive shared files | `docukit_native.getIncomingFiles` + EventChannel `docukit/incoming` (ADR-037) | own | Replaces the `receive_sharing_intent` option in the row above |
| 1.2 | Document scanner | Android `com.google.android.gms:play-services-mlkit-document-scanner` (Gradle dep of `docukit_native`); iOS VisionKit `VNDocumentCameraViewController` (ADR-041) | Google APIs ToS / Apple SDK | No camera permission on Android; iOS `NSCameraUsageDescription` |
| 1.3 | Text recognition | `google_mlkit_text_recognition` | MIT + ML Kit terms | iOS 15.5 minimum (ADR-044); scripts per ADR-045 |
| 1.3 | Text-layer fonts | Noto Sans (+ Noto Sans Devanagari per ADR-045), regular weight | SIL OFL 1.1 | Licence entries |
| 1.4 | Page-object stamping | PDFium FFI via the bindings pdfrx ships (ADR-048) | BSD-3 | `FPDFPageObj_NewImageObj`, `FPDFImageObj_SetBitmap`, … — verify in T11.0 |
| 1.4 | PDF encryption | iOS PDFKit; Android PdfBox-Android `com.tom-roush:pdfbox-android` 2.0.27.0 (ADR-049) | Apple / Apache-2.0 | +3–5 MB on Android; R8 keep rules; NOTICE in licences |
| 1.4 | Handwriting fonts | 3 OFL fonts (Regular only) | SIL OFL 1.1 | ≈ 150–300 KB |
| 1.5 | Local notifications | `flutter_local_notifications` + `timezone` (+ `flutter_timezone` or a native call) | BSD-3 / BSD-2 / Apache-2.0 | Inexact scheduling only; verify API names in T12.0 |
| 1.5 | App lock | `local_auth` | BSD-3 | May need `FlutterFragmentActivity` (conflict C-6) |
| 1.5 | Full-text search | drift + SQLite FTS5 (`sqlite3_flutter_libs`) | MIT | Verify FTS5 is bundled in T12.0 |
| 1.5 | SHA-256 for duplicates | `crypto` | BSD-3 | Already a regular dependency (3.0.8) |

**Dependency rule:** pin exact versions in `pubspec.yaml` after verifying them. Add nothing outside this table without a `DECISIONS.md` entry that gives the purpose, licence, maintenance status and size impact.

## 2. Layering

```
┌──────────────── Presentation ────────────────┐  features/*/presentation
│ Screens (widgets) · Controllers (Notifiers)  │  UI state only, no IO
└───────────────▲──────────────────────────────┘
                │ calls
┌───────────────┴──────── Application ─────────┐  features/*/application + core/operation
│ Tool use-cases (implement ToolOperation)     │  validation, orchestration
│ JobRunner (lifecycle, temp dirs, history)    │
└───────────────▲──────────────────────────────┘
                │ uses interfaces
┌───────────────┴──────── Engines ─────────────┐  core/image, core/pdf
│ ImageEngine · PdfEngine · OutputValidator    │  pure processing, testable
└───────────────▲──────────────────────────────┘
                │
┌───────────────┴──────── Platform & Data ─────┐  core/files, core/platform, data/
│ FileGateway (pick/copy/save/share/open)      │
│ StorageInfo · BackgroundGuard                │
│ AppDatabase (drift) · SettingsRepository     │
└──────────────────────────────────────────────┘
```

Rules:
- Widgets never touch `File`, `dart:io`, plugins or the DB directly. They call their controller.
- Engines don't know about Riverpod, routes or the DB. Their inputs are paths and options; their outputs are paths and metadata.
- Every plugin sits behind an interface in `core/` so tests can fake it.

## 3. Project layout

```
docukit/
├─ CLAUDE.md
├─ docs/                       # this documentation pack
├─ pubspec.yaml
├─ analysis_options.yaml
├─ l10n.yaml                   # gen-l10n config → lib/l10n/
├─ assets/
│  ├─ icons/                   # tool icons (SVG → generated) if not using Material Symbols
│  └─ test_corpus/ (dev only, not bundled)
├─ packages/
│  └─ docukit_native/          # local federated-lite plugin
│     ├─ lib/docukit_native.dart
│     ├─ android/src/main/kotlin/.../DocukitNativePlugin.kt
│     └─ ios/Classes/DocukitNativePlugin.swift
├─ lib/
│  ├─ main.dart                # bootstrap: bindings, DB, prefs, sweeps, ProviderScope
│  ├─ app/
│  │  ├─ app.dart              # MaterialApp.router, theme, locale
│  │  ├─ router.dart           # go_router config + route names
│  │  ├─ theme/                # tokens.dart, color_schemes.dart, typography.dart, theme.dart
│  │  └─ bootstrap/            # startup tasks: temp sweep, retention sweep, interrupted-job fix
│  ├─ core/
│  │  ├─ ads/                  # v2.1 (ADS.md §7): ads_config, ads_service, ad_policy, interstitial/rewarded/
│  │  │                        # app_open managers, native_ad_slot, banner_ad_slot, consent_gate — the ONLY network code
│  │  ├─ errors/               # app_error.dart (sealed), error_codes.dart, error_copy.dart
│  │  ├─ operation/            # tool_operation.dart, job.dart, job_state.dart, job_runner.dart,
│  │  │                        # cancel_token.dart, progress.dart, job_context.dart
│  │  ├─ files/                # file_gateway.dart (interface), file_gateway_impl.dart,
│  │  │                        # picked_file.dart, file_naming.dart, mime_sniffer.dart, paths.dart
│  │  ├─ image/                # image_engine.dart, image_engine_impl.dart, image_info.dart,
│  │  │                        # resize_math.dart, target_size_search.dart
│  │  ├─ pdf/                  # pdf_engine.dart, pdfrx_pdf_engine.dart, pdf_info.dart,
│  │  │                        # page_edit.dart, image_to_pdf_builder.dart, pdf_reducer.dart
│  │  ├─ validation/           # output_validator.dart, input_validator.dart
│  │  ├─ platform/             # storage_info.dart, background_guard.dart, native_bridge.dart
│  │  ├─ formatting/           # bytes_format.dart, date_format.dart
│  │  └─ widgets/              # shared components (see DESIGN_SYSTEM §6)
│  ├─ data/
│  │  ├─ db/                   # app_database.dart (drift), tables.dart, daos/
│  │  ├─ repositories/         # history_repository.dart, outputs_repository.dart
│  │  └─ settings/             # settings_repository.dart, app_settings.dart
│  ├─ features/
│  │  ├─ home/                 # presentation/, application/, quick_actions.dart (v2.1, UI_REFRESH §2.1)
│  │  ├─ search/               # tool_catalog.dart (single source of truth for tools), synonyms.dart
│  │  ├─ image_compress/       # presentation/ (screen, widgets), application/ (controller, operation)
│  │  ├─ image_resize/
│  │  ├─ image_to_pdf/
│  │  ├─ pdf_merge/
│  │  ├─ pdf_organize/
│  │  ├─ pdf_compress/
│  │  ├─ job/                  # processing_screen, result_screen, error_screen, save flow
│  │  ├─ history/
│  │  ├─ settings/
│  │  ├─ privacy/
│  │  ├─ onboarding/
│  │  ├─ tour/                 # v2.1 (TOUR.md §4): tour_step, tour_steps, tour_controller, tour_overlay, tour_targets
│  │  └─ incoming/             # P1 shared-in file chooser
│  └─ l10n/                    # app_en.arb (+ generated)
├─ test/                       # unit + widget tests mirroring lib/
└─ integration_test/           # end-to-end flows per tool
```

**v3 additions to the layout (1.1–1.5):**
```
lib/core/operation/            # + multi_output.dart (MultiOutput, OutputOk/OutputFailed), MultiToolOperation (1.1)
lib/core/files/                # + zip_builder.dart, saveManyToFolder on FileGateway (1.1)
lib/core/pdf/                  # + page_range.dart (1.1), pdf_stamper.dart (1.4), pdf_security.dart (1.4)
lib/core/scan/                 # DocumentScanner interface (1.2)
lib/core/ocr/                  # TextRecognizer interface, OCR models (1.3)
lib/core/notifications/        # NotificationService (1.5)
lib/data/library/              # library tables, FTS, LibraryRepository (1.5)
lib/features/image_convert/  pdf_split/  pdf_to_images/          (1.1)
lib/features/incoming/         # IncomingFilesController + S19 (1.1)
lib/features/scan/             (1.2)
lib/features/ocr/              (1.3)
lib/features/pdf_sign/  pdf_watermark/  pdf_protect/  pdf_unlock/ (1.4)
lib/features/library/          # application/ + presentation/ (1.5)
lib/features/lock/             # lock_controller, lock_screen, lock_guard (1.5)
lib/debug/                     # throwaway spike screens (kDebugMode only, never in release)
```

Start with this single package (plus the local native plugin). Split into more packages only if build time or reuse requires it.

## 4. The tool catalogue (single source of truth)

`features/search/tool_catalog.dart`:

```dart
enum ToolId { imageCompress, imageResize, imageToPdf, pdfMerge, pdfOrganize, pdfCompress }

enum ToolCategory { image, pdf }

class ToolDescriptor {
  final ToolId id;
  final ToolCategory category;
  final String route;              // e.g. '/tool/image-compress'
  final IconData icon;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) subtitle;
  final List<String> Function(AppLocalizations) keywords; // synonyms, localised
  final InputKind inputKind;       // images | pdfs | singlePdf
  final int minInputs, maxInputs;
  const ToolDescriptor(...);
}

const toolCatalog = <ToolDescriptor>[ ... ]; // Home, Search, Incoming chooser and History all read this
```

Adding a tool = a catalogue entry + a feature folder + one `ToolOperation`.

**v3 catalogue additions (FULL_PRODUCT §4.2):**

| ToolId | Route | Category | Release |
|---|---|---|---|
| `imageConvert` | `/tool/image-convert` | image | 1.1 |
| `pdfSplit` | `/tool/pdf-split` | pdf | 1.1 |
| `pdfToImages` | `/tool/pdf-to-images` | pdf | 1.1 |
| `scanDocument` | `/tool/scan` | scan | 1.2 |
| `ocr` | `/tool/ocr` | scan | 1.3 |
| `pdfSign` | `/tool/pdf-sign` | secure | 1.4 |
| `pdfWatermark` | `/tool/pdf-watermark` | secure | 1.4 |
| `pdfProtect` | `/tool/pdf-protect` | secure | 1.4 |
| `pdfUnlock` | `/tool/pdf-unlock` | secure | 1.4 |

New `ToolCategory` values: `scan` (1.2), `secure` (1.4), and `library` (1.5, Home card only — not a tool). New values are appended to the enums (stored as text in drift via `textEnum`).

## 5. Operation engine

### 5.1 Contract

```dart
/// One run of a tool. Implemented once per tool in features/<tool>/application/.
abstract interface class ToolOperation<O extends ToolOptions> {
  ToolId get tool;

  /// Fast checks before any heavy work (counts, formats, encryption, size limits).
  Future<void> validateInputs(List<PickedFile> inputs, O options); // throws AppError

  /// Rough bytes needed for temp + output, for the storage pre-check.
  int estimateRequiredBytes(List<PickedFile> inputs, O options);

  /// Do the work. Write the output ONLY inside ctx.workDir. Report progress via ctx.
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, O options);

  /// Re-open and check the output (see §5.4). Throws OutputValidationFailed.
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, O options);
}

class JobContext {
  final String jobId;
  final Directory workDir;            // cache/jobs/<id>/work
  final CancelToken cancel;           // cooperative; call cancel.throwIfCancelled()
  final void Function(JobProgress) report;
}

sealed class JobProgress {}
class Indeterminate extends JobProgress { final String stepKey; }            // e.g. 'step_encoding'
class Determinate  extends JobProgress { final int done, total; final String stepKey; } // pages/images
```

### 5.2 Job states

```
Created → Validating → (StoragePreCheck) → Processing → ValidatingOutput → Completed
              │              │                  │               │
              └──────────────┴──────► Failed ◄──┴───────────────┘
Processing ──(user cancel)──► Cancelled
Processing ──(process killed; found at next launch)──► Interrupted
```

```dart
sealed class JobState {}
class JobCreated extends JobState {}
class JobValidating extends JobState {}
class JobProcessing extends JobState { final JobProgress progress; }
class JobValidatingOutput extends JobState {}
class JobCompleted extends JobState { final JobResult result; }
class JobFailed extends JobState { final AppError error; }
class JobCancelled extends JobState {}
// Interrupted exists only in history (status column), never as a live state.
```

### 5.3 JobRunner algorithm

```
run(tool, inputs, options):
  id = uuidV7()
  dirs = createJobDirs(id)                      # cache/jobs/<id>/{work}
  history.insert(id, tool, status=RUNNING, inputs meta, options json)   # lets us detect kills
  emit Validating
  tool.validateInputs(...)                      # AppError → Failed
  need = tool.estimateRequiredBytes(...)
  if storage.free() < need + 50MB → Failed(InsufficientStorage)
  guard = background.begin('docukit-job')       # iOS background task; no-op on Android
  try:
    emit Processing(Indeterminate('step_preparing'))
    raw = await tool.execute(ctx, ...)          # ctx.cancel checked inside
    emit ValidatingOutput
    meta = await tool.validateOutput(raw, ...)
    final = outputs.adopt(id, raw.path, safeName(raw.suggestedName))  # move → appSupport/outputs/<id>/
    history.complete(id, final, meta, duration)
    emit Completed(JobResult(...))
  on CancelledException → history.mark(id, CANCELLED); emit Cancelled
  on AppError e        → history.fail(id, e.code); emit Failed(e)
  on Object e, st      → log(code only); history.fail(id, PROCESSING_FAILED); emit Failed(ProcessingFailed)
  finally:
    guard.end(); deleteDir(dirs.work)           # inputs dir kept while the tool screen is alive (re-run)
```

The **live job** is held by `jobControllerProvider(id)` (a `Notifier<JobState>`). The Processing screen listens to it; on `Completed` it replaces itself with Result, and on `Failed` with Error.

At launch, `bootstrap` runs:
1. `history.markRunningAsInterrupted()`
2. delete `cache/jobs/*` older than 24 h (except dirs referenced by a saved draft)
3. the retention sweep: delete `outputs/<id>` past retention → set `output_deleted_at`.

### 5.4 Output validation (per tool)

| Tool | Checks before showing success |
|---|---|
| Image (compress/resize) | File exists, size > 0; magic bytes match the declared format; `ImageDescriptor` decodes the header; width/height == expected (resize) |
| Image→PDF | Opens with pdfrx; `pageCount == images.length`; first page renders at 64 px |
| Merge | Opens; `pageCount == Σ input pages` |
| Organize | Opens; `pageCount == edits.length`; the rotation of pages 1 and N matches |
| Reduce | Opens; `pageCount == input pageCount`; first and last page render |

## 6. Files and storage

### 6.1 Directories

| Purpose | Android | iOS | Lifetime |
|---|---|---|---|
| Job temp (`jobs/<id>/in`, `work`) | `getTemporaryDirectory()` (cacheDir) | `getTemporaryDirectory()` (tmp) | Deleted after the job/screen; sweep > 24 h |
| App-managed outputs (`outputs/<id>/<name>`) | `getApplicationSupportDirectory()` | `getApplicationSupportDirectory()`, excluded from iCloud backup (`isExcludedFromBackup`), file protection `completeUntilFirstUserAuthentication` | Retention setting (default 7 days) |
| Thumbnail cache | memory LRU only (MVP) | same | Session |
| DB | `drift_flutter` default (app documents/support) | same | Until uninstall / Clear history |

### 6.2 FileGateway interface

```dart
abstract interface class FileGateway {
  Future<List<PickedFile>> pickImages({required int max});        // Photo picker
  Future<List<PickedFile>> pickPdfs({required bool multiple});     // Document picker
  Future<SaveOutcome> saveAs(String path, {required String suggestedName, required String mime});
  Future<SaveOutcome> saveToPhotos(String path);                    // images only
  Future<ShareOutcome> share(List<String> paths, {required String mime, Rect? origin});
  Future<bool> openWith(String path, {required String mime});
  Future<bool> exists(String path);
}

class PickedFile {          // always a COPY inside the job's in/ dir
  final String path;
  final String displayName; // original name for UI/history
  final String mime;        // sniffed from magic bytes, not the extension
  final int sizeBytes;
  final FileMeta? meta;     // width/height/orientation/alpha | pageCount/encrypted
  final ValidationStatus status; // ok | warning(code) | invalid(code)
}

sealed class SaveOutcome { } // Saved(displayLocation) | SaveCancelled | SaveFailed(AppError)
```

Picking flow: plugin returns cache copies → `FileGateway` moves them into `jobs/<draftId>/in/`, sniffs the MIME, reads meta (`ImageEngine.inspect` / `PdfEngine.inspect`) → returns `PickedFile`s with status. A picked file that is no longer readable → `PermissionLost`.

### 6.3 Naming (`core/files/file_naming.dart`)

```
safeBaseName(input):
  s = NFC(input) ; remove extension
  replace [\\/:*?"<>|\x00-\x1F] with '_' ; collapse whitespace ; trim dots/spaces
  if s empty → 'DocuKit'
  truncate to 120 UTF-16 units without splitting a surrogate pair
defaultOutputName(tool, firstInputName, now):
  image_compress → '<base>_compressed.<ext>'
  image_resize   → '<base>_<w>x<h>.<ext>'
  image_to_pdf   → 'Images_<yyyyMMdd_HHmm>.pdf'
  pdf_merge      → 'Merged_<yyyyMMdd_HHmm>.pdf'
  pdf_organize   → '<base>_edited.pdf'
  pdf_compress   → '<base>_reduced.pdf'
uniqueIn(dir, name): append ' (n)' before the extension until free
```

### 6.4 Native plugin `docukit_native` (MethodChannel `docukit/native`)

| Method | Args | Android | iOS | Returns |
|---|---|---|---|---|
| `saveAs` | path, name, mime | `ACTION_CREATE_DOCUMENT` → stream-copy into `contentResolver.openOutputStream(uri)`; query `DISPLAY_NAME` | `UIDocumentPickerViewController(forExporting: [URL], asCopy: true)` | `{status: saved|cancelled|failed, name?}` |
| `openWith` | path, mime | `FileProvider` URI + `ACTION_VIEW` chooser + `FLAG_GRANT_READ_URI_PERMISSION` | `UIDocumentInteractionController.presentOpenInMenu` (fallback: `QLPreviewController`) | bool |
| `freeBytes` | — | `StatFs(filesDir).availableBytes` | `volumeAvailableCapacityForImportantUsageKey` | int |
| `beginBackgroundTask` / `end` | name | no-op (MVP) | `UIApplication.beginBackgroundTask` / `endBackgroundTask` | token |
| `getIncomingFiles` (P1) | — | Reads `ACTION_SEND`/`SEND_MULTIPLE`/`VIEW` intents, copies to cache | `application(_:open:options:)` / scene `openURLContexts`, copies to tmp | list of paths |
| `getIncomingFiles` + EventChannel `docukit/incoming` (1.1, ADR-037) | — | Launch intent + `onNewIntent`; copies each `content://` to `cacheDir/incoming/<uuid>/` and clears the extras | `scene(_:openURLContexts:)` / `willConnectTo` / `application(_:open:options:)`; copies to `tmp/incoming/<uuid>/` | `List<{path, displayName}>` (RELEASE_V1_1 §4.4) |
| `saveManyToFolder` (1.1) | paths, names, mimes | `ACTION_OPEN_DOCUMENT_TREE` → `DocumentFile.createFile` per file; no persistable permission | `UIDocumentPickerViewController(forExporting: urls, asCopy: true)` | `{status, savedCount, failedCount, folderName?}` |
| `scanDocument` (1.2, ADR-041) | options | ML Kit `GmsDocumentScanning` (full mode, JPEG) → copies pages into the job dir | `VNDocumentCameraViewController` → JPEG per page | list of page paths (RELEASE_V1_2 §4.3) |
| `protectPdf` / `unlockPdf` / `pdfProtection` (1.4, ADR-049) | in/out paths, passwords | PdfBox-Android | PDFKit | see RELEASE_V1_4 §4.6 — passwords are never logged (CI grep) |
| `setSecure`, privacy overlay, `timezoneChanged` stream, `batteryState` (1.5) | — | `FLAG_SECURE`; `ACTION_TIMEZONE_CHANGED` | resign-active overlay; `NSSystemTimeZoneDidChange` | RELEASE_V1_5 §3.3, §4.7 |

Android manifest: `FileProvider` with `<cache-path name="share" path="share/"/>` and `<files-path name="outputs" path="outputs/"/>` — **no root paths**. iOS: `CFBundleDocumentTypes` for `com.adobe.pdf`, `public.jpeg`, `public.png`, `public.heic`, `org.webmproject.webp` (P1), with `LSSupportsOpeningDocumentsInPlace = NO`.

## 7. Engines

### 7.1 ImageEngine

```dart
abstract interface class ImageEngine {
  Future<ImageMeta> inspect(String path);   // w, h (oriented), format, hasAlpha, orientation, hasGps
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t);
}
class ImageTransform {
  final ImageFormat format;     // jpeg | png | webp | heic
  final int quality;            // 1–100 (ignored for png)
  final int? targetWidth, targetHeight;   // final pixel size after orientation
  final FitMode fit;            // stretch | contain(padColor) | cover
  final int extraRotation;      // 0/90/180/270 (Image→PDF per-item rotation)
  final bool stripMetadata;
}
```
Implementation: `flutter_image_compress.compressAndGetFile` with `minWidth/minHeight` for downsampled decode, `autoCorrectionAngle: true`, `keepExif: !stripMetadata`, `rotate`. For exact dimensions (it scales proportionally by its minWidth/minHeight semantics), follow up with an exact resize step — see `FEATURE_SPECS.md §3.4`. Contain/cover use the `image` package in an isolate on the already-downsampled image.

### 7.2 PdfEngine

```dart
abstract interface class PdfEngine {
  Future<PdfMeta> inspect(String path);    // pageCount, isEncrypted, pageSizes(pt), imageCount?, producer
  Future<ui.Image> renderPage(String path, int index, {required int targetWidthPx});
  Future<void> merge(List<String> inputs, String out, JobContext ctx);
  Future<void> organize(String input, List<PageEdit> edits, String out, JobContext ctx);
  Future<void> reduce(String input, String out, ReduceLevel level, JobContext ctx);
}
class PageEdit { final int sourceIndex; final int rotationQuarterTurns; } // list order = output order
enum ReduceLevel { basic, balanced, strong }
```
Default implementation: `PdfrxPdfEngine`. If spike T3.0 finds a missing capability, add `NativePdfOps` (Android PdfBox-Android, iOS PDFKit) for that single method only, keeping the interface the same.

Image→PDF has its own builder (`ImageToPdfBuilder`, built on the `pdf` package), so the engine stays focused on existing PDFs.

## 8. Data model (drift)

```dart
class Operations extends Table {
  TextColumn get id => text()();                       // uuid v7
  TextColumn get tool => textEnum<ToolId>()();
  TextColumn get status => text()();                   // RUNNING|SUCCESS|FAILED|CANCELLED|INTERRUPTED
  TextColumn get errorCode => text().nullable()();     // AppErrorCode.name
  IntColumn  get createdAt => integer()();             // epoch ms
  IntColumn  get finishedAt => integer().nullable()();
  IntColumn  get durationMs => integer().nullable()();
  IntColumn  get inputCount => integer()();
  IntColumn  get inputTotalBytes => integer()();
  TextColumn get outputName => text().nullable()();
  TextColumn get outputMime => text().nullable()();
  IntColumn  get outputBytes => integer().nullable()();
  TextColumn get outputRelPath => text().nullable()(); // relative to outputs/, never absolute
  TextColumn get outputMetaJson => text().nullable()();// {"w":..,"h":..} | {"pages":..}
  TextColumn get optionsJson => text().nullable()();   // non-sensitive options for "Run again"
  BoolColumn get savedExternally => boolean().withDefault(const Constant(false))();
  IntColumn  get outputDeletedAt => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}

class OperationInputs extends Table {
  TextColumn get operationId => text().references(Operations, #id, onDelete: KeyAction.cascade)();
  IntColumn  get position => integer()();
  TextColumn get displayName => text()();              // file name only; no path
  TextColumn get mime => text()();
  IntColumn  get sizeBytes => integer()();
  TextColumn get metaJson => text().nullable()();
  @override Set<Column> get primaryKey => {operationId, position};
}
```
Indexes: `operations(createdAt DESC)`, `operations(tool)`. Migrations are tested with `drift_dev schema` snapshots from v1.

**Output availability** = `outputRelPath != null && outputDeletedAt == null && File(outputs/relPath).exists()`.

**v3 data-model additions** (1.1 is `schemaVersion => 2`; the v1 baseline is `test/data/schemas/schema_v1.sql`, migrated in `test/data/migration_test.dart` — conflict C-4 in DECISIONS):

| Release | Change |
|---|---|
| 1.1 | `Operations.status` gains `PARTIAL`; new columns `outputCount` (default 1), `failedCount` (default 0), `zipRelPath`; new table `OperationOutputs` (operationId, position, displayName, relPath, sizeBytes, beforeBytes, errorCode, metaJson). Schema v1 → v2 (done, T8.2). Multi jobs keep `output*` columns null except `outputBytes` (total of succeeded items); a batch of one also fills them. Retention and "delete all outputs" include rows with `outputCount > 1`; "completed" includes `PARTIAL` |
| 1.2 | `ToolId.scanDocument` (text enum, no column change); schema +1 with a migration test |
| 1.3 | `ToolId.ocr`; `optionsJson = {outputs, script}` only, **never text**; text-only jobs keep `outputRelPath = null` |
| 1.4 | `ToolId.pdfSign/pdfWatermark/pdfProtect/pdfUnlock`; Protect/Unlock `optionsJson = {}` (**no passwords**) |
| 1.5 | New tables `library_folders`, `library_documents`, `library_tags` (P1), `library_fts` (FTS5), `reminder_snoozes` (P1). Schema +1; `operations` unchanged |

### 8.1 Settings (shared_preferences keys)

| Key | Type | Default |
|---|---|---|
| `theme_mode` | `system|light|dark` | system |
| `img_quality` | int | 80 |
| `img_format` | `same|jpeg|png|webp` | same |
| `img_strip_metadata` | bool | true |
| `resize_lock_ratio` | bool | true |
| `resize_custom_presets` | json list | [] |
| `pdf_page_size` | `a4|letter|legal|image` | a4 (letter if the locale's country is US/CA/MX/PH) |
| `pdf_fit` | `fit|fill` | fit |
| `pdf_margin` | `none|small|large` | small |
| `pdf_image_quality` | `original|high|compact` | high |
| `reduce_level` | `basic|balanced|strong` | balanced |
| `output_retention` | `h24|d7|d30|forever` | d7 |
| `confirm_destructive` | bool | true |
| `onboarding_done` | bool | false |
| `last_tool` | ToolId? | null |
| `draft_<tool>` | json | — (FR-LIFE-03) |
| `tour_done` (v2.1) | bool | false |
| `tour_version` (v2.1) | int | 0 |
| `stats_total_saved_bytes` (v2.1) | int | 0 |
| `ads_removed` (v2.1) | bool | false |
| `ads_jobs_since_interstitial` (v2.1) | int | 0 |
| `ads_last_interstitial_at` (v2.1) | int (epoch ms) | 0 |
| `ads_lifetime_jobs` (v2.1) | int | 0 |
| `ads_free_until` (v2.1) | int (epoch ms) | 0 |
| `ads_rewards_today` (v2.1) | int | 0 |
| `ads_rewards_day` (v2.1) | string (yyyyMMdd) | "" |
| `ads_last_fullscreen_at` (v2.1) | int (epoch ms) | 0 |
| `session_number` (v2.1) | int | 0 |
| `favourite_tools` (1.1) | JSON list of ToolId | [] (max 6) |
| `convert_format` (1.1) | `jpg|png|webp|heic` | jpg |
| `convert_quality` (1.1) | int | 90 |
| `p2i_format` (1.1) | `jpg|png` | jpg |
| `p2i_dpi` (1.1) | `72|150|300` | 150 |
| `split_mode` (1.1) | `ranges|everyN|each` | ranges |
| `split_every_n` (1.1) | int | 1 (shown as 2, the smallest useful value) |
| `multi_save_default` (1.1) | `folder|zip` | folder |
| `scan_default_format` (1.2) | `pdf|jpg` | pdf |
| `scan_page_size` (1.2) | `a4|letter|fit` | a4 (letter by locale) |
| `scan_quality` (1.2) | `high|compact` | high |
| `draft_scanDocument` (1.2) | json | — |
| `ocr_script` (1.3) | `latin|devanagari|…` | latin (or the locale's script if it ships) |
| `ocr_outputs` (1.3) | json `{pdf, review, txt}` | `{pdf: true, review: true, txt: false}` |
| `ocr_rotate_retry` (1.3) | bool | true |
| `scan_make_searchable` (1.3) | bool | false |
| `saved_signatures` (1.4) | JSON list `[{id, file, createdAt, kind}]` | [] (max 3; files in `appSupport/signatures/`) |
| `sig_last_colour` (1.4) | `black|blue` | black |
| `sig_last_thickness` (1.4) | `thin|medium|thick` | medium |
| `wmk_last_text_style` (1.4) | json | — (text only) |
| `lib_intro_seen` (1.5) | bool | false |
| `lib_view` (1.5) | `grid|list` | grid |
| `lib_sort` (1.5) | `name|added|size|expiry` | added |
| `lib_index_scans` / `lib_index_other` / `lib_index_paused` (1.5) | bool | true / false / false |
| `rem_minute_of_day` (1.5) | int | 540 (09:00) |
| `rem_show_names` (1.5) | bool | false |
| `rem_last_tz` (1.5) | string | device zone |
| `lock_enabled` (1.5) | bool | false |
| `lock_scope` (1.5) | `library|app` | library |
| `lock_timeout` (1.5) | `immediate|m1|m5` | m1 |
| `lock_hide_recents` (1.5) | bool | true |
| `home_lib_card` (1.5) | bool | true |

`tour_version` is bumped by each release that adds tour steps (1.1 → 2 … 1.5 → 6; conflict C-7). **Never** store passwords or OCR text in settings.

## 9. Error model

```dart
enum AppErrorCode {
  unsupportedFormat, invalidInput, encryptedDocument, corruptFile, fileTooLarge,
  tooManyFiles, notEnoughFiles, insufficientStorage, permissionLost, processingFailed,
  outOfMemory, cancelled, outputValidationFailed, saveFailed, interrupted,
}
sealed class AppError implements Exception {
  AppErrorCode get code;
  String? get fileDisplayName; // which input, for UI only — never logged
}
```
`core/errors/error_copy.dart` maps code → title/body/primary action/secondary action (strings in `COPY.md §4`). Engines translate library exceptions (e.g. pdfrx password exception → `encryptedDocument`; `OutOfMemoryError`/decode failures → `outOfMemory`/`corruptFile`).

**Logging:** `core/logging/log.dart` writes `debugPrint` only in debug builds, with the format `[job <id8>] <event> <code>`. Never log names, paths or bytes. Release builds log nothing.

## 10. Concurrency and performance
- One job at a time in MVP (`JobRunner` is a queue of 1). Starting another while one runs shows a snackbar: "Finish or cancel the current job first."
- Native engines (`flutter_image_compress`, pdfrx/PDFium) do their work off the UI thread. Dart pixel work → `Isolate.run`.
- Thumbnails: a `PdfThumbnailCache` LRU capped by bytes (`min(64 MB, 1/8 of the reported RAM class)`); render at `cellWidth × devicePixelRatio`; cancel renders for cells that scroll away; clear on memory pressure (`WidgetsBindingObserver.didHaveMemoryPressure`).
- Image→PDF and Strong reduce process **one page/image at a time**, with `cancel.throwIfCancelled()` between them.
- Avoid `Uint8List` round-trips over platform channels for large files; pass paths.

## 11. Platform configuration checklist

**Android** (`android/app/build.gradle.kts`): `minSdk 26`, `targetSdk 36`, `compileSdk 36`; R8 on with `proguard-rules.pro` keeping pdfrx/JNI classes; ABI splits are handled by the AAB. Manifest (v2.1, ADR-028 replaces the old "no `INTERNET`" rule): `INTERNET`, `ACCESS_NETWORK_STATE` and `AD_ID` (merged by the ads SDK; keep it), plus the AdMob `com.google.android.gms.ads.APPLICATION_ID` meta-data (missing → crash at launch); still no storage/media read permissions; `WRITE_EXTERNAL_STORAGE maxSdkVersion=28` (only for Save to Photos on API 26–28); intent filters for SEND/VIEW (P1); `android:enableOnBackInvokedCallback="true"`.

**iOS** (`ios/Runner`): deployment target 15.0; `Info.plist` → `NSPhotoLibraryAddUsageDescription` = "DocuKit saves images you choose to your photo library." (no `NSPhotoLibraryUsageDescription` — PHPicker needs none); `CFBundleDocumentTypes` + `UTImportedTypeDeclarations` for WebP (P1); `ITSAppUsesNonExemptEncryption = NO`; `PrivacyInfo.xcprivacy` (see `RELEASE.md §3`); **v2.1:** `GADApplicationIdentifier` and `SKAdNetworkItems` (Google's current list), no `NSUserTrackingUsageDescription` (no ATT, ADR-029). Signing via automatic signing for development and Xcode/`flutter build ipa` for distribution.

## 12. Testing hooks
- Every engine/gateway/repository is an interface → fake it in widget tests with `ProviderScope(overrides: [...])`.
- `integration_test/` drives real engines on the device using `test_corpus` files pushed via `adb push` / bundled in a test-only asset flavour.
- The checksum guard: an integration helper computes SHA-256 of every input before and after each run and fails the test if they differ.
