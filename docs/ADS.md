# DocuKit — Ads Specification (v2.1)

> **This supersedes ADR-002 ("No network at all").** See ADR-028 in `DECISIONS.md`.
> The core promise stays: **your files never leave your phone.** The ads SDK gets no access to files, file names or results. Only `lib/core/ads/` may talk to the network.

## 1. Goals and guardrails

| Goal | Guardrail |
|---|---|
| Earn revenue while keeping the app free | Ads never sit inside a tool's working area or next to a primary action |
| Stay compliant with AdMob policy, so serving isn't disabled | Placements follow Google's interstitial guidance (logical breaks only; at most 1 per 2 user actions; never at app launch or exit) and banner guidance (never next to buttons/navigation; never floating over content) |
| Keep the "works offline" promise | With no network or no ad, every slot collapses to **zero height**; no empty boxes, spinners or errors |
| Keep trust | Every ad is labelled ("Ad" / "Sponsored"), consent is respected, and a one-time **Remove ads** purchase is offered |

## 2. Stack

| Concern | Package | Notes |
|---|---|---|
| Ads | `google_mobile_ads` (8.x at the time of writing; requires Flutter ≥ 3.38) | Banner (anchored adaptive), Native (via `NativeTemplateStyle` templates or a custom factory), Interstitial, Rewarded, App open |
| Consent (GDPR/UK/CH + US states) | UMP SDK, bundled in `google_mobile_ads` (`ConsentInformation`, `ConsentForm`) | Since 16 Jan 2024 a Google-certified CMP is required for EEA/UK traffic, or only Limited Ads are served |
| Remove ads (P1) | `in_app_purchase` (Flutter team) | One non-consumable product, `remove_ads` |
| iOS tracking prompt | **Not used in v2.1** (no ATT prompt) | The SDK then doesn't use the IDFA; ads still serve. Revisit with ADR-029 if revenue needs it |

Pin versions after checking pub.dev, and add them to the ARCHITECTURE stack table.

## 3. Placement map

| ID | Screen | Format | Position | Rules |
|---|---|---|---|---|
| **AD-1** | S01 Home | **Native, small template** (≈ 90–120 dp tall card) | Between the "PDF tools" grid and "Recent", with 24 dp space above and below | Hidden during the tour, on the first launch, and whenever no ad is loaded. Styled as a card with a visible "Ad" badge, so it can't be mistaken for a tool |
| **AD-2** | S11 Result | **Native, medium template** (≈ 300 dp) | Below the retention note ("Kept in Recent for 7 days"), separated by a divider and the label "Sponsored", with **≥ 32 dp** from the nearest button | Shown only after the user has scrolled or after a 600 ms delay (prevents an accidental tap during the success animation). Not shown on the "result is larger" warning state |
| **AD-3** | Result → Home (tap **Done**) | **Interstitial** | Shown on the transition back to Home (a natural break) | Frequency caps in §4. Never after Save/Share/Open, never after a failed or cancelled job |
| **AD-4** | S14 Recent Activity | **Native, small template** in-feed | After the 3rd row; then again every `historyAdInterval` rows (**12** at launch; **8** in Phase B) | Only when the list has ≥ 5 items; never in the empty state; excluded from swipe-to-remove. The interval is a constant in `ads_config.dart` (no remote config: there's no backend) |
| **AD-5** | S16 Settings | **Anchored adaptive banner** | Bottom of the screen, **outside** the scroll view (space reserved, never overlaps the content) | Not on the Privacy & About page or the licences page |
| **AD-6** | S15 Operation Details | **Native, medium template** | Below the last button ("Remove from history"), after a divider and the label "Sponsored", ≥ 32 dp from any button | Only when the screen's content is taller than the ad (so it never fills an otherwise empty screen); not on failed entries |
| **AD-7** *(Phase B)* | App returns from background | **App open ad** | Full screen, shown over the app as it comes back | Rules in §4.2: never on a cold launch, never in the first session, at most once per 4 h, never within 2 min of a job finishing or while a job runs, never if the user was away < 30 s or came back via a share/save/picker flow |
| **AD-8** | Opt-in from the Remove-ads sheet, plus a Result-screen link | **Rewarded ad** | Full screen, only after the user taps "Watch an ad" | Reward: **no ads for 24 hours**. The user always chooses it; never auto-plays; max 2 rewards a day. Later this can unlock V1.1 batch mode for one job |
| **AD-9** *(Phase B)* | S01 Home, second card | **Native, small template** | After the Recent section, above the privacy footer, with 24 dp space | Only if Home's content is at least 1.5 screen-heights tall (measured) and the user has ≥ 3 recent items; otherwise not built |

**Phases.** **Phase A (launch):** AD-1 … AD-6 + AD-8. **Phase B (after about 30 days of AdMob data):** AD-7, AD-9 and the AD-4 interval of 8. Turn on Phase B only if retention and ratings hold (Day-7 retention not more than 10% below Phase A, and store rating ≥ 4.3). Phase B ships as an app update, with the `adsPhase` constant changed in `ads_config.dart`.

### Never show ads on
Onboarding (S20) · the Home tour · tool screens S03–S08 (their sticky primary button makes accidental clicks likely) · Processing (S10) · Error (S18) · Search (S02: short-lived, with the keyboard open) · the Organizer editor · the page preview · any dialog or bottom sheet · Privacy & About (S17) · licences · the Incoming chooser (S19) · system picker/share/save flows · **empty states and blank space on any screen** (AdMob treats ads on screens without content as a violation).

> **Why not more?** The AdMob policies and the "ads should never be the primary focus of the app" principle are enforced by limiting or disabling ad serving, and a suspension covers the whole AdMob account. Most of the revenue comes from the full-screen formats (AD-3, AD-8, AD-7); extra cards mostly add clutter, which shows up in reviews and uninstalls.

## 4. Frequency and timing rules (`AdPolicy`) **[unit]**

```
canShowInterstitial(now):
  !adsRemoved
  && consent.canRequestAds
  && tourDone
  && lifetimeCompletedJobs ≥ 2          // never in a new user's first two jobs
  && jobsSinceLastInterstitial ≥ 3      // at most 1 per 3 completed jobs (stricter than Google's 1 per 2 actions)
  && now − lastInterstitialAt ≥ 4 min
  && now − appForegroundedAt ≥ 60 s     // never right after launch/resume
  && interstitialsThisSession < 2
  && lastJobStatus == SUCCESS
  && userTappedDone                      // not system back from the Result screen
  && interstitialLoaded                  // never wait for one: no ad ready → just navigate
```
- Pre-load the next interstitial when a job **starts** (so it's ready on Done), and discard it after 55 minutes (ads expire after about an hour).
- Show it first, then navigate Home in `onAdDismissedFullScreenContent` / `onAdFailedToShowFullScreenContent`. Navigation must never be blocked for more than 300 ms waiting on an ad.
- Native AD-1/AD-4: load when the screen appears; one request per screen visit; reuse a loaded ad for up to 60 minutes; dispose on screen dispose.
- Counters live in `shared_preferences`: `ads_jobs_since_interstitial`, `ads_last_interstitial_at`, `ads_lifetime_jobs`.
- Native AD-6: same as AD-1/AD-4. AD-9: build only when the measured scroll extent ≥ 1.5 × viewport height.

### 4.2 App open ad (AD-7, Phase B) **[unit]**
```
canShowAppOpen(now):
  adsPhase ≥ B && !adsRemoved && !rewardActive && consent.canRequestAds && tourDone
  && sessionNumber ≥ 2                       // never in the first session
  && isWarmResume                            // never on a cold launch (Google policy: no ads at app load)
  && backgroundedFor ≥ 30 s
  && !returningFromSystemFlow                // picker, save, share, open-with, purchase, consent form
  && !jobRunning && now − lastJobFinishedAt ≥ 2 min
  && now − lastFullScreenAdAt ≥ 4 h          // any interstitial or app open ad
  && appOpenAdLoaded && adAge < 4 h          // app open ads expire after 4 h
```
Load it when the app goes to the background; show it via `AppLifecycleListener.onResume` before the first frame of the resumed screen; never block for more than 300 ms waiting on one.

### 4.3 Rewarded ad (AD-8) **[unit]**
```
canOfferReward(now):
  !adsRemoved && consent.canRequestAds && rewardsGrantedToday < 2 && rewardedAdLoaded
onUserEarnedReward → adsFreeUntil = now + 24 h; every slot collapses; no interstitial or app open ad until then
```
- Offer it in the Remove-ads sheet ("Watch a short ad: no ads for 24 hours") and as a text link under AD-2. The button is hidden when no rewarded ad is loaded — never show a button that leads to "no ad available".
- Grant the reward only in `onUserEarnedReward`, not when the ad closes early.
- Keys: `ads_free_until` (epoch ms), `ads_rewards_today`, `ads_rewards_day` (yyyyMMdd).

### 4.4 Global caps (all formats) **[unit]**
- Full-screen ads (AD-3, AD-7) never within 4 minutes of each other, and at most 3 per session combined.
- No ads at all while `adsFreeUntil > now` or `adsRemoved`.
- No more than **one native card visible on screen at a time** (affects AD-4 with short rows, and AD-1/AD-9 on tall tablets).

## 5. Consent flow (UMP)

```
App start (after first frame, non-blocking):
  ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), onSuccess, onError)
  onSuccess → ConsentForm.loadAndShowConsentFormIfRequired((formError) { ... })
  then if await ConsentInformation.instance.canRequestAds() → MobileAds.instance.initialize()
  onError → no ads this session (log the error code only)
Settings → "Privacy & ad choices" row: visible when
  ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required
  → ConsentForm.showPrivacyOptionsForm(...)
```
- **Order matters on the first run:** onboarding (S20) → consent form (only shown in regions that need it) → Home tour. Don't stack the consent form on top of the tour.
- Create the European regulations message (and the US states message, if you want to cover US state privacy laws) in AdMob → Privacy & messaging.
- Debug: `ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea, testIdentifiers: [...])` to test the EEA flow from anywhere.
- *Verify the exact method names against the `google_mobile_ads` version you pin; the UMP API has been renamed across major versions.*

## 6. Remove ads (P1)

| Item | Spec |
|---|---|
| Product | Non-consumable `remove_ads` on both stores (suggested price tier ≈ US$2.99; localise per store) |
| Entry points | Settings → "Remove ads" row; a small "Remove ads" text link under AD-2 on Result |
| Screen | Bottom sheet: what you get (no ads, forever, on this account), the price from the store, [Buy], [Restore purchase], and below a divider the free option "Watch a short ad: no ads for 24 hours" (AD-8, shown only when a rewarded ad is loaded) |
| Behaviour | On purchase/restore → `ads_removed = true` → every slot collapses immediately; no new ad requests. If the user also hasn't consented, still no ads |
| Verification | Client-side receipt check for v2.1 (no server; acceptable for a low-price unlock); restore on reinstall via the store |
| Copy | "Enjoying DocuKit? Remove ads once and support development." |

## 7. Architecture

```
lib/core/ads/
  ads_config.dart          // unit IDs from --dart-define; test IDs in debug
  ads_service.dart         // init, consent, canRequestAds, adsRemoved stream
  ad_policy.dart           // §4 rules (pure, unit-tested)
  interstitial_manager.dart
  rewarded_manager.dart    // AD-8: load, offer, grant adsFreeUntil
  app_open_manager.dart    // AD-7 (Phase B): lifecycle-driven load/show
  native_ad_slot.dart      // widget: loads, renders template, collapses on fail; "Ad" badge
  banner_ad_slot.dart      // anchored adaptive banner; collapses on fail
  consent_gate.dart
lib/features/settings/presentation/remove_ads_sheet.dart
```
- `AdsService` is an interface (`FakeAdsService` in tests → slots render nothing, so the existing widget tests stay stable).
- **Isolation rule:** only `core/ads/` and `features/settings/...remove_ads...` may import `google_mobile_ads`/`in_app_purchase`. Add a CI grep check.
- **No app data goes to ads:** no keywords, no content URLs, no custom targeting built from file types or tool usage. `AdRequest()` stays empty (apart from the consent-derived flags).
- Unit IDs: `--dart-define=ADMOB_APP_ID_ANDROID=…` etc. The **App ID** must also be in `AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID` meta-data) and in iOS `Info.plist` (`GADApplicationIdentifier`), or the app crashes at launch.
- Debug builds always use Google's test unit IDs. **Never tap your own live ads** — register your devices as test devices.
- **Release gate (v2.1 release fixes):** release builds refuse to build unless the App ID and **all seven** Phase A unit IDs are present, well-formed, and not Google's sample/test IDs. The Android Gradle build checks this itself (`preReleaseBuild`), and the release CI runs `tool/check_release_ads.dart` for both platforms (the iOS App ID comes from `ios/Flutter/AdMob.xcconfig`). A release build never falls back to test IDs at runtime. *This replaces the Ad map's "leave `ADMOB_BANNER_SETTINGS` empty to hide the Settings banner" option:* reuse another banner unit ID instead. `ADMOB_DEBUG_EEA` has no effect in release builds.

## 8. Platform configuration changes

**Android**
- Add `<uses-permission android:name="android.permission.INTERNET"/>` and `ACCESS_NETWORK_STATE` to the **main** manifest. The SDK merges `com.google.android.gms.permission.AD_ID`; keep it (it's needed for ads on Android 13+) and declare it in Play Console.
- The `APPLICATION_ID` meta-data.
- R8: the SDK ships its own consumer rules; verify the release build shows ads.

**iOS**
- `Info.plist`: `GADApplicationIdentifier`, plus `SKAdNetworkItems` (copy Google's current list from the AdMob iOS quick-start page).
- No `NSUserTrackingUsageDescription` (no ATT in v2.1).
- The Google Mobile Ads SDK ships its own `PrivacyInfo.xcprivacy`; re-run Xcode's privacy report after adding it.

**Both**
- `app-ads.txt` on the developer website listed in both stores (AdMob shows the exact line to publish). Without it, ad revenue can be reduced.

## 9. Store and privacy changes (replaces the RELEASE.md answers)

| Store item | Old answer | New answer |
|---|---|---|
| Play "Contains ads" | No | **Yes** |
| Play Data safety | No data collected | Data **collected and shared** by the AdMob SDK: Device or other IDs (advertising ID), App activity/interactions, App info & performance (crash logs, diagnostics), Approximate location (from IP). Purposes: Advertising/marketing, Analytics, Fraud prevention. Follow Google's "Data disclosure for AdMob" guide for the exact mapping |
| App Store privacy label | Data Not Collected | Declare the data the Google Mobile Ads SDK collects (Identifiers → Device ID only if ATT is used; Usage Data → Advertising data, Product interaction; Diagnostics; Location → Coarse). Mark "Used to track you" **No** while ATT isn't used. Check Google's iOS guidance for the current mapping |
| Privacy policy | No data collected | Rewrite: files stay local; the ads partner (Google AdMob) collects device/usage data to serve ads; link to Google's policy; how to change consent (Settings → Privacy & ad choices); Remove ads option |
| Listing text | "no ads, no tracking" | Remove these claims. Keep: "Your files never leave your phone." |
| Store screenshots | — | Don't show ads in screenshots |

## 10. Copy (add to COPY.md)

| Key | Text |
|---|---|
| ad_badge | Ad |
| ad_sponsored | Sponsored |
| set_remove_ads | Remove ads |
| set_remove_ads_sub | One-time purchase |
| set_ad_choices | Privacy & ad choices |
| rem_title | Remove ads |
| rem_body | Enjoying DocuKit? Remove ads once and support development. |
| rem_point1 / 2 / 3 | No ads, ever / Works on this device and future installs with the same store account / Your files stay on your phone, as always |
| rem_buy | Buy for {price} |
| rem_restore | Restore purchase |
| rem_thanks | Thanks for your support. Ads are gone. |
| rem_failed | The purchase didn't go through. You haven't been charged. |
| priv_ads_h | About ads |
| priv_ads_p | DocuKit shows ads from Google AdMob to stay free. Ads never see your files, file names or results. Google may use device information to show and measure ads. You can change your ad choices in Settings, or remove ads with a one-time purchase. |
| priv_local_p (updated) | Everything DocuKit does to your files happens on this device. Your files are never uploaded. |
| priv_tracking_h/p | **Remove this section** (the "no internet permission" claim is no longer true) |
| rew_offer | Watch a short ad: no ads for 24 hours |
| rew_offer_short | No ads for 24 hours? Watch a short ad |
| rew_granted | Done. No ads until {time} tomorrow. |
| rew_not_earned | The ad was closed early, so ads are still on. |
| rew_limit | You've used today's ad-free passes. Try again tomorrow. |
| ads_free_until | Ad-free until {time} |

## 11. Tests

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
