# DocuKit 1.1 — Productivity Release

> Follows the conventions in `docs/FULL_PRODUCT.md §4`. IDs: FR-BAT / FR-CNV / FR-SPL / FR-P2I / FR-EXT / FR-FAV / FR-SHR · tasks T8.x (milestone M8) · screens S21–S26 · regressions R27–R36 · ADRs ADR-036–040 (DECISIONS.md).
> Everything in `CLAUDE.md` still applies (originals untouched, outputs validated, no fabricated progress, no logging of names/paths/content, ARB strings, semantics, both platforms).

## 1. Summary & scope

1.1 makes DocuKit faster for repeat work and adds three small tools that reuse the existing engines.

**In scope**
| Feature | What the user gets |
|---|---|
| Batch Compress / Resize | Pick up to 50 images, apply one set of options, get every result with per-file and total savings |
| Convert Image (new tool) | HEIC / PNG / WebP / JPG → JPG / PNG / WebP (HEIC output on iOS only), single or batch |
| Split PDF (new tool) | Split by ranges ("1-3, 5, 8-10"), every N pages, or each page into its own PDF |
| PDF to Images (new tool) | All pages or a range, JPG or PNG, 72 / 150 / 300 dpi |
| Extract selected pages | Organizer: selected pages → new PDF, original untouched |
| Favourites | Pin up to 6 tools to a row at the top of Home |
| Share to DocuKit | Send images/PDFs from Gallery, Files, WhatsApp, Mail etc. into DocuKit (S19 chooser) |
| Multi-output plumbing | One job → many files: save all to a folder, save one ZIP, share many |

**Out of scope (later or never)**
- Batch for Images→PDF/Merge/Reduce (they already take many inputs or produce one output).
- Splitting by bookmarks or file size ("split into 10 MB parts") — backlog.
- Odd/even extraction as a split mode — reachable via Organizer "Select odd/even" (P2 backlog), not a split mode.
- Converting to/from GIF, TIFF, BMP, AVIF.
- Background batch processing while the app is closed (ADR-009 still applies).

## 2. Requirements

### 2.1 Multi-output jobs (shared)
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-BAT-01 | P0 | A job may produce N outputs (`MultiOutput`) | Result shows every output with name, size, status; job status = SUCCESS if ≥1 output succeeded and none crashed the run, PARTIAL if some failed |
| FR-BAT-02 | P0 | Save all to a folder | Android: user picks a folder (`ACTION_OPEN_DOCUMENT_TREE`), all succeeded outputs are written there; iOS: export picker with all URLs. Name collisions get ` (1)`. Summary snackbar "Saved 18 files" |
| FR-BAT-03 | P0 | Save as one ZIP | ZIP built by streaming from disk (no whole-file buffering); named `DocuKit_<tool>_<yyyyMMdd_HHmm>.zip`; contains only succeeded outputs |
| FR-BAT-04 | P0 | Share many | System share sheet with all succeeded outputs (max 50 files per share; if more, offer ZIP) |
| FR-BAT-05 | P0 | Partial failure continues | One bad input never stops the batch; failed items list the error title from COPY §4 and "Original not changed" |
| FR-BAT-06 | P0 | Truthful progress | Determinate "n of N images/pages"; cancel stops after the current item; already-finished outputs are discarded on cancel (nothing half-saved) |
| FR-BAT-07 | P0 | Storage pre-check for the whole batch | Σ estimates (FEATURE_SPECS §2.3) + 50 MB, checked before the first item |

### 2.2 Batch Compress / Resize
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-BAT-10 | P0 | Image Compressor and Image Resizer accept 1–50 images | Picking 2+ switches the screen to batch layout (S21 grid); 51+ keeps the first 50 with the existing truncation snackbar |
| FR-BAT-11 | P0 | One set of options for all | Quality / target size / format / max size (compress); pixels / percent / preset / fit (resize) apply to every image |
| FR-BAT-12 | P0 | Resize "Pixels" mode in batch uses **fit inside W×H** by default | Each image keeps its own ratio inside the box unless the user chooses Stretch/Crop (FR-RES-07); a preset (e.g. Passport) applies its exact size with the chosen fit |
| FR-BAT-13 | P0 | Target-size mode per image | Each image is searched independently (FEATURE_SPECS §3.5); items that miss the target are marked "Closest: 112 KB" |
| FR-BAT-14 | P0 | Total savings | Result header shows Σ before, Σ after, and % change (only for succeeded items) |
| FR-BAT-15 | P1 | Remove a single item from results | "Discard" on one output removes it from save/share/ZIP |

### 2.3 Convert Image
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-CNV-01 | P0 | Inputs: JPEG, PNG, WebP, HEIC/HEIF, 1–50 | Same validation as FR-IMG-01 |
| FR-CNV-02 | P0 | Outputs: JPG, PNG, WebP; HEIC only on iOS | The format list is built from `ImageEngine.supportedOutputFormats()` (spike T8.0 confirms WebP encode on both OSes) |
| FR-CNV-03 | P0 | Quality slider for lossy outputs (JPG/WebP), default 90 | Hidden for PNG |
| FR-CNV-04 | P0 | Alpha warning | Any input with transparency → JPG shows "Transparent areas will become white." before running; composited onto white |
| FR-CNV-05 | P0 | Metadata toggle (default: remove location & camera info) | Same behaviour as FR-IMG-09 |
| FR-CNV-06 | P0 | Same-format inputs are allowed | Re-encoding JPG→JPG works (useful to strip metadata); hint "Same format: the file is re-saved" |
| FR-CNV-07 | P0 | Dimensions never change | Output w×h == input oriented w×h (magic-byte + header test) |

### 2.4 Split PDF
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-SPL-01 | P0 | One PDF input (2–2,000 pages) | 1-page PDFs show "This PDF has only one page." and disable Split |
| FR-SPL-02 | P0 | Mode A — Custom ranges | Text field accepts the grammar in §4.6; each comma-separated part becomes one output PDF; live preview "3 files: pages 1–3 · page 5 · pages 8–10" |
| FR-SPL-03 | P0 | Mode B — Every N pages | N stepper 1–(pages−1); last file may be shorter; preview "12 files" |
| FR-SPL-04 | P0 | Mode C — Each page | One PDF per page; capped at 500 outputs (above that: suggest Every N) |
| FR-SPL-05 | P0 | Validation | Out-of-range, reversed (5-3), zero, overlapping-allowed? → **overlaps allowed** (a page may appear in two outputs); errors inline: "Page 40 doesn't exist (this PDF has 36 pages)" |
| FR-SPL-06 | P0 | Output names | `<base>_part01.pdf` … zero-padded to the output count; Mode A uses `<base>_p1-3.pdf`, `<base>_p5.pdf` |
| FR-SPL-07 | P0 | Validate every output | Each output reopens and page count matches its range |
| FR-SPL-08 | P0 | Encrypted PDFs blocked | Same as FR-PDF-ENC |

### 2.5 PDF to Images
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-P2I-01 | P0 | One PDF input | Encrypted/corrupt handled as in FR-MRG-03 |
| FR-P2I-02 | P0 | Pages: All or a range (same grammar as §4.6, union of parts, in document order) | Preview "24 images" |
| FR-P2I-03 | P0 | Format JPG (default, q90) or PNG | |
| FR-P2I-04 | P0 | Resolution 72 / 150 (default) / 300 dpi | Pixel size = page pt × dpi / 72, capped to 40 MP per page (cap shown: "Page 3 was limited to 6000 px") |
| FR-P2I-05 | P0 | Bounded memory | One page rendered at a time, encoded, released; peak growth < 200 MB at 300 dpi on A4 |
| FR-P2I-06 | P0 | Names | `<base>_page001.jpg` … zero-padded to page count digits (min 2) |
| FR-P2I-07 | P1 | Transparent page background for PNG | Off by default (white); toggle "Keep transparent background" |

### 2.6 Extract pages (Organizer)
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-EXT-01 | P0 | "Extract" action in the selection bar (Organizer) | Enabled when ≥1 page selected; creates a new PDF with the selected pages in current UI order, with their current rotation |
| FR-EXT-02 | P0 | Original and current edits untouched | The Organizer session keeps its edit stack; extraction is a separate job; history records tool `pdfOrganize` with `optionsJson.mode = "extract"` |
| FR-EXT-03 | P0 | Default name `<base>_extract.pdf` | Editable via D3 on Result |

### 2.7 Favourites
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-FAV-01 | P0 | Pin/unpin a tool | Long-press a ToolCard → sheet with "Add to favourites"/"Remove from favourites"; tool screen overflow ⋮ has the same toggle. A11y custom action "Add to favourites" on each card |
| FR-FAV-02 | P0 | Favourites row on Home | Shown above Quick actions only when ≥1 pinned; max 6; adding a 7th shows "You can pin up to 6 tools. Remove one first." |
| FR-FAV-03 | P0 | Reorder | "Edit" on the row opens a sheet with a reorderable list (drag + Move up/down actions) |
| FR-FAV-04 | P0 | Persisted | Survives restart; unknown ToolIds (from future/older versions) are ignored silently |
| FR-FAV-05 | P1 | Tour | TOUR step for Favourites appears only once, in the v1.1 "What's new" mini-tour |

### 2.8 Share to DocuKit (receive files)
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-SHR-01 | P0 | Android: appear in the share sheet and "Open with" for images and PDFs | Intent filters for `SEND`, `SEND_MULTIPLE` (`image/*`, `application/pdf`) and `VIEW` (`application/pdf`, `image/*`) |
| FR-SHR-02 | P0 | iOS: appear in "Open in…" / "Copy to DocuKit" for PDFs and images | `CFBundleDocumentTypes` for `com.adobe.pdf`, `public.jpeg`, `public.png`, `public.heic`, `org.webmproject.webp`; `LSSupportsOpeningDocumentsInPlace = NO` |
| FR-SHR-03 | P0 | Cold and warm start | Files arriving while the app is closed or open both reach S19; a running job is never interrupted (incoming files wait; banner "1 file received — open when this job finishes") |
| FR-SHR-04 | P0 | Copy immediately | Every incoming file is copied into `jobs/<draftId>/in/` before any UI; sniffed and validated like picked files; URIs are never kept |
| FR-SHR-05 | P0 | Compatible tools only | S19 lists tools whose `inputKind` matches the received set (rules §4.8); none compatible → "DocuKit can't work with this file type." |
| FR-SHR-06 | P0 | Limits | > 50 images or > 20 PDFs: keep the first N with the truncation message |
| FR-SHR-07 | P1 | Mixed images + PDFs | Chooser offers tools for each group separately ("3 images" section, "1 PDF" section) |

### 2.9 Search & tour
| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-HOME-08 | P0 | Synonyms for new tools (§4.10) | "heic to jpg" → Convert first; "split" → Split first; "pdf to jpg" → PDF to Images first; "batch" / "many photos" → Compressor first |
| FR-TOUR-11 | P0 | Tour steps for Convert, Split, PDF to Images | Steps built from the catalogue (TOUR §2); existing users get a "New in DocuKit" mini-tour (FR-TOUR-10) with these 3 steps + Favourites |

## 3. Screens

New screens: **S21** Batch inputs grid · **S22** Multi-result (batch / split / P2I) · **S23** Convert Image · **S24** Split PDF · **S25** PDF to Images · **S26** Favourites edit sheet. Updated: S03, S04 (batch layout), S07 (Extract), S19 (implemented), S01 (Favourites row).

### S21 · Batch inputs (inside S03/S04/S23 when ≥2 images)
```
① IMAGES (18)                        + Add   ⋮ (Clear all)
  ┌────┐┌────┐┌────┐┌────┐            4-col grid of ImageThumbTile (no order numbers:
  │ ✕  ││ ✕  ││ ⚠  ││ ✕  │            order doesn't matter for batch), ✕ remove,
  └────┘└────┘└────┘└────┘            status badge corner (⚠ warning, ⛔ invalid)
  ...                                  "Show all 18" when > 12 → /tool/:id/review list
  Total 46.2 MB · 2 can't be used [Remove them]
② OPTIONS … (same option groups as single mode)
[      Compress 16 images      ]       count excludes invalid items
──────── 24 dp gap + divider ────────
[ bottom banner: ADMOB_BANNER_TOOLS ]
```
States: invalid items don't block the run (they're skipped) but are listed; 0 valid → button disabled "Add images that DocuKit can open".

### S22 · Multi-result (`/job/:jobId`, result body when `MultiOutput`)
```
┌──────────────────────────────────────┐
│ ✓ 16 of 18 done                Done  │  header; "All done" if no failures
├──────────────────────────────────────┤
│ Before 46.2 MB → After 9.8 MB  −79%  │  totals card (batch compress/resize/convert)
│  (Split/P2I: "12 PDFs · 4.1 MB")     │
│ [ ⬇ Save all… ] [ 🗜 Save as ZIP ]   │  Save all → D5-multi (Android folder / iOS export)
│ [ ⇪ Share all ] [ Edit options ]     │
│ FILES                                │
│ ✓ IMG_2041_compressed.jpg  410 KB −87%  ⋮ (Open, Share, Save, Discard)
│ ✓ IMG_2042_compressed.jpg  388 KB −84%  ⋮
│ ⚠ IMG_2043_compressed.jpg  112 KB  Closest to 100 KB
│ ✕ scan.webp — This file looks damaged. Original not changed.
│ …                                    │  lazy list; tap ✓ row → single-output preview sheet
│ Kept in Recent for 7 days            │
│ Sponsored ── AD-2 native card ──     │  existing AD-2 rules
──────── bottom banner: ADMOB_BANNER_MAIN ────────
```
- "Done" follows AD-3 rules (a batch counts as **one** completed job for interstitial counting).
- Save all outcomes: "Saved 16 files to Download/DocuKit" (Android shows the folder display name), "Saved 16 files" (iOS), cancel = silent, partial failure "Saved 15 of 16. 1 couldn't be written." with Retry.
- All failed → S18 Error with the first error and "None of the files could be processed. Originals not changed."

### S23 · Convert Image (`/tool/image-convert`)
```
① IMAGES — single preview card or S21 grid
② CONVERT TO
  ( ● JPG ) ( ○ PNG ) ( ○ WebP ) ( ○ HEIC — iOS only )
  Quality ───────●── 90         (hidden for PNG)
  Remove location & camera info  [■ on]
  ⚠ Transparent areas will become white.   (if any alpha input → JPG)
  ⓘ 3 images are already JPG. They'll be re-saved.   (same-format hint)
[      Convert 18 images      ]
```

### S24 · Split PDF (`/tool/pdf-split`)
```
① FILE   📄 report.pdf · 36 pages · 4.1 MB   [Change]
② HOW TO SPLIT
  ( ● Custom ranges ) ( ○ Every N pages ) ( ○ Each page )
  Custom:  [ 1-3, 5, 8-10            ]  ⓘ Use commas and dashes
           → 3 files: pages 1–3 · page 5 · pages 8–10
           error: "Page 40 doesn't exist. This PDF has 36 pages."
  Every N: Pages per file  [ − 5 + ]  → 8 files (the last has 1 page)
  Each:    → 36 files
③ PAGE STRIP (optional preview, P1): thumbnails with group colour bands
[      Split into 3 PDFs      ]
──────── gap + divider + ADMOB_BANNER_TOOLS ────────
```
Keyboard: the range field uses `TextInputType.text` with a digits/`,`/`-`/space input formatter; the banner hides while the keyboard is open (existing rule).

### S25 · PDF to Images (`/tool/pdf-to-images`)
```
① FILE   📄 brochure.pdf · 24 pages
② PAGES  ( ● All ) ( ○ Choose pages: [ 1-5, 9 ] )
③ FORMAT ( ● JPG ) ( ○ PNG )   Quality (JPG) ──●── 90
④ RESOLUTION ( 72 · Screen ) ( ● 150 · Standard ) ( 300 · Print )
   ≈ 1240 × 1754 px per A4 page        live estimate from page 1 size
[      Create 24 images      ]
```

### S07 update · Organizer selection bar
`[⟲ Left] [⟳ Right] [🗑 Delete] [⇅ Move] [⧉ Extract]` — Extract runs a job and opens S11 (single result). Returning from Result keeps the Organizer edits.

### S01 update · Favourites row
```
★ Favourites                     Edit
[🗜 Compress] [🪪 Resize] [⊕ Merge]       ToolCard v2 compact (64 dp tall chips with gradient tile)
```
Hidden when empty. Long-press on any ToolCard → sheet: tool name, description, **Add to favourites** / **Remove from favourites**, **Open**.

### S26 · Favourites edit sheet
Bottom sheet, reorderable list (drag handle + overflow "Move up / Move down / Remove"), Done. No ads (sheet).

### S19 · Incoming chooser (now built)
As specified in SCREENS.md S19, plus: a header "Received 3 files", FileTiles with validation badges, sections per input group, tools filtered by §4.8, and "Cancel" (deletes the temp copies). Bottom banner: **none** (it's a short routing screen; consistent with ADS "Incoming chooser" exclusion).

### Ads summary for 1.1
| Screen | Ads |
|---|---|
| S21 (inside tool screens), S23, S24, S25 | `ADMOB_BANNER_TOOLS` with 24 dp gap + divider |
| S22 Multi-result | AD-2 native card + `ADMOB_BANNER_MAIN`; AD-3 on Done (one job) |
| S26 sheet, S19 chooser | None |

## 4. Implementation

### 4.1 Packages
| Package | Use | Licence | Note |
|---|---|---|---|
| `archive` | Streaming ZIP writer (`ZipFileEncoder` writes to a file path and adds files from disk) | MIT | **Verify** that the pinned version streams file contents (`addFile` from path) rather than loading them into memory; if not, write a minimal store-only ZIP writer (§4.5) |
| (existing) `flutter_image_compress`, `pdfrx`, `share_plus`, `docukit_native` | Encode, render, share, save | — | No other new dependencies. Don't add `receive_sharing_intent` (no release in over a year) — ADR-037 |

### 4.2 Multi-output contract (`lib/core/operation/`)
```dart
sealed class JobOutput {}
class SingleOutput extends JobOutput { final OutputFile file; }
class MultiOutput extends JobOutput {
  final List<OutputItem> items;          // input order
  int get succeeded => items.whereType<OutputOk>().length;
}
sealed class OutputItem { final int index; final String sourceName; }
class OutputOk extends OutputItem { final OutputFile file; final int? beforeBytes; final ItemNote? note; } // note e.g. targetMissed
class OutputFailed extends OutputItem { final AppErrorCode code; }

abstract interface class MultiToolOperation<O extends ToolOptions> {
  ToolId get tool;
  Future<void> validateInputs(List<PickedFile> inputs, O options);
  int estimateRequiredBytes(List<PickedFile> inputs, O options);
  int itemCount(List<PickedFile> inputs, O options);              // N for progress
  /// Called once per item; must write only inside ctx.workDir and return one file (or throw AppError).
  Future<RawOutput> executeItem(JobContext ctx, int itemIndex, List<PickedFile> inputs, O options);
  Future<OutputMeta> validateItem(RawOutput out, int itemIndex, O options);
}
```
`JobRunner.runMulti`:
```
for i in 0..<N:
  ctx.cancel.throwIfCancelled()
  report(Determinate(i, N, stepKey))
  try raw = executeItem(...); meta = validateItem(...); items.add(OutputOk(...))
  on AppError e where e.code ∉ {insufficientStorage, cancelled}: items.add(OutputFailed(i, e.code))   // continue
  on insufficientStorage: stop the loop, mark remaining as failed(insufficientStorage)
on cancel: delete work dir; history CANCELLED; nothing adopted
if succeeded == 0 → Failed(first error)
else adopt all OutputOk files into outputs/<jobId>/ ; history SUCCESS or PARTIAL
```
- Split and P2I have one input and N items; Batch/Convert have N inputs and N items. Both fit `itemCount` + `executeItem`.
- Inputs of a batch are copied lazily: the picker still copies at pick time (ADR-007), so no change.

### 4.3 Batch compress/resize
- Reuse `CompressImageOperation` / `ResizeImageOperation` logic as per-item functions; the single-image tools call the same function with N = 1 (single code path, ADR-036).
- Memory: items run **sequentially**; native encoders release between items; the Result list holds only metadata (no decoded thumbnails — thumbnails come from `Image.file` with `cacheWidth: 96`).
- Target-size: the search runs per item; total attempts bounded at 8 per item; a missed target is `OutputOk(note: targetMissed(actualBytes))`.

### 4.4 Save many (`FileGateway.saveManyToFolder`) and `docukit_native` additions
| Method | Android (Kotlin) | iOS (Swift) | Returns |
|---|---|---|---|
| `saveManyToFolder(paths, names, mimes)` | *(As built, T8.3 / ADR-060: `DocumentsContract.createDocument(resolver, folderUri, mime, name)` per file, no `findFile` scan; the provider adds " (1)". Original wording:)* `ACTION_OPEN_DOCUMENT_TREE` → `DocumentFile.fromTreeUri(ctx, treeUri)`; for each file: `findFile(name)` → if exists, try `name (1)`…; `createFile(mime, name)` → stream-copy 64 KB buffer on a background executor; take **no** persistable permission (one-time use) | `UIDocumentPickerViewController(forExporting: urls, asCopy: true)` (iOS 14+), `allowsMultipleSelection` n/a; result = `didPickDocumentsAt` count | `{status, savedCount, failedCount, folderName?}` |
| `getIncomingFiles()` | Read the launch `Intent` and later `onNewIntent`: `ACTION_SEND` → `EXTRA_STREAM`; `ACTION_SEND_MULTIPLE` → `getParcelableArrayListExtra(EXTRA_STREAM)`; `ACTION_VIEW` → `data`. Copy each `content://` to `cacheDir/incoming/<uuid>/<displayName>` (query `OpenableColumns.DISPLAY_NAME`), then clear the intent extras so a rotation doesn't re-deliver | `SceneDelegate.scene(_:openURLContexts:)` and `scene(_:willConnectTo:options:)` (`connectionOptions.urlContexts`), or `AppDelegate application(_:open:options:)` if the app has no scene delegate; `startAccessingSecurityScopedResource` if needed → copy to `tmp/incoming/<uuid>/` → stop access; delete files the system placed in `Documents/Inbox` | `List<{path, displayName}>` |
| `incomingFilesStream` (EventChannel `docukit/incoming`) | Emits when `onNewIntent` delivers files while running | Emits on `openURLContexts` while running | stream of the same list |

Dart: `IncomingFilesController` (Riverpod) reads `getIncomingFiles()` after the first frame (cold start) and listens to the stream (warm start). If a job is running → hold in `pendingIncoming` and show the banner; else `context.go('/incoming')`. The copies move into `jobs/<draftId>/in/` via `FileGateway.adoptExternal(paths)`, which sniffs and validates like the picker.

**AndroidManifest (MainActivity)**: `android:launchMode="singleTask"` (so `onNewIntent` is used) and:
```xml
<intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="image/*"/></intent-filter>
<intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="application/pdf"/></intent-filter>
<intent-filter><action android:name="android.intent.action.SEND_MULTIPLE"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="image/*"/></intent-filter>
<intent-filter><action android:name="android.intent.action.SEND_MULTIPLE"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="application/pdf"/></intent-filter>
<intent-filter><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.DEFAULT"/><data android:scheme="content" android:mimeType="application/pdf"/></intent-filter>
<intent-filter><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.DEFAULT"/><data android:scheme="content" android:mimeType="image/*"/></intent-filter>
```
*Verify* that `singleTask` doesn't break go_router deep links or the AdMob/consent activities; alternative is `singleTop`.

**iOS Info.plist**: `CFBundleDocumentTypes` (role Viewer, rank Alternate) for the five UTIs, `UTImportedTypeDeclarations` for `org.webmproject.webp`, `LSSupportsOpeningDocumentsInPlace = NO`. A Share Extension is **not** in scope (ADR-038): iOS users use "Open in DocuKit" / "Copy to DocuKit" from the share sheet's app row, which document types provide.

### 4.5 ZIP building (`core/files/zip_builder.dart`)
```
buildZip(items: List<(path, nameInZip)>, outPath, cancel):
  enc = ZipFileEncoder(); enc.create(outPath)          // verify streaming in the pinned archive version
  usedNames = {}
  for (path, name) in items:
     cancel.throwIfCancelled()
     name = uniqueIn(usedNames, safeBaseName(name)+ext)  // same rules as file_naming.dart
     enc.addFile(File(path), name, level: STORE for jpg/png/webp/pdf else DEFLATE)
  enc.close()
  validate: reopen with ZipDecoder reading only the central directory; entry count == items.length
```
Images and PDFs are already compressed; use STORE (no compression) for them to save time and battery. Fallback if `archive` can't stream: a minimal store-only ZIP writer (local file headers + CRC32 computed while streaming + central directory) — about 150 lines, unit-tested against `ZipDecoder`.

ZIPs are built **on demand** (when the user taps Save as ZIP or shares > 50 files) into `outputs/<jobId>/`, then reused.

### 4.6 Page-range grammar (Split, PDF to Images) **[unit]**
```
input    := ws part (ws "," ws part)* ws
part     := number | number ws "-" ws number | number ws "-" ws "end" | "end"
number   := [1-9][0-9]*
ws       := [ \t]*
```
- "end" (and its localised alias from ARB) = last page.
- Errors (first one shown, with its position): empty input; `0`; a page > pageCount; reversed range (`5-3`) → "Write ranges from low to high, e.g. 3-5"; unknown characters; more than 500 parts.
- Split: each part → one output, in the order written (duplicates and overlaps allowed).
- PDF→Images: union of parts, sorted ascending, de-duplicated.
- Test cases: `"1-3, 5, 8-10"`, `" 2 "`, `"7-end"`, `"1,1"`, `"5-3"`, `"0"`, `"1-"`, `"a"`, `"1-3,,5"`, `"36"` on a 36-page PDF, `"37"` on a 36-page PDF.

### 4.7 Split / P2I engines
```
split(input, groups: List<List<int>>, ctx):   // one item per group
  src = PdfDocument.openFile(input)            // keep open across items
  for each group g (executeItem):
     out = PdfDocument.createNew(); out.pages = g.map(i => src.pages[i]); bytes = encodePdf(); write; out.dispose()
  src.dispose() at the end (also on cancel/failure)
pdfToImages(input, pages, format, dpi, ctx):
  for each page p (executeItem):
     wPx = round(p.width/72*dpi); hPx = round(p.height/72*dpi); scale down to ≤ 40 MP
     img = renderPage(p, wPx, hPx, background: white unless keepTransparent && png)
     encode in Isolate (JPG q / PNG) → write; release img
```
Encoding: use `flutter_image_compress` from raw RGBA if supported (*verify*); otherwise `package:image` in `Isolate.run`. The rendered bitmap must be released before the next page (FR-P2I-05).

### 4.8 Incoming → tool matching **[unit]**
| Received | Tools offered |
|---|---|
| 1 image | Compress, Resize, Convert, Images to PDF |
| 2–50 images | Compress (batch), Resize (batch), Convert (batch), Images to PDF |
| 1 PDF | Organize, Split, PDF to Images, Reduce, Merge ("needs one more — you can add it next") |
| 2–20 PDFs | Merge |
| images + PDFs | Two sections, as above per group |
| none supported | Error card |

### 4.9 Favourites
`settings.favourite_tools` = JSON list of `ToolId.name` (max 6). `FavouritesController` exposes `pin`, `unpin`, `reorder`. Home reads catalogue ∩ favourites, preserving the list order.

### 4.10 Catalogue, search and tour additions
| ToolId | Title / subtitle | Keywords (add to synonym table) |
|---|---|---|
| imageConvert | Convert Image / Change the file format | convert, heic, heic to jpg, png to jpg, jpg to png, webp, change format, format, iphone photo |
| pdfSplit | Split PDF / Break a PDF into parts | split, separate, divide, cut pdf, break, extract pages, ranges, pages to pdf |
| pdfToImages | PDF to Images / Save pages as pictures | pdf to jpg, pdf to png, pdf to image, export pages, page to photo, screenshot pdf |
| (batch) | — | Add to Compress/Resize keywords: batch, many photos, multiple images, all photos, bulk |

Tour: add one step per new tool (title/body/example in §7). `tour_version` = 2; existing users see the mini-tour (Convert, Split, PDF to Images, Favourites row).

Category placement on Home: Image → Compress, Resize, **Convert**, Images to PDF; PDF → Merge, Organize, **Split**, **PDF to Images**, Reduce.

## 5. Data model & settings

### 5.1 drift migration (schema v2 → v3; use the next version number in your project)
- `Operations.status` gains `PARTIAL`.
- New columns on `Operations`: `outputCount INTEGER NOT NULL DEFAULT 1`, `failedCount INTEGER NOT NULL DEFAULT 0`, `zipRelPath TEXT NULL`.
- New table:
```dart
class OperationOutputs extends Table {
  TextColumn get operationId => text().references(Operations, #id, onDelete: KeyAction.cascade)();
  IntColumn  get position => integer()();
  TextColumn get displayName => text()();          // file name only
  TextColumn get relPath => text().nullable()();   // relative to outputs/<jobId>/, null if failed
  IntColumn  get sizeBytes => integer().nullable()();
  IntColumn  get beforeBytes => integer().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get metaJson => text().nullable()();
  @override Set<Column> get primaryKey => {operationId, position};
}
```
- Single-output jobs keep using the existing `output*` columns (no backfill); history and details read `OperationOutputs` when `outputCount > 1`.
- History row for a batch: title "18 images compressed", subtitle "46.2 MB → 9.8 MB · 2 failed"; S15 Details lists outputs with per-file Open/Share and **Save all** / **Save as ZIP**.
- Migration test with a `drift_dev` schema snapshot.

### 5.2 Settings keys
| Key | Type | Default |
|---|---|---|
| `favourite_tools` | JSON list of ToolId | [] |
| `convert_format` | jpg/png/webp/heic | jpg |
| `convert_quality` | int | 90 |
| `p2i_format` | jpg/png | jpg |
| `p2i_dpi` | 72/150/300 | 150 |
| `split_mode` | ranges/everyN/each | ranges |
| `split_every_n` | int | 1 → shown as smallest useful (2) |
| `multi_save_default` | folder/zip | folder |
| `tour_version` | int | bump to 2 |

## 6. Permissions, privacy & store impact
- **No new permissions.** `ACTION_OPEN_DOCUMENT_TREE` and the iOS export picker are user-mediated.
- Intent filters make DocuKit appear in other apps' share sheets; no data is read until the user chooses DocuKit.
- Privacy policy: add one sentence — "Files you share into DocuKit from other apps are copied into the app and processed only on your device."
- Store listing "What's new": batch processing, Convert Image, Split PDF, PDF to Images, favourites, share to DocuKit.
- Screenshots: add a batch result screen (no ads visible).
- Data safety / App privacy: unchanged.

## 7. Copy (add to COPY.md; ARB keys camelCase)
| Key | Text |
|---|---|
| tool_image_convert_title / subtitle | Convert Image / Change the file format |
| tool_pdf_split_title / subtitle | Split PDF / Break a PDF into parts |
| tool_pdf_to_images_title / subtitle | PDF to Images / Save pages as pictures |
| batch_header | IMAGES ({count}) |
| batch_total | Total {size} · {invalid, plural, =0{} =1{1 can't be used} other{# can't be used}} |
| batch_remove_invalid | Remove them |
| batch_none_valid | Add images that DocuKit can open |
| batch_run_compress / resize / convert | Compress {count} images / Resize {count} images / Convert {count} images |
| multi_header_all | All done |
| multi_header_some | {done} of {total} done |
| multi_totals | Before {before} → After {after} |
| multi_count_pdfs / images | {count} PDFs · {size} / {count} images · {size} |
| multi_save_all | Save all… |
| multi_save_zip | Save as ZIP |
| multi_share_all | Share all |
| multi_saved_folder | Saved {count} files to {folder} |
| multi_saved | Saved {count} files |
| multi_saved_partial | Saved {saved} of {total}. {failed} couldn't be written. |
| multi_share_too_many | That's more than 50 files. Share them as one ZIP instead? |
| multi_item_closest | Closest to {target} |
| multi_item_failed | {error}. Original not changed. |
| multi_all_failed | None of the files could be processed. Your originals were not changed. |
| cnv_to | CONVERT TO |
| cnv_same_format | {count, plural, =1{1 image is} other{# images are}} already {format}. They'll be re-saved. |
| cnv_heic_ios_only | HEIC is available on iPhone only. |
| spl_mode_ranges / every / each | Custom ranges / Every N pages / Each page |
| spl_ranges_hint | Use commas and dashes, e.g. 1-3, 5, 8-end |
| spl_preview_files | {count, plural, =1{1 file} other{# files}}: {parts} |
| spl_every_label | Pages per file |
| spl_every_preview | {count} files (the last has {lastPages, plural, =1{1 page} other{# pages}}) |
| spl_one_page | This PDF has only one page. |
| spl_each_cap | That would make more than 500 files. Use Every N pages instead. |
| spl_run | Split into {count, plural, =1{1 PDF} other{# PDFs}} |
| range_err_page | Page {page} doesn't exist. This PDF has {total} pages. |
| range_err_reversed | Write ranges from low to high, e.g. 3-5. |
| range_err_zero | Pages start at 1. |
| range_err_chars | Use only numbers, commas, dashes and "end". |
| range_err_empty | Enter at least one page. |
| range_end_word | end |
| p2i_pages_all / choose | All pages / Choose pages |
| p2i_res_72 / 150 / 300 | Screen / Standard / Print |
| p2i_px_estimate | ≈ {w} × {h} px per page |
| p2i_page_capped | Page {page} was limited to {px} px to save memory. |
| p2i_keep_transparent | Keep transparent background |
| p2i_run | Create {count, plural, =1{1 image} other{# images}} |
| org_extract | Extract |
| org_extract_done_name | {base}_extract |
| fav_header | Favourites |
| fav_edit | Edit |
| fav_add / remove | Add to favourites / Remove from favourites |
| fav_limit | You can pin up to 6 tools. Remove one first. |
| fav_move_up / down | Move up / Move down |
| inc_title | Received {count, plural, =1{1 file} other{# files}} |
| inc_images_section / pdfs_section | {count, plural, =1{1 image} other{# images}} / {count, plural, =1{1 PDF} other{# PDFs}} |
| inc_merge_needs_more | Needs one more PDF. You can add it next. |
| inc_unsupported | DocuKit can't work with this file type. |
| inc_waiting | {count, plural, =1{1 file received} other{# files received}}. Open when this job finishes. |
| tour_image_convert_title / body / example | Convert Image / Change photos between JPG, PNG, WebP and HEIC. / Turn iPhone HEIC photos into JPG for upload forms. |
| tour_pdf_split_title / body / example | Split PDF / Break one PDF into several smaller ones. / Send only pages 3–5 of a long report. |
| tour_pdf_to_images_title / body / example | PDF to Images / Save each page as a picture. / Post a page of a PDF as a photo. |
| tour_favourites_title / body | Favourites / Long-press any tool to pin it here. |

## 8. Tests

### 8.1 Unit
Range parser (all §4.6 cases) · split grouping (ranges / every N incl. remainder / each, 500 cap) · P2I pixel maths + 40 MP cap · incoming→tool matching table · favourites (cap 6, reorder, unknown ids dropped) · `JobRunner.runMulti` (all succeed, partial, all fail → Failed, cancel mid-way deletes everything, insufficient storage mid-batch) · ZIP builder (names de-duplicated, entry count, STORE vs DEFLATE, cancel) · unique naming in save-many · drift migration v→v+1 and `PARTIAL` status · batch target-size per item with a fake encoder.

### 8.2 Widget
S21 grid states (valid, warning, invalid; 0 valid disables button) · S22 totals/partial/all-failed header · S23 alpha warning + same-format hint + HEIC hidden on Android · S24 inline range errors and live preview, banner hidden with keyboard · S25 estimate text · Favourites row hidden when empty, 7th pin message, a11y custom action · S19 sections and filtered tools · ads: banners on S23/S24/S25 with gap, none on S26/S19.

### 8.3 Integration (device)
Batch compress 20 corpus images (incl. IMG-17 corrupt) → 19 ok + 1 failed, checksums unchanged · Convert HEIC→JPG and PNG(alpha)→JPG (white background check on a known pixel) · Split PDF-08 every 25 → page counts per file · P2I PDF-03 at 300 dpi → peak memory recorded, dims checked · Extract 3 pages from PDF-04 keeps rotation · ZIP opened and entry count verified.

### 8.4 Corpus additions
`IMG-22 batch_50/` (50 × 4 MP JPEG generated by `tool/make_fixtures.dart`) · `IMG-23 transparent.webp` · `PDF-13 sixty_pages_mixed_sizes.pdf` · `PDF-14 one_page_landscape.pdf`.

### 8.5 Regression additions
| # | Steps | Expected |
|---|---|---|
| R27 | Compress 30 photos (q70) → Save all to a new folder | 30 files in the folder, totals correct |
| R28 | Same batch → Save as ZIP → open the ZIP in Files | 30 entries, opens |
| R29 | Batch with 1 corrupt + 1 unsupported file | Partial result, clear per-file errors, history PARTIAL |
| R30 | Resize 10 photos with the Passport preset (fit with border) | All 413×531, upright, no stretching |
| R31 | Convert 5 HEIC → JPG; 2 alpha PNG → JPG | Opens everywhere; alpha warning shown; white background |
| R32 | Split PDF-08 "1-3, 5, 8-end"; every 25; each page on a 10-page PDF | Correct files and page counts |
| R33 | PDF to Images, 300 dpi, 30 pages | Completes; no crash; dimensions as estimated |
| R34 | Organizer: select 3 pages → Extract | New PDF with those pages; Organizer edits kept |
| R35 | Pin 6 tools, try a 7th, reorder, restart | Limit message; order persists |
| R36 | Share 3 photos from Gallery/Photos and 1 PDF from Files to DocuKit, cold and warm start, also during a running job | S19 with correct tools; waiting banner during a job; temp copies cleaned on Cancel |

## 9. Tasks (milestone M8)

- [~] 🔬 **T8.0 Spike (½ day).** *(2026-10-28: Android checks 1–4 PASS on the emulator, results in ADR-060; iOS export picker + iOS encode pending the Xcode round.)* Confirm: `archive` streams files from disk into a ZIP (memory for a 500 MB ZIP); WebP and HEIC encode support per OS in `flutter_image_compress`; RGBA → JPEG/PNG encode path for P2I; `DocumentFile.createFile` speed for 50 files; iOS multi-URL export picker behaviour. *Accept:* DECISIONS entry (resolves ADR-039) with measurements.
- [x] **T8.1 Catalogue & colours.** Add the 3 ToolIds, routes, categories placement, keywords, tour steps (strings only), placeholder screens. *Accept:* search test cases in FR-HOME-08 pass; tour builds 3 new steps from the catalogue.
- [x] **T8.2 Multi-output engine.** `MultiOutput`, `MultiToolOperation`, `JobRunner.runMulti`, history `PARTIAL`, `OperationOutputs` table + migration. *Accept:* §8.1 runner and migration tests.
- [x] **T8.3 Save many + ZIP.** `saveManyToFolder` (Kotlin + Swift), `ZipBuilder`, share-many with the 50 cap. *Accept:* save 50 files to a folder on the emulator; ZIP validated; iOS code compiles (run in the Xcode round). *(2026-10-28: Android 50/50 saved on the emulator, second run renamed " (1)"; ZIP tests pass; Swift syntax-checked only — compile + run in the Xcode round; spike code removed.)*
- [x] **T8.4 Multi-result screen (S22) + history/details for multi jobs.** *Accept:* widget tests; AD-2/banner placement; Done counts as one job for AD-3. *(2026-10-28: S22 + goldens; History shows the tool name and "16 of 18 done" (COPY has no batch title yet); a row tap opens Open with… rather than a preview sheet; Recent's long-press Open/Share stay disabled for multi jobs — Details has them.)*
- [x] **T8.5 Batch Compress.** S21 grid inside S03; per-item target-size. *Accept:* FR-BAT-10/11/13/14; R27–R29. *(2026-10-28, emulator API 34, debug build, `integration_test/batch_compress_test.dart`: R27 30 × 4 MP at q70 in 14.5 s, 90.4 MB → 16.5 MB, Save all 30/30 into a new folder; R28 ZIP 30 entries, reopened (built in 1.3 s; not opened in the Files app); R29 corrupt → corruptFile, GIF → unsupportedFormat, history PARTIAL; 50-image batch 33 s, peak RSS +36 MB; target 100 KB per image: 5/5 fit. `engines_test.dart` (R7) still 13/13.)*
- [x] **T8.6 Batch Resize.** Fit-inside default in batch, presets with fit. *Accept:* FR-BAT-12; R30. *(2026-10-28, emulator API 34: R30 10 photos (orientations 1–8 + 2 landscapes) → all 413×531, upright, white border, not stretched; Fit inside 1080×1080 → 1080×810 / 810×1080 / 800×600 unchanged (ADR-062: shrink only); `engines_test.dart` 13/13.)*
- [x] **T8.7 Convert Image (S23).** *Accept:* FR-CNV-01…07; R31. *(2026-10-28, emulator API 34: R31 5 HEIC (made on-device) → JPG, same sizes, decodable; 2 alpha PNG → JPG with white background (255,255,255) and colours kept; WebP output keeps alpha. "Opens everywhere" checked with a plain JPEG decoder, not other apps. HEIC output hidden on Android with the iPhone-only note.)*
- [x] **T8.8 Range parser + Split PDF (S24).** Parser tests first. *Accept:* FR-SPL-01…08; R32. *(2026-10-28, emulator API 34, `integration_test/split_test.dart`: 300 pages "1-3, 5, 8-end" → pages 1–3 / 5 / 8–300 (1.6 s); every 25 → 12 × 25 (2.2 s); each page of 10 → 10 × 1; overlaps/duplicates kept. Pages identified by their width, not only counted.)*
- [x] **T8.9 PDF to Images (S25).** *Accept:* FR-P2I-01…07; R33 with recorded memory. *(2026-10-28, emulator API 34, debug build: R33 30 mixed A4/Letter/landscape pages at 300 dpi → 30 JPEGs, every one exactly the estimated size (A4 2480×3508); **peak RSS +106 MB** (< 200 MB, FR-P2I-05); 442 s total (~14.7 s/page). One-page profile on the same emulator: render 1.6–2.0 s, BMP write 1.3–1.6 s, native JPEG 2.6–3.0 s, against 0.25 s / 0.86 s in the T8.0 profile-mode spike: the emulator was swapping and this was a debug build, so recheck speed on a real phone in T8.14. PNG: white background by default; transparent keeps alpha.)*
- [ ] **T8.10 Organizer Extract.** *Accept:* FR-EXT-01…03; R34.
- [ ] **T8.11 Favourites (S01 row, S26 sheet, long-press sheet, tool ⋮).** *Accept:* FR-FAV-01…05; R35.
- [ ] 🤖🍎 **T8.12 Share to DocuKit.** Intent filters, iOS document types, `getIncomingFiles` + stream, `IncomingFilesController`, S19. *Accept:* FR-SHR-01…07; R36 on Android; iOS compiled and listed for the Xcode round.
- [ ] **T8.13 Mini-tour, copy, privacy text, What's new.** *Accept:* FR-TOUR-11; COPY keys present; privacy sentence added.
- [ ] **T8.14 Regression R1–R36 + version 1.1.0.** *Accept:* report in TESTING.md; build number bumped.

Order: T8.0 → T8.1 → T8.2 → T8.3 → T8.4 → T8.5 → T8.6 → T8.7 → T8.8 → T8.9 → T8.10 → T8.11 → T8.12 → T8.13 → T8.14.

## 10. Claude Code prompts (fresh session each: `/clear` first)

**1. Spike + catalogue**
```
Read docs/FULL_PRODUCT.md and docs/features/RELEASE_V1_1.md. Do T8.0 (spike) then T8.1.
T8.0: build a throwaway debug screen under lib/debug/ and measure: ZIP streaming memory with the pinned `archive` version (500 MB of inputs), WebP/HEIC encode per OS in flutter_image_compress, RGBA→JPEG/PNG encode for PDF to Images, DocumentFile.createFile speed for 50 files. Record results and the chosen approach as a DECISIONS entry (resolve ADR-039). Don't build production code in T8.0.
T8.1: add the three ToolIds, routes, Home placement, search keywords and tour strings per §4.10; write the search tests from FR-HOME-08 first.
Report the commands you ran and their real results.
```

**2. Multi-output foundation**
```
Do T8.2, T8.3 and T8.4 from docs/features/RELEASE_V1_1.md (§4.2, §4.4, §4.5, §5.1, S22).
Write the unit tests in §8.1 for JobRunner.runMulti, the ZIP builder and the drift migration BEFORE the implementation.
Implement saveManyToFolder in docukit_native for Android (ACTION_OPEN_DOCUMENT_TREE + DocumentFile, streaming copy) and iOS (UIDocumentPickerViewController forExporting multiple URLs). iOS can't be run here — make it compile-ready and list what must be checked in the Xcode round.
Banner/ad rules per FULL_PRODUCT §4.4. Report commands and real results.
```

**3. Image batch + Convert**
```
Do T8.5, T8.6 and T8.7 from docs/features/RELEASE_V1_1.md. Single-image Compress/Resize must call the same per-item code as batch (ADR-036); no duplicated logic.
Tests first for per-item target size, fit-inside resize maths, alpha handling and the same-format hint. Then run R27–R31 on the emulator with the corpus (including tool/make_fixtures.dart for the 50-image batch) and report peak memory for the 50-image batch.
Originals must stay byte-identical (checksum helper). Report commands and real results.
```

**4. Split, PDF to Images, Extract, Favourites**
```
Do T8.8, T8.9, T8.10 and T8.11 from docs/features/RELEASE_V1_1.md.
Write the range-parser tests (all §4.6 cases) first. PDF to Images must render, encode and release one page at a time (FR-P2I-05) — record peak memory for 30 pages at 300 dpi.
Run R32–R35 on the emulator. Report commands and real results.
```

**5. Share to DocuKit + release prep**
```
Do T8.12, T8.13 and T8.14 from docs/features/RELEASE_V1_1.md. Implement incoming files in packages/docukit_native (do NOT add receive_sharing_intent). Handle cold start, warm start (onNewIntent / openURLContexts) and "a job is running". Copy every incoming file before showing UI; never keep URIs.
Check that android:launchMode changes don't break go_router, consent or ads.
Run R36 on the emulator (adb `am start` with SEND/SEND_MULTIPLE/VIEW intents is fine), then the full regression R1–R36, and bump the version to 1.1.0. Report commands and real results.
```

## 11. Risks & open decisions

**ADR-036 — One per-item code path for single and batch image tools · Proposed**
*Context:* duplicating compress/resize logic for batch would let the two drift apart. *Decision:* single-image jobs are batches of one through `MultiToolOperation`, presented with the single-result screen when N = 1. *Consequences:* a one-time refactor of the 1.0 operations; all existing tests must keep passing unchanged.

**ADR-037 — Incoming files implemented in `docukit_native`, not `receive_sharing_intent` · Proposed**
*Context:* `receive_sharing_intent` has had no release in over a year; the share-in path touches launch modes and scene delegates, which we want under our control. *Decision:* implement `getIncomingFiles` + an EventChannel in the local plugin. *Consequences:* ~250 lines of Kotlin/Swift we own; iOS must be verified in the Xcode round.

**ADR-038 — No iOS Share Extension in 1.1 · Proposed**
*Context:* a Share Extension gives DocuKit an icon in the iOS share sheet's action row, but it's a separate target with its own memory limit (~120 MB) and needs an App Group to hand files to the app. *Decision:* use document types ("Open in DocuKit" / "Copy to DocuKit") only. *Consequences:* iOS users find DocuKit in the share sheet's app row, not as an action. Revisit if testers ask.

**ADR-039 — ZIP implementation · Open (decided by T8.0)**
*Context:* the `archive` package may buffer entries in memory depending on version. *Decision:* use `archive` if it streams from disk; otherwise ship the small store-only writer in §4.5. *Consequences:* either way, ZIPs are STORE-only for already-compressed formats.

**ADR-040 — Batch outputs counted as one job for ads and history · Proposed**
*Context:* AD-3 counts completed jobs; a 50-image batch shouldn't trigger more interstitials. *Decision:* one batch = one job everywhere (history, AD-3 counters, savings counter adds the batch total). *Consequences:* simpler mental model; slightly fewer interstitial opportunities.

**Risks**
| Risk | Mitigation |
|---|---|
| `singleTask` launch mode breaks consent/ads activities or deep links | T8.12 checks; fall back to `singleTop` |
| Android folder save is slow for many files (SAF overhead) | Background executor, progress "Saving 12 of 50…", ZIP as the faster option |
| HEIC encode unsupported on some Android devices | HEIC output offered on iOS only (FR-CNV-02) |
| P2I at 300 dpi on large-format pages (A0) | 40 MP cap per page with a visible note |
| Users expect odd/even splitting | Backlog item; Organizer selection helpers in P2 |
