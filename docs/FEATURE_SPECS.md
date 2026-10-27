# DocuKit — Feature Implementation Specs

How each tool actually works. The pseudo-code is language-neutral but close to Dart. Every function marked **[unit]** must have unit tests (`TESTING.md §2`).

---

## 1. Tool search (S02) **[unit]**

### 1.1 Synonym table (English; localise the arrays in ARB later)

| Tool | Title | Keywords / phrases |
|---|---|---|
| imageCompress | Image Compressor | compress, compressor, reduce, smaller, shrink, kb, mb, size, photo size, image size, reduce photo size, make picture smaller, lower quality, optimize image, jpg, jpeg, png, webp, heic, upload limit, under 100kb, whatsapp |
| imageResize | Image Resizer | resize, resizer, dimension, dimensions, pixel, pixels, width, height, scale, crop, passport, signature, passport photo, profile picture, dp, instagram, square, story, hd, 1080 |
| imageToPdf | Images to PDF | image to pdf, photo to pdf, jpg to pdf, picture to pdf, convert, scan, notes, receipts, gallery to pdf, png to pdf, make pdf, create pdf |
| pdfMerge | Merge PDFs | merge, combine, join, append, together, one pdf, multiple pdf, unite, attach pdf |
| pdfOrganize | Organize Pages | organize, organise, reorder, rearrange, sort pages, rotate, rotate page, delete page, remove page, move page, pages, arrange |
| pdfCompress | Reduce PDF Size | compress pdf, reduce pdf, shrink pdf, pdf size, smaller pdf, optimize pdf, email limit, pdf kb, pdf mb |

### 1.2 Matching and ranking
```
normalize(s) = removeDiacritics(s.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').squash()
score(tool, q):
  if q empty → 0
  qn = normalize(q); tokens = qn.split(' ')
  s = 0
  if normalize(title).startsWith(qn) → s += 100
  if normalize(title).contains(qn)   → s += 60
  for kw in keywords:
     k = normalize(kw)
     if k == qn → s += 90 ; elif k.startsWith(qn) → s += 50 ; elif qn.contains(k) && k.length ≥ 3 → s += 40
  s += 10 × |{t ∈ tokens : t.length ≥ 2 ∧ any keyword token startsWith t}|
  // category hint: if "pdf" ∈ tokens → +15 for pdf tools; if any of {photo,image,picture,jpg,png} → +15 for image tools
  return s
results = tools.where(score>0).sortedByDescending(score).thenBy(catalogOrder)
matchedPhrase = the keyword that gave the largest single increment (shown as "Matches …")
```
Test cases: "reduce photo size" → imageCompress first; "compress pdf" → pdfCompress first (not imageCompress); "passport" → imageResize; "jpg to pdf" → imageToPdf; "rotate" → pdfOrganize; "COMBINE" → pdfMerge; "xyz" → empty.

---

## 2. Input intake and validation

### 2.1 MIME sniffing by magic bytes **[unit]**
| Format | Signature |
|---|---|
| JPEG | `FF D8 FF` |
| PNG | `89 50 4E 47 0D 0A 1A 0A` |
| WebP | `52 49 46 46 ?? ?? ?? ?? 57 45 42 50` ("RIFF....WEBP") |
| HEIC/HEIF | bytes 4–7 = `ftyp` and brand ∈ {heic, heix, hevc, heim, heis, mif1, msf1} |
| GIF (reject in MVP) | `47 49 46 38` |
| PDF | `%PDF-` within the first 1024 bytes |

The extension is ignored for the decision; a mismatch (`.jpg` that is actually PNG) is treated as PNG, without a warning.

### 2.2 Validation per tool
```
validateImage(f):
  if f.size > 100 MB → invalid(fileTooLarge)
  mime ∉ {jpeg,png,webp,heic} → invalid(unsupportedFormat)
  meta = ImageEngine.inspect(f)          // header-only decode
     on failure → invalid(corruptFile)
  if meta.w * meta.h > 200_000_000 → invalid(fileTooLarge)
  warnings: hasAlpha && output will be JPEG → warning(alphaLost)
validatePdf(f):
  if f.size > 500 MB → invalid(fileTooLarge)
  mime != pdf → invalid(unsupportedFormat)
  meta = PdfEngine.inspect(f)
     on password exception → invalid(encryptedDocument)
     on other failure      → invalid(corruptFile)
  if meta.pageCount == 0 → invalid(corruptFile)
```
Counts: Merge 2–20 files and Σ pages ≤ 2000; Image→PDF 1–100; Organize 1 (≤ 2000 pages); Compress/Resize 1 (batch in V1.1).

### 2.3 Storage estimate **[unit]**
| Tool | requiredBytes |
|---|---|
| Image compress/resize | `input × 1.5` |
| Image→PDF | `Σ inputs × 1.2` (normalised JPEG copies + PDF) |
| Merge | `Σ inputs × 2.1` |
| Organize | `input × 2.1` |
| Reduce | `input × 2.5` |
Run is refused when `free < required + 50 MB`.

---

## 3. Image tools

### 3.1 Orientation and dimensions
- `inspect` reads EXIF orientation (1–8). For orientations 5–8 the **display** width/height are swapped. All the UI and maths use display (oriented) dimensions.
- The encode step applies the orientation to the pixels (`autoCorrectionAngle: true`) and writes no orientation tag (or 1).

### 3.2 Resize maths **[unit]**
```
lockedHeightFor(w, origW, origH) = max(1, round(w * origH / origW))
lockedWidthFor(h, origW, origH)  = max(1, round(h * origW / origH))
percentDims(p, origW, origH)     = (max(1, round(origW*p/100)), max(1, round(origH*p/100)))
validDims(w,h): 1 ≤ w ≤ 12000 ∧ 1 ≤ h ≤ 12000 ∧ w*h ≤ 100_000_000
ratioDiffers(w,h,origW,origH) = |w/h − origW/origH| > 0.01
```
Rounding is half-up (`(x + 0.5).floor()`) to be deterministic across platforms.

### 3.3 Fit modes when the ratio differs
```
stretch: scale to exactly (w,h)
contain: s = min(w/origW, h/origH); draw at (round(origW*s), round(origH*s)) centred on a w×h canvas filled with padColor
cover:   s = max(w/origW, h/origH); scale, then centre-crop to w×h
```

### 3.4 Encode pipeline (compress and resize)
```
transform(in, out, t):
  // Step A: native downsampled decode + orientation + optional coarse scale + encode
  if t.target dims are known:
     coarse = flutter_image_compress(minWidth = t.targetW, minHeight = t.targetH, …)  // scales so that w ≥ minW and h ≥ minH (preserves the ratio)
  else coarse = flutter_image_compress(minWidth = capW, minHeight = capH)            // cap = maxLongEdge or original
  // Step B: exact size / fit (only if Step A's dims ≠ the target exactly, or fit ≠ stretch-with-same-ratio)
  if dims(coarse) != (t.targetW, t.targetH):
     Isolate.run: decode coarse (already small) with package:image → copyResize/contain/cover (cubic) → encode to the target format/quality
  // Step C: metadata
  stripMetadata = true  → keepExif = false (all EXIF incl. GPS and camera info dropped; orientation already baked into pixels)
  stripMetadata = false → keepExif = true, and the orientation tag is reset to 1 after the rotation is baked in
  (verify in spike T2.0 that the EXIF orientation isn't applied twice when keepExif = true)
  write to out (in workDir). Return {bytes, w, h, format}.
```
Notes:
- **Spike T2.0** must confirm the `flutter_image_compress` `minWidth/minHeight` semantics, HEIC/WebP encode support per platform, and the EXIF behaviour. Adjust this pipeline if they differ.
- The PNG path: quality is ignored; the format stays PNG unless the user switches.
- Alpha → JPEG: composite onto white before encoding (Step B is forced for alpha inputs).

### 3.5 Target-size mode **[unit for the search logic with a fake encoder]**
```
targetSize(in, targetBytes, format = jpeg|webp):
  lo = 10; hi = 95; best = null; dimsScale = 1.0
  for attempt in 1..8:
     q = (lo + hi) ~/ 2
     r = encode(in, quality q, scale dimsScale)
     if r.bytes ≤ targetBytes: best = r; lo = q + 1        // try higher quality
     else: hi = q − 1
     if lo > hi:
        if best != null: break
        // even q=10 is too big → shrink the dimensions by 15% and retry the quality search
        dimsScale *= 0.85; lo = 10; hi = 85
        if dimsScale < 0.2: break
  return best ?? last r  (with flag targetMissed = best == null)
```
Target-size with PNG output → force JPEG (UI shows "Target size uses JPEG").

### 3.6 Image → PDF (ADR-012)

**Page sizes (points, portrait):** A4 595.28×841.89 · Letter 612×792 · Legal 612×1008.
**Margins:** none 0, small 18 pt, large 36 pt.

```
for each image i (in list order):
  cancel.throwIfCancelled(); report(Determinate(i, n, 'step_building_pdf'))
  oriented dims (w,h) after EXIF + user rotation r_i
  page:
     if size == sameAsImage: pageW = w*72/150, pageH = h*72/150 (clamp 216..14400 pt), margin = 0
     else (pw, ph) = preset; orientation = auto ? (w > h ? landscape : portrait) : chosen; swap if landscape
  box = page − 2·margin
  fit:  s = min(boxW/w, boxH/h) ; drawW = w*s ; drawH = h*s ; centred
  fill: s = max(boxW/w, boxH/h) ; centred, clipped to the box
  // pixel cap: don't embed more pixels than the dpi cap needs
  maxPx = ceil(drawW_pt/72 * dpiCap), ceil(drawH_pt/72 * dpiCap)   // fill: use the box size, not the draw size
  jpeg_i = ImageEngine.transform(img_i → tmp/i.jpg, jpeg q, longest edge ≤ max(maxPx), rotation r_i, strip metadata)
  record (jpegPath, page dims, draw rect)
then in Isolate.run: pdf.Document; for each record addPage(pw.Page(pageFormat, build: Center/Positioned(pw.Image(MemoryImage(readBytes(jpeg)), fit))))
     save → work/out.pdf
if Σ jpeg bytes > 120 MB: build chunks of 25 → chunk_k.pdf, then PdfEngine.merge(chunks) → out.pdf
```
Quality presets: Original (q95, cap 300 dpi, and never upscale) · High (q85, 200 dpi) · Compact (q65, 150 dpi). PNG/alpha inputs are composited onto white.

---

## 4. PDF tools

### 4.1 Inspect
```
inspect(path):
  doc = PdfDocument.openFile(path, passwordProvider: () => null)   // returning null → pdfrx throws a password exception → encryptedDocument
  pageCount = doc.pages.length; sizes = pages.map(p => (p.width, p.height))   // pt
  imageCount (optional, Reducer pre-analysis): count image page objects via PDFium on ≤ the first 20 pages, extrapolate; label imageHeavy if (images/page ≥ 0.5) or (bytes/page > 150 KB)
  dispose
```

### 4.2 Merge
```
merge(inputs, out, ctx):
  out = PdfDocument.createNew(sourceName: 'merged.pdf')
  docs = []
  pages = []
  for (i, path) in inputs: ctx.cancel.check(); report(Determinate(i, n, 'step_merging'))
      d = openFile(path); docs.add(d); pages.addAll(d.pages)
  out.pages = pages
  bytes = await out.encodePdf()       // NOTE: encodes in memory — see the large-file note
  write bytes → ctx.workDir/merged.pdf
  dispose all
```
**Large-file note:** `encodePdf()` returns bytes. If the merged output is > ~300 MB this may exceed the memory on low-end devices. In spike T3.0, measure the peak memory for a 400 MB total merge; if it's too high, use PDFium `FPDF_SaveAsCopy` with a file-writer callback (streaming), or cap the total input at 250 MB on devices with < 4 GB RAM.

Bookmarks/outlines, form fields and document-level JavaScript from the inputs may not be preserved — document this in the "How it works" sheet ("Bookmarks and form fields may not be kept").

### 4.3 Organize
```
organize(input, edits, out, ctx):
  src = openFile(input)
  newPages = edits.map(e => rotate(src.pages[e.sourceIndex], e.rotationQuarterTurns))
  out = createNew(); out.pages = newPages; bytes = encodePdf(); write; dispose
rotate(page, q): q mod 4 == 0 → page
                 else → pdfrx rotation API if available (spike) → else PDFium FPDFPage_SetRotation((existing + q) mod 4) on the imported page in the output doc
```
**Edit model [unit]:** `PageEdit(sourceIndex, rotationQuarterTurns)`; the operations are pure functions over `List<PageEdit>`:
`move(list, fromPositions, toIndex)`, `rotate(list, positions, ±1)`, `delete(list, positions)` (throws if the result is empty), `isIdentity(list, pageCount)`. Undo = a stack of previous lists.

### 4.4 Reduce (ADR-013)
```
reduce(input, out, level, ctx):
  basic:
     doc = openFile(input); out = createNew(); out.pages = doc.pages; bytes = encodePdf()   // full rewrite, drops unreferenced objects
  balanced:   (requires the PDFium image-object API — spike T3.0)
     for each page p (report Determinate):
        for each image object o on p:
           (pxW, pxH) = image pixel size; (bw, bh) = on-page bounds in pt
           effDpi = min(pxW / (bw/72), pxH / (bh/72))
           if effDpi ≤ 160 and filter == DCT: skip
           if the image has an SMask / is a mask / is a 1-bit image: skip      // preserves transparency & line art
           targetPx = scale so effDpi = 150 (never upscale)
           bmp = FPDFImageObj_GetBitmap(o) → downscale (Isolate, package:image) → JPEG q70
           if the new JPEG bytes < the original stream length × 0.9: replace via FPDFImageObj_LoadJpegFileInline(...); set the matrix unchanged
        FPDFPage_GenerateContent(p)
     save → out
  strong:
     for each page p: render at 120 dpi (pdfrx render → RGBA) → JPEG q60 (Isolate) → new page of the same pt size with the image full-bleed (pdf package or createFromJpegData)
     assemble (chunked like Image→PDF)
after any level: if bytes(out) ≥ bytes(input) → the result is flagged notSmaller (S11 warning, Discard default)
```

---

## 5. Recent Activity rules **[unit]**
- Insert status `RUNNING` at job start; update to the final status at the end.
- At launch: `UPDATE operations SET status='INTERRUPTED' WHERE status='RUNNING'`.
- Retention sweep at launch and when the setting changes: for rows with `finishedAt < now − retention` and `outputDeletedAt IS NULL` → delete `outputs/<id>/`, set `outputDeletedAt = now`. Rows are kept (metadata remains) until the user removes them.
- Clear history: delete rows (cascade inputs) and, if the checkbox is set, `outputs/*`.

## 6. Limits summary

| Limit | Value | Where enforced |
|---|---|---|
| Image file size | 100 MB | pick |
| Image pixels | 200 MP input; 100 MP output | pick / resize fields |
| Image side | 12,000 px output | resize fields |
| Images per PDF | 100 | pick |
| PDF file size | 500 MB | pick |
| PDFs per merge | 2–20, Σ pages ≤ 2,000 | pick / run button |
| Organizer pages | 2,000 | pick |
| Undo steps | 50 | organizer |
| Output name length | 120 chars | D3 / naming |
| Custom presets | 10 | resizer |
| Free space margin | 50 MB + estimate | run |
