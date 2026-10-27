# DocuKit v3 Change Pack — Full product (app versions 1.1 → 1.5)

This pack specifies everything after app version 1.0: ten new tools, batch processing, share-into-app, favourites, and the My Documents library with expiry reminders and app lock. Like the v2.1 pack, it **adds** new documents and gives **merge instructions** for your existing docs. Your project docs are the source of truth; merge these in rather than overwriting.

## 1. New files

| File | Put it in |
|---|---|
| `docs/FULL_PRODUCT.md` | `docs/` — the overview and **shared conventions** (IDs, routes, ads rules, engines) |
| `docs/features/RELEASE_V1_1.md` | `docs/features/` — Productivity: batch, convert, split, PDF→images, extract pages, favourites, share-in |
| `docs/features/RELEASE_V1_2.md` | `docs/features/` — Scan Document |
| `docs/features/RELEASE_V1_3.md` | `docs/features/` — Text Recognition (OCR) |
| `docs/features/RELEASE_V1_4.md` | `docs/features/` — Sign, Watermark, Protect, Unlock |
| `docs/features/RELEASE_V1_5.md` | `docs/features/` — My Documents, expiry reminders, app lock |
| `CHANGES_v3.md` | project root (this file) |

## 2. Before you start

1. **Finish and submit 1.0 first.** Merge `ads-bottom-banners`, push to GitHub, and start the Play closed test. Version 1.1 work happens on a new branch while the 14-day test runs.
2. **Free disk space.** Keep at least 15 GB free. The scanner and OCR releases add native libraries and larger builds.
3. **Work one release at a time**, each on its own branch (`release/1.1`, `release/1.2`, …). Don't start the next release until the current one's regression table is green on Android. For iOS, use the simulator or an iPhone once Xcode is set up.

## 3. Merge instructions (Claude does this with prompt M0 below)

| Existing doc | Change |
|---|---|
| `CLAUDE.md` | Add `docs/FULL_PRODUCT.md` and `docs/features/` to "Read before working". Add the three new global rules from FULL_PRODUCT §4.6 (passwords, OCR text, library files) as non-negotiables #12–#14 |
| `DECISIONS.md` | Append every `ADR-V1x-*` from the five release specs, numbered from the next free ADR number; replace the placeholders in all docs. Add an open decision per release: "Ship 1.x on its own or bundle it with the next" (default: ship on its own) |
| `PRD.md` | Add rows MVP-15… for each new tool/feature with a pointer to its release spec. In §3.2 Later releases, replace the v1.1–v1.5 table with a pointer to FULL_PRODUCT §2. Add one line per release under §9 Roadmap (M8–M12 with the estimates). Change FR-PDF-ENC: protected PDFs in other tools now say "Unlock it first", with a link to Unlock PDF (from 1.4) |
| `ARCHITECTURE.md` | §1 stack: add each release's packages (from their §4). §3 layout: `core/ocr/`, `core/pdf/pdf_stamper.dart`, `core/pdf/pdf_security.dart`, `features/library/`, `features/<new tools>/`. §4 catalogue: new `ToolId`s and `ToolCategory` values (FULL_PRODUCT §4.2). §6.4 native plugin: new methods (`getIncomingFiles`, `saveManyToFolder`, `scanDocument`, `protectPdf`, `unlockPdf`). §8: new tables and settings keys from each spec's §5 |
| `SCREENS.md` | Route table: add every new route. Navigation map: add the new screens S21–S46. Home (S01): the category layout from FULL_PRODUCT §3 |
| `DESIGN_SYSTEM.md` / `UI_REFRESH.md` | Category gradients for scan, secure and library (FULL_PRODUCT §4.5) |
| `ADS.md` | Add FULL_PRODUCT §4.4 as "§3.1 Screens added in 1.1–1.5" |
| `COPY.md` | Add each release spec's §7 copy table as its own section |
| `TESTING.md` | Add regressions R27–R68 from the release specs; add corpus files listed in each spec's §8 |
| `RELEASE.md` | Add a "Per-release store changes" section: FULL_PRODUCT §5, plus each spec's §6 (camera string, iOS 15.5 minimum, notifications, Face ID string, privacy policy wording) |
| `TASKS.md` | Append milestones M8 (T8.x) … M12 (T12.x) from the specs, in order, before the backlog |
| `TOUR.md` | Note per release: new tour steps for new tools, shown as "New in DocuKit" (FR-TOUR-10), with `tour_version` +1 per release |

## 4. Build order inside each release

Every release spec ends with ready-to-paste prompts (its §10). The pattern is always:
1. **Spike (T*.0)** — prove the risky library or API works on both platforms; record the result as an ADR. **If a spike fails, stop and ask before continuing.**
2. **Engine and logic** — tests first.
3. **Screens.**
4. **Integration** — Home, search, tour, history, ads slots.
5. **Regression** — the release's R-table plus a quick pass of R1–R26.
6. **Release prep** — version bump, changelog, store "What's new", privacy and store form updates.

## 5. Versioning
| Release | `pubspec.yaml` version | Branch |
|---|---|---|
| 1.0 | `1.0.0+N` | main |
| 1.1 | `1.1.0+N` | `release/1.1` |
| 1.2 | `1.2.0+N` | `release/1.2` |
| 1.3 | `1.3.0+N` | `release/1.3` |
| 1.4 | `1.4.0+N` | `release/1.4` |
| 1.5 | `1.5.0+N` | `release/1.5` |
`N` (the build number) increases with every store upload and never goes down.

## 6. Prompts for Claude Code

**M0 — Merge the v3 docs (run once, no code)**
```
I've added docs/FULL_PRODUCT.md, docs/features/RELEASE_V1_1.md … RELEASE_V1_5.md and CHANGES_v3.md.
Apply CHANGES_v3.md §3 to the existing docs and CLAUDE.md. Merge into the current text; don't overwrite it. Keep all existing decisions, statuses and copy.
Number the new ADRs from the next free ADR number and replace every ADR-V1x-* placeholder in all docs.
If anything in the release specs conflicts with an accepted ADR or the current code (for example ADR-035 bottom banners, ADR-034 orientation, the chunked Images→PDF builder), list each conflict with a proposed resolution instead of silently choosing.
Don't change any code. Summarise the edits per file.
```

**Start a release (use once per release; replace 1.x)**
```
Start release 1.x. Read docs/FULL_PRODUCT.md and docs/features/RELEASE_V1_x.md in full.
Create branch release/1.x from main.
Do task T<first>.0 (the spike) only, exactly as specified. Build the throwaway debug screen under lib/debug/, test on the Android emulator (and iOS if available), and record the results as an ADR with the exact package versions and API calls that worked.
Stop after the spike and report PASS/FAIL per check, with measurements. Don't start the other tasks.
```

**Continue a release (repeat; use the prompts in the spec's §10, or this generic one)**
```
Continue release 1.x with tasks <IDs> from docs/TASKS.md / RELEASE_V1_x.md §9.
Tests first for all logic. Handle Android and iOS. Bottom banners and other ads only as FULL_PRODUCT §4.4 says.
One commit per task on release/1.x. Run analyze, all tests (with --timeout 90s), goldens and the CI checks.
Report the commands you ran and their real results, and what you couldn't verify.
```

**Finish a release**
```
Finish release 1.x:
1. Run the release's regression table (RELEASE_V1_x.md §8) plus a quick pass of R1–R26 on the Android emulator. Record pass/fail in TESTING.md.
2. Bump pubspec.yaml to 1.x.0+<next build number>.
3. Write CHANGELOG.md and short store "What's new" text (≤ 500 characters, plain language).
4. Update the privacy policy, Data safety and App Store label answers if RELEASE_V1_x.md §6 says they change.
5. Build a release AAB with my real AdMob IDs file and a debug APK to ~/Desktop for my phone test. Check free disk space first (stop if under 5 GB).
6. Don't merge or push; I'll review.
Report real results.
```

## 7. Timeline

| Release | Effort | Calendar (one release at a time, with phone testing and store review) |
|---|---|---|
| 1.1 | 7–10 days | about 2–3 weeks |
| 1.2 | 5–8 days | about 2 weeks |
| 1.3 | 7–10 days | about 2–3 weeks |
| 1.4 | 9–13 days | about 3 weeks |
| 1.5 | 9–13 days | about 3 weeks |
| **All** | **37–54 days** | **about 3 months** |
