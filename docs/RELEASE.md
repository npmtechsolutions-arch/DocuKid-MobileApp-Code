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
| Build | Xcode 26+ with the iOS 26 SDK (required for uploads since 28 Apr 2026); deployment target iOS 15.5 from 1.3 (ADR-044; iOS 15 for 1.0–1.2) |
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
- Flutter's `showLicensePage` aggregates the package licences automatically via `LicenseRegistry`. Add manual entries for the native code: PDFium (BSD-3, bundled by pdfrx), PdfBox-Android (Apache-2.0 + NOTICE, Android only — added in 1.4), any fonts (OFL: Plus Jakarta Sans, Noto Sans + Devanagari, Dancing Script, Sacramento, Mr Dafoe).
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
> **Permissions:** the app accesses only the photos and files you select in the system picker. On iOS it asks for permission to add images to your photo library only when you choose "Save to Photos". Files you share into DocuKit from other apps are copied into the app and processed only on your device. *(1.1)* When you scan, the camera images are processed on your phone. On Android, the scanner is provided by Google Play services, which may send Google basic diagnostics about it, such as the device model, app version and error codes, but never your images. *(1.2, ADR-064)* Text recognition also runs on your phone: DocuKit doesn't upload your files or the text found in them. It uses Google's ML Kit, which may send Google basic diagnostics about it, such as the device model, app version and error codes, but never your images or text. *(1.3, ADR-064)*
>
> **Passwords and signatures:** saved signatures are stored only on your device and are not included in backups. Passwords you enter are used once and never saved. *(1.4)*
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

## 8. Per-release store changes (1.1–1.5)

Merged in M0 from FULL_PRODUCT §5 and each release spec's §6. Apply each block in the release that ships it, and re-run §7 for that release. Versioning: `1.x.0+N` on branch `release/1.x`; `N` never goes down (CHANGES_v3 §5).

### 8.0 Summary (FULL_PRODUCT §5)

| Release | New permissions | Min OS change | Privacy-label / Data safety change | App size impact (est.) |
|---|---|---|---|---|
| 1.1 | None (folder picker needs none) | — | None | +0.2 MB (`archive`) |
| 1.2 | iOS: camera (`NSCameraUsageDescription`). Android: none (ML Kit scanner runs in Google Play services) | — | Declare ML Kit's diagnostics collection, if any (verify Google's ML Kit data-disclosure page) | Android ~0 (Play services); iOS ~0 (VisionKit) |
| 1.3 | None | **iOS 15.5** (ML Kit text recognition requires it) | Same ML Kit note | Android (measured T10.0, bundled, ADR-045): +12.9 MB per phone for Latin, +0.6 MB for Devanagari; iOS +10–25 MB per script (measure in the Xcode round) |
| 1.4 | None | — | None (passwords, signatures and files stay on the device) | Android **+1.74 MB** measured (PdfBox-Android without BouncyCastle, T11.0); fonts **+0.26 MB** both (ADR-067) |
| 1.5 | Notifications (Android 13+ `POST_NOTIFICATIONS`; iOS prompt), Face ID (`NSFaceIDUsageDescription`). *Measured T12.0 (Android merged manifest):* `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `USE_BIOMETRIC`, `USE_FINGERPRINT` — no storage access | — | None (data stays local), but update the privacy policy: documents can be stored in the app | **+354 KB** measured (arm64 release, ADR-068) |

### 8.1 Version 1.1 — Productivity (RELEASE_V1_1 §6)

- **No new permissions.** `ACTION_OPEN_DOCUMENT_TREE` and the iOS export picker are user-mediated.
- Intent filters make DocuKit appear in other apps' share sheets; no data is read until the user chooses DocuKit.
- Privacy policy: add one sentence — "Files you share into DocuKit from other apps are copied into the app and processed only on your device."
- Store listing "What's new": batch processing, Convert Image, Split PDF, PDF to Images, favourites, share to DocuKit.
- **"What's new" text (T8.13, ready to paste, 373 characters — Play limit 500):**
  > New in DocuKit 1.1:
  > • Compress or resize up to 50 photos at once, then save them all to a folder or as one ZIP
  > • Convert Image: HEIC, PNG, WebP and JPG
  > • Split PDF by page ranges, every N pages or each page
  > • PDF to Images: save pages as JPG or PNG
  > • Pin your favourite tools to Home
  > • Share photos and PDFs to DocuKit from other apps
  > Everything still stays on your device.
- Screenshots: add a batch result screen (no ads visible).
- Data safety / App privacy: unchanged.

### 8.2 Version 1.2 — Scan Document (camera string) (RELEASE_V1_2 §6)

| Item | Android | iOS |
|---|---|---|
| Camera permission | **None** declared by DocuKit (ML Kit scanner runs inside Google Play services) — confirm the merged manifest has no `CAMERA` at T9.0 | `NSCameraUsageDescription` = "DocuKit uses the camera to scan documents. Scans stay on your phone." |
| Photo library | Gallery import happens inside the ML Kit UI; no permission | Not used |
| Network | ML Kit may download the scanner module once via Play services | None |
| Data leaving the device | Scanned images are processed on-device. ML Kit / Play services may send API usage and diagnostics to Google — **verify against Google's ML Kit data disclosure** and update the Data safety form (likely "App info and performance → Diagnostics", collected, not shared) if required | VisionKit is on-device; no change |
| Play Data safety | Update only if the ML Kit disclosure requires it (see above) | — |
| App Store privacy label | — | No change (on-device) |
| Privacy policy | Add: "When you scan, the camera images are processed on your phone. On Android, the scanner is provided by Google Play services." | Same sentence (without the Android part) |
| Privacy & About (S17) | Add a "Camera" row to "What DocuKit can access": "Only while you're scanning" | Same |

### 8.3 Version 1.3 — Text Recognition (iOS 15.5 minimum) (RELEASE_V1_3 §6)

| Item | Change |
|---|---|
| Permissions | None new |
| **iOS deployment target** | **15.0 → 15.5** (required by the ML Kit text recognition pod). Update Xcode settings, `Podfile` (`platform :ios, '15.5'`), and RELEASE.md/PRD compatibility rows. Users on iOS 15.0–15.4 stop receiving updates (ADR-044) |
| Android minSdk | Unchanged (26 ≥ 21) |
| Network | ML Kit may download models through Google Play services (Android, unbundled) and may send anonymous performance metrics. **Verify** Google's "ML Kit data disclosure" page and update the Play Data safety answers (likely App info & performance → Diagnostics, collected, not shared, for analytics) and the App Store privacy label if the iOS SDK collects anything. **Checked 2026-10-29 (T10.9):** models are bundled (ADR-045), so nothing is downloaded; Google's pages list diagnostics and usage analytics only, already covered by the declared types. No new Data safety types; the App Store label is to be confirmed with Xcode's privacy report (STORE_PRIVACY_CHECKLIST "1.3"). |
| Privacy text | Add to Privacy & About: "Text recognition runs on your phone. DocuKit doesn't upload your files or the text found in them." **Done (T10.9):** S17 point + the in-app and hosted policy sentence (owner to review). |
| Ads | S30: bottom Tools banner; S31: none; Result: existing |

**App size (estimates; T10.0 measures them):**

| Item | Android | iOS |
|---|---|---|
| ML Kit Latin model | ~0 if unbundled (Play services); ~4 MB if bundled | ~10–15 MB |
| Each extra script (Devanagari etc.) | ~0 unbundled; ~4–6 MB bundled | ~5–15 MB each |
| Noto Sans + Noto Sans Devanagari | ~0.8 MB | ~0.8 MB |

Decision rule (ADR-045): ship Latin on both platforms; add Devanagari if the iOS download size stays under **60 MB** total. Others in a later update.

### 8.4 Version 1.4 — Sign, Watermark, Protect, Unlock (export compliance) (RELEASE_V1_4 §6)

| Item | Impact |
|---|---|
| New permissions | None |
| Data safety / App Store privacy label | No change: passwords, signatures and files stay on the device |
| Privacy policy | Add: "Saved signatures are stored only on your device and are not included in backups. Passwords you enter are used once and never saved." |
| Privacy & About (S17) | Add a short "Passwords and signatures" section with the same text |
| **Export compliance (iOS)** | The app now **uses encryption** (AES-256 via PDFKit, and on Android via PdfBox). `ITSAppUsesNonExemptEncryption` is currently `NO`. Encrypting the user's own files with standard algorithms provided by the OS is generally considered exempt, but the App Store Connect export-compliance questions must be answered again for 1.4. **Verify Apple's export compliance questions and the current exemption categories before submitting; record the answer in ADR-051.** |
| Google Play | No encryption declaration needed (verify the current Play Console policy) |
| App size | Android **+1.74 MB** (measured, T11.0: PdfBox-Android 2.0.27.0 without BouncyCastle, R8 release build); fonts **+0.26 MB** both platforms (ADR-067) |
| Licences | PdfBox-Android: its NOTICE + Apache-2.0 LICENSE from the v2.0.27.0 tag (`assets/licenses/`, Android build only — the AAR ships no NOTICE); Dancing Script, Sacramento, Mr Dafoe (OFL) — all on the licences page, tested (T11.9) |
| **Status (T11.9)** | Privacy policy (in-app `privPolicyBody2` + §6 template), S17 "Passwords and signatures" and the updated "Password-protected files" text are in. **Export compliance stays open for the owner (ADR-051)**; `ITSAppUsesNonExemptEncryption` is unchanged. Google Play: re-check the Console's export-law question on submit day |

### 8.5 Version 1.5 — My Documents (notifications, Face ID string) (RELEASE_V1_5 §6)

| Item | Android | iOS |
|---|---|---|
| Notifications | `POST_NOTIFICATIONS` (13+), runtime request on first reminder | Authorization request on first reminder |
| Boot reschedule | `RECEIVE_BOOT_COMPLETED` (added by the plugin — verify manifest merge) | — |
| Biometrics | `USE_BIOMETRIC` (merged by `local_auth`) | `NSFaceIDUsageDescription` = "DocuKit uses Face ID to unlock My Documents." |
| Exact alarms | **Not used** (inexact scheduling; no `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`) | — |
| Backup | `dataExtractionRules` / `fullBackupContent` exclude library + DB | `isExcludedFromBackup` on `library/` |
| Privacy manifest | — | Re-check required-reason APIs (file timestamps already declared; UserDefaults already) |

**Play Data safety / App Store label:** no new data collection — documents, notes, tags, OCR text and reminders stay on the device. **Privacy policy additions:** "If you save documents to My Documents, they're stored only on your device, aren't included in cloud backups, and are deleted when you delete them or uninstall DocuKit. Reminders are local notifications created on your device."

**Store listing:** add "Keep your documents in folders, find them by searching their text, and get reminders before they expire" to the description; one new screenshot (Library with Expiring soon — no ads, no real personal documents).
