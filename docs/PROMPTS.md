# DocuKit — Prompts for Claude

Use these with Claude Code in the repo (it reads `CLAUDE.md` automatically) or paste them into a Claude chat along with the relevant docs. One prompt = one task. Review the diff, run it yourself, then tick it off in `TASKS.md`.

---

## P0 · Kick-off (once)
```
Read CLAUDE.md and everything in docs/. Don't write code yet.
1. Summarise the MVP in 10 bullet points so I can check that you've understood it.
2. List any contradictions or gaps you found across the docs, with file + section.
3. Propose the exact pubspec dependency list with versions you believe are current, and mark each one "verify" — I'll confirm them on pub.dev.
4. Confirm the order of the M0 tasks.
```

## P1 · M0 foundation (T0.1–T0.5)
```
Task T0.1–T0.5 from docs/TASKS.md.
Create the Flutter project foundation exactly as described in ARCHITECTURE §3 (folders can stay empty with a .gitkeep):
- minSdk 26 / targetSdk 36 / iOS 15; remove INTERNET from the main AndroidManifest.
- Theme from DESIGN_SYSTEM §1–3 (light + dark), go_router with every route in SCREENS §0 pointing to placeholder screens, tool_catalog.dart with all 6 tools, and a Home grid built from the catalogue.
- l10n with gen-l10n; only the COPY keys you need.
- No image/PDF packages yet.
Before editing, list the files you'll create. Afterwards report: the files, the commands you ran, their results, and anything you couldn't verify.
```

## P2 · Spike template (T1.2 / T2.0 / T3.0)
```
Spike <ID> from docs/TASKS.md. Time box: <½ day / 1 day>.
Build a throwaway debug screen under lib/debug/ (excluded from release via kDebugMode) that tests: <list from the task>.
Use files from assets/test_corpus/. For each check, output PASS/FAIL plus measurements (time, peak memory if available, SHA-256 before/after).
Then write a DECISIONS.md entry with the findings and the recommended path, including the exact API calls that worked (with the package version).
Don't build production code in this task.
```

## P3 · Engine/logic task (e.g. T1.7, T2.2, T3.3)
```
Task <ID>. Implement <component> per ARCHITECTURE §<n> and FEATURE_SPECS §<n>.
Write the unit tests first (list the cases you'll cover before you write them), then the implementation.
Pure Dart; no Flutter widgets. Run `flutter test` for this folder and report the output.
```

## P4 · Tool screen (e.g. T2.4 Image Compressor)
```
Task T2.4 — Image Compressor (SCREENS S03, PRD §5.2 FR-IMG-01…10, FEATURE_SPECS §3).
Build:
- features/image_compress/application/compress_controller.dart (Notifier, the state class as in SCREENS S03)
- features/image_compress/application/compress_image_operation.dart (implements ToolOperation)
- features/image_compress/presentation/compress_screen.dart using ToolScaffold, InputsSection, OptionGroup, QualitySlider
- strings in app_en.arb (keys from COPY §3)
- widget tests for: empty, valid, PNG warning, alpha warning, target-size validation, disabled-button helper text
- one integration test: compress IMG-01 at q60 → output smaller, magic bytes JPEG, input SHA-256 unchanged
Handle Android and iOS differences (HEIC output availability).
List the planned files first. At the end, report the commands run and their results, plus the acceptance criteria that you verified and those you didn't.
```

## P5 · Native plugin task (T1.5)
```
Task T1.5 — packages/docukit_native per ARCHITECTURE §6.4.
Kotlin: saveAs via ACTION_CREATE_DOCUMENT with stream copy (8 KB buffer, on a background thread), openWith via FileProvider + ACTION_VIEW chooser, freeBytes via StatFs. Register the FileProvider paths in ARCHITECTURE §6.4 only.
Swift: saveAs via UIDocumentPickerViewController(forExporting:asCopy:), openWith via UIDocumentInteractionController, freeBytes via volumeAvailableCapacityForImportantUsage, begin/endBackgroundTask. Present from the top-most view controller; support an iPad popover source rect passed from Dart.
Dart API: typed results (sealed SaveOutcome). Include a debug screen to try each method.
Explain each platform API you use, and flag anything you aren't sure exists on iOS 15 / Android API 26.
```

## P6 · Bug fix
```
Bug: <one-line summary>
Device/OS: <…>   Build: <version>
Steps: <…>
Expected: <…>   Actual: <…>
Logs/stack trace (exact):
<paste>
First explain the likely root cause and which file(s) you'd change; don't edit yet. After I agree: fix it, add a regression test, and report.
```

## P7 · Review pass (before each milestone exit)
```
Review the changes since <commit/tag> against CLAUDE.md's non-negotiable rules and the Definition of Done in TASKS.md.
Output a table: rule/criterion → pass/fail → evidence (file:line) → fix needed.
Specifically check: source files are never written; success only after validation; no logging of names/paths; strings in ARB; semantics labels; both platforms handled; no new network-capable deps.
Don't fix anything in this pass.
```

## P8 · Store prep (M6)
```
Using docs/RELEASE.md, produce: (1) the final Play listing text, (2) the App Store listing text + keywords, (3) the privacy policy filled with <name/email/date>, (4) a checklist of the Data Safety and App Privacy answers with a justification for each, based on the actual code (grep for any network, analytics or file APIs and report the findings).
```

### Tips
- Keep each Claude session to one task; start a fresh session per task so the context stays clean.
- When Claude proposes an API you haven't seen, open the package's pub.dev API page and check it before accepting.
- Paste **exact** error output. "It doesn't work" costs a round trip.
- Commit after every green task; it makes reverting a bad AI change trivial.
