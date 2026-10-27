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

### AdMob build keys (release builds)
Debug and profile builds always use Google's test ads. A **release** build needs your real AdMob IDs and is refused otherwise (Gradle on Android; `tool/check_release_ads.dart` in the release CI for both platforms). Put them in a JSON file that is kept out of git (`admob_*.json` is ignored) and build with `--dart-define-from-file`:

```json
{
  "ADMOB_APP_ID_ANDROID":    "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY",
  "ADMOB_NATIVE_HOME":       "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_NATIVE_RESULT":     "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_NATIVE_HISTORY":    "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_NATIVE_DETAILS":    "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_BANNER_SETTINGS":   "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_INTERSTITIAL_DONE": "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_REWARDED_ADFREE":   "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN"
}
```
```bash
flutter build appbundle --release --dart-define-from-file=admob_android.json
flutter build ipa       --release --dart-define-from-file=admob_ios.json   # iOS App ID: ios/Flutter/AdMob.xcconfig
```
- Use one file per platform: the unit IDs differ between Android and iOS. The iOS file doesn't need `ADMOB_APP_ID_ANDROID`.
- `"ADMOB_BANNER_SETTINGS": "off"` switches the Settings banner (AD-5) off: the slot is never built, and the release check accepts it. An **empty** value is still refused.
- Never use Google's sample IDs (`ca-app-pub-3940256099942544…`) in a release build; the check refuses them.
- Debug only: `--dart-define=ADMOB_DEBUG_EEA=true --dart-define=ADMOB_TEST_DEVICE=<hashed id>` shows the EEA consent form anywhere (no effect in release).
- The full list, with the test IDs, is the "Ad units" sheet of `docs/DocuKit_Ad_Map.xlsx`.

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
