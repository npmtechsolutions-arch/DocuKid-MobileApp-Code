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

## Backlog (post-MVP, not scheduled)
V1.1: batch compress/resize · format converter · favourites · WebP (if deferred) · Balanced reducer (if deferred) · incoming files (if deferred) · extract pages (FR-ORG-09) · local stats
V1.2: scanner · V1.3: OCR · V1.4: watermark/signature/password · V1.5: organiser/reminders

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
