# DocuKit — Release & Store Compliance

> Store rules change. Re-check every item against the official Play Console and App Store Connect help pages in the week you submit. The values below were current in October 2026.

## 1. Versioning
- `pubspec.yaml` `version: 1.0.0+1` → `versionName/CFBundleShortVersionString = 1.0.0`, `versionCode/CFBundleVersion = 1`. Increase the build number on every upload.
- Tag each release `v1.0.0` in git; keep `CHANGELOG.md`.

## 2. Google Play

| Item | Value / action |
|---|---|
| Build | `flutter build appbundle --release`; **target API 36** (required for new apps/updates from 31 Aug 2026; extension available to 1 Nov 2026) |
| Signing | Play App Signing on; create an upload keystore, store it plus its passwords in a password manager **and** an offline backup |
| Testing track | New *personal* developer accounts must run a **closed test with at least 12 testers opted in for 14 continuous days** before applying for production. Start at M4 |
| Permissions | Only `WRITE_EXTERNAL_STORAGE` (maxSdk 28). No sensitive permissions → no permissions declaration form |
| Data safety *(v2.1, ADS.md §9)* | Data **collected and shared** by the AdMob SDK: Device or other IDs (advertising ID), App activity/interactions, App info & performance (crash logs, diagnostics), Approximate location (from IP). Purposes: Advertising/marketing, Analytics, Fraud prevention. Follow Google's "Data disclosure for AdMob" guide for the exact mapping. Files, file names and results are never collected. Data deletion: no account — explain that history is local and clearable |
| Content rating | IARC questionnaire → Utility, no user-generated content shared → Everyone/3+ |
| Target audience | 13+ (or 18+), *not* designed for children (avoids Families policy requirements) |
| Ads *(v2.1)* | **"Yes, my app contains ads"** (Contains ads = Yes) |
| Advertising ID *(v2.1)* | Declare `AD_ID` use (merged by the Google Mobile Ads SDK) in Play Console |
| In-app product *(v2.1, P1)* | Non-consumable `remove_ads` (≈ US$2.99, localised); Play payments profile set up (ADR-030) |
| app-ads.txt *(v2.1)* | Publish the line AdMob gives you at `https://<your developer website>/app-ads.txt`, and list that website in the store listing |
| App category | Productivity (alt: Tools) |
| Privacy policy URL | Required — host the §6 text (GitHub Pages, Notion public page, or your site). *v2.1:* the policy must describe the AdMob data collection (ADS.md §9) |
| Store listing | Title ≤ 30 chars, short description ≤ 80, full ≤ 4000; feature graphic 1024×500; ≥ 2 phone screenshots (use 6), 7" and 10" tablet screenshots if tablets are supported. *v2.1:* no "no ads / no tracking" claims; **don't show ads in screenshots** |

## 3. Apple App Store

| Item | Value / action |
|---|---|
| Build | Xcode 26+ with the iOS 26 SDK (required for uploads since 28 Apr 2026); deployment target iOS 15 |
| Account | Apple Developer Program (individual or organisation — an organisation needs a D-U-N-S number; the seller name shown is the legal name) |
| Bundle ID | `com.<you>.docukit` — permanent |
| Capabilities | None required (no iCloud, no push). Document types for Open-in (P1). *v2.1:* In-App Purchase for `remove_ads` (P1) |
| Info.plist | `NSPhotoLibraryAddUsageDescription`; `ITSAppUsesNonExemptEncryption = NO`; `CFBundleDocumentTypes` (P1); *v2.1:* `GADApplicationIdentifier`, `SKAdNetworkItems`; no `NSUserTrackingUsageDescription` (no ATT, ADR-029) |
| App Privacy ("nutrition label") *(v2.1, ADS.md §9)* | Declare the data the Google Mobile Ads SDK collects (Identifiers → Device ID only if ATT is used; Usage Data → Advertising data, Product interaction; Diagnostics; Location → Coarse). Mark **"Used to track you: No"** while ATT isn't used. Check Google's iOS guidance for the current mapping |
| Paid-apps agreement *(v2.1, P1)* | Accept the Paid Apps agreement and complete tax/banking in App Store Connect; create the non-consumable `remove_ads` product (ADR-030) |
| app-ads.txt *(v2.1)* | Same developer website as on Play (see §2) |
| Privacy manifest | `ios/Runner/PrivacyInfo.xcprivacy` (below). Each plugin ships its own; check the merged privacy report from the archive |
| Age rating | 4+ |
| Category | Productivity (secondary: Utilities) |
| Review notes | "All processing is on-device; no login required. Sample files: use any photos/PDF in Files. The Strong PDF reduction intentionally rasterises pages after a confirmation." |
| Screenshots | 6.9" iPhone (required set) + 13" iPad if iPad is supported (OD-2) |
| Guideline risks | 4.2 Minimum functionality → mitigated by six real tools; 5.1.1 → no unnecessary permissions; 2.3 → screenshots must show the real app |

### 3.1 `PrivacyInfo.xcprivacy` (app target — adjust to the APIs your code actually uses)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryDiskSpace</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>E174.1</string><string>85F4.1</string></array>
      <!-- E174.1: check free space before writing; 85F4.1: show storage used to the user -->
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>C617.1</string></array>
      <!-- C617.1: timestamps of files inside the app container (temp/retention sweeps) -->
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
      <!-- CA92.1: app's own settings via shared_preferences -->
    </dict>
  </array>
</dict>
</plist>
```
Confirm the reason codes against Apple's "Describing use of required reason API" page at submission time.

## 4. Licences
- Flutter's `showLicensePage` aggregates the package licences automatically via `LicenseRegistry`. Add manual entries for the native code: PDFium (BSD-3, bundled by pdfrx), PdfBox-Android (Apache-2.0, only if used), any fonts (OFL).
- Apache-2.0 deps: include NOTICE contents if a dependency provides a NOTICE file.
- Run `flutter pub deps --json` and review the transitive packages before M6.

## 5. Store listing draft
**Title:** DocuKit: PDF & Image Tools
**Short description (≤ 80):** Compress photos, resize images, make & merge PDFs — offline and private.
**Full description:**
> DocuKit puts the document tools you need in one simple app — and your files never leave your phone.
>
> • **Compress images** — choose a quality, or hit a target like "under 100 KB" for upload forms.
> • **Resize images** — exact pixels, percentages, or presets for passport photos and signatures.
> • **Images to PDF** — turn photos of notes, receipts or certificates into one tidy PDF.
> • **Merge PDFs** — combine several files in the order you choose.
> • **Organize pages** — reorder, rotate or delete pages.
> • **Reduce PDF size** — shrink PDFs for email, with clear choices about quality.
>
> **Private by design:** no account and no uploads — your files never leave your phone. Everything happens on your device, and your originals are never changed. DocuKit always shows you the real result size — no fake promises.

*(v2.1: removed the "no ads, no tracking" claim per ADS.md §9. DocuKit is free and ad-supported, with an optional one-time Remove ads purchase.)*

**Keywords (iOS, 100 chars):** `pdf,compress,resize,merge,image to pdf,photo,kb,passport,signature,scanner,reduce,jpg,combine`

## 6. Privacy policy (template — edit the bracketed parts)
> **DocuKit Privacy Policy** — Effective [date]
>
> DocuKit ("the app") is made by [your name/company], [contact email].
>
> *(v2.1 draft per ADS.md §9 — review before publishing.)*
>
> **Your files:** files you choose are processed only on your device. The app never uploads your files, file names or results, and never passes them to advertising partners. The app has no account system.
>
> **Advertising:** DocuKit is free and shows ads from Google AdMob. To show and measure ads, Google may collect device information such as the advertising ID, app interactions, diagnostics and approximate location (from your IP address). See Google's policy: [link to Google's "How Google uses information from sites or apps that use our services"]. Where the law requires it, the app asks for your consent first; you can change your choices at any time in Settings → Privacy & ad choices. You can also remove ads with a one-time purchase.
>
> **How your files are handled:** files you choose are processed only on your device. The app keeps a list of recent jobs and copies of results on your device for the period you choose in Settings (7 days by default). You can delete them at any time in Settings. Uninstalling the app deletes them.
>
> **Permissions:** the app accesses only the photos and files you select in the system picker. On iOS it asks for permission to add images to your photo library only when you choose "Save to Photos".
>
> **Crash information:** Google Play and Apple may provide us with anonymous crash statistics if you've allowed this in your device settings. We don't receive your files.
>
> **Children:** the app isn't directed at children under 13. *(v2.1: "collects no personal data" removed — the ads SDK collects device data, see Advertising.)*
>
> **Changes:** we'll update this page and the effective date if this policy changes.
>
> **Contact:** [email]

## 7. Pre-submission checklist
- [ ] Release builds tested on a real device on each OS (R1–R26)
- [ ] Merged release manifest: `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID` and the AdMob `APPLICATION_ID` present; no media/storage read permissions (v2.1)
- [ ] Privacy report from the Xcode archive matches the declared App Privacy label (v2.1, incl. the Google Mobile Ads SDK's own manifest)
- [ ] app-ads.txt published; `remove_ads` product live in both stores; paid-apps agreement signed (v2.1)
- [ ] Store screenshots show no ads (v2.1)
- [ ] Licences page complete
- [ ] App icon (all variants), screenshots, descriptions final
- [ ] Privacy policy URL live
- [ ] Upload key backed up; iOS certificates valid
- [ ] `CHANGELOG.md` + git tag
