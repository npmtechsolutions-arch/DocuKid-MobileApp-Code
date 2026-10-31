# DocuKit 1.4 — Secure & Sign (Sign PDF, Watermark PDF, Protect PDF, Unlock PDF)

> Milestone **M11** · Tasks **T11.x** · Screens **S33–S38** · Regression **R49–R58** · ADRs **ADR-048–053** (DECISIONS.md).
> Read `docs/FULL_PRODUCT.md` §4 first. Every rule in `CLAUDE.md` still applies.

---

## 1. Summary & scope

Version 1.4 adds a fourth Home category, **Secure & Sign** (category `secure`), with four tools:

| Tool | ToolId | Route | One line |
|---|---|---|---|
| Sign PDF | `pdfSign` | `/tool/pdf-sign` | Draw, type or photograph a signature and place it on pages |
| Watermark PDF | `pdfWatermark` | `/tool/pdf-watermark` | Stamp text or an image on pages, with position, size, opacity and page choice |
| Protect PDF | `pdfProtect` | `/tool/pdf-protect` | Add an open password (AES-256) |
| Unlock PDF | `pdfUnlock` | `/tool/pdf-unlock` | Remove a password **you know** |

Two shared engines are introduced and owned by this release:
- **`PdfStamper`** (`lib/core/pdf/pdf_stamper.dart`): adds image page objects to existing pages through PDFium FFI. It extends the FFI layer the Balanced reducer already uses. Sign and Watermark use it; v1.3 OCR may reuse it.
- **`PdfSecurity`** (`lib/core/pdf/pdf_security.dart`): encrypts and decrypts through native code (iOS PDFKit, Android PdfBox-Android), with a PDFium path for Unlock where possible.

### In scope
- All four tools, end to end, on Android and iOS, with validation, history, Result, Save/Share, and ads per §4.4.
- Up to 3 saved signatures (opt-in).
- "Unlock it first" routing: other tools that hit an encrypted PDF now link to Unlock PDF.
- Updated search synonyms, tour steps (`tour_version` + 1) and Home section.

### Out of scope (say so in help text)
- **Certified digital signatures** (cryptographic, certificate-based, PAdES). DocuKit's signature is a **visual** signature: an image on the page.
- Watermark **behind** the content. Watermarks are always drawn on top.
- Owner-permission editing (print/copy restrictions as a separate feature). Protect sets them to "allow all" (§4.5).
- Removing a password without knowing it. **Never.** No bypass, no brute force, no "recovery".
- Editing or removing existing watermarks or signatures.

---

## 2. Requirements

Priority: **P0** must ship in 1.4 · **P1** should · **P2** later.

### 2.1 Sign PDF (FR-SIG)

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-SIG-01 | P0 | Pick one PDF | Encrypted → "Unlock it first" banner with an **Unlock PDF** button; damaged → corruptFile copy |
| FR-SIG-02 | P0 | Draw a signature | Pad (S34) with smooth strokes (quadratic smoothing over the touch points), colour black / blue, thickness thin / medium / thick, Undo stroke, Clear; "Done" disabled while empty |
| FR-SIG-03 | P0 | Type a signature | Name field + 3 handwriting-style OFL fonts shown as live previews; colour choice; rendered to a transparent PNG |
| FR-SIG-04 | P1 | Photo of a signature | Pick an image → auto background removal (threshold to transparent; slider "Background cleanup" 0–100, default 55), crop to the ink, preview on a checkerboard |
| FR-SIG-05 | P0 | Place a signature | Placement editor (S35): page view + thumbnail strip, drag / pinch-resize / rotate (snaps at 0°, ±90°), stays inside the page; at least one placement needed before Save |
| FR-SIG-06 | P0 | Multiple placements | Add the same or another signature to any number of pages; "Add to all pages" / "Add to pages…" (range) duplicates the current placement at the same relative position |
| FR-SIG-07 | P1 | Date / text / initials stamps | Add a date stamp (locale format, today, editable), a free-text stamp, or initials (typed) as further placements |
| FR-SIG-08 | P0 | Undo/redo in the editor | ≥ 30 steps (add, move, resize, rotate, delete placement) |
| FR-SIG-09 | P0 | Correct output | The placed image appears at the same visual position and size, relative to the page, as in the editor on every page rotation (0/90/180/270) and with non-zero crop boxes; tolerance ±1 pt |
| FR-SIG-10 | P0 | Saved signatures (opt-in) | After creating one: "Save this signature for next time?" [Save] [Not now]; default is **not** saved; max 3; deletable from the picker sheet and from Settings → Saved signatures |
| FR-SIG-11 | P0 | Honest labelling | The ⓘ sheet and S33 footer say: "This adds an image of your signature. It isn't a certified digital signature." |
| FR-SIG-12 | P0 | Preserve the original | The output is a new file; the source checksum is unchanged |

### 2.2 Watermark PDF (FR-WMK)

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-WMK-01 | P0 | Pick one PDF | Same encrypted/damaged handling as FR-SIG-01 |
| FR-WMK-02 | P0 | Text watermark | Text ≤ 60 chars, any script (rendered to an image via Flutter so Hindi, Arabic, CJK etc. work without font embedding), colour (6 presets + custom), bold toggle |
| FR-WMK-03 | P0 | Image watermark | Pick a PNG/JPG (e.g. a logo); PNG transparency is kept |
| FR-WMK-04 | P0 | Position presets | Centre diagonal (default for text, −35°), centre, tile (3×4 grid, diagonal), top-left, top-right, bottom-left, bottom-right |
| FR-WMK-05 | P0 | Size, opacity, rotation | Size 10–100% of the page's short side (default 60% text / 30% image); opacity 10–80% (default 25%); rotation −90°…+90° (preset-specific defaults) |
| FR-WMK-06 | P0 | Pages | All (default) / range ("1-3, 5, 8-10", validated) / odd / even |
| FR-WMK-07 | P0 | Live preview | Preview of the selected page updates within 150 ms of a change; a swipeable page strip |
| FR-WMK-08 | P0 | On top only | Helper text: "The watermark is added on top of the page." No "behind" option |
| FR-WMK-09 | P0 | Correct output | Matches the preview position on rotated/cropped pages (±1 pt); opacity applied (verified by rendering) |
| FR-WMK-10 | P1 | Save watermark preset | Remember the last used text/style (not images) in settings |

### 2.3 Protect PDF (FR-PRT)

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-PRT-01 | P0 | Pick one PDF | An already-encrypted PDF → "This PDF already has a password." [Unlock PDF] |
| FR-PRT-02 | P0 | Password entry | Password + Confirm fields, masked, show/hide toggle, no autocorrect/suggestions/autofill-save prompts (`autofillHints: null`, `enableSuggestions: false`, `autocorrect: false`); min 6 chars, max 64 **and ≤ 127 UTF-8 bytes** (ADR-049, T11.3); mismatch error inline |
| FR-PRT-03 | P0 | Strength hint | Weak / OK / Strong from length + character classes (T11.3: weak < 8 characters or one kind; strong ≥ 12 characters and ≥ 3 kinds; kinds = lowercase, uppercase, digits, everything else); weak is allowed after an extra confirm |
| FR-PRT-04 | P0 | Can't-recover warning | Above the button, always visible: "If you forget this password, nobody can open the file — DocuKit can't recover it." |
| FR-PRT-05 | P0 | AES-256 encryption | Open (user) password = the entered one; owner password = random 32-byte value, never shown or stored; permissions = all allowed |
| FR-PRT-06 | P0 | Validate | The output: (a) **fails** to open without a password (pdfrx password exception), (b) opens with the password, (c) page count equals the input's. Only then success |
| FR-PRT-07 | P0 | Password hygiene | The password is never stored, logged, put in history `optionsJson`, put in the draft/restore state, or kept after the job ends (cleared from controller state on Result/Cancel/Error) |
| FR-PRT-08 | P0 | Preserve the original | The source is unchanged; the output name defaults to `<base>_protected.pdf` |

### 2.4 Unlock PDF (FR-UNL)

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-UNL-01 | P0 | Pick one PDF | Not encrypted → "This PDF doesn't have a password." (button disabled) |
| FR-UNL-02 | P0 | Enter the password | One masked field with show/hide; Unlock enabled when non-empty |
| FR-UNL-03 | P0 | Wrong password | Inline error "That password didn't work. Check it and try again." The field stays filled, so the user can correct it. No lockout, no delay, no counter |
| FR-UNL-04 | P0 | No bypass, ever | No code path removes security without a correct password; no guessing, dictionary or retries generated by the app |
| FR-UNL-05 | P0 | Owner-only PDFs | PDFs that open without a password but carry restrictions: "This PDF opens without a password. It has restrictions set by its creator, which DocuKit keeps." No removal offered |
| FR-UNL-06 | P0 | Validate | The output opens **without** a password, the page count matches, and the first page renders |
| FR-UNL-07 | P0 | Hygiene | Same as FR-PRT-07 |
| FR-UNL-08 | P0 | "Unlock it first" routing | Every other tool that rejects an encrypted PDF (FR-PDF-ENC) shows **Unlock PDF** as its primary action, opening `/tool/pdf-unlock` with that file pre-loaded |

### 2.5 Cross-cutting

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-SEC-01 | P0 | Home section "Secure & Sign" | Four tool cards with the `secure` gradient (`#7C3AED → #C026D3`); search synonyms per §4.9 |
| FR-SEC-02 | P0 | Tour | New steps for the category (`tour_version` + 1, "New in DocuKit" for existing users) |
| FR-SEC-03 | P0 | Ads | Option screens S33, S36, S37, S38: `ADMOB_BANNER_TOOLS` with the 24 dp gap. **No ads** on S34 (signature pad), S35 (placement editor) or the password fields' focus state (banner hidden while the keyboard is open, as already implemented) |
| FR-SEC-04 | P0 | History | Entries record the tool, sizes and page count; for Sign/Watermark also the number of placements / page selection. **Never** passwords or signature images |

---

## 3. Screens

All option screens use `ToolScaffold`, `InputsSection` (single PDF) and `PrimaryActionBar`, plus the bottom banner (`ADMOB_BANNER_TOOLS`) with the 24 dp gap and divider.

### S33 · Sign PDF (`/tool/pdf-sign`)

```
┌──────────────────────────────────────┐
│ ←  Sign PDF                     ⓘ    │
├──────────────────────────────────────┤
│ File                                  │
│ 📄 lease_agreement.pdf · 6 pages      │
│                              [Change]│
│ Your signature                        │
│ ┌──────────┐ ┌──────────┐ ┌────────┐ │  saved signatures (if any), max 3
│ │ ~Neha P~ │ │ ~N.P.~   │ │  + New │ │  tap = use · long-press = delete (D2)
│ └──────────┘ └──────────┘ └────────┘ │
│ ( Draw ) ( Type ) ( Photo )           │  creation entry points → S34
│                                       │
│ ⓘ This adds an image of your          │
│   signature. It isn't a certified     │
│   digital signature.                  │
├──────────────────────────────────────┤
│ [   Place signature on pages   ]      │  → S35 (enabled when a file + signature exist)
│ ─────────── 24 dp + divider ───────── │
│ [ Test Ad banner (Tools) ]            │
└──────────────────────────────────────┘
```
States: no file (picker card); file encrypted (red badge + **Unlock PDF** button); no signature yet (only Draw/Type/Photo); signature chosen (selected ring on its tile).

### S34 · Signature pad / creator (`/tool/pdf-sign/create?mode=draw|type|photo`), full screen, **no ads**

```
Draw mode                                   Type mode
┌──────────────────────────────────────┐   ┌──────────────────────────────────────┐
│ ✕  Draw signature        Undo  Clear │   │ ✕  Type signature                    │
├──────────────────────────────────────┤   │ Your name [ Neha Patel           ]   │
│                                      │   │ ○ Neha Patel   (font 1 preview)      │
│        (white pad, baseline line)    │   │ ● Neha Patel   (font 2 preview)      │
│     ~~~~ ink strokes ~~~~            │   │ ○ Neha Patel   (font 3 preview)      │
│ ─────────────────────────────────    │   │ Colour  ● Black  ○ Blue              │
│ Colour ● ○   Thickness ▁ ▂ ▃         │   │                                      │
├──────────────────────────────────────┤   │ [            Done            ]       │
│ [            Done            ]       │   └──────────────────────────────────────┘
└──────────────────────────────────────┘
Photo mode: picked image on a checkerboard, a "Background cleanup" slider, crop handles, [Done]
```
- On phones, draw mode **suggests landscape** ("Turn your phone for more room") but works in portrait too.
- Done → crops to the ink bounds + 8 px padding → PNG (transparent) → the "Save this signature for next time?" sheet (FR-SIG-10) → back to S33 with it selected.
- Back with ink → D4 "Discard this signature?".
- A11y: the pad has the semantics label "Signature pad. Draw with one finger." Typed mode is the accessible alternative and is mentioned in that label.

### S35 · Placement editor (`/tool/pdf-sign/place`), full screen, **no ads**

```
┌──────────────────────────────────────┐
│ ✕  Place signature     ↶ ↷   [Save]  │  Save = run the job
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │        page 3 rendered           │ │  pinch-zoom on the page (two fingers)
│ │                                  │ │
│ │          ┌──────────────┐ ⟳      │ │  placement: drag body, corner handle = resize
│ │          │ ~Neha Patel~ │        │ │  (keeps aspect), ⟳ handle = rotate, ✕ = remove
│ │          └──────────────┘ ⤡      │ │
│ └──────────────────────────────────┘ │
│ [+ Signature] [+ Date] [+ Text] [⧉ Pages…] │  P1 for Date/Text/Initials
│ ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐              │  page strip; dot = page has placements
│ │1 ││2 ││3•││4 ││5 ││6 │              │
│ └──┘└──┘└──┘└──┘└──┘└──┘              │
└──────────────────────────────────────┘
```
- First entry: one placement is dropped at the bottom-right of the current page, width = 30% of the page width.
- "⧉ Pages…" sheet: "Add this to: All pages / Pages [range] / Only this page".
- Bounds: a placement can't move more than 50% outside the page; on Save, placements are clipped to the crop box.
- Accessible alternative to dragging: select a placement → the overflow sheet has "Move to: top-left / top-right / centre / bottom-left / bottom-right", "Bigger / Smaller", "Rotate 90°".
- Save with zero placements → disabled; helper text "Add your signature to at least one page."
- Back with placements → D4.

### S36 · Watermark PDF (`/tool/pdf-watermark`)

```
┌──────────────────────────────────────┐
│ ←  Watermark PDF                ⓘ    │
├──────────────────────────────────────┤
│ File  📄 report.pdf · 12 pages [Change]│
│ ┌──────────────────────────────────┐ │
│ │   live preview of page 1         │ │  swipe for other pages
│ │        ╲ CONFIDENTIAL ╲          │ │
│ └──────────────────────────────────┘ │
│ ( ● Text ) ( ○ Image )               │
│ Text   [ CONFIDENTIAL            ]   │
│ Colour ● ● ● ● ● ● +    Bold [■]     │
│ Position  [Centre diagonal ▾]        │
│ Size      ─────●──── 60%             │
│ Opacity   ──●─────── 25%             │
│ Rotation  ──────●─── −35°            │
│ Pages     ( All ) ( Range ) ( Odd ) ( Even ) │
│ ⓘ The watermark is added on top of   │
│   the page.                          │
├──────────────────────────────────────┤
│ [        Add watermark        ]      │
│ ─────────── 24 dp + divider ─────────│
│ [ Test Ad banner (Tools) ]           │
└──────────────────────────────────────┘
```
States: empty text → button disabled ("Enter watermark text"); invalid range → inline error "Use page numbers like 1-3, 5"; image mode without an image → the "Choose image" card.

### S37 · Protect PDF (`/tool/pdf-protect`)

```
┌──────────────────────────────────────┐
│ ←  Protect PDF                  ⓘ    │
├──────────────────────────────────────┤
│ File  📄 bank_statement.pdf [Change] │
│ Password          [••••••••    👁]   │
│ Strength  ▰▰▱  OK                    │
│ Confirm password  [••••••••    👁]   │
│ ┌──────────────────────────────────┐ │
│ │ ⚠ If you forget this password,   │ │  warning banner, always visible
│ │ nobody can open the file —       │ │
│ │ DocuKit can't recover it.        │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ [        Protect PDF        ]        │
│ ─────────── 24 dp + divider ─────────│
│ [ banner — hidden while keyboard open]│
└──────────────────────────────────────┘
```
Errors: "Use at least 6 characters", "Passwords don't match". Weak password → confirm dialog "This password is easy to guess. Use it anyway?" [Change it] [Use anyway].

### S38 · Unlock PDF (`/tool/pdf-unlock`)

```
┌──────────────────────────────────────┐
│ ←  Unlock PDF                   ⓘ    │
├──────────────────────────────────────┤
│ File  📄 statement.pdf 🔒 [Change]   │
│ Password  [••••••••          👁]     │
│   ✕ That password didn't work.       │  inline, after a failed attempt
│     Check it and try again.          │
│ ⓘ You need the file's password.      │
│   DocuKit can't unlock files without │
│   it.                                │
├──────────────────────────────────────┤
│ [        Unlock PDF        ]         │
│ ─────────── 24 dp + divider ─────────│
│ [ banner ]                           │
└──────────────────────────────────────┘
```
The password check runs as part of the job (Processing shows "Checking password…"). A wrong password returns to S38 with the inline error, not to the Error screen.

### Shared states & platform notes

| Condition | Behaviour |
|---|---|
| Encrypted input in Sign / Watermark / Protect | Badge 🔒 + banner "This PDF is password-protected. Unlock it first." [Unlock PDF] |
| Very large PDF (> 300 pages) in Sign/Watermark | Info line "Large PDF — adding to all pages may take a while." |
| App backgrounded mid-job | Existing lifecycle rules (Interrupted + Retry) |
| iOS keyboard | `TextInputAction.next/done`; secure fields use `obscureText`; iOS may offer "Use Strong Password" only if `autofillHints` is set — we don't set it (no Keychain save prompts) |
| Android | `FLAG_SECURE` is **not** applied (screenshots allowed), but the password fields don't appear in screenshots because they're masked |
| Tablet | S35: the page strip becomes a vertical rail on the left; S36: preview left, options right |

---

## 4. Implementation

### 4.1 Packages

| Need | Package / API | Licence | Notes |
|---|---|---|---|
| Page rendering, open with password | `pdfrx` (existing) | MIT / PDFium BSD-3 | `PdfDocument.openFile(path, passwordProvider: …)` — verify the exact signature in the pinned version |
| Page-object editing | PDFium FFI via the bindings pdfrx ships (already used by the Balanced reducer) | BSD-3 | `FPDFPageObj_NewImageObj`, `FPDFImageObj_SetBitmap`, `FPDFImageObj_SetMatrix`, `FPDFPage_InsertObject`, `FPDFPage_GenerateContent`, `FPDF_SaveAsCopy` — verify each is exported by the pinned binding |
| Encryption (iOS) | PDFKit (system) | Apple | `PDFDocument.write(to:withOptions:)` with `.userPasswordOption`, `.ownerPasswordOption` — verify the encryption algorithm used on iOS 15.5 (AES-256 expected; RC4/AES-128 on older?) and whether `PDFDocumentWriteOption.accessPermissionsOption` exists on 15.5 |
| Encryption (Android) | **PdfBox-Android** `com.tom-roush:pdfbox-android` | Apache-2.0 | Latest release seen: **v2.0.27.0** (not recently updated → ADR-049). `StandardProtectionPolicy(owner, user, AccessPermission())`, `setEncryptionKeyLength(256)`, `doc.protect(policy)`, `doc.save(file)`; unlock with `PDDocument.load(file, password)` + `setAllSecurityToBeRemoved(true)`. Requires `PDFBoxResourceLoader.init(context)` once. Add R8 keep rules |
| Signature drawing | Flutter `CustomPainter` + `GestureDetector` (no package) | — | Quadratic smoothing, velocity-based width optional (P2) |
| Handwriting fonts | 3 OFL fonts bundled as assets (candidates: *Caveat*, *Dancing Script*, *Homemade Apple* or *Great Vibes* — check each is OFL; only the Regular weight) | SIL OFL 1.1 | ≈ 150–300 KB total; add to the licences page |
| Image decode/encode | `image` (existing, in isolates), `dart:ui` | MIT | Background removal, PNG encode |

### 4.2 `PdfStamper` (shared, `lib/core/pdf/pdf_stamper.dart`)

```dart
/// One image to draw on one page. Geometry is in the page's *visual* space
/// (as the user sees it: rotation applied, origin top-left, units = PDF points).
class Stamp {
  final int pageIndex;                 // 0-based
  final String pngPath;                // RGBA PNG (transparent where empty)
  final Rect visualRect;               // un-rotated box of the stamp in visual space
  final double rotationDegrees;        // the stamp's own rotation, clockwise, about its centre
  final double opacity;                // 0.1–1.0 (baked into alpha before insertion)
  const Stamp(...);
}

abstract interface class PdfStamper {
  /// Writes a NEW file at outPath. Reports Determinate(progress over pages with stamps).
  Future<void> apply(String inPath, List<Stamp> stamps, String outPath, JobContext ctx);
}
```

**Insertion algorithm (FFI):**
```
apply(in, stamps, out, ctx):
  doc = FPDF_LoadDocument(in, null)                      // input is never encrypted here (FR-*-01)
  byPage = stamps.groupBy(pageIndex)
  imageCache = {}                                        // pngPath+opacity → decoded BGRA bitmap (reuse for "all pages")
  for (i, pageStamps) in byPage (ascending):
    ctx.cancel.throwIfCancelled(); report(Determinate(done, total, 'step_adding_stamps'))
    page = FPDF_LoadPage(doc, i)
    geo = PageGeometry.of(page)                          // mediaBox, cropBox, rotation (0/90/180/270)
    for s in pageStamps:
      bmp = imageCache[s] ??= decodeToBgraPremultiplied(s.pngPath, s.opacity)   // Isolate
      obj = FPDFPageObj_NewImageObj(doc)
      FPDFImageObj_SetBitmap(&page, 1, obj, bmp)         // verify: BGRA with alpha → PDFium writes an SMask
      m = placementMatrix(geo, s)                        // §4.4
      FPDFImageObj_SetMatrix(obj, m.a, m.b, m.c, m.d, m.e, m.f)
      FPDFPage_InsertObject(page, obj)
    FPDFPage_GenerateContent(page)
    FPDF_ClosePage(page)
  FPDF_SaveAsCopy(doc, fileWriter(out), FPDF_NO_INCREMENTAL)
  FPDF_CloseDocument(doc); free bitmaps
```
- **Alpha:** `FPDFBitmap_Create(w, h, alpha=1)` (BGRA). Spike T11.0 must confirm that the transparent areas stay transparent in the output (i.e. PDFium generates an SMask). If not: fall back to drawing the alpha as a separate soft-mask image object (verify an API exists), or (last resort) native insertion (iOS: draw via `PDFPage` + annotation-free re-render isn't acceptable → use PdfBox on Android and CoreGraphics `PDFContext` page re-composition on iOS). Record the result in ADR-048.
- **Opacity:** baked into the bitmap's alpha (premultiplied), so no graphics-state/ExtGState handling is needed.
- **Resolution:** stamp images are rasterised at **300 dpi** of their final placed size (capped at 2400 px on the long side), so text watermarks stay crisp when printed.
- **Shared image objects:** PDFium creates one image XObject per `SetBitmap` call. For "all pages" on a 300-page PDF, that means 300 copies. Spike T11.0 checks the output size. If it grows by more than 30 KB per page, investigate reusing one XObject (verify whether `FPDFPageObj_NewImageObj` + a shared stream is possible), or reduce the dpi to 200 for tile/large watermarks.

### 4.3 Text → image rendering (watermarks, typed signatures, date/text stamps)

```
renderTextPng(text, fontFamily, colour, bold, targetHeightPt, dpi=300):
  px = targetHeightPt / 72 * dpi
  builder = ui.ParagraphBuilder(ParagraphStyle(fontFamily, fontSize: px * 0.8, fontWeight))
  layout with infinite width → measure (w, h)
  recorder → canvas.drawParagraph → picture.toImage(ceil(w)+pad, ceil(h)+pad)
  toByteData(png) → write work/<hash>.png
```
Any script the device's fonts support renders correctly. That's the reason for rendering to an image instead of embedding a PDF font. Text watermarks are therefore **not selectable or searchable** in the output, which is acceptable, and the ⓘ sheet mentions it.

### 4.4 Placement maths (visual space → PDF user space) **[unit]**

The editor works in **visual space**: the page as displayed (crop box only, rotation applied, origin top-left, y down, units = points). PDF content lives in **user space**: the unrotated page, origin bottom-left, y up.

```
PageGeometry: crop = (cx0, cy0, cx1, cy1)   // user space
              W = cx1 - cx0 ; H = cy1 - cy0 // unrotated size
              rot ∈ {0, 90, 180, 270}       // /Rotate, clockwise
visualSize = rot ∈ {90, 270} ? (H, W) : (W, H)

// map a visual point (vx, vy) to user space (ux, uy)
toUser(vx, vy):
  switch rot:
    0:   ux = cx0 + vx;          uy = cy1 - vy
    90:  ux = cx0 + vy;          uy = cy0 + vx
    180: ux = cx1 - vx;          uy = cy0 + vy
    270: ux = cx1 - vy;          uy = cy1 - vx
  return (ux, uy)

placementMatrix(geo, s):
  // image space: unit square (0,0)-(1,1); PDF draws the image upright in that square
  // 1) scale to the stamp size, centred at the origin
  S  = scale(s.visualRect.w, s.visualRect.h) · translate(-0.5, -0.5)
  // 2) the stamp's own rotation (clockwise in visual space = negative in a y-up space)
  R  = rotate(-s.rotationDegrees)
  // 3) undo the page rotation, so the stamp looks upright when the viewer applies /Rotate
  P  = rotate(+geo.rot)                 // the viewer rotates the page clockwise by rot
  // 4) move the centre to the mapped visual centre
  (ux, uy) = toUser(s.visualRect.center)
  T  = translate(ux, uy)
  return T · P · R · S                  // as an affine (a, b, c, d, e, f)
```
Unit tests (FEATURE_SPECS style): for each rot ∈ {0, 90, 180, 270} and a crop box offset from the media box (e.g. crop = (36, 36, 576, 756)), place a 100×50 stamp at the visual top-left (10, 10) and check that the four transformed image corners land at the expected user-space points (±0.01). The on-device test (R54) renders the output and checks the stamp's colour-marker position (±1 pt at 72 dpi).

**Editor ↔ visual space:** the editor shows the page rendered at `scale = viewWidthPx / visualSize.w`; a placement's screen rect ÷ scale = its visual rect in points. Store placements in points, so zooming and rotating the device don't change them.

### 4.5 `PdfSecurity` (shared, `lib/core/pdf/pdf_security.dart`)

```dart
sealed class UnlockResult { }
class Unlocked extends UnlockResult {}
class WrongPassword extends UnlockResult {}
class NotEncrypted extends UnlockResult {}

abstract interface class PdfSecurity {
  /// Encrypts with AES-256. ownerPassword is generated here (32 random bytes, base64) and discarded.
  Future<void> protect(String inPath, String outPath, {required String userPassword}, JobContext ctx);
  /// Decrypts only with the correct password. Never tries anything else.
  Future<UnlockResult> unlock(String inPath, String outPath, {required String password}, JobContext ctx);
  /// Cheap check used by the pickers in every tool.
  Future<PdfProtection> inspect(String path); // none | openPassword | ownerOnly
}
```

**Protect** → always native (`docukit_native.protectPdf`).
**Unlock**:
```
unlock(in, out, password):
  try PDFium path:
     doc = pdfrx open(in, password)            // wrong → PdfPasswordException → WrongPassword
     bytes = save with FPDF_REMOVE_SECURITY    // verify pdfrx/encodePdf exposes this flag; else raw FFI FPDF_SaveAsCopy(doc, writer, FPDF_REMOVE_SECURITY)
     write out; validate opens without a password
  if the PDFium path is unsupported or the output still reports encryption → native docukit_native.unlockPdf
```

### 4.6 Native methods (`packages/docukit_native`, channel `docukit/native`)

| Method | Args | Android (PdfBox-Android) | iOS (PDFKit) | Returns |
|---|---|---|---|---|
| `protectPdf` | `inPath, outPath, userPassword, ownerPassword` | `PDFBoxResourceLoader.init(ctx)`; `PDDocument.load(File(in))`; `ap = AccessPermission()` (all allowed); `spp = StandardProtectionPolicy(owner, user, ap)`; `spp.encryptionKeyLength = 256`; `doc.protect(spp)`; `doc.save(File(out))`; `doc.close()`. On a background thread | `PDFDocument(url:)`; `write(to: outURL, withOptions: [.userPasswordOption: user, .ownerPasswordOption: owner])` — verify AES-256 is used (check the output's `/Filter /Standard /V 5 /R 6` with a desktop tool in T11.0) | `{status: ok | failed, code?}` |
| `unlockPdf` | `inPath, outPath, password` | `PDDocument.load(File(in), password)` (throws `InvalidPasswordException` → `wrongPassword`); `doc.isAllSecurityToBeRemoved = true`; `save(out)` | `doc.unlock(withPassword:)` → false → `wrongPassword`; then `write(to:)` **without** password options (verify the output is unencrypted) | `{status: ok | wrongPassword | notEncrypted | failed}` |
| `pdfProtection` | `path` | `PDDocument.load(file)` → `isEncrypted`; if load fails with `InvalidPasswordException` → `openPassword` | `doc.isEncrypted`, `doc.isLocked` | `none | openPassword | ownerOnly` |

Rules for native code:
- **Passwords cross the channel as `String`, are never logged** (no `Log.d`/`print`/`NSLog` with arguments), and the Kotlin/Swift locals go out of scope immediately. Add a CI grep: `protectPdf|unlockPdf` must not appear on the same line as `Log.`/`print(`/`NSLog`.
- Stream to files; never return PDF bytes over the channel.
- Memory: PdfBox loads the document with `MemoryUsageSetting.setupTempFileOnly()` (scratch file in `ctx.workDir`) for files > 50 MB — verify the 2.0.27 API.

### 4.7 Signature pipeline

```
Draw:   points (with timestamps) per stroke → smoothed Path (midpoint quadratic Béziers)
        → on Done: compute ink bounds → render at 3× device pixel ratio onto a transparent canvas
        → crop to bounds + 8 px → PNG (RGBA) → work/sig_<uuid>.png
Type:   renderTextPng(name, chosenFont, colour, bold=false, height=60 pt @ 300 dpi)
Photo:  decode (≤ 2000 px long edge) → greyscale luminance L
        → alpha = clamp((threshold - L) / softness, 0, 1) × 255  (threshold from the slider; softness = 24)
        → ink colour = original pixel colour, darkened 20% (keeps blue ink blue)
        → crop to bounds where alpha > 10 → PNG
Saved:  copy to appSupport/signatures/<uuid>.png (only after "Save"), index in settings key
```

### 4.8 Operations (ToolOperation implementations)

| Operation | Steps | Progress | Output name | Validation |
|---|---|---|---|---|
| `SignPdfOperation` | render stamps (signatures cached) → `PdfStamper.apply` | Determinate over pages with placements | `<base>_signed.pdf` | Opens; page count equal; render the first stamped page at 72 dpi and check the stamp's bounding box isn't blank (non-background pixels > 0.5% of the box) |
| `WatermarkPdfOperation` | renderTextPng / load image → expand pages selection → build stamps per preset (tile = 3×4 grid) → apply | Determinate over pages | `<base>_watermarked.pdf` | Same as above, on the first selected page |
| `ProtectPdfOperation` | `PdfSecurity.protect` | Indeterminate `step_encrypting` | `<base>_protected.pdf` | FR-PRT-06 (a)+(b)+(c) |
| `UnlockPdfOperation` | `PdfSecurity.unlock` | Indeterminate `step_checking_password` → `step_unlocking` | `<base>_unlocked.pdf` | FR-UNL-06 |

`WrongPassword` is **not** an `AppError` that ends on S18. The controller maps it to the inline field error, and the history row is not written for wrong-password attempts (FR-UNL-03; this avoids filling history with failures).

### 4.9 Catalogue, search and tour

```dart
ToolDescriptor(id: ToolId.pdfSign, category: ToolCategory.secure, route: '/tool/pdf-sign', inputKind: InputKind.singlePdf, ...)
// keywords:
pdfSign:      sign, signature, e-sign, esign, autograph, initials, fill and sign, sign document, sign contract, add signature
pdfWatermark: watermark, stamp, confidential, draft, logo on pdf, mark pages, copyright
pdfProtect:   password, protect, lock, encrypt, secure pdf, add password, password protect
pdfUnlock:    unlock, remove password, decrypt, open locked pdf, forgot? (no — don't add "forgot"/"crack"/"bypass")
```
Never add search keywords that suggest bypassing ("crack", "bypass", "forgot password", "remove protection without password").

Tour (FR-TOUR-10): steps for the "Secure & Sign" section header + one step per tool, built from the catalogue (`tourTitle/tourBody/tourExample`, §7).

### 4.10 Memory and performance

| Case | Budget / rule |
|---|---|
| Stamp bitmaps | ≤ 2400 px long edge × 4 bytes ≈ 23 MB worst case each; cache ≤ 3 distinct bitmaps; free after the job |
| Placement editor | Render only the visible page at screen resolution + thumbnails via the existing `PdfThumbnailCache` |
| Watermark preview | Composite in Flutter (page image + stamp widget), not by running PDFium per change |
| PdfBox on Android | Temp-file memory mode for > 50 MB inputs; run on `Dispatchers.IO` |
| 300-page "all pages" watermark | Target < 60 s on the emulator; record it in TESTING §6 |

---

## 5. Data model & settings

### 5.1 New settings keys (`SettingsRepository`)

| Key | Type | Default | Notes |
|---|---|---|---|
| `saved_signatures` | JSON list `[{id, file, createdAt, kind}]` | `[]` | Max 3; files in `appSupport/signatures/` |
| `sig_last_colour` | `black|blue` | black | |
| `sig_last_thickness` | `thin|medium|thick` | medium | |
| `wmk_last_text_style` | JSON `{text, colour, bold, position, size, opacity, rotation}` | — | FR-WMK-10; text only, never images |

### 5.2 Storage rules
- `appSupport/signatures/<uuid>.png`: excluded from iCloud backup (`isExcludedFromBackup = true`) and from Android Auto Backup (`android:fullBackupContent` / `dataExtractionRules` exclude `signatures/`). A signature is a sensitive personal artefact (ADR-050).
- Deleting a saved signature deletes the file immediately (no trash).
- Clear history does **not** delete saved signatures; Settings → Saved signatures → "Delete all" does (D2).
- **No passwords anywhere:** not in settings, drafts, history (`optionsJson` for Protect/Unlock = `{}`), logs, crash reports or analytics. The tool drafts (FR-LIFE-03) for S37/S38 store only the input file reference.

### 5.3 History (`operations` table)
New `tool` values: `pdfSign`, `pdfWatermark`, `pdfProtect`, `pdfUnlock`. `outputMetaJson`: `{"pages": n, "stamped": k}` for Sign/Watermark, `{"pages": n, "encrypted": true}` for Protect. "Run again" for Protect/Unlock re-opens the tool with an **empty** password field.

---

## 6. Permissions, privacy & store impact

| Item | Impact |
|---|---|
| New permissions | None |
| Data safety / App Store privacy label | No change: passwords, signatures and files stay on the device |
| Privacy policy | Add: "Saved signatures are stored only on your device and are not included in backups. Passwords you enter are used once and never saved." |
| Privacy & About (S17) | Add a short "Passwords and signatures" section with the same text |
| **Export compliance (iOS)** | The app now **uses encryption** (AES-256 via PDFKit, and on Android via PdfBox). `ITSAppUsesNonExemptEncryption` is currently `NO`. Encrypting the user's own files with standard algorithms provided by the OS is generally considered exempt, but the App Store Connect export-compliance questions must be answered again for 1.4. **Verify Apple's export compliance questions and the current exemption categories before submitting; record the answer in ADR-051.** |
| Google Play | No encryption declaration needed (verify the current Play Console policy) |
| App size | Android **+3–5 MB** (PdfBox-Android + resources; measure in T11.0); fonts +0.3 MB both platforms |
| Licences | PdfBox-Android (Apache-2.0, includes NOTICE), the 3 OFL fonts |

---

## 7. Copy (add to COPY.md)

| Key | Text |
|---|---|
| tool_pdf_sign_title / subtitle | Sign PDF / Add your signature to pages |
| tool_pdf_watermark_title / subtitle | Watermark PDF / Stamp text or a logo on pages |
| tool_pdf_protect_title / subtitle | Protect PDF / Add a password |
| tool_pdf_unlock_title / subtitle | Unlock PDF / Remove a password you know |
| home_section_secure | Secure & Sign |
| sig_your_signature | Your signature |
| sig_draw / type / photo | Draw / Type / Photo |
| sig_new | New |
| sig_not_certified | This adds an image of your signature. It isn't a certified digital signature. |
| sig_place_cta | Place signature on pages |
| sig_pad_title_draw / type / photo | Draw signature / Type signature / Signature from photo |
| sig_pad_hint | Sign with your finger |
| sig_pad_landscape | Turn your phone for more room |
| sig_undo_stroke / clear | Undo / Clear |
| sig_colour / thickness | Colour / Thickness |
| sig_your_name | Your name |
| sig_bg_cleanup | Background cleanup |
| sig_save_ask_title / body | Save this signature for next time? / It's kept only on this phone and isn't included in backups. |
| sig_save_yes / no | Save / Not now |
| sig_saved_limit | You can keep up to 3 signatures. Delete one to save this. |
| sig_delete_title | Delete this saved signature? |
| sig_discard_title | Discard this signature? |
| sig_place_title | Place signature |
| sig_add_signature / date / text / initials | Signature / Date / Text / Initials |
| sig_pages_sheet | Add this to |
| sig_pages_all / range / this | All pages / Pages / Only this page |
| sig_need_one | Add your signature to at least one page. |
| sig_move_to | Move to |
| sig_bigger / smaller / rotate | Bigger / Smaller / Rotate 90° |
| sig_run | Save signed PDF |
| wmk_text / image | Text / Image |
| wmk_text_hint | Watermark text |
| wmk_need_text | Enter watermark text |
| wmk_position | Position |
| wmk_pos_diagonal / centre / tile / tl / tr / bl / br | Centre diagonal / Centre / Tile / Top left / Top right / Bottom left / Bottom right |
| wmk_size / opacity / rotation | Size / Opacity / Rotation |
| wmk_pages | Pages |
| wmk_pages_all / range / odd / even | All / Range / Odd / Even |
| wmk_range_hint / error | e.g. 1-3, 5 / Use page numbers like 1-3, 5 |
| wmk_on_top | The watermark is added on top of the page. |
| wmk_not_searchable (ⓘ sheet) | Text watermarks are added as an image, so they can't be selected or searched. |
| wmk_run | Add watermark |
| prt_password / confirm | Password / Confirm password |
| prt_show / hide (a11y) | Show password / Hide password |
| prt_strength_weak / ok / strong | Weak / OK / Strong |
| prt_err_short | Use at least 6 characters |
| prt_err_long | Use 64 characters or fewer |
| prt_err_mismatch | Passwords don't match |
| prt_no_recover | If you forget this password, nobody can open the file — DocuKit can't recover it. |
| prt_weak_title / body | This password is easy to guess / Use it anyway? |
| prt_weak_change / use | Change it / Use anyway |
| prt_already | This PDF already has a password. |
| prt_run | Protect PDF |
| unl_password | Password |
| unl_wrong | That password didn't work. Check it and try again. |
| unl_need_pw | You need the file's password. DocuKit can't unlock files without it. |
| unl_not_encrypted | This PDF doesn't have a password. |
| unl_owner_only | This PDF opens without a password. It has restrictions set by its creator, which DocuKit keeps. |
| unl_run | Unlock PDF |
| enc_unlock_first | This PDF is password-protected. Unlock it first. |
| enc_unlock_action | Unlock PDF |
| step_adding_stamps / encrypting / checking_password / unlocking | Adding to pages… / Adding password… / Checking password… / Removing password… |
| result_protected_note | Keep the password somewhere safe. |
| set_saved_signatures / delete_all | Saved signatures / Delete all saved signatures |
| priv_pw_sig_h / p | Passwords and signatures / Passwords you enter are used once and never saved. Saved signatures stay only on this phone and aren't included in backups. |
| tour_secure_title / body | Secure & Sign / Sign, watermark, or add and remove passwords — all on your phone. |
| tour_pdf_sign_example | Sign a rental agreement without printing it. |
| tour_pdf_watermark_example | Mark a document "Draft" or "Confidential". |
| tour_pdf_protect_example | Lock a bank statement before emailing it. |
| tour_pdf_unlock_example | Remove a password you know from a statement. |

---

## 8. Tests

### 8.1 Unit
| Area | Cases |
|---|---|
| Placement maths (§4.4) | 4 rotations × crop-box offset × stamp rotation {0, 30, 90}: the corners land within ±0.01 pt |
| Page-range parser | "1-3, 5", "5-3" (invalid), "0", "1-999" on 12 pages (clamped or invalid per spec: **invalid**, with the message), whitespace, duplicates de-duplicated |
| Watermark layout | Each preset gives the expected rects for A4 portrait/landscape; tile = 12 stamps inside the crop box |
| Strength meter | Boundaries for weak/OK/strong |
| Password validation | Min/max, mismatch, unicode passwords allowed (verify both native libs accept non-ASCII; if not, restrict to printable ASCII with a clear message — decided in T11.0) |
| Hygiene | Protect/Unlock `optionsJson` is `{}`; the draft JSON doesn't contain the password; the controller clears the password on Result/Cancel/Error |
| Background removal | Synthetic image: ink pixels kept, paper pixels alpha 0 at the default threshold |

### 8.2 Widget
- S33–S38 states in §3 (empty, encrypted input with the Unlock link, errors, disabled buttons with helper text).
- Banner present on S33/S36/S37/S38 with the 24 dp gap; **absent** on S34/S35.
- S35: drag → the visual rect updates; "Move to: top-right" moves to the expected rect; undo/redo.
- 200% text on S37/S38: the warning banner and fields don't overflow.

### 8.3 Integration (on device, real engines)
| Test | Expected |
|---|---|
| Protect PDF-01 with `Test-1234` | pdfrx open without a password → password exception; with the password → opens; pages equal; source SHA-256 unchanged |
| Protect then Unlock round-trip | The final output opens without a password; page count and first-page render match the original (pixel diff < 1%) |
| Unlock PDF-05 (`encrypted_user_pw.pdf`) with a wrong password | `WrongPassword`; no output file left in `workDir`; no history row |
| Unlock PDF-06 (owner-only) | `unl_owner_only` message; no job runs |
| Sign on `rotated_pages.pdf` (PDF-04) | Stamp marker (a coloured square in the signature PNG) found at the expected position on pages rotated 0/90/180/270, ±1 pt |
| Sign with a crop box (new corpus file PDF-15 `cropbox_offset.pdf`) | Same accuracy |
| Watermark tile, all pages, 300-page PDF-08 | Completes; output grows < 30 KB/page (or the T11.0 decision); time recorded |
| Watermark opacity 25% | Rendered pixel under the watermark is a blend (not fully opaque) |
| Hindi/Arabic text watermark | Renders correctly (visual check + non-blank box) |

**Desktop cross-check (manual, once per platform in T11.0 and T11.9):** open the protected output in Adobe Acrobat Reader and macOS Preview (or Chrome's PDF viewer): asks for the password; the document properties show AES-256. Open signed/watermarked outputs: the stamp is where expected and transparent around the ink.

### 8.4 Corpus additions
`PDF-15 cropbox_offset.pdf` (crop box inset 36 pt), `PDF-16 owner_restricted.pdf` (owner password only, printing disabled), `IMG-24 signature_photo.jpg` (blue ink on off-white paper), `IMG-25 logo_alpha.png`.

### 8.5 Regression (append to TESTING.md §4)

| # | Steps | Expected |
|---|---|---|
| R49 | Sign: draw a signature, don't save it, place on page 1, save | Signed PDF; signature not in the saved list |
| R50 | Sign: type a signature, save it, place on all pages of a 6-page PDF | 6 stamps; saved signature appears on the next visit |
| R51 | Sign: photo signature (IMG-24) on PDF-04 rotated pages | Upright, transparent background, correct positions |
| R52 | Watermark text "CONFIDENTIAL", diagonal, 25%, all pages | Matches the preview on every page |
| R53 | Watermark logo (IMG-25), bottom-right, odd pages only | Only odd pages stamped; transparency kept |
| R54 | Protect PDF-01; open the output in another app | Asks for the password; opens with it |
| R55 | Unlock the R54 output with a wrong, then the right password | Inline error first; then an unlocked copy that opens without a password |
| R56 | Merge with an encrypted PDF in the list | 🔒 badge + "Unlock it first" → Unlock PDF opens with that file |
| R57 | Protect / Unlock history entries; "Run again" | No password anywhere in Details; Run again opens with an empty field |
| R58 | Ads: S33/S36/S37/S38 show the bottom banner with the gap; S34/S35 show none; the banner hides while typing a password | ✓ |

---

## 9. Tasks (milestone M11)

- [~] 🔬 **T11.0 PDF security & stamping spike (1 day, GATE).** On both OSes, with PDF-01/04/05/06/08/15/16:
  1. PDFium image object with BGRA alpha → is the transparency kept (SMask)? Output size per stamped page.
  2. Matrix placement on rotated and crop-boxed pages (the 4.4 maths).
  3. iOS PDFKit protect: the algorithm actually written (inspect the `/Encrypt` dictionary: `/V 5 /R 6` = AES-256); non-ASCII passwords.
  4. Android PdfBox-Android 2.0.27.0: protect with AES-256, unlock, R8 release build works, APK size delta, behaviour on a 200 MB PDF.
  5. Unlock via PDFium (`FPDF_REMOVE_SECURITY`): available through pdfrx/FFI? The output is really unencrypted?
  *Accept:* ADR-048 (stamping path) and ADR-049 (encryption libraries) written with the exact API calls that worked and the measurements; go/no-go for each tool.
  — *Android done 2026-10-30* (ADR-048/049): **go for all four tools.** Stamping: PDFium image objects keep transparency (straight alpha, not premultiplied), §4.4 placement within ±1 pt on all rotations with a crop box, one shared form XObject per image (+3 KB/page instead of +781 KB/page) — `test/core/pdf_stamp_spike_host_test.dart`. Security: PdfBox-Android 2.0.27.0 without BouncyCastle (owner accepted) writes AES-256 (`/V 5 /R 6 /AESV3`), unlocks, handles non-ASCII passwords and owner-only PDFs, 204 MB in 97 s with no memory growth, +1.74 MB, R8 release build passes; PDFium `FPDF_REMOVE_SECURITY` unlock works — `integration_test/pdf_security_spike_test.dart`. Native `protectPdf` / `unlockPdf` / `pdfProtection` are in `docukit_native` (Kotlin; iOS returns "unsupported" until the Xcode round); `PdfSecurity` and the no-logging CI grep come in T11.2. ⚠️ iOS (PDFKit algorithm, non-ASCII) waits for Xcode; the release build *running* PdfBox is checked in the owner's phone pass.
- [x] **T11.1 Catalogue, Home section, colours, search, tour steps** (FR-SEC-01/02). *Accept:* 4 cards in a new "Secure & Sign" section; search tests for the §4.9 keywords; tour version bumped with tests. — *Done 2026-10-30:* `ToolId.pdfSign/pdfWatermark/pdfProtect/pdfUnlock` in `ToolCategory.secure` (`secureGradient`/`secureAccent`, ADR-061), slugs `pdf-sign`, `pdf-watermark`, `pdf-protect`, `pdf-unlock`, one PDF each; Home "Secure & Sign" after Scan & text; the §4.9 keywords (none suggesting a bypass, tested); `currentTourVersion = 5` with a section step on the "Secure & Sign" header before the four tool steps (tool title + subtitle + COPY example), shown once in "New in DocuKit" to 1.0–1.3 users. Secure tools count as PDF tools for the History PDFs filter and the search "pdf" boost (`ToolCategory.makesPdf`). Until each screen lands (T11.3/T11.4/T11.7/T11.8) the routes use `SecureToolShell` (title, PDF picker, a disabled run button). Tests: 28 keyword rankings + the no-bypass check, history filter, tour unit/widget tests for v5 (incl. a 1.3 user), Home order; the banner-gap test covers the four routes.
- [x] **T11.2 `PdfSecurity` + native `protectPdf` / `unlockPdf` / `pdfProtection`** (Kotlin + Swift + Dart, with the CI no-logging grep). *Accept:* unit tests with a fake channel; on-device round-trip tests (§8.3 first two rows). — *Android done 2026-10-30:* `lib/core/pdf/pdf_security.dart` — `PdfSecurity` (`protect` / `unlock` / `inspect`), `UnlockResult` = `Unlocked | WrongPassword | NotEncrypted | OwnerOnly`, `PdfProtection` = `none | openPassword | ownerOnly`. Protect: native PdfBox with the user's password and a fresh random 32-byte owner password (`Random.secure`, base64, never kept). Unlock: inspect first — not encrypted / owner-only are returned before anything is written, so owner restrictions are never removed (FR-UNL-05, ADR-053); then PDFium `FPDF_REMOVE_SECURITY` with the given password only (`removeSecurityInWorker` in pdfrx's worker), the output re-inspected to be really unencrypted, else the PdfBox fallback (Android; iOS → `processingFailed` until the Xcode round). Inspect is PDFium on both platforms (`inspectSecurityInWorker`: load error 4 → open password; `FPDF_GetSecurityHandlerRevision` ≥ 0 → owner-only — so an encrypted file with an empty open password is treated as owner-only too). `pdfSecurityProvider`. CI: `tool/check_no_password_logs.sh` (any print/log/Log.*/println/NSLog/os_log call mentioning a password, Dart + Kotlin + Swift; checked against planted violations). Tests: 11 unit tests with a fake channel and fake PDFium ops; `integration_test/pdf_security_test.dart` on the emulator, 4/4: Protect PDF-01 (needs the password, opens with it, 10 pages, source SHA unchanged), Protect→Unlock round trip (opens without a password, 10 pages, first-page diff 0.000%), a non-ASCII password (PDFium alone unlocks it), wrong password → no output, owner-only → nothing written. ⚠️ Swift `protectPdf`/`unlockPdf` still return "unsupported" (Xcode round).
- [x] **T11.3 Protect PDF screen + operation (S37).** *Accept:* FR-PRT-01…08; R54, R57. — *Android done 2026-10-30:* `lib/features/pdf_protect/` — S37 `ProtectScreen` (masked Password + Confirm, show/hide with tooltips, no autocorrect/suggestions/autofill/IME learning; inline errors; Weak/OK/Strong meter with the word, not colour alone; always-visible can't-recover warning; weak → "Change it / Use anyway"; a locked **or owner-restricted** PDF → "This PDF already has a password." + Unlock PDF, Run disabled, since protecting would replace the creator's restrictions, ADR-053) and `ProtectPdfOperation` (inspect → `PdfSecurity.protect`, `stepEncrypting`; validation FR-PRT-06 a/b/c via PDFium: needs a password, opens with it, same pages; `<base>_protected.pdf`; meta `{pages, encrypted: true}`). Rules (FR-PRT-02/03, owner-approved): 6–64 characters and ≤ 127 UTF-8 bytes (`prt_err_bytes`, ADR-049 — above that PdfBox and PDFium disagree, measured); weak < 8 chars or one kind, strong ≥ 12 and ≥ 3 kinds. Hygiene (FR-PRT-07): the fields clear at Run; the job holds a `OneTimePassword` (no `toString`), `ToolOptions.wipe()` is called by `JobRunner` in every `finally`, so it's gone on Result/Cancel/Error and the S18 restart closure can't reuse it; S18 "Try again" for Protect/Unlock goes back to the tool (`toolsWithPasswords`); `optionsJson` = `{}`; no draft of the password. Result and History Details show a lock placeholder (the output can't render without the password) and "Keep the password somewhere safe." Tests: 17 unit (strength boundaries, length/bytes/mismatch, runner + history hygiene, FR-PRT-06 failures, owner-only/locked refused, wipe on success/fail/cancel), 7 widget (fields, errors, strength, weak dialog, Result, locked/owner-only + Unlock link, Try again, 200% text), `integration_test/protect_operation_test.dart` 2/2 on the emulator (validated output asks for the password, opens with it, 10 pages, source SHA unchanged, no password in any history table; 42 Hindi chars = 126 bytes works). ⚠️ R54 "open in another app" and the desktop cross-check are manual (owner); iOS waits for Xcode; the Unlock link opens S38 without the file until T11.4.
- [x] **T11.4 Unlock PDF screen + operation (S38) + "Unlock it first" routing in all existing PDF tools** (FR-UNL-08). *Accept:* FR-UNL-01…08; R55, R56. — *Android done 2026-10-30:* `lib/features/pdf_unlock/` — S38 `UnlockScreen` (one masked field with show/hide, no suggestions/autofill, Unlock enabled when non-empty, no length/byte rule; "You need the file's password" note; unprotected → `unl_not_encrypted`, owner-restricted → `unl_owner_only`, both disabled) and `UnlockPdfOperation` (`stepCheckingPassword`: PDFium opens with the typed password only; `stepUnlocking`: `PdfSecurity.unlock`; validation FR-UNL-06: no password needed, same page count as opened with the password, first page renders; `<base>_unlocked.pdf`). Wrong password / unprotected / owner-only end the job with the new `ReturnToTool` → `JobReturned(reason)`: the runner **deletes the history row** it created, Processing closes, S38 shows the error inline with the field still filled (FR-UNL-03); Result/Cancel/Error clear the field (FR-UNL-07); the password is a wiped `OneTimePassword` as in T11.3 (ARCHITECTURE §5.2/§5.3 updated). "Unlock it first" (FR-UNL-08): `lib/features/secure/unlock_first.dart` hands S38 a **copy** of the file (hand-off copy mode; the source tool keeps its list and draft) — Size Reducer, Organize, Split, PDF → Images and Text Recognition make **Unlock PDF** the primary action with `enc_unlock_first` as helper; Merge shows the banner + [Unlock PDF] for the first locked file (R56); Protect's "already has a password" button pre-loads the file; S18 for `encryptedDocument` now says "Unlock it first, then try again." with [Unlock PDF] / [Choose another] (COPY updated). Tests: 7 unit (steps, wrong/unprotected/owner-only → returned with no history, engine disagreement, FR-UNL-06 failures, other invalid inputs, wiped password), 6 S38 widget, 9 "Unlock it first" (Merge R56, 5 single-PDF tools, Protect, S18 copy + action), `integration_test/unlock_operation_test.dart` 2/2 on the emulator (R55: wrong → no row, no output; right → opens without a password, 6 pages, source unchanged; owner-only / unprotected returned). ⚠️ Privacy text ("doesn't unlock protected PDFs") is updated in T11.9; iOS waits for Xcode; R55/R56 by hand in the phone pass.
- [x] **T11.5 `PdfStamper` + placement maths + text-to-image renderer.** *Accept:* §8.1 placement tests; on-device accuracy tests on PDF-04 and PDF-15. — *Android done 2026-10-30:* `lib/core/pdf/stamp_geometry.dart` (`Affine`, `PageGeometry` incl. normalising inverted boxes / odd `/Rotate`, `toUser`, `placementMatrix`), `lib/core/pdf/pdf_stamper.dart` (`Stamp`, `PdfStamper`, `PdfiumStamper` → `stampInWorker` in pdfrx's worker: page box = `FPDF_GetPageBoundingBox`, one shared form XObject per (PNG, opacity), straight alpha with opacity baked in, > 2400 px scaled down, `stepAddingStamps` progress over stamped pages only, cancel flag, a missing page → `invalidInput`, never writes the input), `lib/core/pdf/text_stamp_renderer.dart` (`renderTextPng`: 300 dpi of the placed height, 2400 px cap, transparent, device fonts, RTL detected), `pdfStamperProvider`. Tests: 19 unit (§8.1: 4 rotations × 36 pt crop offset × stamp 0/30/90°, all four corners ±0.01 pt; hand-checked `toUser`), 8 host on real PDFium (`pdf_stamper_host_test.dart`, now in CI and `tool/test_pdf_host.sh`: ±1 pt on all rotations with/without crop, rotated stamp, 50% opacity blend, two images on a page, 300 pages +0.40 KB/page with real progress and an unchanged input, partial pages, cancel, missing page, 3000 px PNG), 4 widget (text PNG size/transparency/colour, Hindi + Arabic, the cap, blank refused), `integration_test/pdf_stamper_test.dart` 3/3 on the emulator: the marker within ±1 pt on PDF-04 and PDF-15 at 0/90/180/270 (built in-test with `test/helpers/pdf_page_setup.dart`), Latin and Hindi text stamps non-blank. ⚠️ iOS waits for Xcode.
- [x] **T11.6 Signature creator (S34): draw, type, photo + saved signatures + Settings entry.** *Accept:* FR-SIG-02/03/04/10; storage excluded from backups (checked in the manifest / with `URLResourceValues`). — *Android done 2026-10-30:* `lib/features/pdf_sign/` — `ink.dart` (midpoint quadratic smoothing, ink bounds, PNG export at 3× cropped to the ink + 8 px; black/blue, thin/medium/thick, remembered in `sig_last_colour` / `sig_last_thickness`), `photo_signature.dart` (§4.7 background removal in an isolate: threshold = cleanup % of white, softness 24, ink darkened 20%, crop where alpha > 10; the photo is first oriented/limited to 2000 px by the image engine, so HEIC works), `signature_repository.dart` + `signature_providers.dart` (opt-in, max 3, `saved_signatures` index, `appSupport/signatures/<uuid>.png`, `protectOutput` on the folder and each file = iOS `isExcludedFromBackup`; delete removes the file at once; Delete all), S34 `SignatureCreatorScreen` at `/tool/pdf-sign/create?mode=draw|type|photo` (full screen, **no ads**; Done disabled while empty; Undo / Clear; landscape hint; pad semantics label naming Type as the alternative; Type with three live previews in **Dancing Script / Sacramento / Mr Dafoe** — ADR-067, 261 KB, OFL, on the licences page; Photo on a checkerboard with Background cleanup 0–100, default 55; back with content → "Discard this signature?"), the "Save this signature for next time?" sheet (default not saved; at 3 only "Not now" + `sig_saved_limit`), Settings → Saved signatures (list, delete with D2, Delete all). Unsaved PNGs live in the Sign tool's draft (`jobs/<draft>/sig/`), deleted with it. Tests: 11 unit (smoothing, bounds, export, §8.1 background removal on a synthetic image, repository incl. max 3 / delete / damaged index), 8 widget (no banner on S34, draw/undo/clear, Not now vs Save + limit, discard, type fonts, photo slider + crop, Settings delete/delete all, Android backup rules exclude `file`/`root`), font licences. ⚠️ iOS backup exclusion (`URLResourceValues`) is the existing `protectOutput` path but not run (no Xcode); S33's tiles (tap to use, long-press delete) come with S33 in T11.7; photo mode crops automatically (no manual crop handles).
- [x] **T11.7 Placement editor (S35) + Sign PDF screen (S33) + operation.** *Accept:* FR-SIG-01, 05–09, 11, 12; R49–R51. — *Android done 2026-10-30:* `lib/features/pdf_sign/` — `placement.dart` (default bottom-right at 30% width in a 5% margin, ≤ 50% outside the page, resize about the centre keeping the aspect (12 pt … page width), rotation snaps at 0/±90 within 5°, Move-to presets, same relative position on other page sizes, `PlacementHistory` with gestures as one step, 50 steps kept), `sign_session.dart` (S33 choice; S35 editor controller), `sign_operation.dart` (`SignPdfOperation` → `PdfStamper`; validation: page count + the first stamped page rendered at 72 dpi has > 0.5% ink in its first stamp's (rotated) box; `<base>_signed.pdf`; meta `{pages, stamped}`; history `{placements, pages}` counts only), S33 `SignScreen` (file card, Unlock-it-first banner, saved tiles: tap to choose, long-press → D2 delete; the new tile; Draw/Type/Photo → S34; the not-certified note in the footer and ⓘ; banner ad), S35 `PlacementScreen` at `/tool/pdf-sign/place` (full screen, **no ads**; drag / corner resize / ⟳ rotate / ✕ remove / ⋯ sheet with Move to, Bigger, Smaller, Rotate 90°, Remove; page strip with dots; + Signature / Date (today, locale format, editable) / Text / Initials rendered to images; Pages… = All / range / this page; undo/redo; Save disabled with `sig_need_one`; leaving asks). Found by the tests and fixed: the page strip overflowed; dialog/sheet controllers were disposed while closing; handles hanging outside a placement (and the page) couldn't be tapped — the page and each placement now have a 24 dp handle border. Tests: 11 placement/history unit, 4 operation unit, 10 S33/S35 widget (banner on S33, none on S35, locked file, tiles, R49 flow from S34, drag + undo/redo, Pages… all/range with errors, the accessible sheet, date stamp, leave dialog, R50 Save with counts-only history), `integration_test/sign_operation_test.dart` 3/3 on the emulator: R49 drawn signature (source SHA unchanged), R50 typed signature on 6 pages (ink inside each box ±1.5 pt), R51 photo signature on PDF-04 0/90/180/270 — ink within 1 pt of the placed box, upright. ⚠️ No pinch-zoom on S35 (owner-approved deferral: it fights with dragging); manual R49–R51 on a real phone; iOS waits for Xcode.
- [x] **T11.8 Watermark PDF (S36) + operation.** *Accept:* FR-WMK-01…10; R52, R53; the 300-page timing recorded. — *Android done 2026-10-30:* `lib/features/pdf_watermark/` — `watermark_layout.dart` (centre diagonal −35° / centre / tile 3×4, 4×3 on landscape, each rotated stamp inside its cell / corners in a 5% margin with the rotated box; size = % of the short side, 10–100 (60 text / 30 image), opacity 10–80 (25), rotation −90…90 reset per preset; All / Range / Odd / Even, a bad range → `wmk_range_error`), `watermark_operation.dart` (`WatermarkPdfOperation` → `PdfStamper`, opacity baked into alpha; validation: page count + the first selected page's first stamp has ink at threshold 252 (owner-approved, a light 10% colour is barely off white); `<base>_watermarked.pdf`; history = style only, never the text or image path; `wmk_last_text_style` for text watermarks only, FR-WMK-10), S36 `WatermarkScreen` (swipeable live preview from the same layout maths and image, text ≤ 60 chars any script with 6 colours + a hue-slider custom colour + Bold, image mode with a PNG kept as is / JPG·HEIC converted to PNG, position / size / opacity / rotation, pages, the on-top note, ⓘ = not searchable, Unlock-it-first, banner ad). `stampHasInk` / `rotatedBounds` moved to `lib/core/pdf/stamp_check.dart`; `pngSize` to `core/files/png_size.dart`; page sizes for restored drafts to `core/providers.dart`; `SecureToolShell` removed (all four tools have their screens). Tests: 11 layout unit (§8.1 presets on A4 portrait/landscape, tile 12 inside, page modes, "1-999" on 12 pages invalid), 6 operation unit, 8 S36 widget (banner, preview + empty text, tile ×12, even pages + range error, image mode, run + remembered style + style-only history, restore, locked), `integration_test/watermark_operation_test.dart` 3/3 on the emulator: R52 (ink inside the stamp box on every page, no solid colour = opacity applied), R53 (logo within 1 pt on PDF-04 odd pages, transparent centre shows the page, even pages untouched), **300 pages tiled: 5.1 s, +0.68 KB/page** (TESTING §6). ⚠️ Hindi/Arabic text watermark visual check and R52/R53 by hand on a real phone; iOS waits for Xcode.
- [~] **T11.9 Privacy, store and docs.** Privacy policy + S17 text, licences (PdfBox NOTICE, fonts), the export-compliance answer (ADR-051), ARCHITECTURE stack rows, COPY, TESTING. *Accept:* the RELEASE checklist re-run; the desktop cross-check (§8.3) done on both platforms. — *Android done 2026-10-31; export compliance waits for the owner:* privacy policy (`privPolicyBody2` + RELEASE §6 template: saved signatures stay on the device and out of backups; passwords used once, never saved), S17 "Passwords and signatures" point and the corrected "Password-protected files" text (it said DocuKit doesn't open protected PDFs) — **owner: review the wording**; licences: PdfBox-Android NOTICE + Apache-2.0 LICENSE from the v2.0.27.0 tag in `assets/licenses/` (the AAR ships none), shown on Android only, plus the 3 OFL fonts — tested; ARCHITECTURE stack rows as built; RELEASE §4/§8.0/§8.4 with measured sizes (+1.74 MB PdfBox, +0.26 MB fonts); STORE_PRIVACY_CHECKLIST §1.4 (no Data safety / label change, no new permissions; merged manifest re-checked — `WRITE_EXTERNAL_STORAGE` max SDK 28 is the documented v2.1 Save-to-Photos one); **ADR-051 stays open**: Apple's App Store Connect help lists OS-provided crypto among cases needing a determination and the page defining `ITSAppUsesNonExemptEncryption` couldn't be read, so the key is unchanged and the owner answers App Store Connect's questions; desktop cross-check (TESTING §4.5) with macOS PDFKit on Android-made files: protected = locked, wrong password refused, AES-256 (V5 R6 AESV3), signed/watermarked render correctly on rotated pages. ⚠️ Not done: Acrobat (not installed), iOS-made files (Xcode), the owner's wording review.
- [~] **T11.10 Regression R1–R58** on the Android emulator + a real phone; iOS once Xcode is set up. *Accept:* the pass/fail table in TESTING §4.1. — *Emulator done 2026-10-31* (TESTING §4.6): R49–R58 pass (R49–R53, R55 on real engines; R54 also in macOS PDFKit; R56–R58 widget-level), the 6 new device suites and 12 earlier ones that share changed code pass; host suites 1044 + 30 green. Added `test/widgets/secure_history_test.dart` (R57). Version **1.4.0 (build 5)** (1.2's own bump is still deferred on `release/1.2`). ⚠️ Real phone pass, the release build with PdfBox, the interactive folder-picker suites, Acrobat, iOS (Xcode), ADR-051 and the wording review are the owner's.

**Order:** T11.0 → T11.1 → T11.2 → T11.3 → T11.4 → T11.5 → T11.6 → T11.7 → T11.8 → T11.9 → T11.10. If T11.0 fails for stamping, ship Protect + Unlock as 1.4 and move Sign + Watermark to 1.4.1 behind the fallback path.

---

## 10. Claude Code prompts

**P11-A · Spike (T11.0)**
```
Task T11.0 from docs/features/RELEASE_V1_4.md §9. Time box: 1 day. Build a debug-only screen under lib/debug/ (excluded from release).
Test, on the Android emulator (and iOS if Xcode is available):
1) PDFium image object with BGRA alpha via our existing FFI layer: does transparency survive? Output size per stamped page.
2) The §4.4 placement maths on PDF-04 (rotated pages) and a new PDF-15 with an inset crop box.
3) Protect with PdfBox-Android 2.0.27.0 (AES-256) and with iOS PDFKit; inspect the /Encrypt dictionary of each output; try a non-ASCII password.
4) Unlock via pdfrx/PDFium FPDF_REMOVE_SECURITY, and via each native library.
5) Release build with R8: PdfBox still works; APK size delta.
Report PASS/FAIL with measurements, and update ADR-048 and ADR-049 in DECISIONS.md with the exact API calls that worked and their package versions.
Don't write production code. Don't log any password.
```

**P11-B · Security core + Protect/Unlock (T11.2–T11.4)**
```
Tasks T11.2, T11.3, T11.4 per docs/features/RELEASE_V1_4.md §2.3, §2.4, §3 (S37, S38), §4.5, §4.6, §5.
Hard rules: passwords never stored, logged, put in history optionsJson or drafts; cleared on Result/Cancel/Error; native code never logs arguments (add the CI grep in §4.6). No bypass or guessing code paths of any kind.
Write the unit tests and the on-device round-trip tests first (§8.1 hygiene, §8.3 rows 1–4). Add the "Unlock it first" action to every existing tool that rejects encrypted PDFs.
Bottom banner on S37/S38 with the 24 dp gap; it hides while the keyboard is open.
List the planned files first. Report the commands you ran and their real results.
```

**P11-C · Stamper + signature creator (T11.5–T11.6)**
```
Tasks T11.5 and T11.6 per RELEASE_V1_4.md §4.2, §4.3, §4.4, §4.7, §5.
Use the stamping path decided in ADR-048. Unit-test the §4.4 maths for all 4 rotations with a crop-box offset before wiring the UI.
S34 is full screen with NO ads. Saved signatures are opt-in, max 3, excluded from iCloud and Android backups.
Report the commands you ran and their real results, including the on-device accuracy test on PDF-04 and PDF-15.
```

**P11-D · Sign + Watermark screens (T11.7–T11.8)**
```
Tasks T11.7 and T11.8 per RELEASE_V1_4.md §2.1, §2.2, §3 (S33, S35, S36), §4.8.
S35 (placement editor) has NO ads; S33/S36 have the Tools bottom banner with the 24 dp gap.
The watermark preview composites in Flutter (no PDFium call per slider change). Text watermarks are rendered to images (any script).
Add the accessible "Move to / Bigger / Smaller / Rotate" alternatives to dragging.
Run regression R49–R53 on the emulator and record the 300-page watermark timing in TESTING.md §6. Report real results.
```

**P11-E · Privacy, store, regression (T11.9–T11.10)**
```
Tasks T11.9 and T11.10 per RELEASE_V1_4.md §6, §7, §8.5.
Update the privacy policy, S17, licences (PdfBox-Android NOTICE, the 3 fonts), COPY.md, ARCHITECTURE.md and TESTING.md.
Draft the App Store export-compliance answers for 1.4 and list the exact questions I must answer in App Store Connect (mark anything you're unsure about "verify").
Run R1–R58 on the Android emulator; report a pass/fail table. Fix only clear bugs; list anything else for me.
```

---

## 11. Risks & decisions

### 11.1 Risks

| Risk | Impact | Mitigation |
|---|---|---|
| PDFium doesn't keep alpha on inserted images | Signatures appear in white boxes | T11.0 gate; fallbacks in §4.2; ship Protect/Unlock first if needed |
| PdfBox-Android is not actively maintained (last seen 2.0.27.0) | Future Android/AGP incompatibility, unpatched bugs | Isolate it behind `PdfSecurity`; keep the PDFium unlock path; revisit if a build breaks (ADR-049 lists the alternatives: a newer fork, or Android's platform PDF APIs if they gain encryption) |
| iOS PDFKit writes weaker encryption than AES-256 on some OS versions | Protection weaker than advertised | T11.0 inspects `/Encrypt`; if not AES-256, say "password protected" (not "AES-256") in the UI, and record it |
| Users think the signature is legally certified | Misuse / complaints | FR-SIG-11 copy on S33 and in ⓘ; no "legally binding" wording anywhere, including the store listing |
| Users forget passwords | 1-star reviews ("can't open my file") | FR-PRT-04 always-visible warning; the original is untouched, so they still have it |
| Stamp duplication bloats big PDFs | Large outputs | Per-page size check in T11.0; dpi reduction for tile mode |
| Store reviewers see "Unlock PDF" as a cracking tool | Rejection | Copy is explicit ("Remove a password you know"); no bypass keywords; review notes explain the password is required |
| Export compliance answered incorrectly | Delayed release | ADR-051 + verify against Apple's current questions before submitting 1.4 |

### 11.2 Decisions (merged into DECISIONS.md as ADR-048–053)

**ADR-048 — Stamping via PDFium page objects · Proposed (decided by T11.0)**
*Context:* Sign and Watermark must add images to existing pages on both platforms without re-rendering pages. *Decision:* use PDFium FFI image objects (`FPDFPageObj_NewImageObj` + `FPDFImageObj_SetBitmap` + matrix), with text rendered to transparent PNGs in Flutter. *Fallback:* native per-platform insertion if alpha isn't preserved. *Consequences:* one implementation for both OSes; text watermarks aren't searchable.

**ADR-049 — Encryption via platform/native libraries · Proposed (decided by T11.0)**
*Context:* PDFium can't encrypt. *Decision:* iOS PDFKit write options; Android PdfBox-Android (Apache-2.0) with AES-256; owner password random and discarded; Unlock prefers PDFium `FPDF_REMOVE_SECURITY`, then native. *Consequences:* +3–5 MB on Android; dependency on a library whose last seen release is 2.0.27.0 (maintenance risk accepted; isolated behind `PdfSecurity`).

**ADR-050 — Saved signatures are opt-in, local-only and excluded from backups · Accepted**
*Decision:* default "Not now"; max 3; `appSupport/signatures/`, excluded from iCloud and Android Auto Backup; deleted immediately on request. *Consequences:* a signature is lost on a phone change; acceptable for a sensitive artefact.

**ADR-051 — Export compliance for 1.4 · Open**
*Decision needed before submitting 1.4:* how to answer App Store Connect's encryption questions now that the app encrypts user files (AES via OS/standard libraries). Verify Apple's current exemption criteria; update `ITSAppUsesNonExemptEncryption` only according to that answer.

**ADR-052 — Visual signatures only · Accepted**
*Decision:* no certificate-based digital signatures in 1.4; the UI says so. *Revisit* if users ask for PAdES (it would need certificate management and a different library).

**ADR-053 — No bypass, ever · Accepted** (reaffirms DECISIONS and the PRD exclusions)
*Decision:* Unlock requires the correct password; no guessing, dictionary, retries or "recovery"; no keywords suggesting otherwise. *Consequences:* a smaller feature set than some competitors; protects store standing and trust.
