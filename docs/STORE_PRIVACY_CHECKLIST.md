# DocuKit v2.1 — Store privacy answers (T7.11)

Based on what the code actually ships (checked 2026-10-27), not on intentions. Re-check whenever a dependency changes.

## What the build contains

| Source | What it does with data |
|---|---|
| **DocuKit's own code** | Processes files only on the device. Sends nothing anywhere. No analytics, crash reporting or account. Network code exists only in `lib/core/ads/` (CI-enforced). |
| **google_mobile_ads 9.2.0** (+ UMP consent SDK) | Requests and shows ads; collects the device/usage data listed below. `AdRequest()` carries no app data (no keywords, content URLs or targeting; unit-tested). |
| **in_app_purchase 3.3.1** (Google Play Billing / StoreKit) | The `remove_ads` purchase and restore. Payment is handled by the store; DocuKit never sees payment details and keeps only `ads_removed = true` on the device. |
| webview_flutter | Transitive dependency of google_mobile_ads; DocuKit doesn't use it directly. |
| **play-services-mlkit-document-scanner 16.0.0** (1.2, Android; ADR-041/064) | Scan Document. The scanner runs inside Google Play services on the device; DocuKit receives only the page JPEGs. ML Kit sends diagnostics and usage analytics to Google (see 1.2 below). No camera permission in DocuKit's manifest. |
| VisionKit (1.2, iOS) | Scan Document on iOS: on-device, Apple framework; asks for the camera (`NSCameraUsageDescription`). |

Merged Android permissions (from the built APK): `INTERNET`, `ACCESS_NETWORK_STATE`, `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_AD_ID` / `_ATTRIBUTION` / `_TOPICS`, `com.android.vending.BILLING`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, and `WRITE_EXTERNAL_STORAGE` (max SDK 28, for Save to Photos). There are no storage-read, camera, location or contacts permissions.

## Google Play — App content

- [ ] **Contains ads:** Yes.
- [ ] **Advertising ID:** Yes, used for advertising (the AdMob SDK). Keep the `AD_ID` permission.
- [ ] **Target audience:** 13+ (not directed at children; the policy says so).
- [ ] **Data safety → Does your app collect or share user data?** Yes, through the AdMob SDK. Declare it exactly as Google's *"Data disclosure for Google Mobile Ads SDK"* page says on the day you submit. At the time of writing:

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Location → Approximate location (from the IP address) | Yes | Yes | Advertising or marketing; Analytics; Fraud prevention, security and compliance | No |
| Device or other IDs (advertising ID, app set ID) | Yes | Yes | Advertising or marketing; Analytics; Fraud prevention, security and compliance | No |
| App activity → App interactions (ad taps/views) | Yes | Yes | Advertising or marketing; Analytics | No |
| App info and performance → Crash logs, Diagnostics | Yes | Yes | Analytics; Fraud prevention, security and compliance | No |
| **Files and docs, Photos and videos** | **No** | **No** | Processed on the device only, never transmitted | — |
| Financial info → Purchase history | Check: purchases go through Google Play Billing; DocuKit itself stores nothing but a local flag. Follow Google's current guidance on Play Billing. | | | |

- [ ] **Is all data encrypted in transit?** Yes (the SDK uses HTTPS).
- [ ] **Can users request deletion?** There's no account. Local history and results can be cleared in Settings; uninstalling deletes everything. Ad data is controlled by Google (link to Google's ad settings in the privacy policy).
- [ ] **Privacy policy URL:** host the rewritten policy (the in-app text `privPolicyBody1…5` is the same content).

## App Store — App Privacy label

- [ ] **Data used to track you:** **No** (no ATT prompt; the IDFA isn't available to the SDK).
- [ ] **Data linked to you:** None (no account).
- [ ] **Data not linked to you** (collected by the Google Mobile Ads SDK; confirm against Google's iOS *"Prepare for Apple's App Store data disclosure requirements"* page):
  - Location → Coarse location (Third-party advertising, Analytics)
  - Identifiers → Device ID (only if the SDK reports collecting the IDFV/IDFA without ATT; check Google's page)
  - Usage data → Product interaction, Advertising data (Third-party advertising, Analytics)
  - Diagnostics → Crash data, Performance data, Other diagnostic data (Analytics)
- [ ] **Purchases:** not collected by DocuKit (StoreKit handles them).
- [ ] **Files, photos:** not collected.
- [ ] After archiving in Xcode, open **Generate Privacy Report** and check that every collected type in the merged `PrivacyInfo.xcprivacy` files appears on the label. *Not done yet: Xcode isn't installed on the build machine.*

## Listing and screenshots

- [ ] Remove "no ads", "no tracking" and "no internet" from every store text. Keep **"Your files never leave your phone."**
- [ ] Take screenshots with ads absent (a Remove ads test purchase, or airplane mode: every slot collapses to nothing).
- [ ] Publish `app-ads.txt` on the developer website listed in both stores (AdMob shows the exact line).

## 1.2 — Scan Document (T9.8, checked 2026-10-28)

Sources: Google's *ML Kit Android data disclosure* (developers.google.com/ml-kit/android-data-disclosure, footer "Last updated 2026-07-15") and the Document Scanner page (developers.google.com/ml-kit/vision/doc-scanner, "Last updated 2025-09-30"). Neither page names the Document Scanner in the per-library list. The "all features" table applies to every ML Kit Android SDK. It lists:
- device information: maker, model, OS version, build, ML accelerators;
- app information: package name, app version;
- a device identifier for "thin" features (the scanner's module is downloaded through Play services, so treat it as thin);
- performance metrics (latency), API configuration (image format, resolution), input/output size, feature version, event type and error codes.

All of these are "used for diagnostics and usage analytics", "encrypted in transit using HTTPS" and "not transferred to third parties". The scanner page says "the entire document scanner flow operates on-device" and "No camera permission is needed from your app".

**What changes in Play Data safety:**
- **No new data types.** ML Kit's collection falls under types the form already declares as collected for AdMob: *Device or other IDs* and *App info and performance → Diagnostics*. Both already list *Analytics* as a purpose.
- **Keep:** Files and docs, Photos and videos → **not collected**. Scanned images never leave the device.
- **Encrypted in transit:** still Yes.
- **On submit day, re-check both Google pages.** If the Data safety form asks per SDK, or Google's page starts listing extra types for the Document Scanner, add them as *collected, not shared, Analytics, required*.

**Merged Android permissions:** unchanged; no `CAMERA` (checked from the built APK in T9.0, ADR-041).

**App Store privacy label:** no change. VisionKit is on-device and adds no SDK. The camera prompt text is in `Info.plist`. *Not verified: no Xcode on the build machine.*

**Privacy policy:** the in-app policy (`privPolicyBody3`) and the hosted template (RELEASE.md §6) now say: "When you scan, the camera images are processed on your phone. On Android, the scanner is provided by Google Play services, which may send Google basic diagnostics about it, such as the device model, app version and error codes, but never your images." The second half is the ADR-064 disclosure. **Owner: review this wording before publishing.**

**Privacy & About (S17):** new row "Camera — Camera, only while you're scanning".

