# DocuKit — Decisions (ADRs)

Format: **Context → Decision → Consequences**. Add a new ADR rather than editing an accepted one; mark the old one *Superseded by ADR-0xx*.

---

### ADR-001 — Flutter as the cross-platform framework · *Accepted*
**Context.** The v1 PRD was native Android (Kotlin/Compose). The product must now ship on Android and iOS with one developer. The candidates were:

| Option | Pros | Cons |
|---|---|---|
| **Flutter** | One UI + logic codebase; mature on both OSes; strong PDF ecosystem via `pdfrx` (PDFium on both platforms, so identical PDF behaviour); good image plugins with native encoders; very well known to Claude | Dart is a third language next to small Kotlin/Swift plugin code; app size +PDFium |
| Kotlin Multiplatform + Compose Multiplatform | Reuses the v1 Kotlin plan; native performance | The iOS side of the PDF/image work needs separate PDFKit/CoreGraphics implementations (two engines → two sets of bugs); smaller library ecosystem for document UI |
| React Native / Expo | TypeScript; Expo modules | Large-file PDF manipulation in JS (pdf-lib) loads whole files into JS memory; you'd still write native modules for performance |
| Two native apps | Best platform fidelity | Doubles the work; not feasible solo |

**Decision.** Flutter (stable channel), Material 3, with a small local native plugin for OS-specific file operations.
**Consequences.** One PDF engine (PDFium) behaves the same on both OSes. iOS still gets platform-correct pickers, save dialogs and share sheets because those are system UI.

### ADR-002 — No network at all in MVP · *Superseded by ADR-028 (v2.1)*
**Decision.** Don't declare the Android `INTERNET` permission in release builds; add no analytics, crash-reporting or ads SDKs.
**Consequences.** The "nothing leaves your phone" claim is enforceable and easy to verify. Crash data comes only from Play vitals and App Store Connect. Any future telemetry needs a new ADR plus updated privacy labels.

### ADR-003 — Riverpod 3 without code generation · *Accepted*
**Decision.** Use `Notifier`/`AsyncNotifier`/`FamilyNotifier` written by hand. `build_runner` is used only by drift.
**Consequences.** Less generated code for Claude to get wrong; it's easy to add codegen later.

### ADR-004 — drift (SQLite) for history; shared_preferences for settings · *Accepted*
**Decision.** History is relational (operation + inputs) and needs queries/filters → drift. Settings are a flat key-value map → `SharedPreferencesWithCache` behind `SettingsRepository`.

### ADR-005 — PDFium via `pdfrx` as the PDF engine, with a native fallback per method · *Accepted, gated by spike T3.0*
**Context.** pdfrx (MIT) documents `PdfDocument.createNew`, assigning a `pages` list (pages from other documents allowed) for combine/reorder, `createFromJpegData`, and `encodePdf()` (page-manipulation support added in 2.2.8; current 2.9.0, Oct 2026). Rotation and per-image replacement aren't confirmed in the public docs.
**Decision.** Use pdfrx for inspect/render/merge/reorder/delete/encode. For rotation and Balanced-level image recompression, first try the pdfrx API; if it's absent, use raw PDFium calls through the bindings pdfrx ships (`FPDFPage_SetRotation`; page-object image replacement). If that fails, implement the one method natively (Android PdfBox-Android, Apache-2.0; iOS PDFKit `PDFPage.rotation`).
**Consequences.** The spike decides it. If Balanced can't be done reliably on both platforms in M3, ship Basic + Strong and move Balanced to V1.1 (ADR-013).

### ADR-006 — Own small native plugin for Save As / Open with / free space / background task · *Accepted*
**Context.** Generic plugins often pass whole files as bytes over the channel (memory spikes on 200 MB PDFs) or don't stream to a SAF URI.
**Decision.** `packages/docukit_native` with 5 methods (ARCHITECTURE §6.4), streaming from file paths.

### ADR-007 — Copy every input into a per-job temp directory at selection time · *Accepted*
**Decision.** Picked files are copied into `cache/jobs/<id>/in/` right away.
**Consequences.** Processing never depends on revoked Android URIs or iOS security-scoped URLs; originals can't be modified by accident; you need storage for the copy (handled by the pre-check).

### ADR-008 — Keep app-managed result copies with a retention policy (default 7 days) · *Accepted*
**Decision.** Every successful output is kept in `appSupport/outputs/<jobId>/`, so Result/History can reopen, share or save it again. The launch sweep deletes copies past the retention period. Saving elsewhere is always explicit.
**Consequences.** History can reopen files on both OSes without persisted URI permissions. Storage use is shown and clearable.

### ADR-009 — No Android foreground service in MVP · *Accepted*
**Context.** Foreground services on Android 14+ need a declared type and a Play Console declaration; the job lengths here are typically seconds. iOS has no equivalent anyway.
**Decision.** Jobs run in the app process. If the OS kills it, the job is recorded as Interrupted with Retry. Revisit if testers report long jobs being killed (candidate: `shortService` type).

### ADR-010 — File Selection Review (S09) embedded in the tool screens · *Accepted*
**Context.** The v1 PRD listed Review as its own screen. A separate step adds a tap to every job.
**Decision.** S09 is a shared `InputsSection` component inside every tool screen, plus a full-screen "Manage files" variant (`/review`) for multi-file tools with more than 6 items.

### ADR-011 — Material 3 everywhere, with iOS-adaptive behaviours · *Accepted*
**Decision.** One Material 3 design language (consistent brand, less code) with adaptive touches on iOS: Cupertino page transitions + edge-swipe back, `.adaptive` switches/dialogs/progress indicators, SF Pro through the system font, and bottom sheets with a drag handle.
**Consequences.** It looks native enough to pass review while keeping one widget tree.

### ADR-012 — Image→PDF built with the `pdf` package, chunked for big batches · *Accepted*
**Decision.** Normalise each image to JPEG (oriented, rotated, ≤ the dpi cap) with native code, then lay out pages with `pdf` in an isolate. If the prepared JPEGs total > 120 MB, build chunks of 25 pages and combine them with pdfrx. *Amended (v2.1 release fixes): always build chunks of 20 pages and combine them, whatever the size; one chunk (≤ 20 images) is written directly. Measured in TESTING §6: 100 × 12 MP went from +369 MB to +264 MB peak RSS.*
**Consequences.** Full control over page size, margins and fit; bounded memory.

### ADR-013 — PDF Size Reducer levels · *Accepted*
- **Basic** — lossless re-save (drops unused objects, incremental-update history and embedded thumbnails). Small or no gains.
- **Balanced (default)** — recompress embedded raster images above 150 effective dpi to JPEG q≈70, downscaled to 150 dpi; text/vectors untouched. *Depends on ADR-005.*
- **Strong (opt-in)** — rasterise each page at 120 dpi, JPEG q≈60. Text becomes image-only. Blocking warning.
- If the output ≥ input → the result screen says so and offers Discard (the default action).

### ADR-014 — HEIC/HEIF input defaults to JPEG output · *Accepted*
**Reason.** Upload portals and Windows often reject HEIC. The user can still choose "Same as original" on iOS, where HEIC encoding is supported.

### ADR-015 — Minimum OS versions: Android 8.0 (API 26), iOS 15 · *Proposed — confirm at M0*
**Reason.** Covers the large majority of active devices, is compatible with the plugin floors (Flutter itself supports Android API 24+ and iOS 13+), and avoids legacy storage paths below API 26. Store build rules: target API 36 for Play uploads from 31 Aug 2026; Xcode 26 / iOS 26 SDK for App Store uploads since 28 Apr 2026.

### ADR-016 — Store file display names in history (local only) · *Accepted*
**Decision.** History shows input/output file names (not paths), because "which file was this?" is the main use of history. They stay in the local DB, are removed with Clear history, and are never logged.

---

### ADR-017 — Dependency versions pinned to the installed Flutter 3.41.4 · *Accepted (2026-10-26)*
**Context.** The machine has Flutter 3.41.4 / Dart 3.11.1 (`meta` 1.17). The newest pdfrx (2.10, needs Dart 3.12), drift_dev ≥ 2.34.6 and archive ≥ 4.1 don't resolve against it, and `image` 4.11.0 calls `ZLibDecoder.decodeLazy`, which only exists in archive ≥ 4.1 (pdf 3.12 caps archive < 4.1), so it fails to compile.
**Decision.** Exact pins in `pubspec.yaml`: flutter_riverpod 3.3.2, go_router 17.5.0, drift 2.34.4 / drift_dev 2.34.0, drift_flutter 0.3.1, shared_preferences 2.5.6, image_picker 1.2.4, file_picker 13.3.0, flutter_image_compress 2.5.1, pdfrx 2.4.7 (+ pdfium_dart 0.2.5 for raw PDFium), pdf 3.12.0, image 4.10.0, share_plus 13.3.1, gal 2.3.3, path_provider 2.1.6, path 1.9.1, uuid 4.6.0, intl 0.20.2, package_info_plus 10.2.2, url_launcher 6.3.3, crypto 3.0.8, ffi 2.2.0. All MIT/BSD/Apache-2.0. `exif` was dropped (a 200-line header parser in `core/image/image_header.dart` covers orientation/GPS without a dependency).
**Consequences.** Upgrading Flutter later unlocks pdfrx 2.10 and image 4.12; re-run the test suite after any bump. The global SDK was deliberately not upgraded because other projects on this machine may depend on it.

**Update (2026-10-27).** The shared SDK was upgraded to **Flutter 3.47.8 / Dart 3.13.7** by another project. pdfrx_engine 0.4.5 no longer compiles on Dart 3.13, so DocuKit now pins **pdfrx 2.10.1** (engine 0.8.0, pdfium_dart 0.4.0) and **intl 0.20.3** (required by flutter_localizations). Every pdfrx/PDFium API DocuKit uses was re-checked in the new sources and is unchanged. `material.dart` no longer exports `CupertinoPageTransitionsBuilder` (imported from `cupertino.dart`), and `ReorderableListView.onReorder` is replaced by `onReorderItem`. analyze, all unit/widget tests, the real-PDFium host tests and the on-device integration tests pass on 3.47.8.

### ADR-018 — No Unicode NFC normalisation of file names · *Accepted*
**Context.** ARCHITECTURE §6.3 asks for `NFC(input)`. Dart has no built-in normaliser; it would need a new package.
**Decision.** Skip NFC in MVP. Names are still sanitised, truncated without splitting surrogate pairs, and de-duplicated.
**Consequences.** An iOS (NFD) name and an Android (NFC) name that look the same can both exist in `outputs/<id>/` — harmless, since each job has its own folder.

### ADR-019 — Image engine findings (spike T2.0, verified in plugin sources) · *Accepted; on-device check pending*
Verified by reading flutter_image_compress 2.5.1's Kotlin and Objective-C sources (not yet measured on devices):
- Both platforms scale by `max(1, min(w/minW, h/minH))` and truncate, never upscale; min dims are compared in EXIF-oriented space before the extra `rotate`. → Exact sizes need the Dart exact-resize step (FEATURE_SPECS §3.4 Step B), which also handles upscaling, fit modes and alpha → white.
- **Android `keepExif` copies `TAG_ORIENTATION` after the pixels are rotated → double rotation.** DocuKit only keeps EXIF for direct JPEG output and then rewrites the tag to 1 (`core/image/jpeg_exif_patch.dart`). Any path through the exact step drops metadata.
- WebP encodes on both platforms (OD-3: **WebP output included**). HEIC encode is offered on iOS only (Android HeifWriter depends on a hardware encoder, so it's hidden).
- Header facts (dimensions, orientation, alpha, GPS) come from a pure-Dart parser instead of `ImageDescriptor`, which is deterministic and unit-tested; HEIC falls back to the platform codec if `meta` comes after `mdat`.

### ADR-020 — pdfrx capabilities (spike T3.0, verified in pdfrx 2.4.7 sources) · *Accepted; on-device check pending*
- Rotation is supported by pdfrx itself: `PdfPage.rotatedBy(PdfPageRotation)` + `PdfDocument.pages =` + `encodePdf()`. **No native fallback (PdfBox/PDFKit) is needed.** ADR-005's gate is resolved for rotation.
- Merge / organize / Basic reduce: `PdfDocument.createNew` + `pages` setter + `encodePdf()` (in memory — see the large-file note in FEATURE_SPECS §4.2; measure a 400 MB merge on a 3–4 GB device).
- **Balanced (OD-5): included.** pdfrx doesn't expose image objects, so `core/pdf/pdfium_raw_ops.dart` uses the PDFium bindings that pdfrx ships (`pdfium_dart`) in a separate isolate while holding `PdfrxEntryFunctions.suspendPdfiumWorkerDuringAction`, so PDFium is never used from two threads. It recompresses only single-filter `DCTDecode` images whose effective dpi is > 160, that appear once in the file (shared logos are skipped to avoid duplicating data), downscaled to 150 dpi at JPEG q70, kept only if ≥ 10% smaller. Output is streamed with `FPDF_SaveAsCopy`. Masked/transparent images and line art are untouched by construction.
- Strong rasterises at 120 dpi → JPEG q60 → `createFromJpegData`, in chunks of 40 pages.
- Encrypted detection: `openFile` without a password provider throws `PdfPasswordException` → `encryptedDocument`. Owner-password-only PDFs open (no bypass is attempted).

### ADR-021 — Picker choice (spike T1.2, desk decision) · *Accepted; SHA-256 check on devices pending*
- Android images: `image_picker` → Android Photo Picker; with no resize/quality options it copies the original bytes.
- iOS images: `file_picker` `FileType.image` with `DarwinAssetRepresentationMode.current` → PHPicker without transcoding (HEIC stays HEIC).
- PDFs (both): `file_picker` custom `pdf` → SAF OPEN_DOCUMENT / UIDocumentPickerViewController.
- **Known trade-off (decide before release):** on Android the Photo Picker hands `image_picker` a media-ID name (e.g. `1000000019.png`), so outputs/history show that instead of `IMG_2041.jpg`. Switching Android images to `file_picker` (`ACTION_GET_CONTENT`) keeps real names but isn't the Photo Picker that FR-FILE-01 specifies.
- Plugin cache copies are *moved* into `cache/jobs/<draftId>/in/` only when they're inside the app's own directories; anything else is copied, so a user's file can never be moved or modified.

### ADR-022 — OD-1 provisional identifiers · *Proposed — confirm before the first store upload*
Android `applicationId` and iOS bundle ID: `com.npmtechsolutions.docukit`; display name "DocuKit". Check trademark/store availability; the ID can't change after release.

### ADR-023 — Android backup disabled · *Accepted*
`allowBackup="false"` plus data-extraction rules exclude history, settings and result copies from cloud backup and device transfer, consistent with "files never leave your phone". (iOS outputs are excluded from iCloud backup by `docukit_native.protectOutput`.)

### ADR-024 — OD-4: receive-from-other-apps (MVP-10, S19) moves to V1.1 · *Accepted*
It needs native intent/open-URL handling on both OSes and device testing; the six core tools ship first.

### ADR-025 — Reorderable grids without `reorderable_grid_view` · *Accepted*
`ReorderableGrid` (Images → PDF, ≤ 100 items) and `ReorderableSliverGrid` (Organizer, lazy, ≤ 2,000 pages) are built on Flutter's `LongPressDraggable` + `DragTarget`, with edge auto-scroll. Lists use `ReorderableListView`. Every reorder has a non-drag "Move to…" path.

### ADR-026 — Feedback address via `--dart-define` · *Accepted*
`DOCUKIT_FEEDBACK_EMAIL` is a build-time define; the "Send feedback" row is hidden when it's empty, so no placeholder address can ship.

### ADR-027 — Visual polish inside the design system · *Accepted*
Home and Onboarding use a primary-family gradient hero, a new `Radii.xl` (24) token for hero surfaces, tinted gradient icon tiles and a subtle watermark glyph on tool cards. Category accents still appear only in icon tiles and category headers; all colours come from tokens.

---

### ADR-028 — Ads via Google AdMob; supersedes ADR-002 · *Accepted (v2.1)*
**Context.** Free distribution needs revenue.
**Decision.** Use `google_mobile_ads` with the UMP consent flow, the placements in ADS.md §3 (Phase A: AD-1…AD-6 + AD-8; Phase B: AD-7, AD-9), and the frequency rules in ADS.md §4. Only `lib/core/ads/` may access the network; the processing engines never do.
**Consequences.** The INTERNET, ACCESS_NETWORK_STATE and AD_ID permissions; the Data safety form and App Store privacy label must now declare the SDK's data collection; the privacy copy is rewritten; offline use still works fully, with ad slots collapsing.

### ADR-029 — No App Tracking Transparency prompt in v2.1 · *Accepted (v2.1)*
**Decision.** Don't request ATT on iOS.
**Consequences.** No scary system prompt and "Used to track you: No"; possibly lower iOS ad revenue. Revisit after 60 days of data.

### ADR-030 — One-time "Remove ads" purchase · *Accepted (P1, v2.1)*
**Decision.** A non-consumable `remove_ads` via `in_app_purchase`, verified client-side (no server).
**Consequences.** Product setup in both stores; a restore flow; a paid-apps agreement plus tax/banking forms in App Store Connect and the Play payments profile.

### ADR-031 — Custom spotlight overlay for the Home tour · *Accepted (v2.1)*
**Decision.** Build a small custom overlay instead of a showcase package (TOUR.md §4), because the grid needs scroll-into-view and full a11y control.
**Consequences.** About 250 lines; no dependency risk.

### ADR-032 — Brand heading font + gradients · *Accepted (v2.1)*
**Decision.** Bundle Plus Jakarta Sans (OFL) for headings only; add the gradient tokens (UI_REFRESH.md §1); illustrations via `flutter_svg` or `CustomPainter`.
**Consequences.** < 600 KB size increase; licence entries. Builds on ADR-027 (the existing gradient hero, tool cards and tokens are kept and restyled, not replaced).

### ADR-033 — Contrast fixes to the v2.1 tokens · *Accepted (v2.1, T7.1)*
**Context.** UI-REF-03 requires text ≥ 4.5:1 and graphics ≥ 3:1. The new contrast test (`test/app/contrast_test.dart`) failed four values: white text on the `surfaceGlass` chip (white 14% over `#2F5BEA` → 4.25:1), white glyphs on the light end of `imageGradient` (`#26C6DA` → 2.06:1; dark `#3BB8C9` → 2.36:1), and the existing `success` text on its container (`#1B7F3B` → 4.40:1).
**Decision.** `surfaceGlass` fill becomes black @ 10% (the white 24% border stays) → ≥ 6:1; `imageGradient` ends at `#0097A7` (light) / `#1593A4` (dark) → ≥ 3.2:1; `success` (light) becomes `#187536` → 5.0:1. All other UI_REFRESH §1 values are unchanged.
**Consequences.** Slightly deeper teal tiles and a darker glass chip than the mockup; the contrast test guards all token pairs in both themes.

### ADR-034 — Apply the EXIF mirror ourselves on Android · *Accepted (v2.1 release fixes, R7)* · ⚠️ *iOS to verify in the Xcode round*
**Context.** The R7 on-device test (`integration_test/engines_test.dart`, fixtures from `tool/fixtures/orientation.dart`) showed that on Android, EXIF orientations **2, 4, 5 and 7** (the mirrored ones) came out mirrored from the Resizer, the Compressor and Images → PDF. The size was right and 1/3/6/8 were correct. Cause: `flutter_image_compress` on Android rotates by `ExifInterface.rotationDegrees` but never applies the flip that `isFlipped` reports.
**Decision.** Keep the native rotate + downscale step. On Android, when the orientation is mirrored, send the image through the Dart exact-resize step and apply the remaining flip there: horizontal when the total rotation (EXIF + user) is 0/180°, vertical when it's 90/270° (`mirrorAfterNativeRotation` in `lib/core/image/resize_math.dart`; 32 host cases in `test/core/exif_mirror_test.dart` model the Android behaviour exactly). Not applied on iOS: there the plugin decodes through `UIImage`, which normally honours mirrored orientations, but **this is unverified**.
**Consequences.** Mirrored inputs (rare: mostly some front-camera and edited photos) always take the slower Dart step on Android, even when no resize is needed. **Xcode round:** run `flutter test integration_test/engines_test.dart -d <iPhone/simulator>`. If orientations 2/4/5/7 fail there, enable the same correction on iOS (drop the `Platform.isAndroid` guard in `image_engine_impl.dart` after checking the plugin's iOS rotation behaviour).

### ADR-035 — Bottom banners on most screens (owner decision) · *Accepted (v2.1, overrides parts of ADR-028 and ADS.md §3)*
**Context.** The owner decided to show an anchored adaptive banner at the bottom of most screens, including Search, the tool screens and Privacy & About. These were on ADS.md's "never show ads on" list. This decision overrides that list and CLAUDE.md rule 11 **for bottom banners only**. Native cards, the interstitial and the rewarded ad keep their ADS.md rules.
**Decision.** One shared `AppBottomBanner` (anchored adaptive banner), hosted by `WithBottomBanner`, in its own reserved space **below all content**, never drawn over content. It collapses to zero height when there's no ad, after Remove ads, during the 24 h ad-free pass, during the tour, while the keyboard is open, and while a dialog/sheet is open over the screen.
- `ADMOB_BANNER_MAIN`: Home, Search, Result, Recent activity, Operation details.
- `ADMOB_BANNER_TOOLS`: the 6 tool screens and Manage files. On tool screens and the Organizer, a 24 dp gap and a 1 dp divider sit between the bottom action button (or selection bar) and the banner.
- `ADMOB_BANNER_INFO`: Privacy & About, Licences.
- `ADMOB_BANNER_SETTINGS`: Settings (AD-5, unchanged).
- Every key accepts `off` (no slot built) and goes through the release ID check.
- Never on: onboarding, the tour, Processing, Error, dialogs/sheets, the full-screen page preview.
**Consequences.** More ad inventory. **Risk, accepted by the owner:** AdMob's policy guidance warns against banners next to buttons on working screens, and Google can limit ad serving for an app (or account) that gets accidental clicks. The 24 dp gap and divider reduce this; watch the AdMob Policy center and the click-through rate after launch, and switch `ADMOB_BANNER_TOOLS=off` (no code change) if there's a warning. Hidden ad diagnostics (Settings → tap the version 7 times) show each slot's last result.

## v3 releases (1.1–1.5) — merged from `docs/features/RELEASE_V1_x.md` in M0

Numbered from the next free ADR (ADR-036). The release specs now use these numbers. Statuses are as written in the specs; spikes (T8.0, T9.0, T10.0, T11.0, T12.0) confirm or amend them.

### ADR-036 — One per-item code path for single and batch image tools · *Proposed (v1.1 spec, merged in M0)*
*Context:* duplicating compress/resize logic for batch would let the two drift apart. *Decision:* single-image jobs are batches of one through `MultiToolOperation`, presented with the single-result screen when N = 1. *Consequences:* a one-time refactor of the 1.0 operations; all existing tests must keep passing unchanged.
**Merge note (M0).** Must keep ADR-034 (Android EXIF-mirror path via `mirrorAfterNativeRotation`) and the R7 orientation tests unchanged; see conflict C-2.
**As built (T8.5, Compressor).** The shared code is one per-image function, `compressOneImage`, called by both the single tool (`CompressImageOperation`, still a `ToolOperation` → S11) and `BatchCompressOperation` (`MultiToolOperation` → S22, used when 2+ images are picked). The single tool is not routed through `runMulti`: that keeps S11's single-result data (before/after preview, rename) and the 1.0 tests unchanged with no conversion layer, while the logic still has exactly one copy. Each batch item runs in its own work subfolder (the step clears its own target-size attempts). T8.6 does the same for the Resizer.

### ADR-037 — Incoming files implemented in `docukit_native`, not `receive_sharing_intent` · *Proposed (v1.1 spec, merged in M0)*
*Context:* `receive_sharing_intent` has had no release in over a year; the share-in path touches launch modes and scene delegates, which we want under our control. *Decision:* implement `getIncomingFiles` + an EventChannel in the local plugin. *Consequences:* ~250 lines of Kotlin/Swift we own; iOS must be verified in the Xcode round.

### ADR-038 — No iOS Share Extension in 1.1 · *Proposed (v1.1 spec, merged in M0)*
*Context:* a Share Extension gives DocuKit an icon in the iOS share sheet's action row, but it's a separate target with its own memory limit (~120 MB) and needs an App Group to hand files to the app. *Decision:* use document types ("Open in DocuKit" / "Copy to DocuKit") only. *Consequences:* iOS users find DocuKit in the share sheet's app row, not as an action. Revisit if testers ask.

### ADR-039 — ZIP implementation · *Accepted (resolved by T8.0, 2026-10-28 — see ADR-060: `archive` 4.0.9, STORE via `addArchiveFile`)*
*Context:* the `archive` package may buffer entries in memory depending on version. *Decision:* use `archive` if it streams from disk; otherwise ship the small store-only writer in §4.5. *Consequences:* either way, ZIPs are STORE-only for already-compressed formats.

### ADR-040 — Batch outputs counted as one job for ads and history · *Proposed (v1.1 spec, merged in M0)*
*Context:* AD-3 counts completed jobs; a 50-image batch shouldn't trigger more interstitials. *Decision:* one batch = one job everywhere (history, AD-3 counters, savings counter adds the batch total). *Consequences:* simpler mental model; slightly fewer interstitial opportunities.

### ADR-041 — Use the system document scanners via our own native channel · *Proposed (confirm at T9.0) (v1.2 spec, merged in M0)*
*Context:* building a camera + edge-detection pipeline ourselves is weeks of work and hard to make good. *Decision:* Android ML Kit Document Scanner (Play services) and iOS VisionKit, both behind `docukit_native.scanDocument`, returning JPEGs only; DocuKit builds the PDF with its existing builder. *Consequences:* no camera permission on Android; no scanner on devices without Play services; the scanning UI looks different on each OS (accepted — it's the native experience users know).

### ADR-042 — Scanner output always JPEG pages, never the scanner's own PDF · *Accepted (v1.2 spec, merged in M0)*
*Reason:* one PDF path for the whole app (page sizes, quality presets, chunking, validation), and reordering/rotation after scanning. ML Kit's `RESULT_FORMAT_PDF` is not requested.

### ADR-043 — No visible "Make searchable" in 1.2 · *Accepted (v1.2 spec, merged in M0)*
*Reason:* a disabled control that says "coming soon" adds clutter and invites "doesn't work" reviews. `ScanOptions.makeSearchable` exists as a hook; 1.3 adds the toggle to S29 and wires it to OCR.

### ADR-044 — iOS minimum 15.5 · *Proposed (confirm in T10.0) (v1.3 spec, merged in M0)*
*Context:* `google_mlkit_text_recognition` requires an iOS 15.5 deployment target. *Decision:* raise DocuKit's iOS minimum from 15.0 to 15.5 starting with app version 1.3. *Consequences:* devices stuck on iOS 15.0–15.4 keep version 1.2; docs and store notes are updated.
**Merge note (M0).** Amends ADR-015 (iOS 15) from app version 1.3; see conflict C-9.

### ADR-045 — OCR scripts and model packaging · *Proposed (decided by measurement in T10.0) (v1.3 spec, merged in M0)*
*Decision rule:* Latin on both platforms; Devanagari if the iOS download stays under 60 MB; Android uses unbundled (Play services) models if available through the plugin, otherwise bundled. Chinese/Japanese/Korean later.

### ADR-046 — Searchable PDF construction · *Proposed (v1.3 spec, merged in M0)*
*Decision:* image + invisible text (render mode 3) built with the `pdf` package, per line with horizontal scaling (per word for long or uneven lines); embedded Noto fonts; pages that already have text are imported unchanged. Fallback: PDFium page objects via `PdfStamper` (v1.4) if the `pdf` package can't set render mode 3.

### ADR-047 — OCR text privacy · *Accepted (v1.3 spec, merged in M0)*
*Decision:* OCR text lives only in the job's work dir (deleted with the job) and in the outputs the user chose. It's never logged, never in history, and never sent anywhere. The v1.5 Library index is the only future place it may be stored, under its own ADR.

### ADR-048 — Stamping via PDFium page objects · *Proposed (decided by T11.0) (v1.4 spec, merged in M0)*
*Context:* Sign and Watermark must add images to existing pages on both platforms without re-rendering pages. *Decision:* use PDFium FFI image objects (`FPDFPageObj_NewImageObj` + `FPDFImageObj_SetBitmap` + matrix), with text rendered to transparent PNGs in Flutter. *Fallback:* native per-platform insertion if alpha isn't preserved. *Consequences:* one implementation for both OSes; text watermarks aren't searchable.

### ADR-049 — Encryption via platform/native libraries · *Proposed (decided by T11.0) (v1.4 spec, merged in M0)*
*Context:* PDFium can't encrypt. *Decision:* iOS PDFKit write options; Android PdfBox-Android (Apache-2.0) with AES-256; owner password random and discarded; Unlock prefers PDFium `FPDF_REMOVE_SECURITY`, then native. *Consequences:* +3–5 MB on Android; dependency on a library whose last seen release is 2.0.27.0 (maintenance risk accepted; isolated behind `PdfSecurity`).

### ADR-050 — Saved signatures are opt-in, local-only and excluded from backups · *Accepted (v1.4 spec, merged in M0)*
*Decision:* default "Not now"; max 3; `appSupport/signatures/`, excluded from iCloud and Android Auto Backup; deleted immediately on request. *Consequences:* a signature is lost on a phone change; acceptable for a sensitive artefact.
**Merge note (M0).** Android is already covered by ADR-023 (backup off for the whole app).

### ADR-051 — Export compliance for 1.4 · *Open (v1.4 spec, merged in M0)*
*Decision needed before submitting 1.4:* how to answer App Store Connect's encryption questions now that the app encrypts user files (AES via OS/standard libraries). Verify Apple's current exemption criteria; update `ITSAppUsesNonExemptEncryption` only according to that answer.

### ADR-052 — Visual signatures only · *Accepted (v1.4 spec, merged in M0)*
*Decision:* no certificate-based digital signatures in 1.4; the UI says so. *Revisit* if users ask for PAdES (it would need certificate management and a different library).

### ADR-053 — No bypass, ever · *Accepted (v1.4 spec, merged in M0)*
(reaffirms DECISIONS and the PRD exclusions) *Decision:* Unlock requires the correct password; no guessing, dictionary, retries or "recovery"; no keywords suggesting otherwise. *Consequences:* a smaller feature set than some competitors; protects store standing and trust.

### ADR-054 — Library excluded from cloud backups by default · *Accepted (v1.5 spec, merged in M0)*
Keeps the "files never leave your phone" promise literal. Android Auto Backup and iCloud backup exclude the library and the app database. *Consequence:* users must export a ZIP to move phones; the app warns clearly. Revisit if users ask for an opt-in "Include in device backup" switch (P2).
**Merge note (M0).** On Android this is already true for the whole app: ADR-023 disables backup (`allowBackup=false`, `fullBackupContent=false`, data-extraction rules). The 1.5 work there is to add `files/library/` to the rules explicitly; iOS needs `isExcludedFromBackup` on `library/`.

### ADR-055 — Searchability policy: scans ON, other files OFF by default · *Accepted (v1.5 spec, merged in M0)*
OCR is CPU- and battery-heavy; scans are image-only and benefit most, while most other PDFs already contain text (indexed for free from the text layer). Manual "Make searchable now" available for any document.

### ADR-056 — Device credentials only; no DocuKit PIN · *Accepted (v1.5 spec, merged in M0)*
Avoids storing secrets, avoids a forgotten-PIN lockout, uses OS-level security. *Consequence:* the lock needs a device screen lock; otherwise the option is disabled.

### ADR-057 — Lock scope defaults to My Documents only · *Accepted (v1.5 spec, merged in M0)*
Tools and Recent stay quick to use; users who want everything locked can choose "Whole app".

### ADR-058 — No WorkManager/background tasks for indexing in 1.5 · *Accepted (v1.5 spec, merged in M0)*
Indexing runs only while the app is open (foreground), keeping behaviour identical on both OSes and avoiding background-execution policies. Revisit if large libraries index too slowly.

### ADR-059 — Suggest expiry dates from OCR text · *P2 idea, not in 1.5 (v1.5 spec, merged in M0)*
Detect "Date of expiry" patterns in recognised text and offer to set the expiry. Not in 1.5.

### ADR-060 — T8.0 spike results (release 1.1) · *Accepted (2026-10-28)* · ⚠️ *iOS checks pending the Xcode round*
**Setup.** Android emulator `DocuKit_API34` (API 34, x86_64, software GPU), on branch `release/1.1`. Throwaway target `lib/debug/spike_t80_main.dart` (`flutter run -t …`), run in **profile** mode for timings (debug JIT numbers in brackets). The Android folder-save method `spikeSaveManyToTree` in `docukit_native` is debuggable-only and is deleted in T8.3. Versions: `archive` **4.0.9** (already locked transitively; now pinned as a direct dependency, so nothing new is shipped), `flutter_image_compress` 2.5.1, `pdfrx` 2.10.1, `image` 4.10.0, `androidx.documentfile:documentfile` 1.0.0 (already in the app's release graph transitively).

| Check | Result | Measurement |
|---|---|---|
| 1. ZIP streaming, 50 × 10 MB incompressible files (500 MB) | **PASS** with STORE | `ZipFileEncoder()..create(out)`; per file `ArchiveFile.stream(name, InputFileStream(path))..compression = CompressionType.none` → `enc.addArchiveFile(f)` → close the `InputFileStream`; `enc.closeSync()`. **18.1 s** [debug 24.0–46.7 s], RSS **+1 MB** [debug +27–40 MB] (sampled every 20 ms; encoder in `Isolate.run`). Reopened with `ZipDecoder().decodeStream(InputFileStream(zip))`: 50 entries, sizes correct |
| 1b. Default `ZipFileEncoder.addFile` | **Not usable** | Always deflate (it has no STORE option); deflates each whole file into an `OutputMemoryStream` first. **124 s** [debug 508 s], RSS +37 MB [debug +61 MB], and the output is no smaller for JPEG-like data |
| 2. WebP encode (Android) | **PASS** | `FlutterImageCompress.compressWithFile(path, format: CompressFormat.webp, quality: 85)`: RIFF/WEBP output; 2000×1500 photo in 0.70 s (190 KB); alpha PNG → WebP **keeps alpha** (decoded with `img.decodeWebP`) |
| 2b. HEIC encode (Android) | **PASS on this emulator only** | `CompressFormat.heic` → `ftyp heic`, decodes back via `compressWithList(…, format: jpeg)`. 2.64 s for the photo, 878 KB (larger than JPEG at 492 ms / 308 KB). It depends on the device's HEVC encoder, so **keep HEIC output iOS-only** (FR-CNV-02, ADR-019) |
| 3. P2I RGBA → JPEG/PNG (A4 page; pdfrx `page.render(fullWidth:, fullHeight:, backgroundColor: 0xFFFFFFFF)` gives BGRA `pixels`) | **PASS** | Render: 92 ms at 150 dpi (1240×1753), 250 ms at 300 dpi (2480×3507). **Fastest:** wrap the BGRA in a 32-bit BMP header (BITMAPV4, BI_BITFIELDS, top-down) and encode natively with `compressWithFile(bmp, format: jpeg|png, minWidth: w, minHeight: h)`: **JPEG 295 ms / 857 ms**, **PNG 339 ms / 1,638 ms** (150 / 300 dpi), exact pixel size kept. `image` package in `Isolate.run`: JPEG 1,354 / 5,438 ms (+96 MB RSS at 300 dpi), PNG 806 / 3,134 ms. `PdfImage.createImage()` + `toByteData(png)`: 464 / 1,568 ms (on the UI isolate) |
| 4. Save 50 files to a picked folder (Android) | **PASS** | `ACTION_OPEN_DOCUMENT_TREE` → `DocumentFile.fromTreeUri`; 50 × 3 MB: **`DocumentsContract.createDocument(resolver, dirUri, mime, name)` + 64 KB stream copy = 8.7 s** (create 5.6 s). `DocumentFile.findFile` + `createFile` = 29.4 s (create 25.8 s): `findFile` lists the folder on every call, so it gets slower with every file. 50/50 files present in both |
| 5. iOS multi-URL export picker | **NOT RUN** | No Xcode on this Mac. To check in the Xcode round: `UIDocumentPickerViewController(forExporting: urls, asCopy: true)` with 50 URLs; `didPickDocumentsAt` count; cancel path; HEIC/WebP encode with flutter_image_compress on iOS |

**Decisions.**
- ZipBuilder (T8.3) uses `archive` 4.0.9 with STORE entries via `addArchiveFile`, not `addFile` (resolves ADR-039; no custom writer needed). All 1.1 outputs are JPG/PNG/WebP/PDF, so every entry is STORE. 18 s for 500 MB is mostly the two Dart passes (CRC32 + copy); the progress shown is "Zipping n of N" per entry.
- `saveManyToFolder` (T8.3, Android) uses `DocumentsContract.createDocument` directly. The provider de-duplicates names itself (" (1)"), so there's no `findFile` loop. Spec §4.4's `findFile`/`createFile` wording changes accordingly.
- PDF to Images (T8.8) encodes each page through the BMP wrapper + `flutter_image_compress` (native, off the UI isolate), one page at a time. The `image`-package isolate path is the fallback if a device's codec refuses the BMP.
- WebP output is offered on both OSes; HEIC output on iOS only (unchanged).

**Consequences.** Emulator numbers on a software GPU; recheck on a real phone in T8.14. `lib/debug/` and `spikeSaveManyToTree` were removed in T8.3, along with the spike's direct `androidx.documentfile` dependency (the real `saveManyToFolder` doesn't use `DocumentFile`). **Xcode round (T8.3):** compile `DocukitNativePlugin.swift`; export 50 files with `saveManyToFolder` (count, cancel, the folder name); check hard-link staging falls back to copy; ZIP build/validate on iOS.

---

### ADR-061 — Contrast for the v3 category colours · *Accepted (2026-10-28, T8.1)*
**Context.** FULL_PRODUCT §4.5 / UI_REFRESH §1 add `scanGradient`, `secureGradient` and `libraryGradient` and ask for white-on-gradient ≥ 4.5:1 at the lightest stop. The existing tiles don't meet 4.5:1 (image `#0097A7` 3.5:1, pdf `#F0437A` 3.6:1): ADR-033 treats a tile's white icon as a graphic (WCAG 1.4.11, 3:1), and `test/app/contrast_test.dart` checks tiles at 3:1. Measured against white: scan `#22B8CF` 2.4:1 and `#48C6D8` 2.0:1 (fail even 3:1); dark scan start `#2399B0` 3.4:1; secure all ≥ 3.6:1; library `#64748B` 4.8:1, dark `#5B6B80` 5.4:1, `#8A97A8` 3.0:1.
**Decision.** Same rule as ADR-033: **scan and secure tiles hold only an icon → 3:1**; **library carries text (My Documents card) → 4.5:1**. Darkened, keeping hue and saturation: scan end `#22B8CF` → `#1D9BAF` (light, 3.3:1) and `#48C6D8` → `#259BAC` (dark, 3.3:1); library dark end `#8A97A8` → `#667589` (4.7:1). Secure is unchanged. Accents: light = the darkest light stop (`scanAccent #0E7490`, `secureAccent #7C3AED`, `libraryAccent #334155`); dark = the spec's lightest dark stop (`#48C6D8`, `#D04BDF`, `#8A97A8`), because dark-theme accents are light tints like `imageAccentD`. Accents are used only for icon tiles and strips, so they're tested at ≥ 3:1 on all three surfaces (worst case 4.1:1). Tokens live in `DocuColors` (`scanGradient`, `secureGradient`, `libraryGradient`, `*Accent`). No `ToolCategory` values are added until a tool uses them (1.2 / 1.4 / 1.5).
**Consequences.** Slightly deeper scan tiles and a flatter dark library gradient than the mockup. If the owner wants 4.5:1 on every tile, the scan and secure ends would need to go much darker, and so would the existing image/PDF tiles. That would reverse ADR-033, so it would need a new ADR.

## Open decisions

| # | Decision | Default recommendation | Resolve by |
|---|---|---|---|
| OD-1 | Final app name & bundle IDs (provisionally `com.npmtechsolutions.docukit`, ADR-022) | Check trademark + both stores; the bundle ID can't change after release | Before M0 ends |
| OD-2 | Support iPad as a first-class target? | Yes, with the adaptive layout (needs iPad screenshots) — or untick iPad in Xcode for MVP if short on time | M4 |
| OD-3 | WebP output in the MVP compressor | **Resolved: included** (ADR-019) | M2 |
| OD-4 | Receive-from-other-apps (MVP-10) in MVP | **Resolved: V1.1** (ADR-024) | M4 |
| OD-5 | Balanced PDF reduction in MVP | **Resolved: included**, pending device verification (ADR-020) | M3 day 1 |
| OD-6 | Monetisation | **Resolved (v2.1):** ad-supported via AdMob (ADR-028) with a one-time Remove ads purchase (ADR-030). A later "Pro" unlock for batch/OCR is still possible | After 1k users |
| OD-7 | Opt-in diagnostics | None in MVP; reconsider with a privacy review | V1.1 |
| OD-8 | Distribution | Play internal → closed (12 testers / 14 days) → production; TestFlight internal → external → App Store | M6 |
| OD-9 | Ship 1.1 on its own or bundle it with the next | **Ship on its own** (FULL_PRODUCT §2) | End of M8 |
| OD-10 | Ship 1.2 on its own or bundle it with the next | **Ship on its own** | End of M9 |
| OD-11 | Ship 1.3 on its own or bundle it with the next | **Ship on its own** | End of M10 |
| OD-12 | Ship 1.4 on its own or bundle it with the next | **Ship on its own** | End of M11 |
| OD-13 | Ship 1.5 on its own or bundle it with the next | **Ship on its own** | End of M12 |

### v3 merge conflicts (M0, 2026-10-28) — awaiting the owner

Found while merging the v3 specs. None was resolved silently in code; each row has a proposed resolution. Doc-only fixes already applied are marked.

| # | Conflict | Proposed resolution | Status |
|---|---|---|---|
| C-1 | **ADR-035 bottom banners vs new full-screen editors.** `ToolScaffold` always hosts `ADMOB_BANNER_TOOLS`, but FULL_PRODUCT §4.4 says the scanner, crop/filter editor, signature pad, placement editor and OCR review have **no** banner. | Editors don't use `ToolScaffold` (own full-screen route, like the page preview). Tool *option* screens keep `ToolScaffold` + banner + 24 dp gap. ADR-035's MAIN list gains batch/multi result, Library screens and document detail; SETTINGS gains Library settings (ADS.md §3.1). No new unit IDs, so the release ID check is unchanged. | Proposed |
| C-2 | **ADR-036 (one per-item path) vs ADR-034 (Android mirror fix).** The batch refactor rewrites Compress/Resize. | The per-item function wraps the current engine calls unchanged, including `mirrorAfterNativeRotation`. R7 and `integration_test/engines_test.dart` must pass unchanged before T8.6 is done. | **Compressor done (T8.5):** `engines_test.dart` 13/13 on the emulator after the refactor. Resizer in T8.6. |
| C-3 | **Chunked Images→PDF builder (ADR-012 amended: always chunks of 20).** 1.2 (scanner) and 1.3 (searchable PDF) reuse it. | Compatible: reuse `ImageToPdfBuilder` as is. The scanner's "Fit to scan" (200 dpi) is a new page-size option, not a change to the existing "Same as image" rule. The searchable-PDF builder keeps the same 20-page chunking. | No conflict; note only |
| C-4 | **Drift schema version.** RELEASE_V1_1 §5.1 says "v2 → v3"; the code is at `schemaVersion => 1` and **no drift schema snapshot is committed**, so the specs' "migration test from every snapshot" has no baseline. | First commit a v1 snapshot (`drift_dev schema dump`) on `release/1.1`; then 1.1 = v1→v2, 1.2 = +1 (ToolId added; spec asks for a bump + test), 1.5 = +1. Each release adds a snapshot + migration test. | **Applied for 1.1 (T8.2), with a change:** the pinned `drift_dev` 2.34.0 CLI doesn't compile against `drift` 2.34.4 (`allSchemaEntities` missing), so `schema dump` can't run. Instead the v1 DDL was dumped from the 1.0 code into `test/data/schemas/schema_v1.sql`; `test/data/migration_test.dart` builds a real v1 database from it, migrates it, and compares columns, foreign keys and indexes with a fresh v2 database. Each later release adds `schema_vN.sql` the same way. Moving to drift_dev's own snapshots needs a drift + drift_dev upgrade (owner decision; an ADR). |
| C-5 | **Android launch mode.** RELEASE_V1_1 §4.8 wants `singleTask`; MainActivity is `singleTop` today. Risk to UMP consent / AdMob activities, purchases and go_router deep links. | Try `singleTask` in T8.12 with the spec's checks (consent form, interstitial, Remove ads purchase, quick-action deep links, share-in while running and cold). If any fails, stay on `singleTop` and use `onNewIntent` (the spec's own fallback). | Proposed |
| C-6 | **`local_auth` needs `FlutterFragmentActivity` (1.5).** MainActivity extends `FlutterActivity`. | Verify the requirement in T12.0; if needed, switch the base class and re-run the ads, consent, purchase, picker and share-in checks. | Proposed (1.5) |
| C-7 | **Settings keys.** `tour_version` is code `currentTourVersion = 1`. Specs bump it per release. | 1.1 → 2, 1.2 → 3, 1.3 → 4, 1.4 → 5, 1.5 → 6 (only bump when a release adds tour steps; all five do). All other new keys are new names; no clashes found with ARCHITECTURE §8.1. | Proposed |
| C-8 | **Corpus ID collision.** RELEASE_V1_1 §8 and RELEASE_V1_4 §8 both defined IMG-22, IMG-23, PDF-13, PDF-14. | **Applied (docs only):** the 1.4 files are now IMG-24 (`signature_photo.jpg`), IMG-25 (`logo_alpha.png`), PDF-15 (`cropbox_offset.pdf`), PDF-16 (`owner_restricted.pdf`) in RELEASE_V1_4 and TESTING.md. | Applied |
| C-9 | **iOS minimum.** ADR-015 says iOS 15; ADR-044 raises it to 15.5 from 1.3 (ML Kit text recognition). | Keep 15.0 for 1.1–1.2; raise in `release/1.3` only after T10.0 confirms; update PRD/RELEASE compatibility rows then. | Proposed (1.3) |
| C-10 | **No-network rule (CLAUDE.md #5) vs ML Kit.** 1.2/1.3 add ML Kit (Play services scanner; text recognition). The specs note ML Kit may download models and send usage/diagnostics to Google. ADR-028 already allows network for ads only. | Verify Google's ML Kit data-disclosure page in T9.0/T10.0. If ML Kit sends data, the owner decides: accept with disclosure (Data safety, privacy policy, a new ADR amending #5 like ADR-028), or prefer bundled models / VisionKit-only where possible. Don't ship 1.2 until decided. | **Owner decision** |
| C-11 | **FR-PDF-ENC wording.** PRD/COPY say "DocuKit can't open protected files yet." CHANGES_v3 says protected PDFs should say "Unlock it first" with a link to Unlock PDF. | PRD updated to say the wording changes **from 1.4**; the shipped copy and code stay as they are until T11.x (Unlock PDF must exist first). | Applied (PRD note) |
| C-12 | **Page-range grammar semantics differ by tool.** Split: parts kept in order, overlaps and duplicates allowed. PDF→Images (and Watermark in 1.4): union, sorted, de-duplicated. | One parser (`RangeParser`) returning ordered parts; each tool applies its post-processing. Tests for both modes. | No conflict; note only |
| C-13 | **iOS export compliance (1.4).** `ITSAppUsesNonExemptEncryption = NO` today; Protect PDF adds AES-256 (ADR-051 Open). | Decide before submitting 1.4; don't change the key in earlier releases. | Open (1.4) |
| C-14 | **Disk space.** CHANGES_v3 §2 asks for ≥ 15 GB free; 7.4 GB free on 2026-10-28. The spike gate given for 1.1 is 10 GB. | Free space before T8.0 (builds of release/1.x need it). | **Owner action** |
| C-15 | **CHANGES_v3 §2 step 1** says to push and start the Play closed test before 1.1 work. `main` holds the merged `ads-bottom-banners` locally; nothing was pushed (owner reviews first). | Owner pushes / starts the closed test; 1.1 work can proceed on a local branch meanwhile. | **Owner action** |
| C-16 | **ARB key collision.** RELEASE_V1_5 §7 `rem_title` ("Expiry date") becomes `remTitle` in the ARB, which already exists as "Remove ads" (ADS.md §10). The `rem_*` prefix is also used by Remove ads. | Rename the 1.5 reminder keys to the `rmd_` prefix (`rmd_title`, `rmd_quick_1y`, …, `rmd_notif_title`) when T12.6 adds them; leave the Remove ads keys unchanged. The other 253 new keys don't collide with the current ARB. | Proposed (1.5) |
