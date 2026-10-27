# DocuKit — Product Requirements Document (Android + iOS)

| Field | Value |
|---|---|
| Product | DocuKit (working name — check trademark and store availability before release) |
| Version | 2.0 — cross-platform revision of "DocuKit Android PRD v1.0" (22 Oct 2026) |
| Platforms | Android phones (API 26+) and iPhone (iOS 15+); iPad and Android tablets run the same adaptive layout |
| Codebase | One Flutter codebase, plus small native plugins where the OS does it better (see `ARCHITECTURE.md`) |
| Delivery model | Offline-first processing. No account or backend. Ad-supported, with an optional one-time Remove ads purchase. |
| Team | One developer, working with Claude as a coding assistant |
| Status | Baseline for implementation. Change scope only through `DECISIONS.md` |

> **What changed from v1.0:** the platform is now Android **and** iOS. Each Android-only idea (SAF, Sharesheet, Room, DataStore, PdfDocument, PdfBox-Android, WorkManager) now has a cross-platform equivalent, and the platform-specific behaviour is spelled out per screen. The v1 requirement IDs are kept unchanged, so they still work as the build checklist. New IDs are marked **(new)**.

## Companion documents

| File | Use it for |
|---|---|
| `SCREENS.md` | Every screen and sheet: layout, states, actions, platform differences |
| `DESIGN_SYSTEM.md` | Colours, type, spacing, components, motion, accessibility |
| `ARCHITECTURE.md` | Stack, folder layout, operation engine, data model, native plugins |
| `FEATURE_SPECS.md` | How each tool works: algorithms, limits, edge cases, pseudo-code |
| `COPY.md` | All user-facing strings and error messages (source for the ARB files) |
| `DECISIONS.md` | Architecture decision records (ADRs) and open decisions |
| `TASKS.md` | The ordered build backlog, with acceptance criteria per task |
| `TESTING.md` | Test strategy, sample-file corpus, device matrix, regression script |
| `RELEASE.md` | Play Store + App Store submission, privacy labels, licences, signing |
| `PROMPTS.md` | Ready-to-paste prompts for Claude, one per milestone |

---

## 1. Executive summary

DocuKit is a single mobile app for the everyday document chores people now handle with five different apps, or by uploading private files to a random website. Its promise has three parts: **your files never leave your phone**, **the original is never touched**, and **the numbers shown are real** (actual output sizes, never "up to 90% smaller" claims).

MVP tools: Image Compressor, Image Resizer, Image to PDF, PDF Merger, PDF Page Organizer and PDF Size Reducer. They sit on a shared pipeline: pick → review → configure → process → validate → preview → save/share → history.

### 1.1 Product goals
1. Ship six reliable document tools in one app, on both platforms, from one codebase.
2. Process every MVP operation locally, on the device, without needing a network connection.
3. Never modify or delete a user's source file.
4. Report outcomes truthfully: real sizes, real page counts, no invented progress percentages.
5. Keep the architecture modular, so a new tool is a new feature folder plus one engine method, not a rewrite.
6. Keep the codebase small enough for one developer working with Claude.

### 1.2 Non-goals for MVP
- Accounts, cloud sync, remote storage, or any network call during processing.
- PDF↔Word/Office conversion, AI chat, cloud OCR.
- Subscriptions. Ads anywhere inside the working area of a tool.
- Promising a fixed compression percentage.
- Editing PDF text, filling forms, annotations, signatures (V1.4+).
- Opening password-protected PDFs (they are detected and explained; see FR-PDF-ENC).

### 1.3 Success criteria for the MVP release
| Criterion | Target |
|---|---|
| All six P0 tools pass the regression script on both platforms | 100% |
| Source-file integrity (checksum before == after) in the test corpus | 100% |
| Crash-free completion of the regression script on the minimum-spec devices | 0 crashes |
| Every P0 tool reachable from Home | ≤ 2 taps |
| Cold start to interactive Home on a mid-range device | < 1.5 s (measured, not promised to users) |
| **No network request contains file content, file names or tool data** (verified with a proxy); every tool works in airplane mode | 100% |

---

## 2. Target users and jobs-to-be-done

| Persona | Typical job | Tools used | Key pain |
|---|---|---|---|
| **Job applicant** | Upload a photo under 50 KB and a signature at exactly 140×60 px; combine certificates into one PDF | Compressor, Resizer, Image→PDF, Merger | Government/job portals impose strict size and dimension limits |
| **Student** | Turn 12 photos of notes into one assignment PDF; drop blank pages | Image→PDF, Organizer, Reducer | Ordering pages correctly; email size limits |
| **Office employee** | Merge three reports, reorder, rotate a scanned landscape page | Merger, Organizer | Desktop tools aren't at hand |
| **Freelancer / small business** | Assemble receipts for an expense claim; shrink product photos for WhatsApp | Image→PDF, Compressor, Reducer | Sharing big files over chat |
| **Everyday user** | "Make this photo smaller" and share it | Compressor, Resizer | Doesn't know the word "compress", so search must understand plain words |

### 2.1 Core journey (same for every tool)
1. Open **Home** → tap a tool (or search "reduce photo size").
2. Pick file(s) with the **system picker** (Photo picker for images; Files/Documents picker for PDFs).
3. **Review** the inputs: name, type, size, dimensions/pages, with validation badges; reorder or remove.
4. **Configure** options (defaults pre-filled from Settings).
5. **Process**: truthful progress, cancellable where supported.
6. **Result**: preview, before/after size, dimensions or page count, warnings (e.g. "the output is larger").
7. **Save** to a location the user chooses, **Share** via the system share sheet, or **Save to Photos** (images).
8. The operation appears in **Recent Activity**; the app-managed output copy is kept for the retention period.

---

## 3. Scope and release boundaries

### 3.1 MVP features (P0)

| ID | Feature | MVP behaviour |
|---|---|---|
| MVP-01 | Image Compressor | JPEG/PNG/WebP/HEIC input; quality slider or target-size mode; optional max-dimension cap; output format choice; real before/after size; original untouched |
| MVP-02 | Image Resizer | By pixels, by percentage, or by preset (e.g. passport, signature); aspect-ratio lock on by default; output format choice |
| MVP-03 | Image to PDF | Up to 100 images; reorder/remove/rotate; page size (A4, Letter, Legal, Fit-to-image); orientation; margins; fit/fill; image quality |
| MVP-04 | PDF Merger | 2–20 PDFs; reorder/remove; output name; validates every input and the output |
| MVP-05 | PDF Page Organizer | Thumbnail grid; drag to reorder; multi-select rotate/delete; undo; export as a copy |
| MVP-06 | PDF Size Reducer | Three levels: *Basic* (lossless clean-up), *Balanced* (recompresses embedded images), *Strong* (rasterises pages; opt-in with a warning); real size result; discard if the output is larger |
| MVP-07 | Shared file workflow | Pick, validate, temp-copy, process, validate output, preview, save/share/save-to-Photos, errors |
| MVP-08 | Recent Activity | Tool, time, status, sizes, output availability; open/share/delete; retention policy |
| MVP-09 | Settings / Privacy | Theme, tool defaults, history and output retention, storage used, privacy explanation, licences, version |
| MVP-10 **(new)** | Receive files from other apps | Android "Share to DocuKit" / "Open with"; iOS "Open in DocuKit" / share-sheet copy. The incoming file goes to a tool chooser that shows only compatible tools. **P1. Ship it in MVP if M4 is on time; otherwise in V1.1.** |
| MVP-11 **(v2.1)** | Ads | Phase A: native ads on Home, Result, History and Operation details; banner on Settings; capped interstitial after a finished job; opt-in rewarded ad (24 h ad-free); UMP consent. Phase B (after ~30 days of data): app open ad on resume, second Home card, denser History cards (ADS.md §3) |
| MVP-12 **(v2.1)** | Home tour | A 10-step spotlight tour (plus an intro card) covering every tool; auto once, replayable (TOUR.md) |
| MVP-13 **(v2.1)** | UI refresh | Gradients, quick actions, savings counter, ToolCard v2, Result celebration (UI_REFRESH.md) |
| MVP-14 **(v2.1)** | Remove ads (P1) | One-time purchase + restore (ADS.md §6) |

### 3.2 Later releases

| Release | Features | Gate |
|---|---|---|
| V1.1 | Batch image processing (compress/resize many → zip or multiple outputs), image format converter (HEIC→JPG, PNG↔JPG↔WebP), favourites/pinned tools, receive-from-other-apps if not shipped | MVP crash-free ≥ 99.5% across 2 weeks of testing |
| V1.2 | Camera document scanner (edge detection, perspective correction, filters). iOS: VisionKit `VNDocumentCameraViewController`; Android: ML Kit Document Scanner | Device testing on 6+ devices |
| V1.3 | On-device OCR → searchable PDF (ML Kit / Apple Vision) | Offline capability and languages verified |
| V1.4 | Watermark, signature placement, PDF password protect/unlock (with the user-supplied password only) | Security and library review |
| V1.5 | Document organiser (folders/tags), expiry reminders (local notifications) | User demand |
| V2+ | Office conversion, optional premium/cloud features | Product validation and cost model |

### 3.3 Excluded permanently or until re-decided
- Bypassing, cracking or stripping PDF passwords or DRM — **never**.
- Claims that compression always shrinks a file, or that password protection is "unbreakable".
- Uploading files or file data anywhere; ads targeted using file names, file types or tool usage.

---

## 4. Screen inventory (summary)

The full specification is in `SCREENS.md`. In summary: 18 app-owned routes, 6 reusable sheets/dialogs, and the system UI the app invokes.

| # | Route | Screen | Purpose |
|---|---|---|---|
| S01 | `/` | Home | Tool categories, search entry, recent activity strip, empty state |
| S02 | `/search` | Search Tools | Synonym-aware search, results, empty state |
| S03 | `/tool/image-compress` | Image Compressor | Inputs, quality/target-size options |
| S04 | `/tool/image-resize` | Image Resizer | Dimensions/percent/presets, ratio lock |
| S05 | `/tool/image-to-pdf` | Image to PDF | Ordered image list, page setup |
| S06 | `/tool/pdf-merge` | PDF Merger | Ordered PDF list, output name |
| S07 | `/tool/pdf-organize` | PDF Page Organizer | Thumbnail grid editor |
| S08 | `/tool/pdf-compress` | PDF Size Reducer | Level picker with trade-off explanation |
| S09 | (component + `/review`) | File Selection Review | The inputs section embedded in S03–S08; full-screen variant for long lists |
| S10 | `/job/:id/processing` | Processing | Progress, step label, cancel |
| S11 | `/job/:id/result` | Result / Preview | Preview, before/after, warnings, actions |
| S12 | (system + sheet) | Save / Export | Filename sheet → system Save dialog / Save to Photos |
| S13 | (system) | Share Result | System share sheet |
| S14 | `/history` | Recent Activity | Filterable list of operations |
| S15 | `/history/:id` | Operation Details | Metadata, open/share/save/delete |
| S16 | `/settings` | Settings | Theme, defaults, retention, storage |
| S17 | `/settings/privacy` | Privacy & About | Local-processing explanation, licences, version |
| S18 | `/job/:id/error` + inline | Error / Recovery | Readable error, retry, pick another file |
| S19 **(new)** | `/incoming` | Incoming File Chooser | Picks a tool for a file shared into the app (MVP-10) |
| S20 **(new)** | `/onboarding` | First-run Welcome | One screen: the privacy promise and 3 example tasks; skippable, shown once |

Sheets/dialogs: **D1** File details · **D2** Confirm destructive action · **D3** Rename output · **D4** Unsaved work warning · **D5 (new)** Save destination chooser (Files / Photos) · **D6 (new)** Sort & filter history.

### 4.1 Navigation rules
- Home is the root. History and Settings are reached from the Home app bar on phones, and from a navigation rail on tablets/landscape (≥ 840 dp).
- Tool screens keep their options when the user goes back from Processing/Result, so they can tweak and re-run.
- Leaving a tool screen that has inputs or edits shows D4. Leaving the Organizer with unsaved page edits always shows D4.
- Going back during processing asks for confirmation ("Cancel this job?") and never leaves a half-written output behind.
- System pickers, save dialogs and share sheets are always the OS's own UI; never recreate them.
- iOS: the edge-swipe back gesture works everywhere except where D4 must intercept (it is then disabled with `PopScope`, and D4 appears on the back button).
- Android: predictive back is supported (Flutter `PopScope`), and system back follows the same rules.

---

## 5. Functional requirements

Priority key: **P0** = MVP must, **P1** = MVP should, **P2** = later. Every requirement is testable; the test IDs are in `TESTING.md`.

### 5.1 Home and search
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-HOME-01 | P0 | Show the MVP tools in two categories (Image, PDF) | Every P0 tool reachable in ≤ 2 taps from launch |
| FR-HOME-02 | P0 | Search by tool name or task phrase | Synonym table (`FEATURE_SPECS.md §1`) maps e.g. "reduce photo size", "make picture smaller", "kb" → Image Compressor; "join pdf", "combine" → Merger; case- and accent-insensitive; results update with each keystroke |
| FR-HOME-03 | P0 | Show up to 5 recent operations | Unavailable outputs are visibly marked "File no longer available"; tapping opens S15 |
| FR-HOME-04 | P0 | Useful empty state | First-run users see every tool with a one-line description, plus the privacy promise |
| FR-HOME-05 (new) | P1 | Remember the last-used tool | The "Continue" chip on Home reopens the last tool with its saved defaults |
| FR-HOME-06 (v2.1) | P0 | Quick actions | Each chip opens its tool with its prefilled options (UI_REFRESH §2.1) |
| FR-HOME-07 (v2.1) | P1 | Savings counter | Shows the total bytes saved, local only; hidden when 0 |

### 5.2 Image Compressor
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-IMG-01 | P0 | Pick supported images (JPEG, PNG, WebP, HEIC/HEIF) | An unsupported or unreadable file shows "This file type isn't supported. Supported: JPG, PNG, WebP, HEIC." with a **Choose another** action |
| FR-IMG-02 | P0 | Quality control (10–100, default 80) for lossy outputs | The chosen quality is applied; the output is a new file |
| FR-IMG-03 | P0 | Report the actual size change | Shows the real input and output bytes and the % change; if the output ≥ input, says "Couldn't make this smaller" and offers **Keep original** / **Try lower quality** |
| FR-IMG-04 | P0 | Preserve the original | Source bytes unchanged (checksum test) |
| FR-IMG-05 | P0 | Handle orientation and transparency | Applies EXIF orientation to pixels and resets the tag; PNG/WebP with alpha converted to JPEG shows the warning "Transparent areas will become white" before running |
| FR-IMG-06 | P0 | Bound memory | Decode with downsampling to the target size; peak memory for a 48 MP photo < 300 MB on Android (measured in Profile mode) |
| FR-IMG-07 (new) | P0 | Target-size mode ("Under 100 KB") | Binary-searches quality (and, if needed, dimensions) until output ≤ target, within ≤ 8 encode attempts; if the target can't be reached, shows the closest result and says so |
| FR-IMG-08 (new) | P0 | Output format: Same as original / JPEG / PNG / WebP | The extension always matches the actual encoding (magic-byte test). HEIC input defaults to JPEG output for compatibility |
| FR-IMG-09 (new) | P1 | Metadata: "Remove location & camera info" toggle (default **on**) | EXIF GPS/maker tags absent in the output when on; orientation is still applied |
| FR-IMG-10 (new) | P1 | Before/after compare | Result screen has a draggable split preview at the same zoom |

### 5.3 Image Resizer
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-RES-01 | P0 | Set width and height in pixels | Rejects 0, negative, non-numeric, and > 12,000 px per side or > 100 MP total, with an inline error |
| FR-RES-02 | P0 | Aspect-ratio lock (on by default) | Editing one value updates the other, using `round(other × ratio)`; unlocking allows both to be set independently (stretching is then shown in the preview) |
| FR-RES-03 | P0 | Percentage scaling (1–400%) | Final dimensions = `max(1, round(orig × p/100))` |
| FR-RES-04 | P0 | Show output dimensions | The Result shows the final width × height and file size |
| FR-RES-05 | P0 | Correct output format | The extension matches the encoding |
| FR-RES-06 (new) | P0 | Presets | Built-in presets: Passport 413×531 (35×45 mm @300 dpi), Signature 140×60, Instagram square 1080×1080, Story 1080×1920, HD 1280×720, Full HD 1920×1080, plus up to 10 user-saved custom presets |
| FR-RES-07 (new) | P1 | Fit mode when the ratio is unlocked and differs | Options: Stretch / Fit with padding (colour pick: white/black/transparent*) / Crop to fill (centre). *Transparent only for PNG/WebP |
| FR-RES-08 (new) | P1 | Upscale warning | Scaling > 100% shows "Enlarging can make the image blurry" |

### 5.4 Image to PDF
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-I2P-01 | P0 | Select multiple images (1–100) | All appear in pick order; the count is shown; above 100 the extra files are refused with a message |
| FR-I2P-02 | P0 | Reorder, remove, rotate (90° steps) each image | PDF page order and rotation match the list exactly |
| FR-I2P-03 | P0 | Page size + fit | A4 (default), Letter, Legal, or "Same as image"; orientation Auto/Portrait/Landscape; margins None/Small (18 pt)/Large (36 pt); Fit (default, no stretching) or Fill (crop to page) |
| FR-I2P-04 | P0 | Generate locally | The output opens in the system PDF viewer; page count == image count |
| FR-I2P-05 | P0 | Handle batches safely | Images streamed one at a time and downscaled to ≤ 300 dpi at page size; peak memory stays bounded regardless of count; a failing image is reported by name with **Remove and continue** |
| FR-I2P-06 (new) | P1 | Image quality: Original / High (default) / Compact | Maps to JPEG quality 95 / 85 / 65 and max 300 / 200 / 150 dpi |

### 5.5 PDF Merger
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-MRG-01 | P0 | Select at least two PDFs (max 20 files or 2,000 total pages) | **Merge** is disabled with fewer than two, with the hint "Add at least 2 PDFs" |
| FR-MRG-02 | P0 | Reorder and remove inputs | The output follows the list order |
| FR-MRG-03 | P0 | Validate the inputs | Encrypted PDFs get badge 🔒 "Password-protected — can't be merged"; malformed ones get "This PDF looks damaged"; invalid items block Merge until removed |
| FR-MRG-04 | P0 | Validate the result | The output reopens and its page count == the sum of the input pages |
| FR-MRG-05 | P0 | Preserve the inputs | Checksums unchanged |
| FR-MRG-06 (new) | P1 | Output name | Defaults to `Merged_{yyyyMMdd_HHmm}.pdf`; editable via D3 |

### 5.6 PDF Page Organizer
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-ORG-01 | P0 | Show page thumbnails | Lazy-rendered at the grid cell size; the original page number is shown on each; per-thumbnail loading and error states; scroll at 60 fps on a 300-page PDF |
| FR-ORG-02 | P0 | Reorder pages | Long-press and drag (plus an accessible "Move to…" action); the export order matches the UI |
| FR-ORG-03 | P0 | Rotate pages | Only the selected pages rotate, ±90°; the rotation persists in the export |
| FR-ORG-04 | P0 | Delete pages | A delete of more than one page needs D2 confirmation; deleting the last remaining page is impossible ("A PDF needs at least one page") |
| FR-ORG-05 | P0 | Export as a copy | The original is untouched; cancel/back discards edits after D4 |
| FR-ORG-06 (new) | P0 | Undo/redo | At least 50 steps for move/rotate/delete within the session |
| FR-ORG-07 (new) | P1 | Selection tools | Select all, select none, invert; tap = select in selection mode |
| FR-ORG-08 (new) | P1 | Page preview | Double-tap opens a full-screen preview of the page with pinch-zoom |
| FR-ORG-09 (new) | P2 | Extract selected pages to a new PDF | — |

### 5.7 PDF Size Reducer
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-CMP-01 | P0 | Choose the optimisation level | Each level shows a one-line explanation; a static note says "How much a PDF shrinks depends on what's inside it" |
| FR-CMP-02 | P0 | Conservative first | The default is **Balanced**; **Strong** (rasterise) is never the default |
| FR-CMP-03 | P0 | Warn about lossy changes | Balanced: "Photos inside the PDF may look slightly softer." Strong: a blocking confirm, "Text will no longer be selectable or searchable, and links will stop working." |
| FR-CMP-04 | P0 | Report the actual difference | If output ≥ input: "This PDF is already well optimised. The result is not smaller." with **Discard**, and **Keep anyway** as the secondary action |
| FR-CMP-05 | P0 | Preserve the original | Checksum test |
| FR-CMP-06 (new) | P1 | Pre-analysis | Shows page count, image count and a rough "image-heavy / text-heavy" label so the user can choose a sensible level |

### 5.8 Shared file workflow
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-FILE-01 | P0 | Use the system pickers; request no broad storage permission | Android: Photo Picker for images, SAF `OPEN_DOCUMENT` for PDFs; iOS: PHPicker for images, `UIDocumentPickerViewController` for PDFs/files. The Android manifest declares **no** `READ_EXTERNAL_STORAGE`/`READ_MEDIA_*`/`MANAGE_EXTERNAL_STORAGE` |
| FR-FILE-02 | P0 | Save to a user-chosen destination | Android: SAF `CREATE_DOCUMENT` (the user picks the folder and name); iOS: document picker in export mode ("Save to Files"). Images also offer **Save to Photos** |
| FR-FILE-03 | P0 | Safe output names | Strips `/\:*?"<>|` and control characters, trims to 120 chars, preserves the extension; duplicates in the app's output folder get ` (1)`, ` (2)`… |
| FR-FILE-04 | P0 | Manage temporary files | Each job has its own temp dir; it is deleted on completion/cancel/failure; a launch sweep deletes job dirs older than 24 h |
| FR-FILE-05 | P0 | Respect URI lifetime | Inputs are copied into the job temp dir at selection time (both platforms) so processing never depends on a revoked URI or a security-scoped URL; a copy failure → PermissionLost error |
| FR-FILE-06 | P0 | Share only on explicit action | System share sheet with a temporary read grant (Android FileProvider, `FLAG_GRANT_READ_URI_PERMISSION`); iOS `UIActivityViewController` with an iPad popover anchor |
| FR-FILE-07 (new) | P0 | Storage pre-check | Before running, estimate the needed space (2.5× the total input size); if free space < the estimate + 50 MB → InsufficientStorage before any work starts |
| FR-FILE-08 (new) | P0 | Open the result in another app | "Open with…" (Android `ACTION_VIEW` chooser; iOS `UIDocumentInteractionController` / Quick Look preview) |
| FR-FILE-09 (new) | P0 | Input size limits | Image ≤ 100 MB / 200 MP; PDF ≤ 500 MB; oversize → a clear message before copying |

### 5.9 History, settings, privacy
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-HIS-01 | P0 | Store operation metadata | Completed, failed, cancelled and interrupted jobs are recorded with tool, time, sizes, status, error code; never file contents or full paths |
| FR-HIS-02 | P0 | Open the output when available | Availability is checked on display; unavailable outputs are labelled; the entry can be removed |
| FR-HIS-03 | P0 | Clear history safely | D2 explains: "Clears the list. Files you saved elsewhere are not affected. App copies of results will also be deleted." with an option to keep the copies |
| FR-HIS-04 (new) | P0 | Output retention | App-managed result copies auto-delete after 7 days by default (options: 24 h / 7 d / 30 d / Keep until I delete); a sweep runs at launch |
| FR-HIS-05 (new) | P1 | Filter and sort | Filter by tool category and status; sort newest/oldest/largest saving |
| FR-SET-01 | P0 | Persist preferences | They survive restarts and app updates |
| FR-SET-02 | P0 | Explain privacy accurately | Privacy & About states that no file leaves the device, that no analytics are used, and lists the permissions used and why |
| FR-SET-03 (new) | P0 | Storage used | Shows the size of the app's result copies + temp files with **Clear now** |
| FR-SET-04 (new) | P0 | Open-source licences | Flutter `LicenseRegistry`-based page listing every dependency licence |
| FR-SET-05 (new) | P1 | Contact/feedback | A `mailto:` link with the app version and OS version prefilled (no file attachment, no logs unless the user adds them) |

### 5.10 App lifecycle (new)
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-LIFE-01 | P0 | Backgrounding during a job | Android: the job keeps running while the process lives (no foreground service in MVP — ADR-009); iOS: the job keeps running while the system allows (`beginBackgroundTask`, about 30 s); if the OS suspends or kills it, it is marked **Interrupted** at next launch with **Retry**. The Processing screen shows "Keep DocuKit open until this finishes" for inputs > 50 MB |
| FR-LIFE-02 | P0 | Rotation/resize/split-screen | No loss of inputs, options or Organizer edits |
| FR-LIFE-03 | P0 | Process death | Tool screen inputs/options are restored on relaunch for 24 h (state persisted in the job temp dir) — P1 for the Organizer's edit stack |
| FR-LIFE-04 | P0 | Low memory | Android `onTrimMemory`/iOS memory warning → clear the thumbnail caches; no crash |

### 5.11 PDF security (new)
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-PDF-ENC | P0 | Detect password-protected/encrypted PDFs | Detected at validation; message: "This PDF is password-protected. DocuKit can't open protected files yet." No attempt to bypass. (V1.4 adds unlock **with the user's password**) |

### 5.12 Home tour (v2.1 — TOUR.md)
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-TOUR-01 | P0 | Auto-start once for new users | Starts 600 ms after Home's first frame when `tour_done == false`, **after** onboarding and the consent form (if any) have closed. Never starts while a dialog/sheet is open |
| FR-TOUR-02 | P0 | Explain every tool | One step per tool (6), each with a title, what it does and a real example |
| FR-TOUR-03 | P0 | Always skippable | "Skip" is visible on every step; Android back on step 1 or the intro = skip; skip sets `tour_done = true` |
| FR-TOUR-04 | P0 | Back/Next navigation with progress | "Step 3 of 10" text + dots; Back is hidden on the first step; the last step's button reads "Done" |
| FR-TOUR-05 | P0 | Replay | Home app bar **help (?)** icon and Settings → "Take the tour" restart it from step 1 |
| FR-TOUR-06 | P0 | Targets always visible | Off-screen targets are scrolled into view (`Scrollable.ensureVisible`, alignment 0.35, 300 ms) before the spotlight moves |
| FR-TOUR-07 | P0 | Accessible | The tooltip is a focus-trapped modal; on each step the screen reader announces "Step n of 10. {title}. {body}"; all buttons ≥ 48 dp; reduce-motion → no animations; text scales to 200% (the tooltip grows, and the spotlight adapts) |
| FR-TOUR-08 | P0 | No interference | No ads while the tour is open (AD-1 is hidden until `tour_done`); taps on the scrim do nothing (no accidental tool launches); rotation/resize re-measures the target |
| FR-TOUR-09 | P1 | "Try it" on tool steps | A secondary "Try it" button on each tool step ends the tour (`tour_done = true`) and opens that tool |
| FR-TOUR-10 | P1 | Versioned "What's new" | `tour_version` int. When a release adds tools, existing users see only the new steps (titled "New in DocuKit") once |

### 5.13 Ads (v2.1 — ADS.md, ADR-028)
| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-ADS-01 | P0 | Ads only at AD-1…AD-9 (Phase B ones only when `adsPhase = B`) | No ad widget renders on the excluded screens (ADS.md §3) |
| FR-ADS-02 | P0 | Interstitial caps | All the §4 rules unit-tested |
| FR-ADS-03 | P0 | Consent before ad requests | No ad request until `canRequestAds()` is true; "Privacy & ad choices" row shown when required |
| FR-ADS-04 | P0 | Offline-safe | Slots collapse to zero height with no network or no fill |
| FR-ADS-05 | P0 | Clearly labelled | Every native ad shows an "Ad" badge and is visually distinct from tool cards |
| FR-ADS-06 | P1 | Remove ads | Purchase/restore hides all ads immediately and permanently |
| FR-ADS-07 | P0 | Rewarded ad-free pass (AD-8) | Reward only on `onUserEarnedReward`; 24 h with no ads of any kind; max 2 a day; offer hidden when no ad is loaded |
| FR-ADS-08 | P1 | App open ad (AD-7, Phase B) | All of ADS.md §4.2 unit-tested; never on a cold launch |
| FR-ADS-09 | P0 | Global caps | Full-screen ads ≥ 4 min apart and ≤ 3 per session; never two native cards visible at once (ADS.md §4.4) |

---

## 6. Non-functional requirements

| Category | Requirement |
|---|---|
| Performance | All decoding/encoding/PDF work runs off the UI isolate (native threads or `Isolate.run`). UI stays at 60 fps during processing. Progress is truthful; indeterminate when unknown |
| Stability | No known crash in supported workflows; a failure never corrupts or deletes an original |
| Privacy | No account. File contents never leave the device. Only the ads SDK uses the network, with consent where required. |
| Security | Least-privilege file access; never log file contents, names or full paths (log only job IDs and error codes); no app data is passed in ad requests; `FileProvider` paths restricted to the outputs/share directories; iOS data protection `NSFileProtectionCompleteUntilFirstUserAuthentication` on outputs |
| Storage | Pre-check free space; temp cleanup; a user-visible storage total |
| Accessibility | WCAG 2.2 AA contrast; Dynamic Type / font scale up to 200% without clipping; TalkBack and VoiceOver labels on every control; 48×48 dp touch targets; drag-reorder has a non-drag alternative; reduced-motion respected |
| Compatibility | Android 8.0 (API 26)+, target API 36 (Play requirement from 31 Aug 2026); iOS 15+, built with Xcode 26 / iOS 26 SDK (App Store requirement since 28 Apr 2026). Phones primary; tablets adaptive |
| Localisation | All strings in ARB files from day one (English); RTL-safe layouts (`EdgeInsetsDirectional`); locale-aware number/size formatting |
| App size | Android AAB download < 25 MB; iOS download < 40 MB (PDFium adds ~5–8 MB per architecture) |
| Maintainability | Feature folders; a single `OperationEngine` contract; a sealed error model; unit tests for all logic; lints at `very_good_analysis` or `flutter_lints` strict |
| Reliability | Success is never shown until the output is written, re-opened and validated |

---

## 7. Product metrics (privacy-preserving)

No analytics SDK in MVP. Measure through:
- **Local counters** (on-device only, visible to the user in Settings → "Your stats", P2): jobs completed per tool, total bytes saved.
- **Store dashboards**: Play Console Android vitals (crashes/ANRs, collected by the OS, not by the app) and App Store Connect crash reports from users who opted in at the OS level.
- **Feedback**: the in-app feedback mail link plus store reviews.
- **AdMob dashboard** (v2.1): impressions, eCPM, fill rate per placement; Remove ads conversion.
- Decide on any opt-in telemetry only after MVP, via a `DECISIONS.md` entry and privacy label updates.

| Metric | Source |
|---|---|
| Completion rate per tool | Test-cohort interviews; local counters (P2) |
| Failure rate by error code | Beta testers' exported diagnostics (an opt-in "Copy diagnostics" button that copies only codes and counts) |
| Crash-free sessions | Play vitals, App Store Connect |
| Median processing time by size band | `TESTING.md` benchmark script on reference devices |

---

## 8. Release acceptance criteria
1. All P0 requirements pass on both platforms (Android min-spec + current device; oldest supported iPhone + current iPhone).
2. Every operation creates a new output and preserves the original (checksum suite green).
3. Outputs are validated before success is displayed.
4. Every corpus edge case (`TESTING.md §3`) produces a clear message and no crash.
5. History and settings survive restart and app update.
6. Every tool works in airplane mode; the proxy log shows only ad/consent traffic, with no file data.
7. No open critical/high defects in data loss, privacy or crashes.
8. Licences, privacy policy, Play Data Safety form, App Store privacy nutrition label, `PrivacyInfo.xcprivacy`, icons, screenshots and signing all done (`RELEASE.md`).

---

## 9. Roadmap (solo developer + Claude)

| Milestone | Scope | Estimate | Exit gate |
|---|---|---|---|
| M0 Setup | Flutter project, flavours, lints, theme, router, l10n, CI, empty screens | 2–3 days | Builds and navigates on both platforms |
| M1 Foundation | File gateway (pick/copy/save/share/open), job temp dirs, OperationEngine, error model, drift DB, settings | 4–6 days | A "copy file" dummy tool works end to end on both platforms |
| M2 Image tools | Compressor, Resizer, Image→PDF | 5–8 days | Image regression passes on both |
| M3 PDF spike + tools | pdfrx spike (gate), Merger, Organizer, Reducer | 7–12 days | PDF regression passes on both |
| M4 Shared UX | Result/preview, history, settings, privacy, onboarding, incoming files (P1) | 3–5 days | UX consistent; all screen states implemented |
| M5 Hardening | Large files, lifecycle, accessibility, performance, edge corpus | 4–7 days | Release-candidate build |
| M6 Distribution | Store assets, privacy forms, licences, closed testing (Play requires a 12-tester/14-day closed test for new personal accounts), TestFlight | 3–5 days + review time | Approved on both stores |
| M7 v2.1 | UI refresh, Home tour, ads (+ Remove ads, P1) — TASKS T7.1–T7.13 | 6–9 days + 1–3 days of AdMob account review | R1–R26 pass; ads collapse cleanly offline / with no fill |

**Total: about 28–46 working days.** This is a range, not a promise. **Smaller first release option:** Compressor + Resizer + Image→PDF + Merger (cut the Organizer and Reducer to V1.1) saves about 6–9 days.

---

## 10. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| A PDF library gap (e.g. rotation or image replacement not exposed by pdfrx) | A PDF tool blocked on one or both platforms | M3 starts with a 1-day spike (TASKS T3.0); fallback: a native plugin method (iOS PDFKit, Android PdfBox-Android) behind the same `PdfEngine` interface |
| Compression expectations | Bad reviews | Truthful copy, real numbers, discard option, target-size mode |
| Memory pressure on large files | Crashes, iOS jetsam kills | Downsampled decoding, streaming per page/image, caches with limits, a profile on 3 GB RAM Android / iPhone SE |
| iOS background limits | Long jobs killed in the background | Background task assertion, the Interrupted state + retry, the copy "Keep DocuKit open for large files" |
| Store review (Apple 4.2 "minimum functionality", Play's closed-testing rule) | Release delay | Six real tools at launch; plan the 14-day Play closed test early (start at M4) |
| Licensing (PDFium BSD, pdfrx MIT, PdfBox Apache-2.0, fonts OFL) | Compliance | Licence page from `LicenseRegistry`; review transitive deps in M6 |
| AI-generated defects | Data loss, build breaks | Small tasks, tests first for logic, diff review, checksum suite in CI |
| Privacy-claim mismatch | Store rejection, trust | Network only in `core/ads/` (ADR-028), Data safety / privacy label declare the AdMob SDK; audit dependencies; the privacy manifest declares the required-reason APIs actually used |
| Scope creep | Never ships | Freeze P0; everything else goes into `TASKS.md` backlog |

---

## 11. Glossary
| Term | Meaning |
|---|---|
| SAF | Android Storage Access Framework: system UI for user-mediated open/save |
| PHPicker | iOS system photo picker; no photo-library permission needed |
| Security-scoped URL | iOS file URL from the document picker that needs `startAccessing…` to read |
| FileProvider | Android component that shares app files to other apps via `content://` URIs |
| PDFium | Google's PDF engine (BSD-3) used through the `pdfrx` package |
| Isolate | Dart's thread-like unit with separate memory, used for CPU work |
| Job | One run of a tool, with its own ID, temp directory, state and history record |
| App-managed output | The copy of a result kept in the app sandbox so History can reopen it |
| P0/P1/P2 | Must / should / later |
