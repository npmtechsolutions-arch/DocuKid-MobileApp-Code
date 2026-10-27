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
  "ADMOB_BANNER_MAIN":       "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_BANNER_TOOLS":      "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_BANNER_INFO":       "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_INTERSTITIAL_DONE": "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN",
  "ADMOB_REWARDED_ADFREE":   "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN"
}
```
- Use one file per platform: the unit IDs differ between Android and iOS. The iOS file has `ADMOB_APP_ID_IOS` instead of `ADMOB_APP_ID_ANDROID`.
- **iOS App ID:** the tracked `ios/Flutter/AdMob.xcconfig` holds Google's sample ID (used by Debug). Put the real one in the untracked `ios/Flutter/AdMobRelease.local.xcconfig`, which only `Release.xcconfig` includes:
  ```
  ADMOB_APP_ID_IOS = ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
  ```
  The release CI writes this file from `ADMOB_APP_ID_IOS` in the `ADMOB_DEFINES_IOS` secret.

**Release build commands** (from the project root, with the two local files in place):
```bash
# Check the IDs first (both also run in the release CI; Android's Gradle build checks again)
dart run tool/check_release_ads.dart --platform android --defines admob_android.json
dart run tool/check_release_ads.dart --platform ios     --defines admob_ios.json

# Android: Play Store bundle (or an APK for side-loading on your own test device)
flutter build appbundle --release --dart-define-from-file=admob_android.json
flutter build apk       --release --dart-define-from-file=admob_android.json

# iOS (on a Mac with Xcode; App ID from ios/Flutter/AdMobRelease.local.xcconfig)
flutter build ipa --release --dart-define-from-file=admob_ios.json
```
Before installing a release build with real ads on your own phone, register it as a test device in AdMob, and never tap your own live ads.
- Bottom banners (ADR-035): `ADMOB_BANNER_MAIN` (Home, Search, Result, Recent activity, Operation details), `ADMOB_BANNER_TOOLS` (the tool screens and Manage files), `ADMOB_BANNER_INFO` (Privacy & About, Licences), `ADMOB_BANNER_SETTINGS` (Settings).
- Any banner key can be `"off"`: that banner's slot is never built, and the release check accepts it. An **empty** value is still refused.
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
