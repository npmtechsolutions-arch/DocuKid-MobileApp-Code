# DocuKit — UI Refresh (v2.1)

Goal: make DocuKit feel **friendly and polished** without slowing anyone down. This builds on what's already in the app (the gradient Home header, balanced tool cards, branded launch screen, new icon, dark mode, tablet rail): **keep those**, and apply the changes below on top. Every change uses the design tokens; nothing hard-coded. See `mockups/` for the visual reference.

## 1. Brand upgrades (tokens)

| Token | Light | Dark | Use |
|---|---|---|---|
| `brandGradient` | `#2F5BEA → #6A4CFF` (135°) | `#3D5BD9 → #6B53E8` | Home hero, the Result success header, primary-button pressed glow |
| `imageGradient` | `#00897B → #26C6DA` | `#1E9E8F → #3BB8C9` | Image-tool icon tiles |
| `pdfGradient` | `#E8590C → #F0437A` | `#E2702E → #E8578A` | PDF-tool icon tiles |
| `scanGradient` (1.2) | `#0E7490 → #22B8CF` | `#2399B0 → #48C6D8` | Scan & Text tool icon tiles (FULL_PRODUCT §4.5) |
| `secureGradient` (1.4) | `#7C3AED → #C026D3` | `#8B5CF6 → #D04BDF` | Secure & Sign tool icon tiles |
| `libraryGradient` (1.5) | `#334155 → #64748B` | `#5B6B80 → #8A97A8` | My Documents card and library screens |
| `successGradient` | `#1B9E4B → #4CC38A` | same, at 85% opacity | Savings ring, the celebration check |
| `surfaceGlass` | white @ 14% + 1 dp white @ 24% border | white @ 8% | Chips and the search bar on top of gradients |

**Section headers:** switch from UPPERCASE `labelMedium` to sentence-case `titleSmall` (Plus Jakarta Sans 600, `onSurface`), e.g. "Image tools". It reads friendlier and is easier on screen readers.

**Typography:** headings use **Plus Jakarta Sans** (SIL OFL, bundled as assets: SemiBold 600 + Bold 700 only, ≈ 180 KB); body stays the system font. Apply it to `headlineSmall`, `titleLarge`, `titleMedium` and `displaySmall` in `typography.dart`. Add it to the licences page.

Check contrast: white text on `brandGradient` ≥ 4.5:1 at the lightest stop (`#6A4CFF` with white ≈ 5.1:1 ✓).

**v3 category gradients (scan, secure, library):** check white-on-gradient contrast ≥ 4.5:1 at the lightest stop in T8.1 and adjust the lightest stop if it fails (same approach as ADR-033). Expect `#22B8CF` and `#48C6D8` to need darkening; record any change as an ADR and in the contrast test.

## 2. Home (S01)

```
┌──────────────────────────────────────┐
│░░ brandGradient hero (rounded bottom 28 dp) ░░│
│ Good evening 👋               ?  🕘  ⚙︎ │  greeting by local time; help (tour) icon added
│ What do you want to do today?        │  headlineSmall, white
│ ┌──────────────────────────────────┐ │
│ │ 🔍 Search tools…                  │ │  surfaceGlass search bar
│ └──────────────────────────────────┘ │
│ ✨ You've saved 48.2 MB so far        │  savings chip (hidden until the first job; local counter)
├──────────────────────────────────────┤
│ Quick actions                         │  horizontal scroll of shortcut chips
│ [🪪 Passport photo] [📉 Under 100 KB] │  each = a tool + preset options (see §2.1)
│ [🖼→📄 Photos to PDF] [⊕ Merge PDFs]   │
│ Image tools                           │
│ ┌──────────┐ ┌──────────┐            │  ToolCard v2 (see §3)
│ │ ▣ grad   │ │ ▣ grad   │            │
│ │ Compress │ │ Resize   │            │
│ │ Make pho…│ │ Exact si…│            │
│ └──────────┘ └──────────┘            │
│ ...                                   │
│ PDF tools                             │
│ ...                                   │
│ ┌─ Ad ──────────────────────────────┐ │  AD-1 (outlined, different from tool cards)
│ └───────────────────────────────────┘ │
│ Recent                      See all › │
│ 🔒 Files never leave your phone       │
└──────────────────────────────────────┘
```

### 2.1 Quick actions (new; deep links with preset options)
| Chip | Opens | Prefill |
|---|---|---|
| Passport photo | `/tool/image-resize?preset=passport` | Preset Passport, fit = Fit with border (white) |
| Under 100 KB | `/tool/image-compress?target=102400` | Target-size mode, 100 KB |
| Signature | `/tool/image-resize?preset=signature` | Preset Signature |
| Photos to PDF | `/tool/image-to-pdf` | Defaults |
| Merge PDFs | `/tool/pdf-merge` | Defaults |
| Email-size PDF | `/tool/pdf-compress?level=balanced` | Balanced |

Define them in `features/home/quick_actions.dart` (list of `{labelKey, icon, route, query}`). The tool screens read the query params alongside `?from=history`.

### 2.2 Savings counter (new, local only)
`stats_total_saved_bytes` (int) in settings, increased on every successful job where output < input (by input − output). Shown as "You've saved {size} so far"; hidden when 0. It's also the subject of a count-up animation the first time it appears in a session.

### 2.3 Entrance
On the first Home build per launch: the tool cards fade + slide up 12 dp, staggered 40 ms (total ≤ 400 ms). Skipped with reduce-motion. Never replays on back navigation.

## 3. ToolCard v2

```
┌───────────────────────────┐
│ ╭────╮                  › │  56 dp gradient icon tile (r 16) with a white glyph
│ │ ▣  │                    │  + a soft shadow tinted by the category colour (y 6, blur 16, 25%)
│ ╰────╯                    │
│ Image Compressor          │  titleMedium (Plus Jakarta Sans 600)
│ Make photos smaller       │  bodyMedium, onSurfaceVariant, 2 lines
│ JPG · PNG · HEIC          │  bodySmall chip row (formats) — optional third line
└───────────────────────────┘
```
- Background `surfaceContainer`, r 20, 1 dp `outlineVariant` @ 60%; min height 136.
- Press: scale 0.97 (100 ms) + ripple; release springs back; light haptic.
- Ad cards (AD-1/AD-4) **must look different**: outlined with no gradient tile, an "Ad" badge top-left, and a muted background, so they're never confused with tools (it's both a policy and a trust requirement).

## 4. Tool screens

- Header: a compact gradient strip (category gradient, 4 dp) under the app bar, plus the tool's icon tile next to the title.
- Empty picker card: a large illustration (a simple vector drawn with `CustomPainter` or one SVG per category), with the dashed border animating subtly once (reduce-motion → static).
- Option groups become **cards** (r 16) with a small leading icon per group (`tune`, `straighten`, `description`), instead of bare sections.
- The quality slider gets a live hint under it: "Smaller ←→ Sharper" plus the **estimated size** after the first real encode (the target-size search already gives it; label "≈ 420 KB", updated with a 400 ms debounce, P1).
- Sticky button: a full-width pill with a gradient fill (`brandGradient`); disabled = `surfaceContainerHigh` with a helper text.

## 5. Processing (S10)
- Replace the bare ring with a **per-tool animated glyph** inside the ring (e.g. arrows squeezing for Compress, pages stacking for Merge), built with `AnimatedBuilder` + Icons (no Lottie dependency).
- Below the progress text, a rotating **tip card** (every 5 s, fade): "Tip: Use Target size to hit upload limits exactly." Tips are keys `tip_1…tip_8` in COPY; static with reduce-motion.

## 6. Result (S11)
- Success header: `brandGradient` band with an animated check (scale + stroke draw, 400 ms) and a light haptic.
- **Savings ring:** a donut showing after/before (successGradient arc) with the big "−87%" in the centre (count-up 500 ms), and the Before/After sizes beside it.
- **Celebration** (subtle confetti burst, 1.2 s, about 24 particles, `CustomPainter`) only when savings ≥ 50% and reduce-motion is off; at most once per session.
- The action buttons become a 2×2 grid of large tonal buttons with icons (Save, Share, Open with, Edit options).
- AD-2 sits below, with the divider and "Sponsored" label (ADS.md).

## 7. Empty states and illustrations
One illustration style: flat, two-tone (category accent + `surfaceContainerHigh`), rounded shapes. Needed for: Home recent (empty), History empty, Picker card (image / PDF), Error (generic), Onboarding. Deliver them as SVG (`flutter_svg`, MIT — add it to the stack) or draw them with `CustomPainter` to avoid the dependency.

## 8. Motion and haptics summary

| Moment | Animation | Haptic |
|---|---|---|
| Card press | Scale 0.97 | light |
| Reorder drop | Settle 200 ms | selection click |
| Job success | Check draw + count-up | light impact |
| Delete page | Collapse 180 ms | light |
| Tour step change | Spotlight morph 280 ms | — |
All are disabled or shortened under `MediaQuery.disableAnimations`.

## 9. Acceptance (UI-REF-*)

| ID | Criterion |
|---|---|
| UI-REF-01 | Golden tests updated for Home, a tool screen, Processing and Result in light/dark, at compact and expanded widths |
| UI-REF-02 | No frame > 16 ms during the Home entrance or Result celebration on the low-end Android device (profile mode) |
| UI-REF-03 | All text contrast ≥ 4.5:1, including on gradients |
| UI-REF-04 | Reduce-motion turns off the entrance, confetti, count-ups and tip rotation |
| UI-REF-05 | Ad cards are visually distinct from tool cards (a reviewer can tell them apart in a screenshot) |
| UI-REF-06 | App size grows by < 600 KB (font + illustrations) |
