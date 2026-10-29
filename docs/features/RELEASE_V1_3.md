# DocuKit 1.3 — Text Recognition (OCR)

> Milestone **M10** · tasks **T10.x** · requirements **FR-OCR-*** · screens **S30–S32** · regressions **R43–R48** · ADRs **ADR-044–047** (DECISIONS.md).
> Read `docs/FULL_PRODUCT.md` §4 first. Every rule in `CLAUDE.md` still applies.

## 1. Summary and scope

Version 1.3 adds **Text Recognition**, which finds the text in photos and scanned PDFs, entirely on the device. The user can:

- **make a searchable PDF**: the page images stay exactly as they look, with an invisible text layer on top, so the text can be searched, selected and copied in any PDF viewer;
- **review and copy the text**, page by page, then copy it all or share it as plain text;
- **save it as a `.txt` file**.

It also adds a **"Make searchable"** switch to the scanner's review screen (from 1.2), so a scan can become a searchable PDF in one step.

### 1.1 In scope
| Item | Notes |
|---|---|
| Inputs: 1–50 images (JPG, PNG, WebP, HEIC) **or** one PDF (≤ 300 pages) | A PDF that already has text on every page is detected and the user is told; pages that already have text are skipped |
| Outputs: Searchable PDF, Review & copy text, Save `.txt` | The user picks one or more; at least one is required |
| Languages: Latin (default) + the optional scripts shipped at launch (ADR-045) | Chosen per job; the default comes from Settings |
| Determinate progress per page; cancel between pages | Never a fake percentage |
| Low-text warning | When a page yields little or no text |
| Scanner hook | "Make searchable" toggle on Scan Review (S29 in RELEASE_V1_2), wired to `ScanOptions.makeSearchable` (the 1.2 hook, ADR-043) |
| Tool search synonyms + a tour step | §3.5, §7 |

### 1.2 Out of scope (later or never)
- Handwriting recognition, tables-to-spreadsheet, translation.
- OCR on PDFs that are password-protected (they're refused, as everywhere).
- Editing text **inside** the PDF. The review screen edits only the text that's copied or saved as `.txt`; it never changes the PDF's text layer.
- Cloud OCR of any kind (core promise: files never leave the phone).
- Keeping OCR text anywhere except the outputs the user chooses. The v1.5 Library index will add that, under its own rules.

## 2. Requirements

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-OCR-01 | P0 | Accept images or one PDF | 1–50 images (mixed formats OK) or exactly 1 PDF of ≤ 300 pages; mixing images and a PDF is refused with "Choose images or one PDF, not both." Password-protected PDFs: the existing 🔒 badge, blocked |
| FR-OCR-02 | P0 | Detect PDFs that already have text | During validation, check every page for extractable text (§4.6). All pages have text → info banner "This PDF already has text you can search and copy." Run stays enabled only for **Review & copy** and **.txt** (the text is extracted directly, with no OCR). Some pages have text → banner "{n} of {total} pages already have text. Only the other pages will be recognised." |
| FR-OCR-03 | P0 | Choose outputs | Three checkboxes: Searchable PDF (default on), Review & copy text (default on), Save as .txt (default off). The Run button is disabled when none is ticked, with the helper "Choose at least one result" |
| FR-OCR-04 | P0 | Choose the language set | "Text language": Latin (English, Spanish, French, …) is the default; each optional script shipped at launch is listed (e.g. Hindi/Marathi → Devanagari). Exactly one script per job (ML Kit recognisers are per script). The default comes from Settings |
| FR-OCR-05 | P0 | Searchable PDF matches the input visually | Each output page shows the source image (EXIF-oriented, at the source's pixels up to a 300 dpi cap) at the same page size rules as Images to PDF (§4.4). The text layer is invisible: a pixel diff of the output page rendered vs. the image-only page rendered is ≤ 1% (§8) |
| FR-OCR-06 | P0 | The text layer is positioned and searchable | Searching the output with pdfrx text extraction finds ≥ 95% of the words in the accuracy fixtures; each found word's bounding box overlaps its ground-truth box by ≥ 50% (IoU) |
| FR-OCR-07 | P0 | PDF input pages | Image-only pages are rendered at 300 dpi (200 dpi if the page is larger than A3 or memory is low), recognised, and rebuilt as image + text. Pages that already have text are copied **unchanged** into the output (pdfrx page import). Before running: warning "Recognised pages are rebuilt from images. Links and form fields on those pages won't work." |
| FR-OCR-08 | P0 | Review & copy text (S31) | Per-page text in a pager; **Copy page**, **Copy all**, **Share text**, **Save as .txt**; text editable in the review screen only (it doesn't change the PDF); "Edited" marker per page; leaving with edits → D4 |
| FR-OCR-09 | P0 | `.txt` output | UTF-8, LF line breaks, pages separated by `\n\n--- Page {n} ---\n\n`; reading order = block order (top-to-bottom, left-to-right per §4.5); name `<base>_text.txt` |
| FR-OCR-10 | P0 | Truthful progress and cancel | Determinate "Recognising page {n} of {total}"; cancel takes effect between pages; cancelling leaves no output and no history success |
| FR-OCR-11 | P0 | Low-text warning | A page with < 3 recognised words gets "Little or no text found on page {n}"; all pages under the threshold → result banner "We couldn't find much text. Try a sharper photo, or check the language." The job still succeeds if a searchable PDF was requested (image pages are kept) |
| FR-OCR-12 | P0 | Bounded memory | Only one page image is decoded at a time; peak extra memory for a 50-page job is ≤ 250 MB on the reference emulator (measured, TESTING §6) |
| FR-OCR-13 | P0 | Scanner integration | Scan Review (S29) gets a "Make searchable" switch (default off; remembered). On → after the scan is saved as PDF, the same OCR pipeline runs on the scanned pages before Result. Only available when the scan output is PDF |
| FR-OCR-14 | P0 | Privacy of text | OCR text is never logged, never put in history `optionsJson`, and never written anywhere except the outputs the user chose. The temporary per-page text files live in the job's work dir and are deleted with it |
| FR-OCR-15 | P1 | Rotated pages | Pages photographed sideways: if a page yields < 3 words, retry once with the image rotated 90°, 180° and 270°; keep the rotation with the most words (and rotate the output page image to match). Off when the job has > 20 pages (time budget) |
| FR-OCR-16 | P1 | Copy from Result | The Result screen of an OCR job shows "{words} words found" and a **Copy text** button when text output was chosen |
| FR-OCR-17 | P1 | History "Run again" | Options (outputs, language) are restorable; text is not stored |
| FR-OCR-18 | P2 | Per-word confidence highlighting in Review | Words below the confidence threshold (if the API exposes confidence: verify) underlined |

## 3. Screens

### 3.1 S30 — Text Recognition (tool screen) `/tool/ocr`

Uses `ToolScaffold`, `InputsSection` and `OptionGroup`. Bottom banner `ADMOB_BANNER_TOOLS`, with the 24 dp gap + divider under the main button (ADR-035).

```
┌──────────────────────────────────────┐
│ ←  Text Recognition            ⓘ     │
│ ▬▬▬▬ scan gradient strip ▬▬▬▬▬▬▬▬▬▬▬ │
├──────────────────────────────────────┤
│ Files                          + Add │  InputsSection (images grid or 1 PDF tile)
│ ┌──────────────────────────────────┐ │
│ │ 📄 scanned_notes.pdf  12 pages    │ │
│ │    No text yet · 8.4 MB           │ │  text-detection badge (§4.6)
│ └──────────────────────────────────┘ │
│ ⓘ Recognised pages are rebuilt from  │  shown for PDF inputs
│   images. Links won't work there.    │
│                                      │
│ ┌ Results ──────────────────────────┐│  OptionGroup card
│ │ ☑ Searchable PDF                  ││
│ │ ☑ Review and copy text            ││
│ │ ☐ Save as .txt                    ││
│ └───────────────────────────────────┘│
│ ┌ Text language ────────────────────┐│
│ │ Latin (English, Spanish, …)    ▾  ││  DropdownMenu
│ └───────────────────────────────────┘│
├──────────────────────────────────────┤
│ [        Recognise text (12 pages)  ]│  PrimaryActionBar
│ ────────── 24 dp gap + divider ───── │
│ [ Test Ad banner (Tools) ]           │
└──────────────────────────────────────┘
```

**States**

| State | Behaviour |
|---|---|
| Empty | `PickerDropCard` with two buttons: "Choose images" (Photo picker) and "Choose PDF" (document picker); line "Up to 50 images or one PDF" |
| Validating a PDF | The tile shows "Checking for text…" with a small spinner (text detection runs in the background; Run is disabled until it finishes) |
| PDF already fully text | Info banner (FR-OCR-02); "Searchable PDF" checkbox disabled with the hint "Already searchable"; Run label "Get text" |
| Mixed PDF | Info banner with counts; Run label "Recognise text ({n} pages)", where n = pages without text |
| Images > 50 | First 50 kept + the existing truncation snackbar |
| No output ticked | Run disabled + helper "Choose at least one result" |
| Script pack missing (Android unbundled model not yet downloaded: spike outcome) | Inline note "The {language} text model downloads once from Google Play (about {size})" + a progress state on first run; offline → error `ocrModelUnavailable` (§7) |
| Large job (> 30 pages) | Info line "This may take a few minutes. Keep DocuKit open." |

**Platform notes:** identical UI. iOS has no model-download state (models are bundled).
**A11y:** every checkbox labelled; the language dropdown reads "Text language, Latin"; the text-detection badge is part of the file tile's semantics.

### 3.2 Processing (S10, existing)

Step keys: `step_ocr_preparing`, `step_ocr_page` ("Recognising page {n} of {total}"), `step_ocr_building` ("Building searchable PDF…"), `step_checking`. Determinate by page. Cancel works between pages. No ads (existing rule).

### 3.3 S31 — Review text `/job/:jobId/text`

Opened from Result ("Review text"), or straight after processing when "Review and copy text" was the only output. **No ads on this screen** (FULL_PRODUCT §4.4; it's a full-screen editor).

```
┌──────────────────────────────────────┐
│ ←  Review text            Copy all ⧉ │
├──────────────────────────────────────┤
│  ◀  Page 3 of 12  ▶      Edited •    │  pager header; swipe between pages
│ ┌──────────────────────────────────┐ │
│ │ [page thumbnail, 25% height,      │ │  tap → full image with word boxes overlay
│ │  tap to enlarge]                  │ │  (P1: highlights recognised lines)
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ Meeting notes — 14 March          │ │  multiline TextField, selectable,
│ │ Budget approved for Q2.           │ │  editable; monospace off; 16 sp
│ │ ...                               │ │
│ └──────────────────────────────────┘ │
│ ⚠ Little or no text found on this    │  per-page low-text banner (FR-OCR-11)
│   page.                              │
├──────────────────────────────────────┤
│ [ ⧉ Copy page ] [ ⇪ Share ] [ ⬇ .txt ]│  tonal buttons row
└──────────────────────────────────────┘
```

- **Copy all** joins the pages with blank lines (no page markers, unlike `.txt`).
- **Share** sends plain text (`share_plus` `ShareParams(text: …)`). If the text exceeds 100,000 characters, it shares a `.txt` file instead, with the snackbar "Shared as a text file because it's long".
- **.txt** saves through the existing Save flow (S12) with the edited text.
- Edits live in the controller only. Back with edits → D4 "Discard your text changes?".
- Big text: each page's field is lazily built; total text above 2 MB keeps editing off, with the note "Text is too long to edit here. You can still copy or save it."
- **A11y:** the pager announces "Page 3 of 12"; buttons have labels; the text field supports the screen reader's text navigation.

### 3.4 S32 — Result for OCR (existing S11, extended)

- Preview: the first page of the searchable PDF (or, text-only jobs, the first 6 lines of text in a card).
- Stats line: "{pages} pages · {words} words found" (+ "· {n} pages with little text" in warning colour).
- Actions: the existing Save/Share/Open with (PDF) + **Review text** + **Copy text** (FR-OCR-16) when text output was chosen.
- Ads unchanged: AD-2 card, AD-3 interstitial on Done, Main bottom banner.

### 3.5 Scan Review hook (S29, owned by RELEASE_V1_2)

Add one row under the output-format choice:

```
│ Make searchable (recognise text)  [ ○ ] │  Switch.adaptive; visible only when output = PDF
│ Language: Latin ▾                       │  appears when the switch is on
```
When on, the scan job's `execute` calls `OcrPipeline.run(pages, ...)` after building page images, and the scan's output becomes the searchable PDF. Progress: scan steps, then the OCR steps. The setting key is `scan_make_searchable`.

### 3.6 Home, search, tour
- ToolCard: icon `document_scanner`/`text_fields` in the **scan** gradient, title "Text Recognition", subtitle "Find text in photos and scans".
- Search keywords: `ocr, text recognition, recognize text, recognise text, extract text, copy text, scan to text, image to text, picture to text, photo to text, searchable pdf, make pdf searchable, read text, text from image, convert to text, txt`.
- Tour (TOUR.md FR-TOUR-10 "What's new" with a `tour_version` bump): step "Text Recognition: Find the text in photos and scans. Copy it, or make a PDF you can search." Example: "Turn a photo of notes into text you can paste."
- Quick action (optional, UI_REFRESH §2.1): "Photo to text" → `/tool/ocr?outputs=text`.

## 4. Implementation

### 4.1 Packages

| Package | Licence | Purpose | Verify |
|---|---|---|---|
| `google_mlkit_text_recognition` | MIT (plugin) + Google ML Kit terms | On-device recognition, Android + iOS | Version, Android bundled vs. unbundled model behaviour, size per script, iOS deployment target (15.5) |
| `pdf` (existing) | Apache-2.0 | Builds the searchable PDF: image + invisible text | That `PdfTextRenderingMode.invisible` exists and how to set it (`PdfGraphics.setTextRenderingMode` or the `drawString(..., mode:)` param), plus TTF embedding with subsetting |
| `pdfrx` (existing) | MIT / PDFium BSD | Render PDF pages; extract existing text; import unchanged pages; validate output | The page text API name (e.g. `PdfPage.loadText()` / `loadStructuredText()`) |
| Noto Sans (Latin) + Noto Sans Devanagari (and any other launch script) | SIL OFL 1.1 | Embedded fonts for the text layer | Add to the licences page. Bundle only the regular weight |

No other new dependencies. `image` (existing) is used for the rotation retry (FR-OCR-15) inside an isolate.

### 4.2 `TextRecognizer` interface (`lib/core/ocr/`)

```dart
enum OcrScript { latin, devanagari, chinese, japanese, korean }

class OcrWord {
  final String text;
  final Rect box;            // image pixel coordinates (oriented image)
  final List<Offset> corners; // 4 points, for skewed text
}

class OcrLine {
  final String text;
  final Rect box;
  final List<Offset> corners;
  final List<OcrWord> words;
}

class OcrPage {
  final int imageWidth, imageHeight; // oriented pixel size actually recognised
  final List<OcrLine> lines;         // reading order (§4.5)
  int get wordCount => lines.fold(0, (n, l) => n + l.words.length);
  String get text => lines.map((l) => l.text).join('\n');
}

abstract interface class TextRecognizer {
  /// Available scripts on this device/build (bundled or downloadable).
  Future<Set<OcrScript>> availableScripts();
  /// Ensures the model for [script] is present (Android unbundled download). Throws AppError(ocrModelUnavailable).
  Future<void> ensureModel(OcrScript script);
  /// Recognises one oriented image file. Must not hold more than one decoded image.
  Future<OcrPage> recognize(String imagePath, OcrScript script);
  Future<void> dispose();
}
```

`MlKitTextRecognizer` wraps `TextRecognizer(script: TextRecognitionScript.x)` from the plugin, using `InputImage.fromFilePath(path)`. One recogniser instance per job, closed in `dispose()`. Elements become `OcrWord`s; lines become `OcrLine`s. **Mapping rule:** ML Kit returns boxes in the coordinate space of the image *as passed*. We always pass an already-oriented JPEG (EXIF applied, orientation tag 1), so the boxes are in oriented pixels. Never pass a raw camera file with an EXIF rotation; the box space would be ambiguous between platforms (spike checks this).

A `FakeTextRecognizer` returns fixed `OcrPage`s for widget/unit tests.

### 4.3 The OCR pipeline (`features/ocr/application/ocr_pipeline.dart`)

```
OcrPipeline.run(inputs, options, ctx):
  pages = expandInputs(inputs)                 // images → 1 page each; PDF → page list with hasText flags (§4.6)
  todo  = pages.where(!hasText)
  ensureModel(options.script)                  // may download (Android); report Indeterminate('step_ocr_preparing')
  results = []                                 // per page: OcrPageRef (path to small JSON in work dir), not kept in memory
  for (i, p) in pages:
     ctx.cancel.throwIfCancelled()
     ctx.report(Determinate(i, pages.length, 'step_ocr_page'))
     if p.hasText:
        results.add(ExistingTextPage(p))       // text extracted via pdfrx when text output requested
        continue
     img = prepareImage(p)                     // §4.4 → oriented JPEG in work dir, capped dpi
     ocr = recognizer.recognize(img.path, script)
     if options.rotateRetry && ocr.wordCount < 3 && pages.length ≤ 20:
        ocr, img = bestOfRotations(img, [90,180,270])   // FR-OCR-15
     writeJson(work/ocr_<i>.json, ocr)         // text stays on disk in work dir only
     results.add(OcrPageRef(img.path, json, ocr.wordCount))
     // drop references → only one decoded image ever alive
  if options.searchablePdf:
     ctx.report(Indeterminate('step_ocr_building'))
     SearchablePdfBuilder.build(results, pages, options, out: work/out.pdf, ctx)
  if options.textOutputs:
     writeTxt(work/out.txt, results)           // also feeds the Review screen through a file, not memory
  return MultiOutput(pdf?, txt?, stats: {pages, words, lowTextPages})
```

The Review screen (S31) loads per-page text lazily from `ocr_<i>.json` (or `out.txt` sections). The job's work dir is kept until the user leaves Result/Review, then deleted (the existing cleanup rule, extended).

### 4.4 Page images and page size

- **Image inputs:** reuse `ImageEngine.transform` to make an oriented JPEG (q 85), downscaled so the long edge ≤ 4,000 px (ML Kit doesn't benefit from more; it bounds memory). The page size follows the **Images to PDF** "Same as image" rule (`pt = px × 72 / 150`, clamped), unless the scanner passes explicit page sizes (A4/Letter from S29), in which case it uses Fit as in FEATURE_SPECS §3.6.
- **PDF inputs:** render each page with pdfrx at `dpi = 300` (or 200 when the page is > A3 or the device RAM class is "low"); the output page keeps the **original page size in points**; the image is drawn full-bleed.
- **Rotation:** the output page image is always upright as recognised. If the PDF page had `/Rotate`, the render already applies it; the output page has `/Rotate 0` and swapped width/height where needed.

### 4.5 Coordinate mapping and reading order **[unit]**

The image is drawn into the page rect `R = (x0, y0, w, h)` in PDF points (origin bottom-left). The image is `W × H` pixels (top-left origin).

```
sx = w / W ; sy = h / H
toPdfRect(box) =                         // box in image pixels: left, top, right, bottom
  Rect.fromLTRB(
    x0 + box.left   * sx,
    y0 + (H - box.bottom) * sy,          // flip y
    x0 + box.right  * sx,
    y0 + (H - box.top) * sy)
```

Skewed lines (when the corner points show an angle > 2°): compute `θ = atan2(c1.y − c0.y, c1.x − c0.x)` from the top edge in image space; in PDF space the angle is `−θ` (y flipped). Place the text with a text matrix `[cos, sin, −sin, cos, x, y]` at the bottom-left corner mapped with the same transform.

**Reading order** (used for `.txt`, Copy all and the line order in the text layer): sort lines by `top` and group them into rows when the vertical overlap is > 50% of the smaller height; within a row, sort by `left`. Two-column detection is P2 (keep the ML Kit block order when blocks don't overlap horizontally: blocks are sorted by their own top-left first, then the lines within each block).

### 4.6 Detecting existing text in a PDF

```
pageHasText(page):
  t = await page.loadText()            // pdfrx text API: verify the exact name and return type
  return t.fullText.replaceAll(RegExp(r'\s'), '').length >= 20
```
Run this during validation, in the background, for up to 300 pages (it's fast: text extraction, no rendering). Store the per-page boolean in `PickedFile.meta` (`textPages: List<bool>`). Pages that have text but where the user wants text output: extract with the same API (no OCR).

### 4.7 Building the invisible text layer **[unit + integration]**

Built with the `pdf` package inside `Isolate.run` (the page images are passed as **file paths**; the isolate reads one at a time and writes the document in chunks of 20 pages, merged with pdfrx, matching ADR-012's chunking rule).

```
for each page result r (in order):
  if r is ExistingTextPage:
     mark: copy the source page unchanged in the merge step (pdfrx page import), skip building
     continue
  page = PdfPage(doc, pageFormat: PdfPageFormat(wPt, hPt))
  g = page.getGraphics()
  g.drawImage(PdfImage.jpeg(doc, image: bytes(r.imagePath)), x0, y0, w, h)
  g.saveContext()
  g.setTextRenderingMode(PdfTextRenderingMode.invisible)   // VERIFY exact API (may be a drawString `mode:` param)
  for line in r.lines:
     font = fontFor(script)                                // embedded TTF (§4.8)
     rect = toPdfRect(line.box)
     size = clamp(rect.height * 0.85, 4, 200)              // pt
     // fit horizontally so selection highlights match the line on screen:
     natural = font.stringMetrics(line.text).width * size
     hScale  = natural > 0 ? rect.width / natural : 1      // horizontal scaling (Tz) 0.5–2.0 clamp
     g.setHorizontalScaling(hScale * 100)                  // VERIFY: may need a raw "Tz" operator via g.buf
     if angle(line) > 2°: g.setTransform(rotation about rect.bottomLeft)
     g.drawString(font, size, line.text, rect.left, rect.bottom + size*0.15)
     reset transform
  g.restoreContext()
```

Per-word placement (P1, improves selection accuracy for long lines): place each `OcrWord` separately when the line has > 12 words or the line's words have uneven spacing (variance of gaps > 2× the median). Default: per line with horizontal scaling, which is simpler and stays accurate for normal text.

**Why invisible text (render mode 3):** the page looks exactly like the image (FR-OCR-05), while viewers can search, select and copy. This is the standard technique used by OCR tools.

### 4.8 Fonts and subsetting

- Bundle `NotoSans-Regular.ttf` (Latin; also covers Latin Extended, Greek and Cyrillic) and, per ADR-045, `NotoSansDevanagari-Regular.ttf`. Add CJK only if those scripts ship. A full CJK font is large (≥ 15 MB), so CJK needs subsetting or is deferred.
- Load with `pw.Font.ttf(ByteData)`. Verify whether the `pdf` package subsets embedded TTFs automatically. If it embeds the whole font, the per-document cost is ~0.5 MB (Latin) and ~0.3–1 MB (Devanagari), acceptable for v1.3. A full CJK font would not be acceptable.
- Characters the font lacks are replaced with U+FFFD in the text layer only (never crash), and counted in the logs as a code-only event `ocr_glyph_missing`.
- Devanagari shaping: invisible text doesn't need correct visual shaping, but **search** depends on the stored Unicode sequence, which the `pdf` package writes from the input string. The spike checks that a Devanagari word written this way is found by pdfrx search.

### 4.9 Memory and performance
- One decoded image at a time (§4.3); OCR results go to disk as JSON per page.
- The PDF build is chunked (20 pages) in an isolate, reading the JPEGs from disk.
- Recognition time is roughly 0.5–2 s per page on mid-range phones (measure in the spike; never promised in the UI).
- `didHaveMemoryPressure` → finish the current page, then lower the render dpi to 200 for the remaining pages (logged as code `ocr_dpi_lowered`).

### 4.10 Output validation (extends ARCHITECTURE §5.4)

| Output | Check |
|---|---|
| Searchable PDF | Opens with pdfrx; page count == input pages; text extraction on the first recognised page returns ≥ 1 word if that page's OCR found ≥ 1 word; the first page renders |
| `.txt` | Exists, is valid UTF-8, and has the page markers expected for the page count |

### 4.11 Errors (add to the `AppErrorCode` enum)

| Code | When | Copy key |
|---|---|---|
| `ocrModelUnavailable` | The Android model can't be downloaded (offline / no Play services) or the script isn't available | `err_ocrModelUnavailable_*` |
| `ocrNothingToDo` | The PDF has text on every page and only "Searchable PDF" was ticked | handled as a disabled state, not an error |
| (existing) `encryptedDocument`, `corruptFile`, `tooManyFiles`, `outOfMemory`, `insufficientStorage` | as today | existing |

## 5. Data model and settings

**Settings keys** (ARCHITECTURE §8.1):

| Key | Type | Default |
|---|---|---|
| `ocr_script` | `latin|devanagari|…` | `latin` (or the locale's script if it ships, e.g. `hi`/`mr` → devanagari) |
| `ocr_outputs` | json `{pdf, review, txt}` | `{pdf: true, review: true, txt: false}` |
| `ocr_rotate_retry` | bool | true |
| `scan_make_searchable` | bool | false |

**History:** `tool = ocr`; `optionsJson = {outputs, script}` only, never text. `outputMetaJson = {pages, words, lowTextPages}`. A text-only job with no file output (review/copy only) still records a history row with `outputRelPath = null` and the status SUCCESS. Its row shows "Text only, not saved".

**Settings screen:** under "Defaults" add **Text recognition language**.

## 6. Permissions, privacy and store impact

| Item | Change |
|---|---|
| Permissions | None new |
| **iOS deployment target** | **15.0 → 15.5** (required by the ML Kit text recognition pod). Update Xcode settings, `Podfile` (`platform :ios, '15.5'`), and RELEASE.md/PRD compatibility rows. Users on iOS 15.0–15.4 stop receiving updates (ADR-044) |
| Android minSdk | Unchanged (26 ≥ 21) |
| Network | ML Kit may download models through Google Play services (Android, unbundled) and may send anonymous performance metrics. **Verify** Google's "ML Kit data disclosure" page and update the Play Data safety answers (likely App info & performance → Diagnostics, collected, not shared, for analytics) and the App Store privacy label if the iOS SDK collects anything |
| Privacy text | Add to Privacy & About: "Text recognition runs on your phone. DocuKit doesn't upload your files or the text found in them." |
| Ads | S30: bottom Tools banner; S31: none; Result: existing |

**App size (estimates; T10.0 measures them):**

| Item | Android | iOS |
|---|---|---|
| ML Kit Latin model | ~0 if unbundled (Play services); ~4 MB if bundled | ~10–15 MB |
| Each extra script (Devanagari etc.) | ~0 unbundled; ~4–6 MB bundled | ~5–15 MB each |
| Noto Sans + Noto Sans Devanagari | ~0.8 MB | ~0.8 MB |

Decision rule (ADR-045): ship Latin on both platforms; add Devanagari if the iOS download size stays under **60 MB** total. Others in a later update.

## 7. Copy (add to COPY.md)

| Key | Text |
|---|---|
| tool_ocr_title / subtitle | Text Recognition / Find text in photos and scans |
| ocr_pick_images / pick_pdf | Choose images / Choose PDF |
| ocr_pick_hint | Up to 50 images or one PDF |
| ocr_mix_refused | Choose images or one PDF, not both. |
| ocr_checking_text | Checking for text… |
| ocr_badge_no_text / has_text / partial | No text yet / Already has text / Text on {n} of {total} pages |
| ocr_pdf_has_text | This PDF already has text you can search and copy. |
| ocr_pdf_partial | {n} of {total} pages already have text. Only the other pages will be recognised. |
| ocr_pdf_rebuild_note | Recognised pages are rebuilt from images. Links and form fields on those pages won't work. |
| ocr_results_header | Results |
| ocr_out_pdf / review / txt | Searchable PDF / Review and copy text / Save as .txt |
| ocr_out_pdf_disabled | Already searchable |
| ocr_need_output | Choose at least one result |
| ocr_language | Text language |
| ocr_lang_latin / devanagari / chinese / japanese / korean | Latin (English, Spanish, French…) / Devanagari (Hindi, Marathi…) / Chinese / Japanese / Korean |
| ocr_model_download | The {language} text model downloads once from Google Play (about {size}). |
| ocr_long_job | This may take a few minutes. Keep DocuKit open. |
| ocr_run | Recognise text ({count, plural, =1{1 page} other{# pages}}) |
| ocr_run_get_text | Get text |
| step_ocr_preparing / page / building | Getting text recognition ready… / Recognising page {n} of {total} / Building searchable PDF… |
| ocr_result_stats | {pages} pages · {words} words found |
| ocr_result_low_pages | {n} pages with little text |
| ocr_low_text_page | Little or no text found on page {n}. |
| ocr_low_text_all | We couldn't find much text. Try a sharper photo, or check the language. |
| ocr_review | Review text |
| ocr_copy_text / copy_page / copy_all | Copy text / Copy page / Copy all |
| ocr_copied | Copied |
| ocr_share_text | Share |
| ocr_save_txt | Save .txt |
| ocr_shared_as_file | Shared as a text file because it's long. |
| ocr_edited | Edited |
| ocr_too_long_to_edit | Text is too long to edit here. You can still copy or save it. |
| ocr_discard_edits | Discard your text changes? |
| ocr_text_only_history | Text only, not saved |
| scan_make_searchable | Make searchable (recognise text) |
| set_ocr_language | Text recognition language |
| priv_ocr_p | Text recognition runs on your phone. DocuKit doesn't upload your files or the text found in them. |
| err_ocrModelUnavailable_title / body | Text recognition isn't ready / The {language} model couldn't be downloaded. Connect to the internet once and try again, or choose Latin. |
| tour_ocr_title / body / example | Text Recognition / Find the text in photos and scans. Copy it, or make a PDF you can search. / Turn a photo of notes into text you can paste. |

## 8. Tests

### 8.1 Fixtures (add to `tool/make_fixtures.dart`; no personal documents)

| ID | Fixture | Ground truth |
|---|---|---|
| OCR-01 | Generated A4 image (300 dpi) of 3 paragraphs of known English text, black on white, Noto Sans 12 pt | Text + word boxes from the generator |
| OCR-02 | Same, photographed look: slight blur, 3° skew, uneven lighting (generated with `image` filters) | Same text |
| OCR-03 | Same page rotated 90° (pixels, orientation tag 1) | Same text (tests FR-OCR-15) |
| OCR-04 | EXIF orientation 6 photo of text | Same text (tests the orientation pipeline) |
| OCR-05 | Devanagari text image (if the script ships) | Known Hindi sentence |
| OCR-06 | Blank page / photo with no text | 0 words, low-text warning |
| OCR-07 | 3-page image-only PDF (built from OCR-01/02/06) | Pages 1–2 searchable after |
| OCR-08 | Mixed PDF: page 1 has real text (vector), pages 2–3 are images | Page 1 copied unchanged; pages 2–3 recognised |
| OCR-09 | Fully text PDF (PDF-01 from the corpus) | "Already has text" path |
| OCR-10 | 50-image batch (generated) | Memory + time benchmark |

### 8.2 Test list

| Test | Type |
|---|---|
| `toPdfRect` mapping: corners, y-flip, page offsets, margins, rotated pages | Unit |
| Reading-order sort: rows, columns, overlapping lines | Unit |
| Low-text rule thresholds; output-choice validation; label/plural logic | Unit |
| `.txt` formatting: markers, UTF-8, LF | Unit |
| Pipeline with `FakeTextRecognizer`: cancel between pages, existing-text pages skipped, rotation retry chooses the best, work-dir cleanup | Unit |
| S30 states: empty, checking, fully-text PDF, partial PDF, no output ticked, >50 images | Widget |
| S31: pager, copy page/all (clipboard mock), share long text → file, edits + D4 | Widget |
| No ad slot on S31; Tools banner with gap on S30 | Widget |
| **Searchability:** OCR-01 → searchable PDF → pdfrx text extraction finds ≥ 95% of the words; IoU ≥ 0.5 for found words | Integration (device) |
| **Invisibility:** render the page of the searchable PDF and of an image-only PDF made from the same JPEG; pixel difference ≤ 1% | Integration |
| Mixed PDF OCR-08: page 1's text layer is the original (its extracted text equals the source's), pages 2–3 contain the OCR words | Integration |
| Accuracy smoke: OCR-01 word recall ≥ 95%, OCR-02 ≥ 85% (record actual numbers in TESTING §6) | Integration |
| Memory: OCR-10 peak extra memory ≤ 250 MB | Integration (stress, like i2p_stress_test) |
| Scanner hook: scan → Make searchable → output searchable | Manual + integration with the scanner's fake camera if available |
| Original checksum unchanged for every input | Integration (existing guard) |

### 8.3 Regression additions (TESTING §4)

| # | Steps | Expected |
|---|---|---|
| R43 | OCR a phone photo of a printed page (Latin) → Searchable PDF | Opens in the phone's PDF viewer; searching a word finds it; the page looks identical to the photo |
| R44 | OCR the same photo → Review text → edit → Copy all → paste in Notes; Save .txt | Edited text pasted; .txt opens with the page markers |
| R45 | OCR a scanned PDF with 10+ pages; cancel at page 4; run again to the end | Cancel leaves nothing; the full run's output is searchable |
| R46 | OCR a PDF that already has text (PDF-01) | "Already has text" banner; Get text works without OCR |
| R47 | Scan → Make searchable on → 3 pages | Result PDF searchable |
| R48 | Airplane mode: OCR Latin (and an extra script if bundled); with an unbundled model not yet downloaded → clear error | Works offline for available models; the clear `ocrModelUnavailable` error otherwise |

## 9. Tasks (milestone M10)

- [~] 🔬 **T10.0 OCR spike (1 day — GATE).** On both platforms (iOS once Xcode is available; Android first):
  1. Add `google_mlkit_text_recognition`; bump iOS to 15.5; build.
  2. Measure the app-size increase for Latin and Devanagari (Android bundled vs. unbundled; iOS per-script pods).
  3. Recognise OCR-01/02/04; check that the boxes are in oriented-pixel space on both platforms.
  4. Build a 1-page PDF with the `pdf` package: image + invisible text (find the exact API for render mode 3 and horizontal scaling); confirm pdfrx text search finds the words, for Latin and Devanagari.
  5. Confirm the pdfrx page-text API for §4.6.
  *Accept:* DECISIONS entries for ADR-044 (iOS 15.5), ADR-045 (scripts + bundling), ADR-046 (text-layer API), with measured numbers.
  — *Android done 2026-10-29* (`integration_test/ocr_spike_test.dart`): `google_mlkit_text_recognition` 0.17.1 added; Latin recall 100% (OCR-01, OCR-02, OCR-04), boxes in upright pixels; invisible text with `drawString(mode: PdfTextRenderingMode.invisible, scale:)` → pdfrx finds 100% of the words, 0.000% pixel difference, font subset (+5.6 KB); Devanagari recall and search 100%; `page.loadText()` for §4.6. Size per phone +12.9 MB (Latin, bundled) +0.64 MB (Devanagari). Owner chose bundled models and Latin + Devanagari (ADR-045). iOS raised to 15.5 (ADR-044, C-9 resolved). ⚠️ iOS steps (build, sizes, box space) wait for Xcode.
- [x] **T10.1 `TextRecognizer` + ML Kit implementation + fake.** *Accept:* unit tests with the fake; on-device recognition of OCR-01 returns ≥ 95% of the words. — *Done 2026-10-29:* `lib/core/ocr/text_recognizer.dart` (interface, `OcrScript`, `OcrPage`/`OcrLine`/`OcrWord` with the work-dir JSON form and per-word confidence), `mlkit_text_recognizer.dart` (`MlKitTextRecognizer`: bundled scripts per ADR-045, one recogniser per script per job, oriented-pixel size from the JPEG header, errors as `AppError`), `ocr_labels.dart`; `textRecognizerFactoryProvider` (a new recogniser per job); new error code `ocrModelUnavailable` with its COPY §4/§8.3 text; `FakeTextRecognizer`. 9 unit tests (`test/core/text_recognizer_test.dart`). On the emulator (`integration_test/ocr_recognizer_test.dart`, fixtures in `tool/fixtures/ocr_text.dart`): OCR-01 recall **100%**, 100% of words on their box (IoU ≥ 0.5), Devanagari ≥ 95%, blank page 0 words, a non-image → `corruptFile`.
- [ ] **T10.2 Mapping + reading order + `.txt` writer** (§4.5, FR-OCR-09). *Accept:* unit tests.
- [ ] **T10.3 Existing-text detection** for PDFs (§4.6) wired into validation + the badges. *Accept:* OCR-07/08/09 badges correct.
- [ ] **T10.4 `SearchablePdfBuilder`** (§4.7–4.8), chunked, in an isolate; mixed-PDF page import. *Accept:* the searchability + invisibility + mixed-PDF integration tests.
- [ ] **T10.5 `OcrPipeline` + `OcrOperation`** (progress, cancel, rotation retry, low-text stats, multi-output). *Accept:* pipeline unit tests; FR-OCR-10/11/12/15.
- [ ] **T10.6 S30 tool screen** + catalogue entry, search keywords, category, Tools banner with gap, tour step (`tour_version` bump). *Accept:* widget tests; FR-OCR-01–04.
- [ ] **T10.7 S31 Review text screen + Result extensions** (S32). *Accept:* widget tests; FR-OCR-08/16; no ads on S31.
- [ ] **T10.8 Scanner hook** (FR-OCR-13) on S29 + setting. *Accept:* R47.
- [ ] **T10.9 Settings, privacy copy, error codes, Data safety / privacy label review, iOS 15.5 docs.** *Accept:* RELEASE checklist updated; copy in ARB.
- [ ] **T10.10 Regression R43–R48 + memory benchmark (OCR-10)** on the emulator and a real Android phone; iOS when available.

**Order:** T10.0 → T10.1 → T10.2 → T10.3 → T10.4 → T10.5 → T10.6 → T10.7 → T10.8 → T10.9 → T10.10.

## 10. Claude Code prompts

**P10-A — Spike (T10.0)**
```
Task T10.0 from docs/features/RELEASE_V1_3.md. Time box: 1 day. Throwaway code under lib/debug/ only (kDebugMode).
1. Add google_mlkit_text_recognition (verify the current version on pub.dev). Bump iOS to 15.5 in Xcode, the Podfile and the docs if the plugin requires it.
2. Measure the APK/AAB size increase for Latin and for Devanagari, bundled vs unbundled on Android (report how each is configured), and the iOS increase if Xcode is available.
3. Recognise fixtures OCR-01, OCR-02 and OCR-04 (generate them in tool/make_fixtures.dart). Report word recall and whether the boxes are in oriented-pixel space.
4. Build a 1-page PDF with the pdf package: the image + an invisible text layer. Find the exact API for text render mode 3 and horizontal scaling. Check that pdfrx text extraction finds the words, for Latin and Devanagari.
5. Confirm the pdfrx API for reading existing page text.
Update the DECISIONS entries ADR-044, ADR-045 and ADR-046 with the measured numbers and exact API calls (package versions included). No production code.
```

**P10-B — Engine (T10.1–T10.5)**
```
Tasks T10.1 to T10.5 from docs/features/RELEASE_V1_3.md, one commit each, following the decisions recorded in T10.0.
Write the unit tests first for: toPdfRect mapping (incl. rotated pages), reading order, the .txt format, and the pipeline with FakeTextRecognizer (cancel, existing-text pages, rotation retry, low-text stats).
Rules: one decoded image at a time; OCR text only in the job work dir and the outputs; never log text; chunk the PDF build by 20 pages in an isolate, passing file paths.
Then run the searchability, invisibility and mixed-PDF integration tests on the emulator and report the real numbers (word recall, IoU, pixel diff, peak memory).
```

**P10-C — Screens (T10.6–T10.8)**
```
Tasks T10.6 to T10.8 from docs/features/RELEASE_V1_3.md. Build S30 (Tools bottom banner with the 24 dp gap), S31 Review text (NO ads), the S32 Result extensions, the Home/search/tour entries, and the "Make searchable" switch on Scan Review.
Strings from §7 into app_en.arb. Widget tests for every state in §3.1 and the S31 behaviours. Check 200% text and TalkBack labels.
Report the commands and real results.
```

**P10-D — Release prep (T10.9–T10.10)**
```
Tasks T10.9 and T10.10. Update the privacy copy, the error codes and the Settings entry. Check Google's ML Kit data-disclosure page and tell me exactly what to change in Play Data safety and the App Store privacy label (cite the page). Update the iOS minimum to 15.5 everywhere in docs.
Then run R43–R48 and the OCR-10 memory benchmark on the emulator, and list what still needs a real phone or iOS.
```

## 11. Risks and decisions

| Risk | Impact | Mitigation |
|---|---|---|
| The invisible-text API differs from what's assumed in the `pdf` package | Searchable PDF blocked | T10.0 finds the exact call; fallback: write the text layer with PDFium page objects via `PdfStamper` FFI (shared with 1.4), using `FPDFTextObj_SetTextRenderMode` (invisible) |
| Large iOS size increase from ML Kit models | Bigger download, lower installs | Ship Latin first; add scripts only under the 60 MB rule; measure in T10.0 |
| Android unbundled model needs a first download | OCR fails offline on first use | Clear `ocrModelUnavailable` error; download on the first Text Recognition screen visit if online (with the size shown) |
| Devanagari search fails (Unicode order) | Searchable PDF not searchable for Hindi | T10.0 tests a Devanagari word round-trip; if it fails, ship Devanagari for Review/.txt only and note it in the UI |
| Accuracy on poor photos | User disappointment | The low-text warning, rotation retry, tips ("Try a sharper photo"), and the scanner (1.2) as the recommended input |
| iOS 15.0–15.4 users lose updates | Small audience loss | Recorded in ADR-044; the store keeps serving them the last compatible version |
| Long jobs killed in the background | Lost work | Existing Interrupted state + retry; the "Keep DocuKit open" note for > 30 pages |

### Decisions (merged into DECISIONS.md as ADR-044–047)

**ADR-044 — iOS minimum 15.5 · Proposed (confirm in T10.0)**
*Context:* `google_mlkit_text_recognition` requires an iOS 15.5 deployment target. *Decision:* raise DocuKit's iOS minimum from 15.0 to 15.5 starting with app version 1.3. *Consequences:* devices stuck on iOS 15.0–15.4 keep version 1.2; docs and store notes are updated.

**ADR-045 — OCR scripts and model packaging · Proposed (decided by measurement in T10.0)**
*Decision rule:* Latin on both platforms; Devanagari if the iOS download stays under 60 MB; Android uses unbundled (Play services) models if available through the plugin, otherwise bundled. Chinese/Japanese/Korean later.

**ADR-046 — Searchable PDF construction · Proposed**
*Decision:* image + invisible text (render mode 3) built with the `pdf` package, per line with horizontal scaling (per word for long or uneven lines); embedded Noto fonts; pages that already have text are imported unchanged. Fallback: PDFium page objects via `PdfStamper` (v1.4) if the `pdf` package can't set render mode 3.

**ADR-047 — OCR text privacy · Accepted**
*Decision:* OCR text lives only in the job's work dir (deleted with the job) and in the outputs the user chose. It's never logged, never in history, and never sent anywhere. The v1.5 Library index is the only future place it may be stored, under its own ADR.
