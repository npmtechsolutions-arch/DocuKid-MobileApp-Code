# DocuKit — Home Tour Specification (v2.1)

A short, skippable spotlight tour on Home that introduces every tool. It runs once after onboarding and can be replayed at any time.

## 1. Requirements

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-TOUR-01 | P0 | Auto-start once for new users | Starts 600 ms after Home's first frame when `tour_done == false`, **after** onboarding and the consent form (if any) have closed. Never starts while a dialog/sheet is open |
| FR-TOUR-02 | P0 | Explain every tool | One step per tool (6), each with a title, what it does and a real example |
| FR-TOUR-03 | P0 | Always skippable | "Skip" is visible on every step; Android back on step 1 or the intro = skip; skip sets `tour_done = true` |
| FR-TOUR-04 | P0 | Back/Next navigation with progress | "Step 3 of 10" text + dots; Back is hidden on the first step; the last step's button reads "Done" |
| FR-TOUR-05 | P0 | Replay | Home app bar **help (?)** icon and Settings → "Take the tour" restart it from step 1 |
| FR-TOUR-06 | P0 | Targets always visible | Off-screen targets are scrolled into view (`Scrollable.ensureVisible`, alignment 0.35, 300 ms) before the spotlight moves |
| FR-TOUR-07 | P0 | Accessible | The tooltip is a focus-trapped modal; on each step the screen reader announces "Step n of 10. {title}. {body}"; all buttons ≥ 48 dp; reduce-motion → no animations; text scales to 200% (the tooltip grows, and the spotlight adapts) |
| FR-TOUR-08 | P0 | No interference | No ads while the tour is open (AD-1 is hidden until `tour_done`); taps on the scrim do nothing (no accidental tool launches); rotation/resize re-measures the target |
| FR-TOUR-09 | P1 | "Try it" on tool steps | A secondary "Try it" button on each tool step ends the tour (`tour_done = true`) and opens that tool |
| FR-TOUR-10 | P1 | Versioned "What's new" | `tour_version` int. When a release adds tools, existing users see only the new steps (titled "New in DocuKit") once |

## 2. Steps

| # | Target (GlobalKey) | Title | Body | Example line |
|---|---|---|---|---|
| 0 | — (centred card, no spotlight) | Quick tour | See what DocuKit can do in about 30 seconds. | [Start tour] [Skip] |
| 1 | `tourKeySearch` (search bar) | Search in plain words | Type what you need, like "make photo smaller" or "join PDFs". | — |
| 2 | `tourKeyTool.imageCompress` | Image Compressor | Make photos smaller. Pick a quality, or set a limit like "under 100 KB". | Great for job and exam portals with upload limits. |
| 3 | `tourKeyTool.imageResize` | Image Resizer | Set an exact size in pixels or percent, or use a preset. | Passport photo 413×531 or a signature at 140×60. |
| 4 | `tourKeyTool.imageToPdf` | Images to PDF | Turn several photos into one PDF, in the order you choose. | Notes, receipts or certificates in one file. |
| 5 | `tourKeyTool.pdfMerge` | Merge PDFs | Combine several PDFs into one. Drag to set the order. | Put a cover letter and CV together. |
| 6 | `tourKeyTool.pdfOrganize` | Organize Pages | Reorder, rotate or delete pages, then save a new copy. | Fix a sideways scan or remove a blank page. |
| 7 | `tourKeyTool.pdfCompress` | Reduce PDF Size | Make a PDF smaller for email, with clear choices about quality. | Get under a 10 MB email limit. |
| 8 | `tourKeyRecent` (Recent section; if empty, its empty hint) | Your recent files | Finished files appear here for 7 days, so you can save or share them again. | — |
| 9 | `tourKeyAppBarActions` (History + Settings icons; on tablets, the rail) | History and settings | See everything you've made, and set your favourite defaults. | — |
| 10 | — (centred card) | You're all set | Your files never leave your phone, and originals are never changed. Tap any tool to start. | [Done] |

The "7 days" in step 8 follows the retention setting (`{period}` placeholder). The tool order matches `toolCatalog`, so build the tool steps **from the catalogue** — a new tool automatically gets a step (its `tourTitle`, `tourBody`, `tourExample` added to `ToolDescriptor`).

## 3. Visual design

```
┌──────────────────────────────────────┐
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  scrim: black 60% (dark theme 70%)
│▓▓▓▓ ╭───────────────╮ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  spotlight: target rect + 8 dp padding,
│▓▓▓▓ │ ↔ Resize       │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  radius = target radius + 4,
│▓▓▓▓ │ Set exact size │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  2 dp primary ring + soft glow (pulse once)
│▓▓▓▓ ╰───────────────╯ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓     ▲                ▓▓▓▓▓▓▓▓▓▓▓▓│  arrow nub points to the target
│ ┌──────────────────────────────────┐ │  Tooltip card: surfaceContainerHigh, r 16,
│ │ STEP 3 OF 10              Skip   │ │  max width 360, 16 dp from the screen edges
│ │ Image Resizer                    │ │  titleMedium
│ │ Set an exact size in pixels or   │ │  bodyMedium
│ │ percent, or use a preset.        │ │
│ │ 💡 Passport photo 413×531 or a   │ │  example: bodySmall on primaryContainer chip
│ │    signature at 140×60.          │ │
│ │ ● ● ● ○ ○ ○ ○ ○ ○ ○              │ │  progress dots (decorative; text is the a11y source)
│ │ [Back]        [Try it] [ Next ]  │ │  Next = FilledButton; Try it = TextButton (P1)
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```
- Placement: below the target if there's ≥ 220 dp of space under it, otherwise above; never covering the target.
- Motion: the spotlight morphs between targets (rect tween, 280 ms `easeInOutCubic`); the tooltip fades/slides 8 dp; with reduce-motion, both jump.
- Colours: use the theme tokens; the spotlight ring is `primary`; it must read in light and dark.

## 4. Implementation

**Recommended: a small custom overlay** (about 250 lines, no dependency) rather than a package. The tool cards live in a scrollable grid, which showcase packages handle poorly (their auto-scroll is documented as unreliable in lazy lists), and a custom overlay gives full control over a11y, skip/back, and the "Try it" action. Alternative: `showcaseview` 5.x (MIT, simform) — its API changed in v5 (`ShowcaseView.register`), so verify it against the pinned version.

```
lib/features/tour/
  tour_step.dart          // TourStep { GlobalKey? target; String Function(l10n) title, body, example?; ToolId? tryTool }
  tour_steps.dart         // buildHomeTourSteps(catalog, l10n, retention) → List<TourStep>
  tour_controller.dart    // Notifier<TourState { int index; bool active; }> next/back/skip/finish/start
  tour_overlay.dart       // OverlayEntry: CustomPainter scrim with an RRect hole (Path.combine difference), tooltip, focus trap
  tour_targets.dart       // the GlobalKeys, provided via a Riverpod provider so Home can attach them
```
Flow:
```
start():  active = true; index = 0; hide AD-1
goTo(i):  target = steps[i].target
          if target != null: await Scrollable.ensureVisible(target.currentContext!, alignment: .35, duration: 300ms)
          await endOfFrame; rect = (target.currentContext!.findRenderObject() as RenderBox).localToGlobal(...)
          animate the spotlight to rect; SemanticsService.announce(...)
finish/skip: active = false; prefs.tour_done = true; prefs.tour_version = currentTourVersion; show AD-1 on the next build
```
- Re-measure on `didChangeMetrics` (rotation, keyboard, split-screen).
- If a target's context is null (e.g. the Recent section isn't built), skip that step silently.
- Wrap the overlay in `PopScope` → back = the previous step (or skip on step 0/1).
- Keep `tour_done` in `SettingsRepository`. Add `tour_done` (bool, false), `tour_version` (int, 0) to ARCHITECTURE §8.1.

## 5. Copy (add to COPY.md §2)

| Key | Text |
|---|---|
| tour_intro_title / body | Quick tour / See what DocuKit can do in about 30 seconds. |
| tour_start / skip / next / back / done / try | Start tour / Skip / Next / Back / Done / Try it |
| tour_progress | Step {n} of {total} |
| tour_search_title / body | Search in plain words / Type what you need, like "make photo smaller" or "join PDFs". |
| tour_<tool>_title / body / example | (from §2, one set per tool) |
| tour_recent_title / body | Your recent files / Finished files appear here for {period}, so you can save or share them again. |
| tour_nav_title / body | History and settings / See everything you've made, and set your favourite defaults. |
| tour_done_title / body | You're all set / Your files never leave your phone, and originals are never changed. Tap any tool to start. |
| tour_whats_new | New in DocuKit |
| home_help_tooltip | Take the tour |
| set_take_tour | Take the tour |
| a11y_tour_step | Step {n} of {total}. {title}. {body} |

## 6. Tests

| Test | Type |
|---|---|
| The steps are built from the catalogue: 6 tool steps, in catalogue order | Unit |
| Controller: next/back bounds, skip sets `tour_done`, finish sets `tour_version` | Unit |
| Auto-start only when `tour_done == false`, and not before onboarding/consent close | Widget |
| Scrim taps don't open tools; Skip on every step; Android back behaviour | Widget |
| A tool card below the fold is scrolled into view before its step | Widget (small screen size 320×568) |
| 200% text: the tooltip doesn't overflow; buttons stay reachable | Widget |
| TalkBack/VoiceOver: step announcement, focus trapped in the tooltip | Manual |
| AD-1 hidden during the tour and shown after | Widget (fake AdsService) |
