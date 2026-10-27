# DocuKit — Testing

## 1. Commands
```bash
flutter analyze
flutter test                                   # unit + widget
flutter test --update-goldens                  # only when a visual change is intended
dart run build_runner build --delete-conflicting-outputs   # drift codegen
flutter test integration_test -d <deviceId>    # end-to-end on a device/simulator
flutter build appbundle --release              # Android release
flutter build ipa --release                    # iOS release (macOS)
flutter run --profile                          # memory / perf profiling with DevTools
```

## 2. Test layers

| Layer | Tooling | Must cover |
|---|---|---|
| Unit | `flutter_test`, `mocktail` | Search ranking (FEATURE_SPECS §1 cases); MIME sniffing; file naming; resize maths; target-size search (fake encoder); page-edit model; storage estimates; size/percent formatting; JobRunner state machine (success/fail/cancel/validation fail/storage fail/temp cleanup); retention sweep dates; error copy completeness |
| Repository | drift in-memory DB, mocked prefs | History insert/complete/fail/interrupt/clear/cascade; outputs adopt/exists/delete/total; settings round-trip; schema migration from v1 snapshot |
| Widget | `ProviderScope` overrides with fake engines/gateway | Every screen's empty/loading/normal/error states; disabled-button helper texts; D2/D3/D4 flows; a11y semantics labels (`tester.getSemantics`); 200% text scale doesn't overflow (`tester.binding.platformDispatcher.textScaleFactorTestValue = 2`) |
| Golden | `matchesGoldenFile` | Home, a tool screen, Result — light/dark, compact/expanded widths |
| Integration | `integration_test` on real engines | One happy path per tool + the key failure per tool (see §4); **checksum guard** on every input |
| Manual | Device matrix (§5) | Regression script (§4), lifecycle, accessibility, privacy (§7) |

## 3. Sample-file corpus (`assets/test_corpus/`, not shipped)

Create or collect these once; keep them in the repo (via LFS if large) or a private drive. Never use real personal documents.

| ID | File | Purpose |
|---|---|---|
| IMG-01 | `photo_12mp.jpg` (4000×3000, ~4 MB) | Baseline compress/resize |
| IMG-02 | `photo_48mp.jpg` (8000×6000, ~15 MB) | Memory bound |
| IMG-03..10 | `exif_orient_1.jpg` … `exif_orient_8.jpg` (from `tool/make_fixtures.dart`: each *displays* as 900×1200 with a red marker top-left) | Orientation handling, incl. mirrored 2/4/5/7 |
| IMG-11 | `gps_tagged.jpg` | Metadata stripping |
| IMG-12 | `transparent.png` (alpha) | Alpha → JPEG warning/composite |
| IMG-13 | `screenshot.png` (opaque) | PNG path |
| IMG-14 | `iphone.heic` | HEIC input → JPEG |
| IMG-15 | `animated.webp` / `still.webp` | WebP handling (animated → first frame + warning or reject) |
| IMG-16 | `wrong_ext.jpg` (actually PNG) | Sniffing |
| IMG-17 | `truncated.jpg` | Corrupt |
| IMG-18 | `tiny_1x1.png` | Edge dims |
| IMG-19 | `panorama_20000x2000.jpg` | Extreme ratio / limits |
| IMG-20 | `emoji_名前_📷 (copy).jpg` | Unicode file names |
| IMG-21 | `already_small_20kb.jpg` | "Couldn't make smaller" |
| PDF-01 | `text_10p.pdf` | Text-only (reducer → not smaller) |
| PDF-02 | `scanned_30p.pdf` (image-heavy) | Reducer Balanced/Strong |
| PDF-03 | `mixed_sizes.pdf` (A4 + Letter + landscape) | Merge/organize page sizes |
| PDF-04 | `rotated_pages.pdf` (pages with /Rotate 90/180/270) | Rotation composition |
| PDF-05 | `encrypted_user_pw.pdf` | Password detection |
| PDF-06 | `encrypted_owner_only.pdf` (opens without password, restrictions) | Behaviour documented: opens; restrictions noted in D1 |
| PDF-07 | `corrupt_header.pdf`, `truncated.pdf` | Corrupt handling |
| PDF-08 | `large_300p.pdf` (~150 MB) | Thumbnails perf, organize, merge memory |
| PDF-09 | `forms_bookmarks.pdf` | Info: bookmarks/forms may be lost (documented) |
| PDF-10 | `one_page.pdf` | Delete-last-page guard; merge of 1 rejected |
| PDF-11 | `pdf_2.0.pdf`, `linearized.pdf` | Compatibility |
| PDF-12 | `not_a_pdf.pdf` (renamed .docx) | Unsupported |

## 4. Regression script (run before every release on each matrix device)

| # | Steps | Expected |
|---|---|---|
| R1 | Fresh install → onboarding → Home | 6 tools visible; privacy footer; no permission prompts |
| R2 | Search "reduce photo size" | Image Compressor first |
| R3 | Compressor: IMG-01, q60 → Save to Photos, Save to Files, Share to a chat app | Smaller, opens everywhere, orig unchanged |
| R4 | Compressor target 100 KB: IMG-02 | ≤ 100 KB or "closest" banner |
| R5 | Compressor: IMG-12 → JPEG | Alpha warning shown; white background |
| R6 | Compressor: IMG-21 | "Couldn't make this smaller" + Keep original |
| R7 | Resizer passport preset on IMG-03..10 | Exactly 413×531, upright |
| R8 | Resizer 12001 px | Inline error, button disabled |
| R9 | Images→PDF: 20 mixed images, reorder 2, rotate 1, A4/Fit/Small | 20 pages; order & rotation correct in system viewer |
| R10 | Merge: PDF-01 + PDF-03 + PDF-05 | 🔒 badge, merge blocked → remove → merge 2 → page sum OK |
| R11 | Organize PDF-08: move 3, rotate 2, delete 1, undo, redo, save | Matches UI; 60 fps scroll |
| R12 | Organize PDF-10: delete only page | Blocked with message |
| R13 | Reducer PDF-02 Balanced and Strong; PDF-01 Basic | Smaller / smaller / "not smaller" + Discard |
| R14 | Start merge of PDF-08 ×3 → background app 60 s → return | Completed or Interrupted+Retry (no crash, no partial file) |
| R15 | Kill app mid-job → relaunch | History shows Interrupted |
| R16 | Fill storage to < 100 MB → run merge | Insufficient storage before work |
| R17 | History: open, share, delete copy, remove, clear (keep copies / delete copies) | Correct per D2 text |
| R18 | Settings: change defaults → tool screens use them; restart → persist | ✓ |
| R19 | Retention 24 h → set device clock +2 days → relaunch | App copies deleted, rows show unavailable |
| R20 | Airplane mode for R3–R13 *(v2.1 wording)* | All tools work; no empty ad boxes |
| R21 | Dark mode, 200% font, TalkBack/VoiceOver walkthrough of R3 and R11 | Usable, no clipping, all controls labelled |
| R22 | Tablet/iPad landscape | Rail layout, split tool screen, share popover anchored |
| R23 | (P1) Share an image from Gallery/Photos to DocuKit | S19 shows Compress/Resize/Images to PDF |
| R24 *(v2.1)* | Fresh install → onboarding → (consent if required) → Home tour: step through all 10, Back, Skip, "Try it"; replay from (?) and Settings; 320×568 and tablet | Every tool step spotlights its card (scrolled into view); no ads during the tour; Skip on every step (TOUR.md) |
| R25 *(v2.1)* | Consent with EEA debug geography (`ConsentDebugSettings`) | Consent form shows after onboarding and before the tour; no ad request before `canRequestAds()`; "Privacy & ad choices" row in Settings reopens it |
| R26 *(v2.1, P1)* | Remove ads: purchase, then reinstall and Restore (store sandbox/test accounts) | All ad slots collapse immediately and stay gone after restore (FR-ADS-06) |

### 4.1 Regression log — 2026-10-27, Android emulator (API 34, x86_64, software GPU), airplane mode on unless noted
Fixtures were generated with `dart run tool/make_fixtures.dart <dir>` (synthetic, no personal data).

| Run | Result | Notes |
|---|---|---|
| R1 | Pass | Fresh install → onboarding → consent check (offline: fails fast) → tour → Home. No permission prompts. |
| R2 | Pass | "reduce photo size" → Image Compressor first. |
| R3 | Pass | IMG-01 q60: 5.5 MB → 1.6 MB; Save to Photos, Save to Files and the share sheet all work; the original's checksum is unchanged. |
| R4 | Pass | IMG-02 (48 MP) via "Under 100 KB": ≤ 100 KB. About 10 min on the emulated CPU. |
| R5 | Pass | Alpha warning + "Switch to JPEG"; white background. |
| R6 | Pass | "Couldn't make this smaller" + Keep original. |
| R7 | Pass (after fix) | New on-device test (`integration_test/engines_test.dart`): EXIF orientations 1–8, each displaying 900×1200 with a red marker top-left, through the passport preset (contain, white). All 8 give 413×531 with orientation 1 and the marker top-left. It first **failed for 2, 4, 5 and 7**: Android's flutter_image_compress applies only the EXIF rotation and drops the mirror. Fixed in the engine (`mirrorAfterNativeRotation`, 32 host cases in `test/core/exif_mirror_test.dart`). iOS not run. |
| R8 | Pass | 12001 px → inline error, button disabled. |
| R9 | Pass | 6 images (not 20), 1 reorder + 1 rotation, A4/Fit/Small → 6 pages, A4 (rotated page landscape). |
| R10 | Pass | 🔒 badge blocks the merge; remove it → 13 pages (10 + 3). |
| R11 | Pass | 300 pages: rotate 2, delete 1, undo, redo, move 1, save → 299 pages. 60 fps not measured (emulator). |
| R12 | Pass | Deleting the only page is blocked with a message. |
| R13 | Pass | 300-DPI PDF-02: Balanced 89 → 12 MB (−87 %), Strong 89 → 4.4 MB (−95 %, after the confirm dialog); PDF-01 Basic → "not smaller" + Discard. |
| R14 | Pass | 60 s in the background mid-job → same process, job still running. |
| R15 | Pass | Killed mid-job → relaunch sweep `interrupted=1`; History shows Interrupted. |
| R16 | Fixed, re-check on device | With ≤ 190 MB free, the system picker returned 0 files and the app showed nothing (the picker plugin couldn't copy the file into its cache). Fix: an empty or failed pick with < 300 MB free now shows "Not enough free space. About 300 MB is needed…"; otherwise it stays a silent cancel (`test/widgets/low_storage_pick_test.dart`). |
| R17 | Pass | Open, share, delete app copy, remove from history; the clear dialog matches D2 (not confirmed, to keep data for later runs). |
| R18 | Pass | Defaults changed → persist after a force-stop. |
| R19 | Pass | 24 h + clock +2 days → sweep `expired=9`; rows show "File no longer available". |
| R20 | Pass | R3–R13 all ran offline: tools work; no ad boxes, gaps or error banners anywhere (Home, Result, History, Details, Settings). |
| R21 | Pass (after fix) | Dark + 200 %: Home cards broke mid-word ("Image Co/mpressor") → fixed (one column at large text). TalkBack walkthrough not done. |
| R22 | Pass (after fix) | Tablet landscape (2560×1600): rail + split tool screen; the 4-column grid left a gap → fixed. Share popover anchoring not checked (Android has no popover). |
| R23 | N/A | P1 share-into-app (S19) isn't implemented in this version. |
| R24 | Pass | All 10 steps, Back, Skip on every step, Try it on the 6 tool steps, no ads; replay from (?) and Settings; 320×568 and tablet. |
| R25 | Pass | Online, EEA debug geography (`--dart-define=ADMOB_DEBUG_EEA=true`): the consent form shows after onboarding and before the tour; "Privacy & ad choices" appears in Settings and reopens it; the banner loads only after consent. |
| R26 | Not run | Needs the `remove_ads` product and store test accounts. |

## 5. Device matrix (minimum)

| Platform | Device class | Why |
|---|---|---|
| Android | Low-end, 3–4 GB RAM, Android 8–10 (e.g. emulator API 26 + any cheap real device) | Min SDK, memory |
| Android | Mid-range Samsung (One UI), Android 14/15 | Most common OEM skin |
| Android | Pixel, Android 16 | Target SDK behaviour, predictive back, photo picker |
| Android | Tablet emulator 10" | Adaptive layout |
| iOS | Oldest supported iPhone you can get (iPhone SE 2/3 or 8 on iOS 15–16) | Memory (jetsam), min OS |
| iOS | Current iPhone, latest iOS | Normal |
| iOS | iPad simulator | Popovers, layout (if OD-2 = yes) |

## 6. Benchmarks (record, don't promise)

| Scenario | Device | Time | Peak memory | Notes |
|---|---|---|---|---|
| Cold start → Home interactive | | | | target < 1.5 s mid-range |
| Compress IMG-02 q80 | | | | |
| Images→PDF 100 × 12 MP, High | | | | |
| Merge 3 × PDF-08 | | | | |
| Organizer open PDF-08 → first thumbnails | | | | |
| Reduce PDF-02 Balanced / Strong | | | | |

## 7. Privacy verification
1. Android: `aapt2 dump permissions build/app/outputs/.../app-release.apk` → **v2.1 (ADR-028):** `INTERNET`, `ACCESS_NETWORK_STATE` and `AD_ID` are now expected; still no `READ_MEDIA_*`, no `READ/MANAGE_EXTERNAL_STORAGE` (only `WRITE_EXTERNAL_STORAGE maxSdk 28`).
2. Run the full regression behind a proxy (mitmproxy/Charles) or with a network monitor → **v2.1:** only ad/consent traffic (Google AdMob/UMP); **no request contains file names, file content or tool data**; every tool works in airplane mode.
3. iOS: Xcode Organizer → *Generate Privacy Report* on the archive; confirm it matches App Store Connect answers.
4. `grep -rn "print(\|debugPrint(\|log(" lib/` → only through `core/logging` and no names/paths.
5. *(v2.1)* `grep -rln "google_mobile_ads\|in_app_purchase" lib/` → only `lib/core/ads/` and the Remove ads code (CLAUDE.md rule 5; also a CI check).

## 7.1 v2.1 tests — Ads (ADS.md §11)
| Test | Type |
|---|---|
| `AdPolicy` rules: first two jobs, 3-job gap, 4-min gap, 60 s after resume, session cap of 2, failed job, removed ads, no consent | Unit |
| Slots collapse to zero height when the fake service returns no ad / an error / ads removed | Widget |
| No slot renders on the excluded screens (a widget-tree search for `NativeAdSlot`/`BannerAdSlot`) | Widget |
| Airplane mode: every tool still works; no empty ad boxes; no error banners | Manual (regression R20) |
| Live test ads appear in debug on both OSes; the EEA consent form appears with debug geography | Manual |
| Remove ads purchase + restore with store sandbox/test accounts | Manual |
| Release build: `APPLICATION_ID` present; no crash at launch without network | Manual |
| Interstitial never appears during the tour, after a failure, after Save/Share, or within 60 s of launch | Manual + unit |
| AD-6 not built when the Details content is shorter than the ad; not on failed entries | Widget |
| Rewarded: reward granted only on `onUserEarnedReward`; 24 h window suppresses every format; 2-per-day limit; offer hidden when no ad is loaded | Unit + manual |
| App open (Phase B): never on a cold launch, the first session, < 30 s away, after a picker/save/share return, during or within 2 min of a job, or within 4 h of another full-screen ad | Unit + manual |
| AD-9 (Phase B): built only when Home is ≥ 1.5 screens tall and has ≥ 3 recents; never two native cards visible at once | Widget (phone + tall tablet sizes) |
| `adsPhase = A` builds contain no AD-7/AD-9 code paths that run | Unit |

## 7.2 v2.1 tests — Home tour (TOUR.md §6)
| Test | Type |
|---|---|
| The steps are built from the catalogue: 6 tool steps, in catalogue order | Unit |
| Controller: next/back bounds, skip sets `tour_done`, finish sets `tour_version` | Unit |
| Auto-start only when `tour_done == false`, and not before onboarding/consent close | Widget |
| Scrim taps don't open tools; Skip on every step; Android back behaviour | Widget |
| A tool card below the fold is scrolled into view before its step | Widget (small screen size 320×568) |
| 200% text: the tooltip doesn't overflow; buttons stay reachable | Widget |
| TalkBack/VoiceOver: step announcement, focus trapped in the tooltip | Manual |
| AD-1 hidden during the tour and shown after | Widget (fake AdsService) |

## 8. Bug report template (for testers)
```
Device / OS:
App version (Settings → Version):
Tool:
Input type & approx size (no personal files please):
Steps:
Expected:
Actual:
Screenshot/screen recording:
```
