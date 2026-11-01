# DocuKit 1.2 — Scan Document

> Follows `docs/FULL_PRODUCT.md` §4 conventions. Requirement prefix **FR-SCN**, tasks **T9.x** (milestone **M9**), ADRs **ADR-041–043** (DECISIONS.md), screens **S27–S29**, regressions **R37–R42**. ToolId `scanDocument`, route `/tool/scan`, category `scan`.

## 1. Summary & scope

Turn paper into a clean PDF with the phone camera. DocuKit uses the **operating system's own document scanner**: Google's ML Kit Document Scanner on Android and Apple's VisionKit document camera on iOS. Both already do edge detection, auto-capture, perspective correction, cropping and colour filters. DocuKit adds what they don't: a review screen to reorder, rotate, delete and add pages, output options, and the usual DocuKit pipeline (validate → result → save/share → history).

**In scope**
- Scan Document tool (S27 entry), system scanner launch (S28 is the system UI), Scan Review screen (S29).
- Multi-page scans (up to 50 pages per job), add more pages to an existing scan, re-order/rotate/delete.
- Output: one PDF (default) or JPG images (one per page, via `MultiOutput` from 1.1).
- Page size A4 / Letter / "Fit to scan", quality High / Compact, file name.
- Android: gallery import inside the scanner (ML Kit option).
- Fallbacks: no Google Play services, first-time module download while offline, iOS camera permission denied, user cancel.
- Home category "Scan & Text", Quick action chip **Scan**, search keywords, tour step.
- A documented hook for 1.3 "Make searchable" (no visible UI in 1.2 — ADR-043).

**Out of scope (later)**
- OCR / searchable PDF (1.3).
- Saving straight into My Documents (1.5 adds "Save to My Documents" on Result).
- A custom DocuKit camera UI (we deliberately use the system scanners — ADR-041).
- Android launcher shortcut (P2, may ship if time allows).

## 2. Requirements

### 2.1 Scanning
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-SCN-01 | P0 | Launch the system scanner from the Scan tool | Android: ML Kit Document Scanner opens with full mode (crop, rotate, filters, cleaning); iOS: `VNDocumentCameraViewController` opens. Both support multiple pages in one session |
| FR-SCN-02 | P0 | Page limit | Max 50 pages per job. Android passes `pageLimit = 50 − pagesAlreadyInJob`; iOS stops accepting after 50 total with a message on return ("Only the first 50 pages were kept.") |
| FR-SCN-03 | P0 | Gallery import (Android) | ML Kit `isGalleryImport = true`, so users can scan an existing photo. iOS: not offered inside VisionKit; the empty state offers "Choose photos instead" (→ Images to PDF) on both platforms |
| FR-SCN-04 | P0 | Cancel is silent | Cancelling the system scanner returns to the previous screen with no error and no history row |
| FR-SCN-05 | P0 | Pages copied into the job directory | Every returned image is moved/copied into `cache/jobs/<draftId>/in/` immediately (ADR-007); system temp URIs are never kept |
| FR-SCN-06 | P0 | No Google Play services (Android) | Detected before launch (`GoogleApiAvailability`). Message: "Scanning needs Google Play services, which isn't on this phone." with **Choose photos instead** → Images to PDF |
| FR-SCN-07 | P0 | First-time module download | If ML Kit reports the scanner module is unavailable/downloading and the device is offline: "The scanner needs a one-time download. Connect to the internet and try again." with Retry. If downloading: indeterminate "Getting the scanner ready…" for up to 60 s, then the same message |
| FR-SCN-08 | P0 | iOS camera permission | First launch triggers the system prompt (VisionKit). If denied/restricted: inline banner "DocuKit can't use the camera. Allow it in Settings." with **Open Settings** and **Choose photos instead** |
| FR-SCN-09 | P0 | Device can't scan | iOS `VNDocumentCameraViewController.isSupported == false` (e.g. no camera, simulator) → same banner as FR-SCN-06 with the iOS wording |

### 2.2 Review & output
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-SCN-10 | P0 | Review screen | All scanned pages shown in order as thumbnails; page count shown |
| FR-SCN-11 | P0 | Reorder, rotate, delete | Drag to reorder (plus "Move to…" a11y action); rotate ±90°; delete with undo snackbar; deleting the last page asks "Discard this scan?" |
| FR-SCN-12 | P0 | Add pages | **Add pages** relaunches the scanner; new pages append to the end, respecting the 50-page limit |
| FR-SCN-13 | P0 | Output format | PDF (default) or JPG images. PDF uses `ImageToPdfBuilder`; JPG uses `MultiOutput` (one file per page, optional ZIP from 1.1) |
| FR-SCN-14 | P0 | Page size | A4 (default; Letter in US/CA/MX/PH locales, same rule as Image→PDF), Letter, **Fit to scan** (page = image aspect at 200 dpi). Margins: none (scans are already cropped) |
| FR-SCN-15 | P0 | Quality | High (JPEG q85, ≤ 200 dpi at page size — default) / Compact (q65, ≤ 150 dpi) |
| FR-SCN-16 | P0 | File name | Default `Scan_yyyyMMdd_HHmm.pdf` (or `…_p01.jpg` …); editable via D3 |
| FR-SCN-17 | P0 | Validation | PDF: page count == review page count, first page renders. JPG: each file decodes and count matches |
| FR-SCN-18 | P0 | Originals | Scanned images are app-generated; the user's gallery photos imported via ML Kit are never modified (checksum test on gallery import) |
| FR-SCN-19 | P0 | Unsaved scan warning | Back from Review with pages → D4 "Discard this scan? The scanned pages will be deleted." |
| FR-SCN-20 | P1 | Process-death recovery | If Android kills the app while the scanner is open, the returned result is still received on relaunch and lands in Review (activity-result restoration); scanned pages already in the draft are restored from `draft_scanDocument` for 24 h |
| FR-SCN-21 | P1 | "Rescan this page" | Overflow on a page → reopens the scanner with `pageLimit = 1`; the new page replaces the selected one |
| FR-SCN-22 | P2 | Android launcher shortcut | Long-press the app icon → **Scan** (static shortcut, deep link `/tool/scan?autostart=1`) |

### 2.3 Discovery
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-SCN-23 | P0 | Home | New "Scan & Text" category with the Scan card (scan gradient) |
| FR-SCN-24 | P0 | Quick action | Chip **Scan** → `/tool/scan?autostart=1` (opens the scanner immediately) |
| FR-SCN-25 | P0 | Search | Keywords: scan, scanner, camera, photo of document, paper, receipt, notes, digitize, capture, document camera, cam scanner |
| FR-SCN-26 | P0 | Tour | One new step (Scan card), shown as a "New in DocuKit" step to existing users (`tour_version` +1) |
| FR-SCN-27 | P1 | Hook for 1.3 | `ScanOptions` has a `makeSearchable` field (always false in 1.2) and the review screen reserves an option slot; no visible UI |

## 3. Screens

### S27 · Scan tool entry (`/tool/scan`)

The tool route shows the entry state only until the scanner returns pages; then it becomes the Review screen (S29). With `?autostart=1` (Quick action, shortcut) the scanner launches immediately after the first frame.

```
┌──────────────────────────────────────┐
│ ←  Scan Document               ⓘ     │
├──────────────────────────────────────┤
│   ┌──────────────────────────────┐   │
│   │   [illustration: page +      │   │  PickerDropCard variant (scan gradient icon)
│   │    camera corners]           │   │
│   │   Scan pages with your camera│   │
│   │   Edges are found and        │   │
│   │   straightened for you.      │   │
│   │   [  📷  Start scanning  ]   │   │  FilledButton
│   └──────────────────────────────┘   │
│   Have photos already?               │
│   Choose photos instead ›            │  → /tool/image-to-pdf
│                                      │
│ ── 24 dp gap + divider ──            │
│ [ bottom banner — ADMOB_BANNER_TOOLS ]│
└──────────────────────────────────────┘
```

| State | Display |
|---|---|
| Ready | As above |
| Checking availability (Android, ≤ 1 s) | Button shows a small spinner |
| Getting the scanner ready (module download) | Inline progress "Getting the scanner ready…" (indeterminate), Cancel |
| Offline, module missing | `InlineBanner` warning: copy `scn_err_module_offline` + **Try again** |
| No Play services / device unsupported | `InlineBanner` error: `scn_err_unavailable_*` + **Choose photos instead** |
| iOS camera denied | `InlineBanner`: `scn_err_camera_denied` + **Open Settings** + **Choose photos instead** |

*As built (T9.4):*
- S27 has no sticky action bar: Start scanning sits in the card, so `ToolScaffold.action` is now optional.
- `ToolScaffold.showAd: false` (`AppBottomBanner.hidden`) collapses the banner while "Getting the scanner ready…" shows.
- **Open Settings** uses a new `docukit_native.openAppSettings` (Android app-details settings; iOS `openSettingsURLString`) through `DeviceServices`.
- A storage failure shows `errInsufficientStorageTitle`.
- The illustration is the scan-gradient icon tile.
- A result delivered after process death is taken on the first frame and appended (FR-SCN-20).

### S28 · System scanner (not app-owned)
Android ML Kit UI or iOS VisionKit UI. **No ads, no DocuKit chrome.** DocuKit only configures it (§4).

### S29 · Scan Review (`/tool/scan`, state = has pages)

```
┌──────────────────────────────────────┐
│ ←  Scan Document         ↶  ↷   ⋮   │  undo/redo, overflow: Discard scan
├──────────────────────────────────────┤
│ 4 pages                     + Add pages│
│ ┌────┐ ┌────┐ ┌────┐                 │  ImageThumbTile grid (3 cols phone)
│ │ 1  │ │ 2  │ │ 3  │                 │  rotate ⟳ bottom-left, ✕ top-right,
│ └────┘ └────┘ └────┘                 │  long-press drag; tap → full preview
│ ┌────┐                               │
│ │ 4  │                               │
│ └────┘                               │
│ ┌ Save as ───────────────────────────┐│  Option cards (UI_REFRESH §4)
│ │ ( ● PDF )  ( ○ JPG images )        ││
│ ├ Page size ─────────────────────────┤│  hidden for JPG
│ │ [A4 ▾]  (A4 · Letter · Fit to scan)││
│ ├ Quality ───────────────────────────┤│
│ │ ( ● High )  ( ○ Compact )          ││
│ ├ Name ──────────────────────────────┤│
│ │ Scan_20261028_1405.pdf          ✎  ││
│ └────────────────────────────────────┘│
│ [        Save scan (4 pages)       ]  │  sticky primary (gradient pill)
│ ── 24 dp gap + divider ──             │
│ [ bottom banner — ADMOB_BANNER_TOOLS ]│
└──────────────────────────────────────┘
```

- Primary label: `scn_run_pdf` "Save scan ({n} pages)" or `scn_run_jpg` "Save {n} images".
- Tap a page → full-screen page preview (pinch-zoom, swipe) — **no ads** (like the Organizer page preview).
- Overflow on a page tile: Details (D1), Rescan this page (P1), Rotate, Move to…, Delete.
- After **Save** → standard Processing (S10) → Result (S11, single PDF) or the multi-output Result from 1.1 (JPG).
- Back with pages → D4 (`scn_discard_title/body`).
- Tablet ≥ 840 dp: grid left, options right (same as other tool screens).

*As built (T9.5):*
- The page tile has ✕ (top-right), ⟳ right (bottom-left) and ⋮ (bottom-right). The ⋮ menu holds Details, Rescan this page, Rotate left, Rotate right, Move to… and Delete; the number badge sits top-left. Delete shows "Page deleted" with Undo.
- Page size is a segmented choice (A4 · Letter · Fit to scan), hidden for JPG.
- The name is edited as a base name (`Scan_<stamp>`): shown as `.pdf`, or as `_p01.jpg` for JPG.
- **Not built (proposed for later):** the app-bar ↶/↷ undo/redo and the app-bar "Discard scan" item. Undo covers deletes, and back → D4 discards. The tool ⋮ already holds the favourites pin (FR-FAV-01).
- Tablet: options go below the grid, not in a right-hand column. The grid and the options share one column, so S27/S29 can switch in place.

### Ad placement summary
| Screen | Banner | Notes |
|---|---|---|
| S27 entry | `ADMOB_BANNER_TOOLS` with 24 dp gap + divider | Not while the module-download progress is showing (the screen is transient) |
| S28 system scanner | **None** | System UI |
| S29 review | `ADMOB_BANNER_TOOLS` with gap | Hidden while the keyboard is open (rename) |
| Full-screen page preview | **None** | Same as Organizer preview |
| Processing / Result | Existing rules | AD-2, AD-3 unchanged |

## 4. Implementation

### 4.1 Packages
| Need | Choice | Licence | Notes |
|---|---|---|---|
| Android scanner | `com.google.android.gms:play-services-mlkit-document-scanner` (Gradle dependency of `docukit_native`) | Google APIs ToS (closed-source; distributed via Play services) | Beta. **Verify** the current version and API at T9.0. No camera permission needed |
| iOS scanner | VisionKit (`VNDocumentCameraViewController`), system framework | Apple SDK | iOS 13+; our floor is 15/15.5 |
| Play services check | `com.google.android.gms:play-services-base` (`GoogleApiAvailability`) | Google APIs ToS | Probably already transitively present via `google_mobile_ads`; **verify** |
| PDF building | existing `ImageToPdfBuilder` (`pdf` package) | Apache-2.0 | Reused unchanged |
| JPG output | existing `ImageEngine.transform` + `MultiOutput` (1.1) | — | |
| Fallback wrapper (only if the spike fails) | `cunning_document_scanner` (wraps both) | MIT (**verify**) | Use only behind the same `DocumentScanner` interface |

The Flutter plugin `google_mlkit_document_scanner` (Android-only) is **not** used: our own channel keeps one interface for both platforms and lets us copy files into the job directory natively (ADR-041).

### 4.2 Dart contract (`lib/core/scan/`)
```dart
abstract interface class DocumentScanner {
  Future<ScannerAvailability> availability();     // ready | needsDownload | noPlayServices | unsupported | cameraDenied
  Future<ScanOutcome> scan({required int maxPages, required String destDir, bool allowGalleryImport = true});
}

sealed class ScanOutcome {}
class ScanCompleted extends ScanOutcome { final List<String> pagePaths; }   // JPEGs already inside destDir, in order
class ScanCancelled extends ScanOutcome {}
class ScanFailed extends ScanOutcome { final ScanErrorCode code; }           // moduleUnavailable | offline | noPlayServices | unsupported | cameraDenied | storage | unknown

class ScanOptions {             // review-screen state that drives the job
  final ScanOutputFormat format;   // pdf | jpg
  final ScanPageSize pageSize;     // a4 | letter | fitToScan
  final ScanQuality quality;       // high | compact
  final String baseName;
  final bool makeSearchable;       // 1.3 hook; always false in 1.2 (ADR-043)
}
```
`DocumentScannerImpl` calls `docukit_native`; tests use `FakeDocumentScanner`.
- **As built (T9.3):** the implementation is `NativeDocumentScanner`. The interface also has `prepare()` (the module download) and `takeRestored()` (FR-SCN-20). `ScanOptions` and its enums arrive with `ScanOperation` in T9.6. `ScanController` (`lib/features/scan/application/`) owns only the scan flow: phase (checking / preparing / scanning / adding), the banner (`moduleOffline`, `noPlayServices`, `unsupported`, `cameraDenied`, `storage`, `unknown`) and the notice (`truncated`, `limitReached`). It returns the inspected pages; S29 appends them to the shared page model (`ToolInputs`, as on Images to PDF), so reorder, rotate and delete aren't duplicated. The 60 s wait is `scanPrepareTimeoutProvider`. Offline, a failed download or a timeout all show `moduleOffline` with Retry.

### 4.3 Native method: `scanDocument`
MethodChannel `docukit/native`, method `scanDocument`.

| Arg | Type | Meaning |
|---|---|---|
| `maxPages` | int | 1–50 |
| `destDir` | String | Absolute path of `cache/jobs/<draftId>/in/` |
| `allowGalleryImport` | bool | Android only |

Returns `{status: "completed"|"cancelled"|"failed", pagePaths: [String], errorCode?: String}`.

**Android (Kotlin)**
```
options = GmsDocumentScannerOptions.Builder()
    .setScannerMode(SCANNER_MODE_FULL)          // crop, rotate, filters, cleaning
    .setGalleryImportAllowed(allowGalleryImport)
    .setPageLimit(maxPages)
    .setResultFormats(RESULT_FORMAT_JPEG)       // JPEG only; DocuKit builds the PDF itself
    .build()
scanner = GmsDocumentScanning.getClient(options)
scanner.getStartScanIntent(activity)
   .addOnSuccessListener { intentSender -> launcher.launch(IntentSenderRequest.Builder(intentSender).build()) }
   .addOnFailureListener { e -> map MlKitException code → moduleUnavailable / unknown }
onActivityResult(RESULT_OK): GmsDocumentScanningResult.fromActivityResultIntent(data).pages
   → for each page.imageUri: contentResolver.openInputStream → copy to destDir/page_###.jpg (8 KB buffer, background thread)
RESULT_CANCELED → cancelled
```
- Register the `ActivityResultLauncher` in the plugin's `onAttachedToActivity` (via `ActivityPluginBinding.addActivityResultListener`), so a result delivered after process death is still received (FR-SCN-20). Persist `destDir` + `maxPages` in `SharedPreferences` before launching, and read them back if the engine restarts.
- Before launch: `GoogleApiAvailability.isGooglePlayServicesAvailable(ctx) != SUCCESS` → `failed/noPlayServices`.
- Module download: ML Kit downloads the scanner module through Play services on first use. If `getStartScanIntent` fails with an "unavailable" code and `ConnectivityManager` reports no network → `offline`; otherwise `moduleUnavailable`. Optionally pre-request with `ModuleInstallClient` (**verify** availability for the document scanner module).
- All names above are from the ML Kit document scanner API — **verify** exact class/constant names against the pinned version at T9.0.
- **As built (T9.1):** two more methods — `prepareScanner` (the module download, FR-SCN-07) and `takeRestoredScan` (FR-SCN-20) — plus a debug-only `debugSetScanOverride`. Pages are numbered after those already in `destDir`, so "Add pages" never overwrites. See ARCHITECTURE §6.4.

**iOS (Swift)**
```
guard VNDocumentCameraViewController.isSupported else → failed/unsupported
check AVCaptureDevice.authorizationStatus(for: .video): .denied/.restricted → failed/cameraDenied
vc = VNDocumentCameraViewController(); vc.delegate = self; present full screen from the top VC
didFinishWith scan: for i in 0..<min(scan.pageCount, maxPages):
    img = scan.imageOfPage(at: i)  → jpegData(compressionQuality: 0.92) → destDir/page_###.jpg
    (autoreleasepool per page to bound memory)
didCancel → cancelled ; didFailWithError → failed/unknown
```
- `.notDetermined` is fine: VisionKit triggers the system prompt itself. If the user denies at that prompt, VisionKit fails → map to `cameraDenied`.
- Report `truncated: true` when `scan.pageCount > maxPages` so Dart can show "Only the first 50 pages were kept."

### 4.4 Job flow
```
ScanController (Notifier<ScanState>):
  start(): availability() → if not ready, show the matching banner
           outcome = scan(maxPages: 50 − pages.length, destDir: draft.inDir)
           Completed → append pages (as PickedFile via ImageEngine.inspect) → state = review
           Cancelled → nothing ; Failed → banner by code
  run(): ScanOperation (implements ToolOperation<ScanOptions>)
     validateInputs: 1–50 pages, each decodes
     estimateRequiredBytes: Σ page bytes × 1.3
     execute:
        pdf → ImageToPdfBuilder.build(pages with rotation, pageSize, margin: none, quality preset, fitMode: fit)
              fitToScan → page = image aspect, pt = px × 72 / 200 (clamped like "Same as image")
        jpg → for each page: ImageEngine.transform(rotate, jpeg q, longest edge cap = dpi cap at A4) → MultiOutput
     validateOutput: §2.2 FR-SCN-17
```
- Reuse the Images-to-PDF page model (`List<ImagePageItem>` with rotation) so reorder/rotate/delete/undo code is shared, not duplicated.
- Memory: scanner images are typically 2–4 MP; pages are processed one at a time, and the PDF is built in chunks of 20 (existing rule).
- Thumbnails: decode at grid cell size (`ResizeImage`), as on the Images to PDF screen.

*As built (T9.6):*
- PDF uses `ImageToPdfBuilder` with `ImageToPdfSettings(margin: none, fit, orientation: auto, quality: High → q85/200 dpi, Compact → q65/150 dpi)`.
- Fit to scan is `PdfPageSize.image` with the new `imageDpi: 200`. The shared "Same as image" layout keeps 150 dpi for Images to PDF.
- The builder's last step reports `stepSavingScan` ("Saving your scan…").
- JPG caps the long edge at A4 for the quality's dpi (2339 / 1754 px) and never enlarges. Names are `<base>_p01.jpg`…; the base is fixed when Save is tapped.
- `estimateBytes('scanDocument')` = Σ × 1.3.
- Input rows keep the page file names (`page_001.jpg`…), not "Page 1": the names are app-generated, and a localised label can't be stored.

### 4.5 Quick action, search, tour, shortcut
- Add `ToolDescriptor(scanDocument, category: scan, route: '/tool/scan', inputKind: camera, minInputs: 1, maxInputs: 50)` to `toolCatalog`.
- Quick action chip `Scan` (icon `document_scanner`), query `autostart=1`.
- Tour: one step built from the catalogue; bump `tour_version`.
- P2 shortcut: `android/app/src/main/res/xml/shortcuts.xml` static shortcut → deep link `docukit://tool/scan?autostart=1`; register the intent filter; go_router handles it.
  - *As built (ADR-065):* there is no intent filter on MainActivity, because launcher shortcuts use CLEAR_TASK. The shortcut targets the relay `ShortcutActivity`, with data `docukit://open/tool/scan?autostart=1`.

## 5. Data model & settings
| Change | Detail |
|---|---|
| `ToolId.scanDocument` | Added to the drift enum. Migration: none needed for `textEnum` (stored as text), but bump the schema version and add a migration test |
| History `optionsJson` | `{"format":"pdf","pageSize":"a4","quality":"high","pages":4}` — no file names of pages |
| Inputs rows | One `operation_inputs` row per page, `displayName = "Page 1"`… (scans have no user file names) |
| Settings keys | `scan_default_format` (pdf), `scan_page_size` (a4/letter by locale), `scan_quality` (high) |
| Draft | `draft_scanDocument` (page paths, order, rotations, options) for FR-SCN-20 |
| Counters | Scans count towards `stats_total_saved_bytes`? **No** — scans create new content, not savings |

## 6. Permissions, privacy & store impact

| Item | Android | iOS |
|---|---|---|
| Camera permission | **None** declared by DocuKit (ML Kit scanner runs inside Google Play services) — confirm the merged manifest has no `CAMERA` at T9.0 | `NSCameraUsageDescription` = "DocuKit uses the camera to scan documents. Scans stay on your phone." |
| Photo library | Gallery import happens inside the ML Kit UI; no permission | Not used |
| Network | ML Kit may download the scanner module once via Play services | None |
| Data leaving the device | Scanned images are processed on-device. ML Kit / Play services may send API usage and diagnostics to Google — **verify against Google's ML Kit data disclosure** and update the Data safety form (likely "App info and performance → Diagnostics", collected, not shared) if required | VisionKit is on-device; no change |
| Play Data safety | Update only if the ML Kit disclosure requires it (see above) | — |
| App Store privacy label | — | No change (on-device) |
| Privacy policy | Add: "When you scan, the camera images are processed on your phone. On Android, the scanner is provided by Google Play services." | Same sentence (without the Android part) |
| Privacy & About (S17) | Add a "Camera" row to "What DocuKit can access": "Only while you're scanning" | Same |

## 7. Copy (add to COPY.md)

| Key | Text |
|---|---|
| tool_scan_title / subtitle | Scan Document / Turn paper into a PDF |
| home_section_scan | Scan & text |
| qa_scan | Scan |
| scn_entry_title | Scan pages with your camera |
| scn_entry_body | Edges are found and straightened for you. |
| scn_start | Start scanning |
| scn_have_photos | Have photos already? |
| scn_choose_photos | Choose photos instead |
| scn_preparing | Getting the scanner ready… |
| scn_err_module_offline | The scanner needs a one-time download. Connect to the internet and try again. |
| scn_err_unavailable_android | Scanning needs Google Play services, which isn't on this phone. |
| scn_err_unavailable_ios | This device can't scan documents. |
| scn_err_camera_denied | DocuKit can't use the camera. Allow it in Settings. |
| scn_err_unknown | The scanner closed unexpectedly. Try again. |
| scn_pages | {count, plural, =1{1 page} other{# pages}} |
| scn_add_pages | Add pages |
| scn_rescan_page | Rescan this page |
| scn_rotate_left / right | Rotate left / Rotate right |
| scn_page_menu | Page options |
| scn_truncated | Only the first {max} pages were kept. |
| scn_limit_reached | You've reached {max} pages. Save this scan to start a new one. |
| scn_save_as | Save as |
| scn_format_pdf / jpg | PDF / JPG images |
| scn_page_fit | Fit to scan |
| scn_quality_high / compact | High / Compact |
| scn_run_pdf | Save scan ({count, plural, =1{1 page} other{# pages}}) |
| scn_run_jpg | Save {count, plural, =1{1 image} other{# images}} |
| scn_discard_title / body | Discard this scan? / The scanned pages will be deleted. |
| scn_delete_last_title | Discard this scan? |
| step_saving_scan | Saving your scan… |
| tour_scan_title / body / example | Scan Document / Scan paper with your camera. Edges are found and straightened automatically. / Notes, receipts or a signed form in one PDF. |
| priv_access_camera_label | Camera |
| priv_access_camera | Camera, only while you're scanning |
| search keywords (`tool_scan_keywords`) | scan, scanner, camera, photo of document, paper, receipt, notes, digitize, capture, document camera |

## 8. Tests

| Test | Type |
|---|---|
| `ScanController`: completed → review; cancelled → no change and no history; each `ScanFailed` code → the right banner; page limit arithmetic (50 − existing) | Unit |
| Reorder/rotate/delete/undo reuse the Images-to-PDF page model (shared tests still pass) | Unit |
| `ScanOperation`: PDF page count == pages; fitToScan page size maths; JPG multi-output count and decode; `makeSearchable` ignored | Unit (fake image engine) |
| S27 states: ready, preparing, offline, unavailable, camera denied — each with correct actions; banner slot present with gap; no banner while preparing | Widget |
| S29: options hide page size for JPG; primary label pluralisation; D4 on back; "Add pages" disabled at 50 | Widget |
| Process-death draft restore (FR-SCN-20) | Widget + manual |
| Native: Android result after `Don't keep activities` dev option (simulates process death) | Manual |
| Gallery import does not modify the source photo (SHA-256) | Manual + integration helper |

**Corpus additions:** `scan_fixture_01..04.jpg` (paper photos at 3 MP) for the fake scanner in integration tests; the real scanner can't be automated reliably — manual regressions below.

### Regressions
| # | Steps | Expected |
|---|---|---|
| R37 | Android: Scan → 3 pages (one tilted) → review → Save PDF | 3 pages, straightened, opens in a PDF viewer; history row |
| R38 | iOS: same as R37 with VisionKit | Same |
| R39 | Add pages after review; reorder; rotate; delete with undo; Save JPG | Correct order/rotation; N JPGs, ZIP offered (1.1 rule) |
| R40 | Android: gallery import inside the scanner | Imported photo is scanned; original photo unchanged |
| R41 | iOS: deny camera → banner → Open Settings → allow → scan works. Android: airplane mode on a device that never used the scanner → offline message → Retry online works | As described |
| R42 | Cancel scanner; back with pages (D4); enable "Don't keep activities", scan, return | Silent cancel; discard warning; pages restored after process death |

## 9. Tasks (M9)

- [~] 🔬 **T9.0 Scanner spike (½–1 day — gate).** Android: add the ML Kit document scanner dependency to `docukit_native`, launch with full mode + JPEG + gallery import, copy results into a dir; confirm the merged manifest has no CAMERA permission; record behaviour on first use offline; check `GoogleApiAvailability` and the module-download path. iOS (when Xcode is available): VisionKit present/dismiss, page images to JPEG, permission denied path. *Accept:* DECISIONS entry (ADR-041 confirmed or fallback chosen) with the exact API names and versions that worked.
- [~] **T9.1 Native `scanDocument` (Android).** Plugin method per §4.3 incl. activity-result restoration and error mapping. *Accept:* returns ordered JPEGs inside `destDir`; cancel → `cancelled`; no Play services → `noPlayServices` (test with a fake availability flag in debug). — *Built 2026-10-28:* channel contract (unit) + emulator integration test (`integration_test/scan_native_test.dart`): the debug flag gives `noPlayServices` and `cancelled`; with the module missing, online → `moduleUnavailable`, airplane mode → `offline` (and `prepareScanner` → `offline`). ⚠️ The ordered-JPEG copy, a real cancel and the process-death result need a device that can download the scanner (the emulator image can't; ADR-041) — checked in R37/R42.
- [ ] 🍎 **T9.2 Native `scanDocument` (iOS).** Per §4.3. *Accept:* R38 and the R41 iOS half on a device. (May trail T9.1 if Xcode isn't ready.)
- [x] **T9.3 `DocumentScanner` + fake + `ScanController`.** *Accept:* §8 unit tests. — *Done 2026-10-28:* `lib/core/scan/document_scanner.dart` (interface + `NativeDocumentScanner`), `FakeDocumentScanner` (test/helpers/fakes.dart), `lib/features/scan/application/scan_controller.dart`; 27 controller tests + 4 mapping tests.
- [x] **T9.4 S27 entry screen + all states + ads slot.** *Accept:* widget tests for every state. — *Done 2026-10-28:* `lib/features/scan/presentation/scan_screen.dart`; the tool ID `scanDocument` (category `scan`, input `camera`), the `/tool/scan` route (`?autostart=1`), and Home's "Scan & text" section, needed now because the tour gives every catalogue tool a step. The quick action, search keywords, tour-version bump and settings defaults stay in T9.7. All COPY §8.2 strings are in the ARB (`copy_keys_test` now checks §8.2). Widget tests: `scan_entry_test.dart` (ready, checking, preparing + Cancel, offline, no Play services, unsupported, camera denied, unknown, Try again, Open Settings, dismiss, autostart, pages returned) and `banner_placement_test.dart` (S27 gap + divider; no banner while preparing). Checked on the emulator: Home section, S27, and the real "Getting the scanner ready…" state.
- [x] **T9.5 S29 review screen** (shared page model, options, D4, add pages, page preview without ads). *Accept:* FR-SCN-10…16, 19, 21. — *Done 2026-10-28:* `scan_review.dart` (page grid, options cards, full-screen preview) inside `scan_screen.dart`; `ScanOptions` (`lib/core/scan/scan_options.dart`) and `scanOptionsProvider` (options draft); pages use `ToolInputs` (new: rotate left, `insertAt` for Undo, `addPages(replaceAt:)`); D4 copy via `ToolScaffold.leaveCopy`. 14 widget tests (`scan_review_test.dart`) + 6 options tests. The Save button is shown but does nothing until T9.6 wires `ScanOperation`.
- [x] **T9.6 `ScanOperation`** (PDF via `ImageToPdfBuilder`, JPG via `MultiOutput`) + validation + history. *Accept:* FR-SCN-13…18. — *Done 2026-10-28:* `scan_operation.dart`: `ScanPdfOperation` (ToolOperation → S11) and `ScanJpgOperation` (MultiToolOperation → S22, ZIP offered). Save is wired on S29. Schema v3 (no DDL; `schema_v2.sql` fixture + migration tests). Scans don't add to the savings counter (`countsAsSaving`). History shows "N pages · size" for a scanned PDF. Tests: 14 unit + 2 widget; `integration_test/scan_operation_test.dart` passes on the emulator (4 pages → A4 PDF in 7.6 s, Fit to scan 720×540 / 540×720 pt, 3 JPGs `_p01…`, pages unchanged). FR-SCN-18 (gallery photo unchanged) needs the real scanner: R40.
- [x] **T9.7 Discovery:** catalogue entry, Home category, Quick action chip, search keywords, tour step (`tour_version` bump), settings defaults. *Accept:* FR-SCN-23…26. — *Done 2026-10-28:* catalogue entry and Home "Scan & text" came in T9.4. Here: the Scan chip (last in the row) → `/tool/scan?autostart=1`; the FR-SCN-25 keywords (each ranks Scan first; "jpg to pdf" still → Images to PDF); `currentTourVersion = 3` with `toolTourVersion[scanDocument] = 3` (1.1 users see one step, 1.0 users see the 1.1 steps + Scan); settings `scan_default_format` / `scan_page_size` (`a4|letter|fit`, Letter by locale) / `scan_quality`, remembering the last choice like the 1.1 tools.
- [x] **T9.8 Privacy & store:** Info.plist key, S17 camera row, privacy policy sentence, ML Kit data-disclosure check → Data safety update if needed. *Accept:* STORE_PRIVACY_CHECKLIST updated with a dated note. — *Done 2026-10-28:* `NSCameraUsageDescription` (Xcode build not run); S17 Camera row; the policy sentence plus the ML Kit diagnostics clause (owner to review), in-app and hosted; the disclosure was checked and Data safety needs no new data types (STORE_PRIVACY_CHECKLIST "1.2").
- [x] **T9.9 (P2) Android launcher shortcut.** — *Done 2026-10-29 (owner chose the relay, ADR-065):* `shortcuts.xml` → `ShortcutActivity` (not exported, own task) → `PendingRoute` → `shortcutRouteProvider` → pushed `/tool/scan?autostart=1`; autostart waits until DocuKit is in front. 6 widget tests; checked on the emulator (picker kept, nothing cleared, cold start).
- [~] **T9.10 Regression R1–R42** on the Android emulator + a real phone; iOS once available. — *Emulator done 2026-11-01* (TESTING §4.3): host 705 + 10 + 20 goldens green, 10 device suites incl. `scan_native_test` / `scan_operation_test` pass; R39 and R42 (cancel, discard) at widget level. Version **1.2.0 (build 3)**. ⚠️ The scanner UI rows (R37, R40, R41 Android, R42 process death), the interactive suites and iOS (T9.2, R38, R41) are the owner's.

Order: T9.0 → T9.1 → T9.3 → T9.4 → T9.5 → T9.6 → T9.7 → T9.8 → T9.10; T9.2 when Xcode is ready; T9.9 optional.

## 10. Claude Code prompts

**1 — Spike (T9.0)**
```
Task T9.0 from docs/features/RELEASE_V1_2.md. Time box: 1 day. Build a throwaway debug screen (kDebugMode only) that:
- launches the ML Kit Document Scanner from docukit_native (full mode, JPEG results, gallery import on, pageLimit 5) and copies the result images into a temp dir;
- reports Google Play services availability and what happens on first use in airplane mode;
- prints the merged release manifest permissions (confirm there is no CAMERA).
Update the DECISIONS.md entry ADR-041 with the exact dependency version, class names and constants that worked. Don't build production code.
```

**2 — Native + controller (T9.1, T9.3)**
```
Tasks T9.1 and T9.3 per docs/features/RELEASE_V1_2.md §4.2–§4.4. Implement scanDocument in docukit_native (Android now; leave a Swift stub that returns failed/unsupported with a TODO for T9.2), the DocumentScanner interface, FakeDocumentScanner and ScanController.
Register the activity-result listener so results survive process death (FR-SCN-20). Copy pages into destDir on a background thread.
Write the unit tests in §8 first. Report commands run and real results.
```

**3 — Screens + operation (T9.4–T9.7)**
```
Tasks T9.4–T9.7 per docs/features/RELEASE_V1_2.md §3–§5 and §7. Reuse the Images-to-PDF page model and ImageToPdfBuilder; JPG output uses MultiOutput from 1.1. Ads: ADMOB_BANNER_TOOLS with the 24 dp gap on S27 and S29 only; none on the scanner, page preview or while "Getting the scanner ready" shows. Add the catalogue entry, Home "Scan & text" category, Scan quick action (autostart=1), search keywords and the tour step (bump tour_version). Strings from §7 into ARB.
Widget tests for every state in §3 first. Build a debug APK to ~/Desktop/DocuKit-debug.apk (check free disk space first; stop under 5 GB). Report results.
```

**4 — iOS + privacy (T9.2, T9.8) — when Xcode is ready**
```
Tasks T9.2 and T9.8 per docs/features/RELEASE_V1_2.md. Implement scanDocument in Swift with VNDocumentCameraViewController (isSupported check, camera-denied mapping, autoreleasepool per page, truncated flag). Add NSCameraUsageDescription with the wording in §6, the S17 camera row and the privacy-policy sentence. Check Google's ML Kit data-disclosure page and tell me exactly what (if anything) changes in Play Data safety. Run R38 and R41 on the simulator/device and report.
```

## 11. Risks & decisions

| Risk | Impact | Mitigation |
|---|---|---|
| ML Kit Document Scanner is beta | API changes, regional or device gaps | Behind `DocumentScanner`; spike pins a version; fallback wrapper or "Choose photos instead" |
| Devices without Google Play services (Huawei, some custom ROMs) | No scanner on those phones | Clear message + Images to PDF fallback (FR-SCN-06) |
| First-use module download needs network | First scan fails offline | Specific message + Retry (FR-SCN-07); consider a background pre-download when online (P2) |
| Process death while the scanner is open (low-RAM Android) | Lost scan | Activity-result restoration + draft (FR-SCN-20); tested with "Don't keep activities" |
| iOS camera denied | Tool unusable | Settings deep link + photos fallback |
| Scan quality varies by device | Disappointing results | System scanners do the heavy lifting; DocuKit adds "Rescan this page" |

**ADR-041 — Use the system document scanners via our own native channel · Proposed (confirm at T9.0)**
*Context:* building a camera + edge-detection pipeline ourselves is weeks of work and hard to make good. *Decision:* Android ML Kit Document Scanner (Play services) and iOS VisionKit, both behind `docukit_native.scanDocument`, returning JPEGs only; DocuKit builds the PDF with its existing builder. *Consequences:* no camera permission on Android; no scanner on devices without Play services; the scanning UI looks different on each OS (accepted — it's the native experience users know).

**ADR-042 — Scanner output always JPEG pages, never the scanner's own PDF · Accepted**
*Reason:* one PDF path for the whole app (page sizes, quality presets, chunking, validation), and reordering/rotation after scanning. ML Kit's `RESULT_FORMAT_PDF` is not requested.

**ADR-043 — No visible "Make searchable" in 1.2 · Accepted**
*Reason:* a disabled control that says "coming soon" adds clutter and invites "doesn't work" reviews. `ScanOptions.makeSearchable` exists as a hook; 1.3 adds the toggle to S29 and wires it to OCR.
