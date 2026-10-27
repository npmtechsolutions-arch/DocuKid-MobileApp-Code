# DocuKit — Project Instructions for Claude

## Product
DocuKit is an offline-first **Flutter** app for **Android and iOS** with six document tools: Image Compressor, Image Resizer, Images to PDF, PDF Merger, PDF Page Organizer and PDF Size Reducer. It has no account and no backend; it is ad-supported (Google AdMob) with an optional Remove ads purchase. Files never leave the device.

## Read before working
- `docs/PRD.md` — scope, requirement IDs (FR-*), acceptance criteria
- `docs/SCREENS.md` — the screen you're building (layout, states, platform notes)
- `docs/ARCHITECTURE.md` — layers, folders, contracts, data model
- `docs/FEATURE_SPECS.md` — the algorithm for the tool you're touching
- `docs/TASKS.md` — find the task ID you were given; follow its acceptance criteria
- `docs/COPY.md` — every user-facing string (add new ones there AND in `lib/l10n/app_en.arb`)
- `docs/DECISIONS.md` — don't contradict an accepted ADR; propose a new one instead
- `docs/FULL_PRODUCT.md` — the v1.0 → v1.5 product plan and the **shared conventions** for every release spec (IDs, routes, ads rules for new screens, engines)
- `docs/features/RELEASE_V1_x.md` — the spec for the release you're working on (1.1 productivity, 1.2 scanner, 1.3 OCR, 1.4 sign/watermark/protect/unlock, 1.5 My Documents)
- `docs/ADS.md` — ad placements AD-1…AD-9, frequency rules, consent, Remove ads (v2.1)
- `docs/TOUR.md` — the Home tour (v2.1)
- `docs/UI_REFRESH.md` — brand tokens, Home v2, ToolCard v2, motion (v2.1)

## Stack
Flutter stable · Dart 3 · Material 3 (adaptive on iOS) · flutter_riverpod 3 (no codegen) · go_router · drift · shared_preferences · image_picker/file_picker · flutter_image_compress · pdfrx (PDFium) · pdf · share_plus · gal · local plugin `packages/docukit_native` (Kotlin + Swift).

## Commands
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter test integration_test -d <device>
flutter run            # add --profile for performance work
```

## Architecture rules
- Layers: presentation (widgets + Notifiers) → application (ToolOperation, JobRunner) → engines (ImageEngine, PdfEngine) → platform/data (FileGateway, DB, settings). Widgets never do IO.
- Every plugin sits behind an interface in `lib/core/`; tests use fakes via ProviderScope overrides.
- New tool = an entry in `tool_catalog.dart` + `lib/features/<tool>/` + one `ToolOperation`.
- Heavy work never runs on the UI isolate: native plugins, or `Isolate.run` for Dart pixel work.
- Pass **file paths**, not large `Uint8List`s, across platform channels.

## Non-negotiable rules
1. **Never modify or delete a user's source file.** Work on copies in `cache/jobs/<id>/`.
2. **Never show success until the output is written, re-opened and validated** (ARCHITECTURE §5.4).
3. **Never fabricate progress.** Use determinate progress only for real page/image counts.
4. **Never log file names, paths or contents.** Log only job IDs and error codes, via `core/logging`.
5. **Network only for ads.** Only `lib/core/ads/` (and the Remove ads purchase code) may import `google_mobile_ads` / `in_app_purchase` or touch the network. Never pass file names, file types, tool usage or any user content into ad requests. Don't add other network-capable packages.
6. **No broad storage permissions.** Use the system pickers, save dialogs and share sheet.
7. **Never bypass PDF passwords.** Detect them and explain.
8. All user-visible text comes from ARB/`AppLocalizations`. No hard-coded strings.
9. Every interactive widget has a semantics label/tooltip; touch targets ≥ 48 dp.
10. Store metadata only in drift; never file bytes.
11. **Ads only at the AD-1…AD-9 placements and the bottom banners in docs/ADS.md** (ADR-035). Bottom banners go only through the shared `AppBottomBanner`, in reserved space below all content, never over content. They never appear on onboarding, the tour, Processing, Error, dialogs/sheets or the page preview, and need a 24 dp gap plus a divider below any bottom action button. No other ads inside a tool's working area, Search, empty states or blank space.
12. **Passwords (v1.4):** never stored, never logged, never in history `optionsJson`; cleared from memory (`Uint8List.fillRange(0)` where possible) after use.
13. **OCR text (v1.3+):** treated like file content: never logged, never sent anywhere, stored only inside the Library index (v1.5), and deleted with the document.
14. **Library files (v1.5):** stored only in the app sandbox, excluded from cloud backup by default (ADR-054), and deleted when the user deletes them.

## Working style
- First restate the task ID and list the files you plan to create or change. Wait for confirmation if the change touches more than about 8 files or any ADR.
- Small, reviewable diffs. No drive-by refactors.
- **Don't invent library APIs.** If you're unsure that a method exists in the pinned version, say so, and propose how to verify it (the pub.dev API docs, or a tiny spike).
- Before adding any dependency: give its purpose, licence, maintenance status, size, and why the existing stack can't do the job. Then add a DECISIONS entry.
- Write or update tests for all logic (maths, validation, state machines, repositories).
- Handle both platforms. If a behaviour differs, implement both branches and note it.
- Finish with: the files changed, the commands you actually ran and their results, what you couldn't verify (e.g. "not run on an iOS device"), and the follow-ups. **Never claim a build or test passed unless you ran it.**
- Ask before making product decisions that the docs don't settle.

## Definition of done
See the bottom of `docs/TASKS.md`. In short: works on Android + iOS · analyze clean · tests green · original unchanged · output validated · strings in ARB · semantics present · nothing sensitive logged · docs updated.
