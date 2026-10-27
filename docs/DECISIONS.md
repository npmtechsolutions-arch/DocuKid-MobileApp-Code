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

---

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
