# DocuKit v2.1 — Change Pack: UI refresh, ads, Home tour

This pack adds three features to the existing app. It has **new documents** to drop into `docs/` and **merge instructions** for the documents you already have. Your copies have moved on since v2.0 (new decisions, copy and task statuses), so merge these changes in rather than overwriting your files. Prompt M0 in §9 has Claude Code do the merge.

## 1. New files
| File | Put it in | Contents |
|---|---|---|
| `docs/ADS.md` | `docs/` | Ad placements, frequency rules, consent, Remove ads, platform/store changes, copy, tests |
| `docs/TOUR.md` | `docs/` | The Home tour: requirements, an intro card + 10 steps, visuals, implementation, copy, tests |
| `docs/UI_REFRESH.md` | `docs/` | Brand tokens, Home v2 (quick actions, savings), ToolCard v2, tool/processing/result polish, motion |
| `mockups/DocuKit_v2.1_mockups.html` | `docs/mockups/` | Visual reference for Home, the tour, Result and Settings (open it in a browser) |

## 2. The product change in one paragraph
DocuKit stays a free, offline-first app; **your files still never leave your phone**. What changes: it now shows a small number of policy-compliant ads (native cards on Home, Result and History; a banner on Settings; a capped interstitial after finishing a job), with a one-time **Remove ads** purchase. The "no ads / no tracking / no internet permission" claims are removed everywhere. The Home tour introduces every tool to new users, and the UI gets a brighter, friendlier finish.

## 3. New decisions (append to `DECISIONS.md`, numbered with the next free ADR numbers)

**ADR-028 — Ads via Google AdMob; supersedes ADR-002 · Accepted**
*Context:* free distribution needs revenue. *Decision:* use `google_mobile_ads` with the UMP consent flow, the placements in ADS.md §3 (Phase A: AD-1…AD-6 + AD-8; Phase B: AD-7, AD-9), and the frequency rules in §4. Only `lib/core/ads/` may access the network; the processing engines never do. *Consequences:* the INTERNET, ACCESS_NETWORK_STATE and AD_ID permissions; the Data safety form and App Store privacy label must now declare the SDK's data collection; the privacy copy is rewritten; offline use still works fully, with ad slots collapsing.

**ADR-029 — No App Tracking Transparency prompt in v2.1 · Accepted**
*Decision:* don't request ATT on iOS. *Consequences:* no scary system prompt and "Used to track you: No"; possibly lower iOS ad revenue. Revisit after 60 days of data.

**ADR-030 — One-time "Remove ads" purchase · Accepted (P1)**
*Decision:* a non-consumable `remove_ads` via `in_app_purchase`, verified client-side (no server). *Consequences:* product setup in both stores; a restore flow; a paid-apps agreement plus tax/banking forms in App Store Connect and the Play payments profile.

**ADR-031 — Custom spotlight overlay for the Home tour · Accepted**
*Decision:* build a small custom overlay instead of a showcase package (TOUR.md §4), because the grid needs scroll-into-view and full a11y control. *Consequences:* about 250 lines; no dependency risk.

**ADR-032 — Brand heading font + gradients · Accepted**
*Decision:* bundle Plus Jakarta Sans (OFL) for headings only; add the gradient tokens (UI_REFRESH.md §1); illustrations via `flutter_svg` or `CustomPainter`. *Consequences:* < 600 KB size increase; licence entries.

## 4. `PRD.md` edits
- **Header table:** Delivery model → "Offline-first processing. No account or backend. Ad-supported, with an optional one-time Remove ads purchase."
- **§1 Executive summary:** keep "your files never leave your phone"; delete any "no ads" wording.
- **§1.2 Non-goals:** delete "Subscriptions, ads, in-app purchases"; replace it with "Subscriptions. Ads anywhere inside the working area of a tool."
- **§1.3 Success criteria:** replace "Network requests made by the app during the full regression script = 0" with "**No network request contains file content, file names or tool data** (verified with a proxy); every tool works in airplane mode."
- **§3.1 MVP table — add:**
  | MVP-11 | Ads | Phase A: native ads on Home, Result, History and Operation details; banner on Settings; capped interstitial after a finished job; opt-in rewarded ad (24 h ad-free); UMP consent. Phase B (after ~30 days of data): app open ad on resume, second Home card, denser History cards (ADS.md §3) |
  | MVP-12 | Home tour | A 10-step spotlight tour (plus an intro card) covering every tool; auto once, replayable (TOUR.md) |
  | MVP-13 | UI refresh | Gradients, quick actions, savings counter, ToolCard v2, Result celebration (UI_REFRESH.md) |
  | MVP-14 | Remove ads (P1) | One-time purchase + restore (ADS.md §6) |
- **§3.3 Excluded:** replace "Automatic uploads, background sync, contact or location access" with "Uploading files or file data anywhere; ads targeted using file names, file types or tool usage."
- **§5 new requirement groups:** add the **FR-TOUR-01…10** table from TOUR.md §1, and:
  | FR-ADS-01 | P0 | Ads only at AD-1…AD-9 (Phase B ones only when `adsPhase = B`) | No ad widget renders on the excluded screens (ADS.md §3) |
  | FR-ADS-02 | P0 | Interstitial caps | All the §4 rules unit-tested |
  | FR-ADS-03 | P0 | Consent before ad requests | No ad request until `canRequestAds()` is true; "Privacy & ad choices" row shown when required |
  | FR-ADS-04 | P0 | Offline-safe | Slots collapse to zero height with no network or no fill |
  | FR-ADS-05 | P0 | Clearly labelled | Every native ad shows an "Ad" badge and is visually distinct from tool cards |
  | FR-ADS-06 | P1 | Remove ads | Purchase/restore hides all ads immediately and permanently |
  | FR-ADS-07 | P0 | Rewarded ad-free pass (AD-8) | Reward only on `onUserEarnedReward`; 24 h with no ads of any kind; max 2 a day; offer hidden when no ad is loaded |
  | FR-ADS-08 | P1 | App open ad (AD-7, Phase B) | All of ADS.md §4.2 unit-tested; never on a cold launch |
  | FR-ADS-09 | P0 | Global caps | Full-screen ads ≥ 4 min apart and ≤ 3 per session; never two native cards visible at once (ADS.md §4.4) |
  | FR-HOME-06 | P0 | Quick actions | Each chip opens its tool with its prefilled options (UI_REFRESH §2.1) |
  | FR-HOME-07 | P1 | Savings counter | Shows the total bytes saved, local only; hidden when 0 |
- **§6 NFR Privacy:** "No account. File contents never leave the device. Only the ads SDK uses the network, with consent where required." **Security:** add "No app data is passed in ad requests."
- **§7 Metrics:** add "AdMob dashboard: impressions, eCPM, fill rate per placement; Remove ads conversion."
- **§8 Release acceptance #6:** replace it with "Every tool works in airplane mode; the proxy log shows only ad/consent traffic, with no file data."
- **§9 Roadmap:** add **M7 — v2.1 (UI refresh, tour, ads): 6–9 days** (TASKS below).

## 5. `CLAUDE.md` edits
- In **Product**, replace "no backend, no network, no analytics and no ads" with "no backend; ad-supported (Google AdMob) with an optional Remove ads purchase. Files never leave the device."
- Replace non-negotiable **#5** with:
  > 5. **Network only for ads.** Only `lib/core/ads/` (and the Remove ads purchase code) may import `google_mobile_ads` / `in_app_purchase` or touch the network. Never pass file names, file types, tool usage or any user content into ad requests. Don't add other network-capable packages.
- Add non-negotiable **#11:** "Ads only at the AD-1…AD-9 placements in docs/ADS.md, and never inside a tool's working area, the tour, dialogs, Search, Processing, Error, empty states or blank space."
- Under "Read before working", add `docs/ADS.md`, `docs/TOUR.md` and `docs/UI_REFRESH.md`.

## 6. Other existing docs
| Doc | Change |
|---|---|
| `ARCHITECTURE.md §1` | Add rows: `google_mobile_ads` (Apache-2.0), `in_app_purchase` (BSD-3), `flutter_svg` (MIT, if used), Plus Jakarta Sans (OFL asset). Add `lib/core/ads/`, `lib/features/tour/` and `features/home/quick_actions.dart` to §3 |
| `ARCHITECTURE.md §8.1` | New settings keys: `tour_done` (false), `tour_version` (0), `stats_total_saved_bytes` (0), `ads_removed` (false), `ads_jobs_since_interstitial` (0), `ads_last_interstitial_at` (0), `ads_lifetime_jobs` (0), `ads_free_until` (0), `ads_rewards_today` (0), `ads_rewards_day` (""), `ads_last_fullscreen_at` (0), `session_number` (0) |
| `ARCHITECTURE.md §11` | Android: INTERNET, ACCESS_NETWORK_STATE, AD_ID, and the AdMob `APPLICATION_ID` meta-data. iOS: `GADApplicationIdentifier`, `SKAdNetworkItems` |
| `SCREENS.md` | S01: the help (?) icon, quick actions, savings chip, AD-1 position. S11: the AD-2 position, Remove-ads link. S14: AD-4. S15: AD-6 below the buttons. S16: new rows "Take the tour", "Remove ads", "Privacy & ad choices", plus the AD-5 banner. S17: replace the "No tracking" section with "About ads". S20: then the consent form (if required) → the tour |
| `DESIGN_SYSTEM.md` | Point to UI_REFRESH.md §1 for the gradient tokens and font; add the components `NativeAdSlot`, `BannerAdSlot`, `TourOverlay`, `QuickActionChip`, `SavingsRing` |
| `COPY.md` | Add the copy tables from ADS.md §10, TOUR.md §5 and the UI_REFRESH tips (`tip_1…tip_8`, quick-action labels, `home_greeting_morning/afternoon/evening`, `home_saved_so_far`); update `priv_*` as ADS.md §10 says |
| `TESTING.md` | Add the tests from ADS.md §11 and TOUR.md §6. Change **R20** to "Airplane mode: all tools work; no empty ad boxes". **§7 Privacy verification:** the expected permissions now include INTERNET/ACCESS_NETWORK_STATE/AD_ID; the proxy test checks that no request contains file names/content. Add **R24** tour, **R25** consent (EEA debug), **R26** Remove ads purchase/restore |
| `RELEASE.md` | Replace the Data safety, App privacy, privacy-policy and listing rows with ADS.md §9; add app-ads.txt hosting, the in-app product setup and the paid-apps agreement; Play: "Contains ads = Yes" |

## 7. New tasks (append to `TASKS.md` as milestone M7)

- [ ] **T7.1 Brand tokens + font.** Gradient tokens, Plus Jakarta Sans headings, licence entry. *Accept:* goldens updated; contrast check passes (UI-REF-03).
- [ ] **T7.2 Home v2.** Hero greeting, help icon, quick actions with query-param prefill, savings counter, ToolCard v2, the entrance animation. *Accept:* FR-HOME-06/07; UI-REF-02/04.
- [ ] **T7.3 Tool, Processing and Result polish.** Option cards, gradient button, per-tool processing glyph + tips, success header, savings ring, confetti, 2×2 actions. *Accept:* UI_REFRESH §4–6; reduce-motion honoured.
- [ ] **T7.4 Empty states + illustrations.** *Accept:* every empty state in UI_REFRESH §7 has art in both themes.
- [ ] **T7.5 Tour controller + overlay.** *Accept:* the TOUR.md §6 unit/widget tests pass.
- [ ] **T7.6 Tour integration.** Keys on Home; auto-start ordering after onboarding and consent; replay from Home and Settings; "Try it". *Accept:* FR-TOUR-01…09 on a 320×568 screen and a tablet.
- [ ] **T7.7 AdMob account setup (you, not Claude).** Create the AdMob account, register the Android + iOS apps, create the ad units listed on the "Ad units" sheet of `DocuKit_Ad_Map.xlsx` (Phase A: Home native, Result native, History native, Details native, Settings banner, Done interstitial, Ad-free rewarded; Phase B later: Resume app open, Home native 2) and the GDPR + US-states messages; publish app-ads.txt on your website.
- [ ] **T7.8 Ads core.** `core/ads/*`: config via `--dart-define`, consent gate, `AdPolicy` + tests, slots that collapse, the interstitial manager, the fake service for tests; Android/iOS config. *Accept:* FR-ADS-01…05; test ads show on both OSes; the CI grep check limits ads imports to `core/ads/`.
- [ ] **T7.9 Place the ads.** AD-1…AD-6 per ADS.md §3, plus the AD-8 rewarded offer (Remove-ads sheet and Result link) and the global caps (§4.4). *Accept:* the excluded-screen widget test; manual policy review with screenshots.
- [ ] **T7.10 Remove ads (P1).** Store products, purchase sheet, restore, the Settings row. *Accept:* FR-ADS-06 with sandbox/test accounts.
- [ ] **T7.11 Privacy and store update.** Copy, privacy policy, Data safety, App privacy label, listing text, screenshots without ads. *Accept:* RELEASE checklist re-run; the Xcode privacy report matches the label.
- [ ] **T7.13 Phase B (about 30 days after launch, only if the ADS.md §3 gate passes).** AD-7 app open ad, AD-9 second Home card, AD-4 interval 8; set `adsPhase = B`. *Accept:* FR-ADS-08 and the Phase B tests in ADS.md §11.
- [ ] **T7.12 Regression.** R1–R26 on the Android emulator + one real Android phone; iOS once Xcode is set up.

**Order:** T7.1 → T7.2 → T7.5 → T7.6 → T7.3 → T7.4 → (T7.7 in parallel, any time) → T7.8 → T7.9 → T7.10 → T7.11 → T7.12; T7.13 later, as a separate update. The UI and tour come first, so the ads land on the final layouts.

## 8. Timeline impact
About 6–9 working days, plus 1–3 days of AdMob account review before real ads serve. New AdMob accounts often show limited ads at first; the app must look normal with no fill, which the collapse rules handle.

## 9. Prompts for Claude Code

**M0 — Merge the docs (run first)**
```
I've added docs/ADS.md, docs/TOUR.md, docs/UI_REFRESH.md, docs/mockups/ and CHANGES_v2.1.md.
Apply CHANGES_v2.1.md §3–§7 to the existing docs and CLAUDE.md. Merge into the current text rather than overwriting it: keep all my existing decisions, statuses and copy. Number the new ADRs with the next free ADR numbers and replace the placeholders (ADR-028, ADR-029, ADR-030, ADR-031, ADR-032) everywhere.
Show me a summary of every edit per file. Don't change any code.
```

**UI refresh (T7.1–T7.4, one at a time)**
```
Task T7.<n> from docs/TASKS.md. Follow docs/UI_REFRESH.md §<section> and match docs/mockups/DocuKit_v2.1_mockups.html.
Keep the existing gradient header, launch screen, icon, dark mode and tablet rail; restyle them rather than replacing them.
Use theme tokens only. Update the goldens. Check reduce-motion and 200% text.
List the planned file changes first; afterwards report the commands run and their results.
```

**Tour (T7.5–T7.6)**
```
Task T7.5 then T7.6. Implement the Home tour exactly per docs/TOUR.md (a custom overlay, not a package).
The steps are built from toolCatalog. Auto-start only after onboarding and the consent form have closed. Ads stay hidden during the tour.
Write the unit and widget tests in TOUR.md §6 first. Report what you verified on the emulator, including at a 320×568 size.
```

**Ads (T7.8–T7.9)**
```
Task T7.8 then T7.9. Implement ads per docs/ADS.md. Use Google's TEST ad unit IDs only; the real IDs come later via --dart-define.
Hard rules: only lib/core/ads/ imports google_mobile_ads; AdRequest carries no app data; ads only at AD-1…AD-6 plus the AD-8 rewarded offer (Phase B formats stay off); global caps per §4.4; slots collapse to zero height when there's no ad; interstitial rules per §4 (unit-test AdPolicy first).
Add the Android/iOS config (permissions, APPLICATION_ID, GADApplicationIdentifier, SKAdNetworkItems) and tell me exactly what I must paste from my AdMob account.
Verify that the method names you use exist in the pinned google_mobile_ads version (UMP APIs were renamed across versions); if unsure, say so.
Then run every tool in airplane mode and confirm nothing breaks.
```
