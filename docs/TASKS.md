# DocuKit — Build Backlog

Work top to bottom. Each task is sized for **one Claude session / one PR** (½–1 day). Mark the status `[ ]` → `[~]` (in progress) → `[x]`. Every task's done criteria include the global **Definition of Done** (bottom of this file).

> **Implementation status — 2026-10-27.** `[x]` = implemented and verified here (`flutter analyze` clean, unit/widget tests green). `[~]` = code complete, but its acceptance criteria need a real device or simulator (pickers, native save/share, PDFium on device, memory/perf, iOS — Xcode isn't installed on the build machine). Spikes T1.2/T2.0/T3.0 were resolved by reading the pinned plugin sources (DECISIONS ADR-019…021); their on-device measurements are still to do.

Legend: 🔬 = spike (time-boxed; its outcome is recorded in `DECISIONS.md`), 🤖 = Android-specific work, 🍎 = iOS-specific work.

---

## M0 — Project setup (2–3 days)

- [~] **T0.1 Create the project.** `flutter create --org com.<you> --platforms android,ios docukit`. Set `minSdk 26 / targetSdk 36`, iOS 15.0. Add `analysis_options.yaml` (strict). Remove `INTERNET` from the main Android manifest.
  *Accept:* `flutter run` works on an Android emulator and the iOS simulator; `flutter analyze` is clean.
- [~] **T0.2 Dependencies.** Add the packages from ARCHITECTURE §1 with exact versions verified on pub.dev; run `flutter pub get`; note each in `DECISIONS.md` (version, licence).
  *Accept:* builds on both platforms; the iOS `pod install` succeeds.
- [~] **T0.3 Theme + tokens.** `app/theme/*` from DESIGN_SYSTEM §1–3; light/dark; `ThemeMode` from settings (stub for now).
  *Accept:* a golden test of a sample screen in light and dark.
- [x] **T0.4 l10n.** `l10n.yaml`, `app_en.arb` with the COPY §1–3 keys used so far; `AppLocalizations` wired.
  *Accept:* no hard-coded user-visible strings (a grep check in CI).
- [x] **T0.5 Router + empty screens.** `go_router` with every route in SCREENS §0 → placeholder screens; the tool catalogue (`tool_catalog.dart`) with all 6 tools; the Home grid renders from the catalogue.
  *Accept:* every route is reachable; an unknown route → Home + snackbar; widget test: Home shows 6 ToolCards.
- [~] **T0.6 CI.** GitHub Actions: `flutter analyze`, `flutter test`, the Android debug build on ubuntu; the iOS build (`flutter build ios --no-codesign`) on macos (optional to save minutes).
  *Accept:* green pipeline on main.

## M1 — Foundation (4–6 days)

- [x] **T1.1 Error model + copy mapping.** `core/errors/*` (AppErrorCode, AppError, error_copy) from ARCHITECTURE §9 and COPY §4.
  *Accept:* unit test: every code has a title, body and primary action.
- [~] 🔬 **T1.2 Picker spike (½ day).** Pick a HEIC, a large JPEG and a PNG via `image_picker.pickMultiImage` and via `file_picker(FileType.image)` on both OSes; compare SHA-256 with the original. Pick a 200 MB PDF via `file_picker`.
  *Accept:* a DECISIONS entry naming the picker that returns **unmodified original bytes** on each OS, and how it copies.
- [~] **T1.3 FileGateway (pick + copy + sniff).** `core/files/*`: `pickImages`, `pickPdfs`, copy into `jobs/<draft>/in`, `MimeSniffer` (FEATURE_SPECS §2.1), `PickedFile`.
  *Accept:* unit tests for the sniffer (all signatures + mismatch); a manual test on both OSes.
- [x] **T1.4 Naming utils.** `file_naming.dart` (ARCHITECTURE §6.3). *Accept:* unit tests: illegal chars, emoji, 200-char names, empty, duplicates.
- [~] 🤖🍎 **T1.5 `docukit_native` plugin.** The `saveAs`, `openWith`, `freeBytes`, `beginBackgroundTask/end` methods (ARCHITECTURE §6.4); FileProvider config; iPad popover anchors.
  *Accept:* a debug screen can save a 300 MB file without its memory going above +50 MB (profiled), open it with another app, and show free space — on both OSes; user cancel returns `cancelled`.
- [~] **T1.6 Share + Save to Photos.** `share_plus` and `gal` behind `FileGateway`. *Accept:* sharing a PDF to Gmail/Files works on both; the iOS Photos add-permission flow plus the denied state.
- [x] **T1.7 Operation engine.** `ToolOperation`, `JobContext`, `CancelToken`, `JobProgress`, `JobState`, `JobRunner` (ARCHITECTURE §5) + `jobControllerProvider`.
  *Accept:* unit tests with a fake tool: success, failure → the error code, cancel mid-way, the validation failure path, the storage pre-check failure, and the temp dir deleted in every case.
- [~] **T1.8 Database.** drift `Operations` + `OperationInputs`, `HistoryRepository` (insert running, complete, fail, cancel, markRunningAsInterrupted, watchRecent, page, remove, clear), `OutputsRepository` (adopt, exists, delete, totalBytes, retention sweep).
  *Accept:* repository tests on an in-memory DB; a schema snapshot is committed.
- [x] **T1.9 Settings.** `SettingsRepository` + `settingsProvider` (ARCHITECTURE §8.1 keys).
  *Accept:* values persist across restart (test with `SharedPreferences.setMockInitialValues`).
- [x] **T1.10 Bootstrap.** Startup: interrupted fix, temp sweep, retention sweep (non-blocking, after the first frame).
  *Accept:* unit tests on the sweep date logic.
- [~] **T1.11 Job UI (S10/S11/S18 generic) + a "Copy file" debug tool.** The Processing, Result (generic file), Error screens; the Save/Share/Open actions; history written.
  *Accept:* **M1 exit gate** — pick → copy → result → save/share works end to end on both OSes, and history shows it.

## M2 — Image tools (5–8 days)

- [~] 🔬 **T2.0 Image engine spike (½ day).** Confirm `flutter_image_compress`: minWidth/minHeight semantics, HEIC/WebP encode per OS, keepExif + orientation behaviour, peak memory on a 48 MP image.
  *Accept:* a DECISIONS entry + FEATURE_SPECS §3.4 updated if needed; OD-3 (WebP) resolved.
- [~] **T2.1 ImageEngine.** `inspect` (ImageDescriptor + exif), `transform` (FEATURE_SPECS §3.4), alpha compositing, the exact-resize isolate step.
  *Accept:* tests on the corpus: dimensions exact, the format matches the magic bytes, orientation correct for EXIF 1–8, GPS removed when asked.
- [x] **T2.2 Resize maths + target-size search.** `resize_math.dart`, `target_size_search.dart` (FEATURE_SPECS §3.2, §3.5).
  *Accept:* unit tests incl. rounding, limits, ≤ 8 attempts, target-missed flag.
- [~] **T2.3 Shared input widgets.** `InputsSection`, `FileTile`, `PickerDropCard`, `StatusBadge`, D1, D4, `ToolScaffold`, `PrimaryActionBar`.
  *Accept:* widget tests for the empty/valid/warning/invalid states; the a11y semantics labels.
- [~] **T2.4 Image Compressor (S03)** — controller, screen, `CompressImageOperation`, result before/after compare (FR-IMG-10).
  *Accept:* FR-IMG-01…10; integration test: compress a JPEG at q60 → smaller, valid, original checksum unchanged.
- [~] **T2.5 Image Resizer (S04)** — pixels/percent/presets, ratio lock, fit modes, custom presets.
  *Accept:* FR-RES-01…08; integration: passport preset → exactly 413×531.
- [~] **T2.6 Images to PDF (S05)** — the grid with reorder/rotate/remove, page setup, `ImageToPdfBuilder` with chunking.
  *Accept:* FR-I2P-01…06; integration: 30 mixed images (incl. EXIF-rotated and PNG-alpha) → 30 pages, correct order/orientation; 100 × 12 MP images complete on a 4 GB RAM Android without OOM.
- [~] **T2.7 Draft persistence (FR-LIFE-03)** for the image tools. *Accept:* kill the app on the tool screen → relaunch → "Restored your last session."

## M3 — PDF tools (7–12 days)

- [~] 🔬 **T3.0 pdfrx spike (1 day — GATE).** On both OSes, with the corpus: open/inspect/password detection; merge 3 files; reorder + delete; **rotate** (pdfrx API or PDFium `FPDFPage_SetRotation`); **image object replace** (Balanced); peak memory for a 400 MB merge; thumbnail render speed for 300 pages.
  *Accept:* a DECISIONS entry resolving ADR-005 and OD-5, and noting any native fallback required.
- [~] **T3.1 PdfEngine — inspect + render + thumbnail cache.** `PdfrxPdfEngine.inspect/renderPage`, `PdfThumbnailCache` (LRU by bytes, cancellation, memory-pressure clear).
  *Accept:* tests on the corpus (page counts, encrypted → the code, corrupt → the code).
- [~] **T3.2 PDF Merger (S06)** + `MergePdfOperation`. *Accept:* FR-MRG-01…06; integration: merge 3 → page sum OK, inputs' checksums unchanged.
- [x] **T3.3 Page edit model.** Pure functions + undo/redo (FEATURE_SPECS §4.3). *Accept:* unit tests: move multiple, rotate wrap, delete-all blocked, identity detection.
- [~] **T3.4 PDF Page Organizer (S07)** — the grid, selection bar, drag reorder + the Move sheet, page preview, D2/D4.
  *Accept:* FR-ORG-01…08; 300-page PDF scroll profile without jank > 16 ms frames on the reference device.
- [~] **T3.5 Organize export** — `OrganizePdfOperation` (rotation per the spike outcome). *Accept:* the exported order/rotation match the UI on both OSes.
- [~] **T3.6 PDF Size Reducer (S08)** — pre-analysis; Basic; Balanced (if the gate passed); Strong with the confirm; the not-smaller flow.
  *Accept:* FR-CMP-01…06; corpus: an image-heavy PDF shrinks with Balanced; a text-only PDF reports "not smaller" correctly.
- [~] **T3.7 Draft persistence** for the PDF tools (the Organizer edit stack is P1).

## M4 — Shared UX (3–5 days)

- [~] **T4.1 Home (S01) final** — recents, availability, Continue chip, job-running banner, empty state, tablet rail.
- [x] **T4.2 Search (S02)** — synonym ranking (FEATURE_SPECS §1) with the listed test cases.
- [~] **T4.3 Recent Activity (S14) + Details (S15) + D6** — filters, paging, swipe remove + undo, Run again.
- [~] **T4.4 Settings (S16)** — every setting wired to its tool defaults; storage used + clear; clear history.
- [~] **T4.5 Privacy & About (S17) + licences + the offline privacy policy page.**
- [~] **T4.6 Onboarding (S20).**
- [ ] 🤖🍎 **T4.7 (P1) Incoming files (S19)** — *moved to V1.1 (ADR-024)* — Android intent filters (SEND, SEND_MULTIPLE, VIEW for pdf/image), iOS document types + open-URL handling; the chooser screen.
- [ ] **T4.8 Start the Play closed test** (12 testers × 14 days needs to begin now for new personal developer accounts) and TestFlight internal testing.

## M5 — Hardening (4–7 days)

- [ ] **T5.1 Run the edge corpus** (TESTING §3) on all devices in the matrix; fix the findings.
- [ ] **T5.2 Lifecycle**: background mid-job, kill mid-job (→ Interrupted), rotation, split-screen, iOS Slide Over, low storage (fill the disk), memory pressure.
- [ ] **T5.3 Accessibility pass** (DESIGN_SYSTEM §9) with TalkBack + VoiceOver + 200% font.
- [ ] **T5.4 Performance**: cold start, Organizer scroll, 100-image PDF, a 400 MB merge — record them in TESTING §6.
- [ ] **T5.5 Privacy verification**: a proxy/airplane-mode run (no traffic); `aapt dump permissions` check; the iOS privacy report from the Xcode archive.
- [ ] **T5.6 Release build checks**: R8/ProGuard keeps pdfrx working in release; the iOS release build on a real device; app size within the NFR.

## M6 — Distribution (3–5 days + review)

- [ ] **T6.1 Store assets** — icon (adaptive + iOS variants), screenshots, feature graphic, descriptions (`RELEASE.md §5`).
- [ ] **T6.2 Compliance** — Data Safety form, the App Privacy label, `PrivacyInfo.xcprivacy`, the hosted privacy policy, export compliance.
- [ ] **T6.3 Signing** — the Play App Signing upload key (backed up), the iOS distribution certificate/profile.
- [ ] **T6.4 Submit** — Play: closed → production (after 14 days); App Store: TestFlight external → review.

---

## M7 — v2.1: UI refresh, Home tour, ads (6–9 days + 1–3 days of AdMob review)

Specs: `UI_REFRESH.md`, `TOUR.md`, `ADS.md`, `mockups/DocuKit_v2.1_mockups.html`; decisions ADR-028…ADR-032.

- [x] **T7.1 Brand tokens + font.** Gradient tokens, Plus Jakarta Sans headings, licence entry. *Accept:* goldens updated; contrast check passes (UI-REF-03).
- [~] **T7.2 Home v2.** Hero greeting, help icon, quick actions with query-param prefill, savings counter, ToolCard v2, the entrance animation. *Accept:* FR-HOME-06/07; UI-REF-02/04.
- [~] **T7.3 Tool, Processing and Result polish.** Option cards, gradient button, per-tool processing glyph + tips, success header, savings ring, confetti, 2×2 actions. *Accept:* UI_REFRESH §4–6; reduce-motion honoured.
- [x] **T7.4 Empty states + illustrations.** *Accept:* every empty state in UI_REFRESH §7 has art in both themes.
- [x] **T7.5 Tour controller + overlay.** *Accept:* the TOUR.md §6 unit/widget tests pass.
- [x] **T7.6 Tour integration.** Keys on Home; auto-start ordering after onboarding and consent; replay from Home and Settings; "Try it". *Accept:* FR-TOUR-01…09 on a 320×568 screen and a tablet.
- [ ] **T7.7 AdMob account setup (you, not Claude).** Create the AdMob account, register the Android + iOS apps, create the ad units listed on the "Ad units" sheet of `docs/DocuKit_Ad_Map.xlsx` (Phase A: Home native, Result native, History native, Details native, Settings banner, Done interstitial, Ad-free rewarded; Phase B later: Resume app open, Home native 2) and the GDPR + US-states messages; publish app-ads.txt on your website.
- [~] **T7.8 Ads core.** `core/ads/*`: config via `--dart-define`, consent gate, `AdPolicy` + tests, slots that collapse, the interstitial manager, the fake service for tests; Android/iOS config. *Accept:* FR-ADS-01…05; test ads show on both OSes; the CI grep check limits ads imports to `core/ads/`.
- [~] **T7.9 Place the ads.** AD-1…AD-6 per ADS.md §3, plus the AD-8 rewarded offer (Remove-ads sheet and Result link) and the global caps (§4.4). *Accept:* the excluded-screen widget test; manual policy review with screenshots.
- [~] **T7.10 Remove ads (P1).** Store products, purchase sheet, restore, the Settings row. *Accept:* FR-ADS-06 with sandbox/test accounts.
- [~] **T7.11 Privacy and store update.** Copy, privacy policy, Data safety, App privacy label, listing text, screenshots without ads. *Accept:* RELEASE checklist re-run; the Xcode privacy report matches the label.
- [ ] **T7.13 Phase B (about 30 days after launch, only if the ADS.md §3 gate passes).** AD-7 app open ad, AD-9 second Home card, AD-4 interval 8; set `adsPhase = B`. *Accept:* FR-ADS-08 and the Phase B tests in ADS.md §11.
- [~] **T7.12 Regression.** R1–R26 on the Android emulator + one real Android phone; iOS once Xcode is set up.

> **M7 status — 2026-10-27 (Android emulator, API 34; iOS not run: no Xcode).**
> - T7.1, T7.4, T7.5, T7.6: done. Contrast test, 16 goldens, the TOUR.md §6 tests, the tour on device at normal size, 320×568 and tablet landscape.
> - T7.2/T7.3 `[~]`: built and checked on the emulator; UI-REF-02 (no frame > 16 ms in profile mode on a low-end phone) still needs a real device.
> - T7.8/T7.9 `[~]`: AdPolicy tests (written first), slot widget tests, CI import check; live Google test ads seen on Android (banner, rewarded; the native test ad failed to load once and its slot collapsed). Pending: iOS, the manual policy review with screenshots, real unit IDs (T7.7).
> - T7.10 `[~]`: sheet, purchase/restore listener and the 24 h rewarded pass work (the reward was granted on the emulator); the purchase itself needs the `remove_ads` product and store test accounts.
> - T7.11 `[~]`: in-app copy and policy rewritten; store answers in `docs/STORE_PRIVACY_CHECKLIST.md`; the Xcode privacy report is still to do.
> - T7.12 `[~]`: regression log in TESTING.md §4.1.

**Order:** T7.1 → T7.2 → T7.5 → T7.6 → T7.3 → T7.4 → (T7.7 in parallel, any time) → T7.8 → T7.9 → T7.10 → T7.11 → T7.12; T7.13 later, as a separate update. The UI and tour come first, so the ads land on the final layouts.

---

## M8 — v1.1: Productivity — batch, convert, split, PDF→images, extract, favourites, share-in (7–10 days)

Spec: `docs/features/RELEASE_V1_1.md` (prompts in its §10); conventions `FULL_PRODUCT.md` §4; decisions ADR-036…ADR-040. Branch `release/1.1`. **If the spike fails, stop and ask before continuing.**

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
- [x] **T8.10 Organizer Extract.** *Accept:* FR-EXT-01…03; R34. *(2026-10-28, emulator API 34: R34 page 9, page 3 rotated, page 6 → `contract_extract.pdf` with exactly those pages in that order, rotation kept, original unchanged, history `pdfOrganize` + `mode: extract`. Organizer edits and undo stack kept: widget test.)*
- [x] **T8.11 Favourites (S01 row, S26 sheet, long-press sheet, tool ⋮).** *Accept:* FR-FAV-01…05; R35. *(2026-10-28: FR-FAV-01…04 done; R35 on the emulator with the real preferences store: 6 pinned, 7th refused, reordered, order intact after rebuilding settings from disk. FR-FAV-05 (the Favourites step in the What's new mini-tour) is part of T8.13. Tool app bar title now scales down to fit beside ⋮ and ⓘ (owner choice).)*
- [x] 🤖🍎 **T8.12 Share to DocuKit.** Intent filters, iOS document types, `getIncomingFiles` + stream, `IncomingFilesController`, S19. *Accept:* FR-SHR-01…07; R36 on Android; iOS compiled and listed for the Xcode round. *(2026-10-28: R36 passed on the emulator — cold, warm, during a job, Cancel — see ADR-063, which also resolves C-5 (MainActivity stays `singleTop`; share-in via `IncomingActivity`). iOS: document types + scene callbacks written, Swift syntax-checked and Info.plist linted only — compile and test in the Xcode round. Mixed photo+PDF in **one** share isn't offered by Android for the spec's filters (`*/*`); separate shares combine on S19.)*
- [x] **T8.13 Mini-tour, copy, privacy text, What's new.** *Accept:* FR-TOUR-11; COPY keys present; privacy sentence added. *(2026-10-28: `tour_version` 2; 1.0 users get "New in DocuKit" (Convert, Split, PDF to Images, Favourites) once — widget test incl. "Step 4 of 5"; `test/core/copy_keys_test.dart` checks every COPY §8.1 key against the ARB; privacy sentence in `privPolicyBody3` and the RELEASE §6 template; store "What's new" text in RELEASE §8.1. Not run on the emulator: needs a 1.0 install to upgrade from — part of T8.14.)*
- [x] **T8.14 Regression R1–R36 + version 1.1.0.** *Accept:* report in TESTING.md; build number bumped. *(2026-10-28: version 1.1.0+2; report in TESTING §4.2 incl. a 1.0.0 → 1.1.0 upgrade check on the emulator. Rows not re-run and the real-phone / Xcode items are listed there.)*

Order: T8.0 → T8.1 → T8.2 → T8.3 → T8.4 → T8.5 → T8.6 → T8.7 → T8.8 → T8.9 → T8.10 → T8.11 → T8.12 → T8.13 → T8.14.

---

## M9 — v1.2: Scan Document (5–8 days)

Spec: `docs/features/RELEASE_V1_2.md` (prompts in its §10); conventions `FULL_PRODUCT.md` §4; decisions ADR-041…ADR-043. Branch `release/1.2`. **If the spike fails, stop and ask before continuing.**

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
- [ ] **T9.10 Regression R1–R42** on the Android emulator + a real phone; iOS once available.

Order: T9.0 → T9.1 → T9.3 → T9.4 → T9.5 → T9.6 → T9.7 → T9.8 → T9.10; T9.2 when Xcode is ready; T9.9 optional.

---

## M10 — v1.3: Text Recognition (OCR) (7–10 days)

Spec: `docs/features/RELEASE_V1_3.md` (prompts in its §10); conventions `FULL_PRODUCT.md` §4; decisions ADR-044…ADR-047. Branch `release/1.3`. **If the spike fails, stop and ask before continuing.**

- [~] 🔬 **T10.0 OCR spike (1 day — GATE).** On both platforms (iOS once Xcode is available; Android first):
  1. Add `google_mlkit_text_recognition`; bump iOS to 15.5; build.
  2. Measure the app-size increase for Latin and Devanagari (Android bundled vs. unbundled; iOS per-script pods).
  3. Recognise OCR-01/02/04; check that the boxes are in oriented-pixel space on both platforms.
  4. Build a 1-page PDF with the `pdf` package: image + invisible text (find the exact API for render mode 3 and horizontal scaling); confirm pdfrx text search finds the words, for Latin and Devanagari.
  5. Confirm the pdfrx page-text API for §4.6.
  *Accept:* DECISIONS entries for ADR-044 (iOS 15.5), ADR-045 (scripts + bundling), ADR-046 (text-layer API), with measured numbers.
  — *Android done 2026-10-29* (`integration_test/ocr_spike_test.dart`): `google_mlkit_text_recognition` 0.17.1 added; Latin recall 100% (OCR-01, OCR-02, OCR-04), boxes in upright pixels; invisible text with `drawString(mode: PdfTextRenderingMode.invisible, scale:)` → pdfrx finds 100% of the words, 0.000% pixel difference, font subset (+5.6 KB); Devanagari recall and search 100%; `page.loadText()` for §4.6. Size per phone +12.9 MB (Latin, bundled) +0.64 MB (Devanagari). Owner chose bundled models and Latin + Devanagari (ADR-045). iOS raised to 15.5 (ADR-044, C-9 resolved). ⚠️ iOS steps (build, sizes, box space) wait for Xcode.
- [x] **T10.1 `TextRecognizer` + ML Kit implementation + fake.** *Accept:* unit tests with the fake; on-device recognition of OCR-01 returns ≥ 95% of the words. — *Done 2026-10-29:* `lib/core/ocr/text_recognizer.dart` (interface, `OcrScript`, `OcrPage`/`OcrLine`/`OcrWord` with the work-dir JSON form and per-word confidence), `mlkit_text_recognizer.dart` (`MlKitTextRecognizer`: bundled scripts per ADR-045, one recogniser per script per job, oriented-pixel size from the JPEG header, errors as `AppError`), `ocr_labels.dart`; `textRecognizerFactoryProvider` (a new recogniser per job); new error code `ocrModelUnavailable` with its COPY §4/§8.3 text; `FakeTextRecognizer`. 9 unit tests (`test/core/text_recognizer_test.dart`). On the emulator (`integration_test/ocr_recognizer_test.dart`, fixtures in `tool/fixtures/ocr_text.dart`): OCR-01 recall **100%**, 100% of words on their box (IoU ≥ 0.5), Devanagari ≥ 95%, blank page 0 words, a non-image → `corruptFile`.
- [x] **T10.2 Mapping + reading order + `.txt` writer** (§4.5, FR-OCR-09). *Accept:* unit tests. — *Done 2026-10-29:* `lib/core/ocr/ocr_layout.dart` (`PdfBox` in PDF points with y up, so it can't be mixed up with a y-down `Rect`; `toPdfBox`/`toPdfPoint`, `imageAngle`/`pdfAngle`/`isSkewed` (> 2°), `readingOrder`: rows by > 50% vertical overlap of the smaller height, left to right within a row; column detection stays P2) and `ocr_text_file.dart` (`formatOcrTxt`, streaming `writeOcrTxt`, `joinForCopy` for Copy all, `isValidOcrTxt` for §4.10); `ocrTxtName`. *As built:* every page, page 1 included, starts with `--- Page {n} ---` + a blank line, so pages are separated exactly by `\n\n--- Page {n} ---\n\n`; the marker is file format, not translated copy. 21 unit tests (`ocr_layout_test`, `ocr_text_file_test`).
- [ ] **T10.3 Existing-text detection** for PDFs (§4.6) wired into validation + the badges. *Accept:* OCR-07/08/09 badges correct.
- [ ] **T10.4 `SearchablePdfBuilder`** (§4.7–4.8), chunked, in an isolate; mixed-PDF page import. *Accept:* the searchability + invisibility + mixed-PDF integration tests.
- [ ] **T10.5 `OcrPipeline` + `OcrOperation`** (progress, cancel, rotation retry, low-text stats, multi-output). *Accept:* pipeline unit tests; FR-OCR-10/11/12/15.
- [ ] **T10.6 S30 tool screen** + catalogue entry, search keywords, category, Tools banner with gap, tour step (`tour_version` bump). *Accept:* widget tests; FR-OCR-01–04.
- [ ] **T10.7 S31 Review text screen + Result extensions** (S32). *Accept:* widget tests; FR-OCR-08/16; no ads on S31.
- [ ] **T10.8 Scanner hook** (FR-OCR-13) on S29 + setting. *Accept:* R47.
- [ ] **T10.9 Settings, privacy copy, error codes, Data safety / privacy label review, iOS 15.5 docs.** *Accept:* RELEASE checklist updated; copy in ARB.
- [ ] **T10.10 Regression R43–R48 + memory benchmark (OCR-10)** on the emulator and a real Android phone; iOS when available.

**Order:** T10.0 → T10.1 → T10.2 → T10.3 → T10.4 → T10.5 → T10.6 → T10.7 → T10.8 → T10.9 → T10.10.

---

## M11 — v1.4: Sign, Watermark, Protect, Unlock (9–13 days)

Spec: `docs/features/RELEASE_V1_4.md` (prompts in its §10); conventions `FULL_PRODUCT.md` §4; decisions ADR-048…ADR-053. Branch `release/1.4`. **If the spike fails, stop and ask before continuing.**

- [ ] 🔬 **T11.0 PDF security & stamping spike (1 day, GATE).** On both OSes, with PDF-01/04/05/06/08/15/16:
  1. PDFium image object with BGRA alpha → is the transparency kept (SMask)? Output size per stamped page.
  2. Matrix placement on rotated and crop-boxed pages (the 4.4 maths).
  3. iOS PDFKit protect: the algorithm actually written (inspect the `/Encrypt` dictionary: `/V 5 /R 6` = AES-256); non-ASCII passwords.
  4. Android PdfBox-Android 2.0.27.0: protect with AES-256, unlock, R8 release build works, APK size delta, behaviour on a 200 MB PDF.
  5. Unlock via PDFium (`FPDF_REMOVE_SECURITY`): available through pdfrx/FFI? The output is really unencrypted?
  *Accept:* ADR-048 (stamping path) and ADR-049 (encryption libraries) written with the exact API calls that worked and the measurements; go/no-go for each tool.
- [ ] **T11.1 Catalogue, Home section, colours, search, tour steps** (FR-SEC-01/02). *Accept:* 4 cards in a new "Secure & Sign" section; search tests for the §4.9 keywords; tour version bumped with tests.
- [ ] **T11.2 `PdfSecurity` + native `protectPdf` / `unlockPdf` / `pdfProtection`** (Kotlin + Swift + Dart, with the CI no-logging grep). *Accept:* unit tests with a fake channel; on-device round-trip tests (§8.3 first two rows).
- [ ] **T11.3 Protect PDF screen + operation (S37).** *Accept:* FR-PRT-01…08; R54, R57.
- [ ] **T11.4 Unlock PDF screen + operation (S38) + "Unlock it first" routing in all existing PDF tools** (FR-UNL-08). *Accept:* FR-UNL-01…08; R55, R56.
- [ ] **T11.5 `PdfStamper` + placement maths + text-to-image renderer.** *Accept:* §8.1 placement tests; on-device accuracy tests on PDF-04 and PDF-15.
- [ ] **T11.6 Signature creator (S34): draw, type, photo + saved signatures + Settings entry.** *Accept:* FR-SIG-02/03/04/10; storage excluded from backups (checked in the manifest / with `URLResourceValues`).
- [ ] **T11.7 Placement editor (S35) + Sign PDF screen (S33) + operation.** *Accept:* FR-SIG-01, 05–09, 11, 12; R49–R51.
- [ ] **T11.8 Watermark PDF (S36) + operation.** *Accept:* FR-WMK-01…10; R52, R53; the 300-page timing recorded.
- [ ] **T11.9 Privacy, store and docs.** Privacy policy + S17 text, licences (PdfBox NOTICE, fonts), the export-compliance answer (ADR-051), ARCHITECTURE stack rows, COPY, TESTING. *Accept:* the RELEASE checklist re-run; the desktop cross-check (§8.3) done on both platforms.
- [ ] **T11.10 Regression R1–R58** on the Android emulator + a real phone; iOS once Xcode is set up. *Accept:* the pass/fail table in TESTING §4.1.

**Order:** T11.0 → T11.1 → T11.2 → T11.3 → T11.4 → T11.5 → T11.6 → T11.7 → T11.8 → T11.9 → T11.10. If T11.0 fails for stamping, ship Protect + Unlock as 1.4 and move Sign + Watermark to 1.4.1 behind the fallback path.

---

## M12 — v1.5: My Documents, expiry reminders, app lock (9–13 days)

Spec: `docs/features/RELEASE_V1_5.md` (prompts in its §10); conventions `FULL_PRODUCT.md` §4; decisions ADR-054…ADR-059. Branch `release/1.5`. **If the spike fails, stop and ask before continuing.**

- [ ] 🔬 **T12.0 Spike (1 day).** Verify: drift + FTS5 availability on both platforms with `sqlite3_flutter_libs`; `flutter_local_notifications` current API (`zonedSchedule`, inexact mode, boot reschedule, iOS categories, cold-start launch details); `local_auth` options and the `FlutterFragmentActivity` requirement; iOS `isExcludedFromBackup` on a directory; Android `dataExtractionRules` excluding `files/library`; pdfrx page-text extraction API for text-layer PDFs. *Accept:* DECISIONS entries for ADR-054–058 with exact API names and versions.
- [ ] **T12.1 Schema + repository.** Tables, FTS, migration, `LibraryRepository` (folders, documents, duplicates, copyForTool, stats) + tests. *Accept:* §8 migration/repository/FTS tests pass.
- [ ] **T12.2 Library UI: S39, S40, S41, S43.** Intro, home (grid/list, sort, filters, selection mode, FAB), folder view, folder picker sheet; ads per §3.2. *Accept:* FR-LIB-01, 02, 06–11 (minus Open in tool), widget + golden tests.
- [ ] **T12.3 Adding documents.** Save to My Documents on S11 and multi-result, Import, Scanner hook, S19 row, duplicate dialog. *Accept:* FR-LIB-03, 04, 05, 21; R60–R61.
- [ ] **T12.4 Document detail S42 + Open in tool.** Preview, full viewer, info, notes autosave, tags (P1), actions. *Accept:* FR-LIB-11, 12, 13.
- [ ] **T12.5 Search + indexing.** Search UI with snippets; index queue with policy, pause/resume, battery; settings section. *Accept:* FR-LIB-14–16; R63, R68.
- [ ] **T12.6 Reminders.** S44, notification service, scheduler with iOS limit, tap routing, time-zone/boot handling, Expiring soon sections, Home card. *Accept:* FR-REM-01–10; R64–R65; scheduler unit tests.
- [ ] **T12.7 App lock.** S45, lock controller + router guard, scopes, timeouts, snapshot cover, FLAG_SECURE, settings. *Accept:* FR-LCK-01–08; R66; state-machine tests.
- [ ] **T12.8 Storage, backup exclusion, export/import.** S46 storage/backup section, ZIP export/import, backup exclusion on both OSes, launch sweeps. *Accept:* FR-LIB-17–20, 22; R67.
- [ ] **T12.9 Privacy, copy, store.** Privacy & About section, privacy policy text, store listing line, permissions review, tour step for My Documents (`tour_version` bump). *Accept:* RELEASE checklist re-run for 1.5.
- [ ] **T12.10 Regression.** R1–R68 on Android emulator + a real phone; iOS once Xcode is available.

Order: T12.0 → T12.1 → T12.2 → T12.3 → T12.4 → T12.5 → T12.6 → T12.7 → T12.8 → T12.9 → T12.10.

---

## Backlog (post-MVP, not scheduled)
V1.1: batch compress/resize · format converter · favourites · WebP (if deferred) · Balanced reducer (if deferred) · incoming files (if deferred) · extract pages (FR-ORG-09) · local stats
V1.2: scanner · V1.3: OCR · V1.4: watermark/signature/password · V1.5: organiser/reminders
*(v3: now scheduled as M8–M12 above. Still unscheduled: local stats, and the P2 ideas in each release spec, e.g. ADR-059.)*

---

## Definition of Done (every task)
1. The acceptance criteria pass on **both** an Android device/emulator and an iOS device/simulator (or the task is explicitly platform-specific).
2. `flutter analyze` is clean; `flutter test` is green; new logic has unit tests.
3. Originals are unchanged (the checksum helper, for any task that processes files).
4. Output is validated before success is shown.
5. All user text comes from ARB; semantics labels are present.
6. No logging of file names/paths/content.
7. Errors map to an `AppErrorCode` with copy.
8. This file is updated (status) and `DECISIONS.md` gains an entry if anything was decided.
