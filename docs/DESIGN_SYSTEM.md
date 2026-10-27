# DocuKit — Design System

Tone: **calm, trustworthy, utilitarian.** Like a good pocket knife: clear labels, big targets, real numbers, no hype. All values live in `lib/app/theme/tokens.dart`; widgets never hard-code colours or sizes.

> **v2.1:** the gradient tokens (`brandGradient`, `imageGradient`, `pdfGradient`, `successGradient`, `surfaceGlass`), the Plus Jakarta Sans heading font and sentence-case section headers are specified in `UI_REFRESH.md §1` (ADR-032). They extend the tokens below; nothing here is removed.

## 1. Colour tokens

Build both schemes with `ColorScheme.fromSeed(seedColor: Color(0xFF2F5BEA))`, then override the roles below. Contrast ratios were checked against the surface they sit on.

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#2F5BEA` (5.5:1 on white) | `#A9C1FF` | Primary buttons, links, selection |
| `onPrimary` | `#FFFFFF` | `#0A1F66` | Text/icons on primary |
| `primaryContainer` | `#DCE4FF` | `#1F3A9E` | Selected chips, Continue chip |
| `surface` | `#FBFBFE` | `#121318` | Screen background |
| `surfaceContainer` | `#F0F1F7` | `#1C1D24` | Cards, tool tiles |
| `surfaceContainerHigh` | `#E8E9F1` | `#24262E` | Bottom sheets, selection bar |
| `onSurface` | `#1A1B21` | `#E3E3EA` | Body text |
| `onSurfaceVariant` | `#4A4D5A` (8.2:1) | `#C2C5D3` | Secondary text, meta lines |
| `outlineVariant` | `#C9CBD6` | `#40434F` | Dividers, tile borders |
| `imageAccent` | `#00796B` | `#5FD3C3` | Image-tool icon tiles, category label |
| `pdfAccent` | `#C2410C` | `#FFA27A` | PDF-tool icon tiles, category label |
| `success` / `successContainer` | `#1B7F3B` / `#DDF5E3` | `#7FDB98` / `#123D20` | Done state, "Saved −87%" |
| `warning` / `warningContainer` | `#8A5A00` / `#FFF1D6` | `#FFC860` / `#3D2A00` | Alpha-loss, "result is larger" |
| `error` / `errorContainer` | `#B3261E` / `#F9DEDC` | `#F2B8B5` / `#601410` | Invalid badges, failures |
| `scrim` | `#000000` @ 32% | same | Behind sheets |
| `checkerboard` | `#E6E6E6`/`#FFFFFF` 8 dp squares | `#2A2A2A`/`#1E1E1E` | Behind transparent images |

Rules: colour is never the only signal (badges always have an icon + text); category accents appear only in icon tiles and category headers.

## 2. Typography

> **v2.1:** headings (`headlineSmall`, `titleLarge`, `titleMedium`, `displaySmall`) use **Plus Jakarta Sans** 600/700; body stays the system font (UI_REFRESH §1).


The system font: Roboto/Google Sans on Android (`fontFamily: null`), SF Pro on iOS (Flutter does this automatically). Material 3 type scale, with these assignments:

| Style | Size/line (sp) | Weight | Use |
|---|---|---|---|
| `headlineSmall` | 24/32 | 600 | Screen titles (large app bar), Result "Done" |
| `titleLarge` | 22/28 | 600 | App bar title |
| `titleMedium` | 16/24 | 600 | Card titles, tool names, section values |
| `labelLarge` | 14/20 | 600 | Buttons |
| `labelMedium` | 12/16 | 600, +0.5 letter-spacing, UPPERCASE | Section headers ("IMAGE TOOLS") |
| `bodyLarge` | 16/24 | 400 | Body, list primary |
| `bodyMedium` | 14/20 | 400 | Tool subtitles, meta lines |
| `bodySmall` | 12/16 | 400 | Helper text, captions |
| `displaySmall` (tabular figures) | 36/44 | 600 | SizeComparison numbers (`FontFeature.tabularFigures()`) |

Support a text scale up to 2.0. Layouts use `Wrap`/`Flexible`; no fixed-height text containers. File names use middle ellipsis (`IMG_2041…ressed.jpg`) via a `MiddleEllipsisText` helper.

## 3. Spacing, shape, elevation

- Spacing scale (dp): `4, 8, 12, 16, 20, 24, 32, 40, 48`. Screen padding is 16 (phone), 24 (≥ 600), and the content max width is 720, centred on tablets.
- Radii: `xs 4` (badges), `sm 8` (thumbnails), `md 12` (cards/tiles/text fields), `lg 16` (bottom sheets — top corners only), `full` (chips, FAB, segmented).
- Elevation: flat by default. Cards use `surfaceContainer` with no shadow; the sticky PrimaryActionBar uses elevation 3 + a `surface` tint; a dragged item uses elevation 6 + 1.04 scale.
- Touch targets ≥ 48×48 dp (iOS ≥ 44 pt is satisfied).

## 4. Iconography

Material Symbols **Rounded**, weight 400, grade 0, 24 dp (`material_symbols_icons` package, Apache-2.0 — add to the ARCHITECTURE table) or the built-in `Icons.*_rounded` to avoid a dependency.

| Tool | Icon |
|---|---|
| Image Compressor | `compress` / `photo_size_select_small` |
| Image Resizer | `aspect_ratio` |
| Images to PDF | `picture_as_pdf` |
| Merge PDFs | `call_merge` / `join` |
| Organize Pages | `grid_view` / `view_module` |
| Reduce PDF Size | `compress` with a PDF badge, or `folder_zip` |
| History | `history` · Settings `settings` · Privacy `shield_lock` / `lock` |

Tool icons sit in a 40 dp rounded-square (r 12) tile filled with the accent at 12% opacity, with the glyph in the accent colour.

## 5. Motion

| Interaction | Spec |
|---|---|
| Page transition | Android: Material `FadeForwardsPageTransitionsBuilder` (or the default predictive-back builder); iOS: `CupertinoPageTransitionsBuilder` (edge-swipe back) |
| Home search → Search | `Hero` on the search bar, 250 ms |
| Reorder drag | Lift 120 ms, scale 1.04, elevation 6; neighbours animate 200 ms `easeOutCubic` |
| Processing → Result | Cross-fade 200 ms + a success check scale-in 300 ms + `HapticFeedback.lightImpact()` |
| Size numbers on Result | Count-up 400 ms (disabled when reduce-motion is on) |
| Reduce motion | `MediaQuery.disableAnimations` → all durations 0 except fades ≤ 100 ms |

## 6. Component library (`lib/core/widgets/`)

| Component | Spec |
|---|---|
| `ToolScaffold` | App bar (back, title, info ⓘ), scrollable body with `SafeArea`, sticky `PrimaryActionBar`. Handles `PopScope` + D4 |
| `PrimaryActionBar` | Full-width `FilledButton` (height 52, r full) + optional helper/estimate line above; bottom padding = max(16, viewPadding.bottom) |
| `ToolCard` | 2-line card: icon tile, title (`titleMedium`), subtitle (`bodyMedium`, 2 lines max); min height 112; ripple; semantics label = title + subtitle |
| `SearchBarButton` | Looks like a `SearchBar`, acts as a button; placeholder rotates 3 examples every 4 s (static when reduce-motion is on) |
| `SectionHeader` | `labelMedium`, onSurfaceVariant, top padding 24, optional trailing action ("See all ›", "+ Add") |
| `InputsSection` | Empty state (`PickerDropCard`) or a `FileTile` list/grid; count in the header; "+ Add"; "Manage all ›" when > 6 |
| `PickerDropCard` | Dashed `outlineVariant` border (r 12), icon, "Choose images"/"Choose PDF", supported-formats line in `bodySmall` |
| `FileTile` | 72 dp row: drag handle (multi), 48 dp thumbnail (image) or PDF glyph, name (middle ellipsis), meta line, `StatusBadge`, overflow menu |
| `ImageThumbTile` | Square, r 8, number badge top-left, rotate button bottom-left, remove (✕) top-right with a 48 dp hit area |
| `PageThumbTile` | Aspect from the page size, r 4, white page bg + 1 dp outline, number below, a selection ring (3 dp primary) + check badge, rotation badge |
| `StatusBadge` | Variants: ok (none), warning (amber container + `warning_rounded`), invalid (error container + `block`), locked (🔒 `lock`). Text is always present |
| `OptionGroup` | Title + control (SegmentedButton / Slider with value label / Dropdown via `DropdownMenu` / Switch.adaptive) + helper |
| `QualitySlider` | 10–100 step 5; end labels "Smaller file" / "Sharper"; value bubble; semantics value "Quality 80 percent" |
| `DimensionFields` | Two numeric `TextField`s with a link toggle between them (`IconButton.filledTonal` `link`/`link_off`); inline errors |
| `SizeComparison` | 3 columns: Before / After / Change; Change coloured success (smaller) or warning (larger); tabular figures |
| `ResultPreview` | Image: `InteractiveViewer` + before/after split slider (`CompareSlider`); PDF: first page render + page count chip |
| `InlineBanner` | Info/warning/error; icon, text, up to 2 text-button actions; dismissible where noted |
| `EmptyHint` | Icon 48, title, body, optional action |
| `ProgressRing` | `CircularProgressIndicator.adaptive` 72 dp, determinate when known; label below |
| `ConfirmDialog`, `RenameDialog`, `UnsavedWorkDialog` | D2/D3/D4 via `showAdaptiveDialog` |
| `AppSnack` | Floating `SnackBar`, 4 s, optional Undo |
| `NativeAdSlot` (v2.1) | Loads a native ad (small/medium template), renders it as an **outlined card with an "Ad" badge**, muted background and no gradient tile, so it can never be mistaken for a tool card; collapses to zero height on no fill / offline / ads removed (ADS.md §3, §7; UI_REFRESH §3) |
| `BannerAdSlot` (v2.1) | Anchored adaptive banner outside the scroll view, with reserved space; collapses to zero height when there's no ad (AD-5) |
| `TourOverlay` (v2.1) | Scrim (black 60%, dark 70%) with an RRect spotlight hole + 2 dp `primary` ring, tooltip card (`surfaceContainerHigh`, r 16, max width 360), progress text + dots, Skip/Back/Try it/Next; focus-trapped (TOUR.md §3–4) |
| `QuickActionChip` (v2.1) | Shortcut chip on Home: icon + label, opens a tool route with prefill query params (UI_REFRESH §2.1) |
| `SavingsRing` (v2.1) | Donut of after/before with a `successGradient` arc and the big "−87%" in the centre (count-up 500 ms, off with reduce-motion) (UI_REFRESH §6) |

## 7. Layout breakpoints

| Width | Layout |
|---|---|
| < 600 dp (compact) | Single column, app-bar icons for History/Settings, 2-col tool grid, 3-col thumbnail grids |
| 600–839 (medium) | 3-col tool grid, 4-col thumbnails, content max 720 |
| ≥ 840 (expanded) | `NavigationRail` + content; tool screens split: inputs on the left, options on the right; 5–6 col thumbnails |

## 8. Platform adaptation (one widget tree)

| Element | Android | iOS |
|---|---|---|
| Back | Predictive back (`PopScope`) | Edge-swipe back via Cupertino transitions; disabled only when D4 must intercept |
| Dialogs | Material `AlertDialog` | `CupertinoAlertDialog` via `showAdaptiveDialog` |
| Switches / progress | Material | `.adaptive` constructors |
| Bottom sheets | `showModalBottomSheet(showDragHandle: true, useSafeArea: true)` | Same (feels native with a drag handle) |
| Haptics | `HapticFeedback` light on success/reorder drop | same |
| Share/Save | System UI | System UI (iPad popover anchors required) |
| Status bar | Edge-to-edge (`SystemUiMode.edgeToEdge`); transparent nav bar | Default |
| Scroll physics | Clamping | Bouncing (automatic) |

## 9. Accessibility checklist (per screen)
- Every icon-only button has a `tooltip` (= semantics label).
- Reorder has a non-drag path (`Move to…`), and custom semantics actions on tiles: "Move up", "Move down", "Rotate", "Remove".
- Thumbnails: semantics "Page 3 of 24, rotated 90 degrees, selected".
- Live regions: progress (throttled), result summary ("Done. 3.2 megabytes to 410 kilobytes, 87 percent smaller").
- Sizes are read in words ("410 kilobytes"), not "KB" — use a semantics-specific formatter.
- Contrast: all text ≥ 4.5:1, large text/graphics ≥ 3:1, in both themes.
- Focus order follows the visual order; the PrimaryActionBar is last.
- Test with TalkBack, VoiceOver, Switch Access, and 200% font on the smallest phone.

## 10. App icon and store art (brief)
- Glyph: a folded-corner document with a small "spark"/wrench cutout; the primary colour on white (light) / a deep navy background. Must read at 48 px.
- Android: an adaptive icon (foreground 108 dp with a 66 dp safe zone) + a monochrome layer (themed icons). iOS: 1024×1024 without transparency; provide the iOS 18+ dark and tinted variants.
- Screenshots: 6 frames — Home, Compressor with a before/after, Resizer passport preset, Image→PDF grid, Organizer, Privacy promise. Captions ≤ 5 words each.
