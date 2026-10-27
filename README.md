# DocuKit

Offline document toolkit for Android and iOS, built with Flutter: Image Compressor, Image Resizer, Images to PDF, PDF Merger, PDF Page Organizer and PDF Size Reducer. No account and no backend; files never leave the device. Ad-supported (Google AdMob, v2.1) with an optional Remove ads purchase.

The specification is in [`docs/`](docs/) (PRD, screens, design system, architecture, feature specs, copy, decisions, tasks, testing, release). Project rules for AI-assisted work are in [`CLAUDE.md`](CLAUDE.md).

## Setup
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift codegen
flutter analyze
flutter test
flutter run                                                 # add --profile for performance work
```
Toolchain: Flutter 3.47.8 / Dart 3.13 (see `docs/DECISIONS.md` ADR-017). PDF engine tests on real PDFium: `tool/test_pdf_host.sh`.

Optional build-time setting:
```bash
flutter run --dart-define=DOCUKIT_FEEDBACK_EMAIL=support@yourdomain.com   # shows "Send feedback"
```

## Layout
```
lib/
  app/          app widget, router, theme tokens, launch sweeps
  core/         errors, logging, files (gateway, naming, sniffing), image & PDF engines,
                operation engine (JobRunner), validation, shared widgets
  data/         drift database, history/outputs repositories, settings
  features/     home, search, onboarding, one folder per tool, job (processing/result/error),
                history, settings, privacy
  l10n/         app_en.arb (every user-visible string)
packages/docukit_native/   local plugin: Save As, Open with, free space, background task (Kotlin + Swift)
test/          unit, repository and widget tests
```

## Before release
See `docs/RELEASE.md` and the open items in `docs/TASKS.md` (`[~]` = needs on-device verification). Confirm the bundle ID (`com.npmtechsolutions.docukit`, ADR-022) and replace the debug signing config in `android/app/build.gradle.kts`.
