# DocuKit — Release 1.6: Print

Print any PDF or image from DocuKit, with an in-app preview of how it will look on paper (orientation, paper size, pages, pages per sheet, margins), then send it to any printer the phone can reach.

Follows the conventions in `FULL_PRODUCT.md §4`. IDs for this feature: requirements **FR-PRN-xx**, milestone **M13** (tasks **T13.x**), screens **S47–S48**, regressions **R69–R74**, ADRs **ADR-069–071**.

> **Owner decisions (2026-10-31), applied to this copy:** ships as **1.6 after 1.5**, on `release/1.6` branched from `release/1.5` (the spec was first written as a 1.1 add-on); the History line reads **"Sent to printer · n sheets"**, never "Printed" (FR-PRN-12); the ADR placeholders ADR-069/070/C are ADR-069/070/071; the free-disk floor for builds stays 10 GB (not 5 GB).

---

## 1. Summary and scope

**How printing works on phones.** Apps don't talk to printers directly. They hand a print-ready PDF to the operating system, and the system print dialog lists the printers the phone can reach:
- **Android:** the built-in Print Framework. Wi-Fi printers are found by the built-in Default Print Service and Mopria, or by the maker's print-service app (HP, Canon, Epson, Brother…). USB (OTG) and some Bluetooth printers work when the maker's print service supports them. The dialog also offers **Save as PDF**.
- **iOS:** AirPrint. Any AirPrint printer on the same Wi-Fi appears automatically.

So DocuKit supports **every printer the phone itself supports**, with no printer drivers and no permissions of its own.

**In scope**
- A **Print** tool (Home → PDF section) for any PDF or 1–100 images.
- A **Print** action on Result, Operation details, the Incoming chooser and (from 1.5) the My Documents document page.
- An in-app **Print preview** (S48): paper size, orientation, page selection, pages per sheet (1/2/4/6), scaling (fit/actual/fill), margins, and for images, photo layouts including a **passport-photo sheet**.
- Handing the print-ready PDF to the system dialog, where the user picks the printer, copies, colour/black-and-white and two-sided printing.
- A "Can't find your printer?" help sheet.

**Out of scope**
- Portable **thermal/receipt printers** that use their own Bluetooth protocol (ESC/POS) and don't appear in the system print dialog. Each brand needs its own code; a possible future add-on.
- Controlling copies, colour or duplex inside DocuKit. The system dialog does this, adapting to what the chosen printer supports.
- Printer setup or pairing. That's done in the phone's settings or the printer maker's app.
- Confirming that the paper actually came out. Phones only report that the job was handed to the printer.

## 2. Requirements

| ID | Pri | Requirement | Acceptance |
|---|---|---|---|
| FR-PRN-01 | P0 | Print tool accepts one PDF or 1–100 images (JPG, PNG, WebP, HEIC) | Same pickers and validation as the other tools; password-protected PDF → "Unlock it first" (link to Unlock PDF from 1.4) |
| FR-PRN-02 | P0 | Print action on Result (any PDF or image output), Operation details (when the output is available), Incoming chooser | The tap opens S48 with that file preloaded; no re-picking |
| FR-PRN-03 | P0 | Preview shows every output **sheet** as it will print | Swipeable sheet view + thumbnail strip; "Sheet 2 of 5"; updates within 1 s of an option change on a mid-range phone (20-page PDF) |
| FR-PRN-04 | P0 | Paper size: A4, Letter, Legal, A5, 4×6 in, 5×7 in, "Same as document" | Default from the locale (Letter in US/CA/MX/PH, otherwise A4) and remembered |
| FR-PRN-05 | P0 | Orientation: Auto, Portrait, Landscape | Auto picks per sheet from the content's shape; the preview reflects it immediately |
| FR-PRN-06 | P0 | Pages: All, Range ("1-3, 5, 8-10", same parser as Split PDF in 1.1), Odd, Even | Inline validation; invalid range disables Print with a helper text |
| FR-PRN-07 | P0 | Scaling: Fit to page (default), Actual size, Fill page (crop) | Fit never crops; Actual size shows a warning when content is bigger than the paper |
| FR-PRN-08 | P0 | Margins: None, Narrow (6 mm), Normal (12 mm) | Applied to the printable area in the preview and the output |
| FR-PRN-09 | P1 | Pages per sheet: 1, 2, 4, 6 | Grid order left→right, top→bottom; thin cell gap of 4 mm |
| FR-PRN-10 | P1 | Image layouts: Full page (one image per sheet), 2 per sheet, 4 per sheet, **Passport photo sheet** (35×45 mm copies filling the sheet with 2 mm gaps and light cut marks) | Passport photo: uses the first image only; orientation is chosen to fit the most photos; count shown, e.g. "8 photos on 4×6 in" (no margins), "30 photos on A4" (narrow margins) |
| FR-PRN-11 | P0 | Send to the system print dialog | Android: the print dialog opens with the job named after the file; iOS: the AirPrint sheet opens (popover anchored on iPad) |
| FR-PRN-12 | P0 | Report the outcome honestly | "Sent to printer" on completion; nothing on user cancel; "Printing failed. Check that the printer is on and connected." on failure. Never "Printed" |
| FR-PRN-13 | P0 | Originals untouched; the print-ready PDF is a temporary file | Deleted after the dialog closes (Android: after the job reaches a final state or the app restarts) |
| FR-PRN-14 | P0 | Vector quality | PDF text and drawings stay vector in the print-ready PDF (no rasterising) unless the spike T13.0 forces the raster fallback (ADR-070) |
| FR-PRN-15 | P1 | Remember the last print settings | Paper, orientation, scaling, margins, pages per sheet persist; the page range doesn't |
| FR-PRN-16 | P0 | Help: "Can't find your printer?" | Bottom sheet with platform-specific steps (§3.3) |
| FR-PRN-17 | P1 | History | A "Print" entry with the file name, sheet count and outcome (Sent / Failed / Cancelled is not recorded) |
| FR-PRN-18 | P0 | Large documents | Up to 500 pages / 500 MB input; preview renders lazily; building the print PDF runs off the UI isolate with determinate progress (sheets) and Cancel |

## 3. Screens

### S47 · Print tool (`/tool/print`)
Standard `ToolScaffold`, like the other tool screens.
```
┌──────────────────────────────────────┐
│ ←  Print                        ⓘ    │
├──────────────────────────────────────┤
│ ① FILE                                │
│  [ Choose PDF ]   [ Choose images ]   │  two picker cards side by side
│  PDF or up to 100 images              │
│                                       │
│  (after picking: FileTile / image grid│
│   with count, like Images to PDF)     │
├──────────────────────────────────────┤
│ [        Preview & print        ]     │  primary button
│ ─────────── 24 dp gap + divider ───── │
│ [ Bottom banner: ADMOB_BANNER_TOOLS ] │
└──────────────────────────────────────┘
```

### S48 · Print preview (`/print/preview`, also opened from Result/Details/Incoming)
```
┌──────────────────────────────────────┐
│ ←  Print preview        Can't find? ⓘ │
├──────────────────────────────────────┤
│        ┌──────────────────┐           │  Sheet view: white paper on grey,
│        │ ┌──────┐┌──────┐ │           │  dashed line = margins,
│        │ │ p.1  ││ p.2  │ │           │  swipe ← → between sheets,
│        │ └──────┘└──────┘ │           │  pinch to zoom
│        └──────────────────┘           │
│          Sheet 1 of 3                 │
│ [▢][▢][▢]  thumbnail strip            │
├──────────────────────────────────────┤
│ Paper        [A4 ▾]                   │  option cards (scrollable)
│ Orientation  (Auto)(Portrait)(Landscape)
│ Pages        (All)(Range)(Odd)(Even)  │  Range → text field "1-3, 5"
│ Per sheet    (1)(2)(4)(6)             │  PDFs; images show Layout instead
│ Scaling      (Fit)(Actual size)(Fill) │
│ Margins      (None)(Narrow)(Normal)   │
│ ⓘ Copies, colour and two-sided are    │
│   set in the next step.               │
├──────────────────────────────────────┤
│ [          Print 3 sheets         ]   │  primary button → system dialog
│ ─────────── 24 dp gap + divider ───── │
│ [ Bottom banner: ADMOB_BANNER_TOOLS ] │
└──────────────────────────────────────┘
```
- **Image layout** replaces "Per sheet" for image input: Full page · 2 per sheet · 4 per sheet · Passport photo sheet (the passport option sets paper to 4×6 in, margins to None, scaling to Actual size, and shows "8 photos"; with margins on 4×6 the count drops to 6 or 4, and the UI says so).
- **Building state:** while the print PDF is being (re)built, the sheet view shows the previous result dimmed with a small progress ring; options stay usable (the latest change wins).
- **Range error:** the field shows "Enter pages like 1-3, 5" and the Print button is disabled with the helper "Fix the page range".
- **Empty result** (e.g. "Even" on a 1-page PDF): "No pages to print with these settings."
- **After the dialog:** sent → snackbar "Sent to printer"; cancelled → nothing; failed → inline banner with **Try again** and **Can't find your printer?**.
- **Back** with changed settings: no D4 dialog (nothing is lost; settings are remembered).

### 3.3 "Can't find your printer?" sheet
| Android | iOS |
|---|---|
| 1. Turn the printer on and connect it to the **same Wi-Fi** as this phone. 2. Open **Settings → Connected devices → Printing** (wording varies by phone) and turn on **Default Print Service**. 3. If your printer still doesn't appear, install your printer maker's **print service** app from Google Play (HP, Canon, Epson, Brother, Samsung) or **Mopria Print Service**. 4. For USB printers, connect with a USB-OTG cable; for Bluetooth printers, pair in Bluetooth settings first, and check the maker's print service supports Bluetooth. | 1. Turn the printer on and connect it to the **same Wi-Fi** as this iPhone. 2. Your printer must support **AirPrint** (most Wi-Fi printers do; check the box or the maker's site). 3. Restart the printer and try again. |
| **Tip:** you can also choose **Save as PDF** in the print dialog. | |

Plus a line for both: "Small portable receipt printers that use their own app aren't supported."

### 3.4 Entry points added
| Where | Change |
|---|---|
| Home | "Print" tool card in the PDF section (icon `print_rounded`, pdf gradient) |
| Result (S11) | "Print" joins the actions grid (becomes a 2×3 grid: Save, Share, Print, Open with, Edit options, + Save to My Documents in 1.5) |
| Operation details (S15) | "Print" next to Save/Share when the output is available |
| Incoming chooser (S19) | "Print" listed for PDFs and images |
| Quick actions | Optional chip "Print" (P2) |
| Search keywords | print, printer, printing, print pdf, print photo, print image, airprint, wifi printer, bluetooth printer, hard copy, paper, passport photo print |
| Tour | One "New in DocuKit" step for the Print card (`tour_version` +1) |

### 3.5 Ads
| Screen | Ads |
|---|---|
| S47 Print tool | Bottom `ADMOB_BANNER_TOOLS` with the 24 dp gap + divider |
| S48 Print preview | Bottom `ADMOB_BANNER_TOOLS` with the gap (it's an options screen with a main button) |
| Help sheet, system print dialog | None |
| After printing | **No interstitial.** A print isn't a "Done" job, and the user is usually walking to the printer |

## 4. Implementation

### 4.1 Packages
**No new Flutter packages.** Preview uses `pdfrx` (already in the app), image layouts use the `pdf` package (already in the app), and the system dialog is opened through **`docukit_native`** (ADR-069), passing a file path (not bytes), consistent with ADR-006. The `printing` package (Apache-2.0, 5.15.x at the time of writing) is the fallback if the native method hits a problem in the spike; it would need the PDF as bytes in memory.

### 4.2 Native methods (`docukit_native`)
| Method | Args | Android | iOS | Returns |
|---|---|---|---|---|
| `printPdf` | `path`, `jobName`, `originRect?` | `PrintManager.print(jobName, adapter, attrs)` with a `PrintDocumentAdapter` whose `onLayout` reports `PrintDocumentInfo(CONTENT_TYPE_DOCUMENT, pageCount)` and whose `onWrite` stream-copies the file (8 KB buffer, background thread, honours `CancellationSignal`). Watch the returned `PrintJob` (`isCompleted / isFailed / isCancelled`, polled every 1 s for up to 10 min, or until the app goes to the background) | `UIPrintInteractionController.shared` with `printingItem = URL(fileURLWithPath:)`, `printInfo.jobName`, `outputType = .general`; `present(from: originRect, in: view)` on iPad, `present(animated:)` on iPhone; completion handler `(completed, error)` | `{status: sent | cancelled | failed, message?}` |
| `printingAvailable` | — | `true` (the Print Framework is always there on API 26+) | `UIPrintInteractionController.isPrintingAvailable` | bool |

Android notes: the print-ready file must stay readable until `onWrite` finishes, so delete it only after the job is final or on the next launch sweep. Use the Activity context. Verify the adapter flow on API 26 and 36.

### 4.3 Print composer (`core/print/print_composer.dart`)
```dart
class PrintSettings {
  final PaperSize paper;           // a4 | letter | legal | a5 | in4x6 | in5x7 | sameAsDocument
  final PrintOrientation orientation; // auto | portrait | landscape
  final PageSelection pages;       // all | range(String) | odd | even
  final int perSheet;              // 1 | 2 | 4 | 6   (PDF input)
  final ImageLayout imageLayout;   // fullPage | twoUp | fourUp | passportSheet   (image input)
  final PrintScaling scaling;      // fit | actual | fill
  final PrintMargins margins;      // none | narrow | normal
}
abstract interface class PrintComposer {
  /// Builds the print-ready PDF in ctx.workDir. Reports Determinate(sheet, totalSheets).
  Future<PrintOutput> compose(PrintSource src, PrintSettings s, JobContext ctx);
}
class PrintOutput { final String path; final int sheetCount; final List<Size> sheetSizesPt; }
```

**PDF input: vector placement with PDFium XObjects (ADR-070)**
```
selected = resolvePages(src.pageCount, s.pages)          // 0-based list, original order
cells    = gridFor(s.perSheet)                            // 1→1×1, 2→1×2 (stacked in portrait), 4→2×2, 6→2×3
for sheetIndex, group in chunk(selected, s.perSheet):
   ctx.cancel.check(); report(Determinate(sheetIndex, totalSheets))
   paper = paperSizePt(s.paper, firstPageOf(group))      // sameAsDocument → that page's own size
   if s.orientation == auto: landscape = contentAspect(group, cells) > 1
   (W,H) = landscape ? (max,min) : (min,max) of paper
   area  = inset(Rect(0,0,W,H), marginPt(s.margins))
   page  = FPDFPage_New(outDoc, sheetIndex, W, H)
   for i, srcIndex in group:
      cell = cellRect(area, cells, i, gap: 4 mm)
      x    = FPDF_NewXObjectFromPage(outDoc, srcDoc, srcIndex)        // verify exposed by pdfrx bindings
      form = FPDF_NewFormObjectFromXObject(x)
      (w,h) = effectivePageSize(srcIndex)                              // includes /Rotate and the crop box
      scale = fit: min(cell.w/w, cell.h/h) | actual: 1.0 | fill: max(cell.w/w, cell.h/h)
      autoRotate = s.perSheet == 1 && orientation==auto ? 0 : rotate 90° if it fits better in the cell
      matrix = translate(cell.center) · rotate(autoRotate) · scale(scale) · translate(−w/2, −h/2)
      FPDFPageObj_Transform(form, matrix…); FPDFPage_InsertObject(page, form)
      if fill or actual: clip to the cell (FPDFPageObj_TransformClipPath or a clip path — verify)
      FPDF_CloseXObject(x)
   FPDFPage_GenerateContent(page); FPDF_ClosePage(page)
save outDoc → ctx.workDir/print.pdf (stream-save if available; otherwise encode in chunks like the merge)
```
Run it on PDFium's worker (the same isolate/thread rule as the Balanced reducer: **never call PDFium from a second thread**; ADR on the earlier crash).

**Fallback (spike fails):** render each selected source page at 300 dpi to JPEG q90 and place it with the `pdf` package (the same geometry). Mark these jobs "raster" in the logs-free debug info; text stops being selectable in the print PDF, which doesn't matter on paper.

**Image input** (the `pdf` package, reusing `ImageToPdfBuilder`'s normalisation: orientation applied, ≤ 300 dpi at the printed size, chunked by 20):
- Full page / 2 / 4 per sheet: same cell geometry as above.
- **Passport photo sheet:** photo 35×45 mm; gap 2 mm; usable area = paper − margins; `cols = floor((areaW + gap) / (35 + gap))`, `rows = floor((areaH + gap) / (45 + gap))`; compute for both orientations and use the one with more photos; centre the grid; draw 0.2 pt light-grey cut marks at every cell corner; the image is placed with **cover** inside each cell (centre crop), because the source is usually the output of the Resizer's passport preset. Expected counts (mm-exact, from the formula): 4×6 in → 8 / 6 / 4 (margins none / narrow / normal); A4 → 32 / 30 / 28; Letter → 28 / 28 / 25; 5×7 in → 9 / 9 / 8.

**Preview:** render sheets from `print.pdf` with `pdfrx` at the view size (lazy, with the existing thumbnail cache). Rebuild on any option change with a 300 ms debounce; cancel the previous build (`CancelToken`); keep showing the last good result until the new one is ready.

### 4.4 Flow
```
S48 open → compose(defaults) → preview
user changes options → debounce → compose → preview
Print tap → native printPdf(print.pdf, jobName = original name without extension)
   sent      → snackbar "Sent to printer"; history entry (FR-PRN-17)
   cancelled → nothing
   failed    → banner + help link
leave S48 → delete work dir (Android: keep print.pdf until the job is final; the launch sweep removes leftovers)
```
`printingAvailable == false` (rare: iOS devices with printing disabled by profile) → the Print button shows "Printing isn't available on this device" and offers **Share** instead.

## 5. Data model and settings
| Key | Type | Default |
|---|---|---|
| `print_paper` | enum string | locale-based (Letter / A4) |
| `print_orientation` | enum | auto |
| `print_scaling` | enum | fit |
| `print_margins` | enum | narrow |
| `print_per_sheet` | int | 1 |
| `print_image_layout` | enum | fullPage |

History: `tool = print`, `status = SUCCESS` (meaning *sent*), `inputCount`, `outputMetaJson = {"sheets": n}`, no output file (`outputRelPath = null`). Drift change: none beyond the new `ToolId` value (stored as text).

## 6. Permissions, privacy and store impact
- **No new permissions** on either platform. The app doesn't use Bluetooth, the local network or USB itself; the system print services do.
- **Privacy text (Privacy & About, privacy policy):** add "When you print, the document goes to the printer or print service you choose in the print dialog. Some printer makers' print services may send it through their own servers; that's set by the service you install, not by DocuKit."
- Play Data safety / App Store label: **no change** (DocuKit itself doesn't collect or transmit the document).
- App size: about +50 KB.

## 7. Copy

| Key | Text |
|---|---|
| tool_print_title / subtitle | Print / Print PDFs and photos |
| prn_choose_pdf / choose_images | Choose PDF / Choose images |
| prn_preview_btn | Preview & print |
| prn_preview_title | Print preview |
| prn_sheet_of | Sheet {n} of {total} |
| prn_paper / orientation / pages / per_sheet / layout / scaling / margins | Paper / Orientation / Pages / Pages per sheet / Layout / Scaling / Margins |
| prn_paper_same | Same as document |
| prn_orient_auto / portrait / landscape | Auto / Portrait / Landscape |
| prn_pages_all / range / odd / even | All / Range / Odd / Even |
| prn_range_hint | Pages like 1-3, 5 |
| prn_range_error | Enter pages like 1-3, 5 |
| prn_fix_range | Fix the page range |
| prn_scale_fit / actual / fill | Fit to page / Actual size / Fill page |
| prn_actual_warning | Some content is bigger than the paper and will be cut off. |
| prn_margin_none / narrow / normal | None / Narrow / Normal |
| prn_layout_full / two / four / passport | Full page / 2 per sheet / 4 per sheet / Passport photo sheet |
| prn_passport_count | {count} photos on {paper} |
| prn_next_step_note | Copies, colour and two-sided printing are set in the next step. |
| prn_print_btn | Print {count, plural, =1{1 sheet} other{# sheets}} |
| prn_no_pages | No pages to print with these settings. |
| prn_sent | Sent to printer |
| prn_failed | Printing failed. Check that the printer is on and connected. |
| prn_unavailable | Printing isn't available on this device. |
| prn_help_title | Can't find your printer? |
| prn_help_android_1…4 / ios_1…3 / tip / receipt | (text from §3.3) |
| prn_locked | This PDF is password-protected. Unlock it first, then print. |
| prn_hist_line | Sent to printer · {sheets, plural, =1{1 sheet} other{{sheets} sheets}} *(owner decision; was "Printed · …")* |
| tour_print_title / body / example | Print / Preview how your document will look on paper, then print to any Wi-Fi or connected printer. / Print a sheet of passport photos. |
| priv_print_p | When you print, the document goes to the printer or print service you choose in the print dialog. Some printer makers' print services may send it through their own servers; that's set by the service you install, not by DocuKit. |

## 8. Tests

| Test | Type |
|---|---|
| Page-selection resolver (all/range/odd/even, invalid input, out-of-range pages, duplicates kept in the given order) | Unit |
| Grid and cell geometry for 1/2/4/6 per sheet, both orientations, all margins | Unit |
| Auto orientation choice | Unit |
| Passport-sheet counts match §4.3 for 4×6, 5×7, A4, Letter × none/narrow/normal margins, with the best orientation chosen | Unit |
| Composer on the corpus: output sheet count; each sheet's size == chosen paper; PDF text still extractable (vector check) unless in fallback mode; rotated source pages (PDF-04) upright | Integration |
| Preview rebuild cancels stale builds; last good preview stays visible | Widget |
| Print button states: no file, invalid range, no pages, building, ready | Widget |
| Native `printPdf` outcome mapping (sent/cancelled/failed) with a fake channel | Unit |
| Banner present with the gap on S47/S48; no interstitial after printing | Widget |
| Temp print file deleted after a final state / on the launch sweep | Unit |

**Regression**
| # | Steps | Expected |
|---|---|---|
| R69 | Print a 10-page PDF, A4, Auto, Fit, 1 per sheet → Android system dialog → **Save as PDF** | Saved PDF has 10 A4 pages, content upright and centred; text selectable |
| R70 | Same PDF, Range "2-4, 7", 2 per sheet, Landscape | 2 sheets; pages 2,3 on sheet 1; 4,7 on sheet 2 |
| R71 | Print to a real Wi-Fi printer (Android; and iOS AirPrint once Xcode is set up) | "Sent to printer"; paper output matches the preview |
| R72 | Passport photo sheet on 4×6 in from a Resizer passport output | 8 photos at 35×45 mm (measure on paper, ±1 mm), cut marks visible |
| R73 | Cancel in the system dialog; then printer off → print | Cancel: no message. Printer off: failed or stuck job → failure banner, or "Sent" with the job failing later in the system queue (document it as a platform limitation) |
| R74 | 300-page PDF, 4 per sheet | Preview responsive; the build shows progress and can be cancelled; no out-of-memory |

## 9. Tasks (milestone M13, on the `release/1.6` branch)

- [x] **T13.0 Spike (½–1 day).** (a) PDFium XObject placement via the pdfrx bindings: `FPDF_NewXObjectFromPage`, `FPDF_NewFormObjectFromXObject`, `FPDFPageObj_Transform`, clipping. Test on the corpus incl. rotated pages; confirm text stays extractable. (b) `printPdf` on Android with "Save as PDF" and a real printer if one is available. *Accept:* ADR-069/070 updated with PASS/FAIL and exact calls; fallback chosen if (a) fails. — *Done 2026-11-01 (Android):* **(a) PASS** on host PDFium and the emulator — pages as XObjects stay vector, /Rotate and crop boxes come out as displayed (PDFium applies them: placement is scale + move only), Fill / Actual size clip cleanly via a cell-sized page XObject; **(b) PASS** — `docukit_native.printPdf` (path, job name, paper) → system dialog → Save as PDF → `sent`, 10 pages; passing the paper as `PrintAttributes` is required (otherwise the dialog's default Letter rescales A4), and Android has no predefined 5 × 7 in. ADR-069 / ADR-070 accepted with the exact calls; raster fallback not needed. Not tried: a real printer, API 26 / 36, iOS (no Xcode).
- [x] **T13.1 Settings model + page-selection resolver + geometry** (pure Dart, tests first). Reuse the Split PDF range parser from T8.x. — *Done 2026-11-01:* `core/print/print_settings.dart` (PrintSettings, PaperSize, PageSelection…) and `core/print/print_geometry.dart` (resolvePages via `parsePageRanges` — ranges keep their order and repeats; paper/margins in pt; `gridFor` long side follows the sheet; `cellRects` with 4 mm gaps; `autoLandscape` = the orientation with more printed area at Fit, ties portrait; `placeInCell` fit/fill/actual + optional quarter turn anticlockwise + the PDF matrix for the XObject; passport sheet — all 12 §4.3 counts match); the six §5 keys in SettingsRepository (Letter in US/CA/MX/PH). 83 unit tests.
- [x] **T13.2 PrintComposer for PDFs** (vector, or the raster fallback). *Accept:* composer tests; R70 on the emulator via Save as PDF. — *Done 2026-11-01:* `core/print/print_composer.dart` (`PdfiumPrintComposer`, `PdfPrintSource`, `PrintOutput`; writes `print.pdf` in the work dir, replaces it on rebuild, re-opens and checks page count and sizes) + `planPdfSheets` in `print_geometry.dart` + `printSheetsInWorker` in `pdfium_raw_ops.dart` (vector XObjects; Fill / oversized Actual size clipped via a cell page; per-sheet progress; cancel by the next sheet). 11 plan tests, 11 host tests (in `tool/test_pdf_host.sh`). **R70 PASS** on the emulator: 2 landscape A4 sheets (B, C | D, G) composed in 415 ms → Save as PDF → `sent`, saved 2 × 841 × 595, text, no images. `printPdf` gained `landscape` (landscape media) — finished in T13.4.
- [x] **T13.3 PrintComposer for images** incl. the passport sheet. *Accept:* the passport count tests; R72 on Save as PDF (measure in a desktop viewer). — *Done 2026-11-01:* `ImagesPrintSource` + the image branch of `PdfiumPrintComposer` (each image normalised once by the ImageEngine — EXIF orientation, JPEG q90, ≤ 300 dpi of its printed size, turned a quarter anticlockwise when placed so; sheets laid out with `pdf` in an isolate, chunks of 20 merged by PDFium; temp JPEGs and chunks removed) + `planImageSheets` (Full page / 2 / 4 reuse the PDF grid; passport = the first image covering each 35 × 45 mm cell, never turned; Actual size / Same as document at 150 dpi like Images to PDF); cut marks 0.2 pt light grey, 1 mm ticks continuing each photo edge. 6 plan + 9 host tests (counts, sizes ±0.5 mm on a render, one embedded JPEG, BGRA render checks, chunks in order, errors, cancel). **R72 PASS** on the emulator (real native image engine): 1 sheet in 1.4 s → dialog preselects Index Card 4x6 → Save as PDF → `sent`; saved 432 × 288 pt, 1 image; measured 4 × 2 = 8 photos, 35.3–35.6 × 45.5 mm at 72 dpi (±0.35 mm/px), red band on top of each, cut marks present. Paper measurement (±1 mm on a real print) is the owner's.
- [ ] **T13.4 Native `printPdf` + `printingAvailable`** (Kotlin + Swift), outcome mapping, temp-file lifetime. *Accept:* R69, R73 on Android; Swift compiles (iOS run deferred to the Xcode round).
- [ ] **T13.5 S48 Print preview** (sheet view, thumbnails, options, debounce/cancel, states, help sheet, banner with gap).
- [ ] **T13.6 S47 Print tool + entry points** (Home card, Result, Details, Incoming, search keywords, tour step, history entry).
- [ ] **T13.7 Copy, privacy text, docs** (COPY.md, Privacy & About, privacy policy line, ADS.md §3.1 rows).
- [ ] **T13.8 Regression R69–R74** + quick pass of R1–R26.

Estimate: **4–6 days**.

## 10. Claude Code prompts

**P-PRN-1 · Spike**
```
Read docs/FULL_PRODUCT.md and docs/features/RELEASE_PRINT.md in full. On branch release/1.6, do task T13.0 only.
Build a throwaway debug screen under lib/debug/ that (a) builds a print-ready PDF from the corpus using PDFium XObject placement (FPDF_NewXObjectFromPage, FPDF_NewFormObjectFromXObject, FPDFPageObj_Transform, clipping) through the bindings pdfrx exposes, including rotated pages, and checks text is still extractable; (b) calls a minimal docukit_native.printPdf(path, jobName) on Android and lets me choose "Save as PDF".
Call PDFium only from its own worker, as in the Balanced reducer.
Record results as ADR-069/070 with exact package versions and calls. Stop and report PASS/FAIL per check.
```

**P-PRN-2 · Logic and composer**
```
Do tasks T13.1, T13.2 and T13.3 from docs/features/RELEASE_PRINT.md on release/1.6, using the approach the T13.0 ADR chose.
Write the unit tests in §8 first (page selection, geometry, auto orientation, passport counts), then the composer. Reuse the Split PDF range parser.
One commit per task. Run analyze, all tests (--timeout 90s), goldens, CI checks. Report real results, including R70 and R72 checked via "Save as PDF" on the emulator.
```

**P-PRN-3 · Native print + screens**
```
Do tasks T13.4, T13.5 and T13.6 from docs/features/RELEASE_PRINT.md on release/1.6.
Native printPdf passes a file path, never bytes. Outcomes: sent / cancelled (silent) / failed (banner + help). Never say "Printed".
Preview: debounce 300 ms, cancel stale builds, keep the last good preview. Bottom banner ADMOB_BANNER_TOOLS with the 24 dp gap on S47 and S48; no interstitial after printing.
Add the Print entry points (Home card, Result, Details, Incoming), search keywords, the tour step and the history entry.
One commit per task, with widget tests. Report real results, including R69 and R73 on the Android emulator.
```

**P-PRN-4 · Finish**
```
Do T13.7 and T13.8 from docs/features/RELEASE_PRINT.md: copy, privacy text and docs, then regression R69–R74 plus a quick pass of R1–R26 on the Android emulator. Record pass/fail in TESTING.md. Build a debug APK to ~/Desktop/DocuKit-print-debug.apk (check free disk space first; stop if under 10 GB). Don't merge or push. Report real results.
```

## 11. Risks and decisions

**ADR-069 — Print through our own native method, passing a file path · Proposed (confirm in T13.0)**
*Context:* the `printing` package's `layoutPdf` takes the whole PDF as bytes; large documents would spike memory, and ADR-006 already prefers file paths over the platform channel. *Decision:* `docukit_native.printPdf` with an Android `PrintDocumentAdapter` that streams the file and iOS `UIPrintInteractionController.printingItem` with a file URL. *Consequences:* about 120 lines of Kotlin + Swift; no new dependency; the `printing` package is the fallback.

**ADR-070 — Keep print output vector via PDFium XObjects · Proposed (gated by T13.0)**
*Context:* N-up, scaling and margins need each source page placed on a new sheet. Rasterising is simple but heavy (300 dpi × hundreds of pages) and loses sharp text. *Decision:* place pages as form XObjects with a transform matrix (the same technique PDFium's own N-up import uses); fall back to 300 dpi raster only if the spike fails. *Consequences:* PDFium FFI must stay single-threaded (existing rule); rotated and cropped pages need careful matrix maths (covered by tests).

**ADR-071 — No receipt/thermal (ESC/POS) printers · Accepted**
They don't appear in the system print dialogs and need per-brand Bluetooth code and permissions. Revisit only if users ask for it.

| Risk | Mitigation |
|---|---|
| Users' printers not showing up | Help sheet; system services handle discovery; Save as PDF still works |
| Android doesn't report the real outcome for some print services (job stays "queued") | Say "Sent to printer", not "Printed"; stop watching after 10 min or when backgrounded |
| Passport photo size wrong because the printer scales the page | The help text in the passport layout says: "In the print dialog, choose 100% / Actual size if your printer offers it"; R72 measures on paper |
| iOS untested until Xcode is set up | Swift compiles in CI; the iOS run is part of the Xcode round |
