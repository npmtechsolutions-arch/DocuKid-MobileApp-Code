# DocuKit — Full Product Plan (v1.0 → v1.5)

The complete DocuKit product: what's in each release, how the app grows from 6 tools to 16 plus a document library, and the shared conventions every v1.1–v1.5 spec follows. Read this before any `docs/features/RELEASE_V1_x.md`.

## 1. The complete product

| Area | Tool / feature | Release | Status |
|---|---|---|---|
| **Image** | Image Compressor (now with batch: up to 50 images) | 1.0 → batch in 1.1 | Built |
| | Image Resizer (now with batch) | 1.0 → batch in 1.1 | Built |
| | **Convert Image** (HEIC / PNG / WebP / JPG, batch) | 1.1 | New |
| | Images to PDF | 1.0 | Built |
| **PDF** | Merge PDFs | 1.0 | Built |
| | Organize Pages (now with "Extract selected pages") | 1.0 → extract in 1.1 | Built |
| | **Split PDF** (by ranges, every N pages, each page) | 1.1 | New |
| | **PDF to Images** (each page as JPG/PNG) | 1.1 | New |
| | Reduce PDF Size | 1.0 | Built |
| **Scan & Text** | **Scan Document** (camera, edge detection, crop, filters → PDF/JPG) | 1.2 | New |
| | **Text Recognition (OCR)**: searchable PDF, copy text, save .txt | 1.3 | New |
| **Secure & Sign** | **Sign PDF** (draw / type / photo signature, place on pages) | 1.4 | New |
| | **Watermark PDF** (text or image, position, opacity, pages) | 1.4 | New |
| | **Protect PDF** (add a password, AES-256) | 1.4 | New |
| | **Unlock PDF** (remove a password you know) | 1.4 | New |
| **Library** | **My Documents**: keep files in folders, search (incl. OCR text), expiry dates with reminders, app lock | 1.5 | New |
| **App** | Favourite tools; Open in / Share to DocuKit from other apps | 1.1 | New |
| | Home tour, ads, Remove ads, UI refresh | 1.0 (v2.1 specs) | Built / in test |

**End state: 16 tools + My Documents.**

## 2. Release plan

| App version | Theme | Spec | Est. effort (solo + Claude) | Gate before starting |
|---|---|---|---|---|
| 1.0 | Six core tools, new look, tour, ads | existing docs | — | — |
| 1.1 | Productivity: batch, convert, split, PDF→images, extract, favourites, share-in | `features/RELEASE_V1_1.md` | 7–10 days | 1.0 on the Play closed test |
| 1.2 | Scanner | `features/RELEASE_V1_2.md` | 5–8 days | 1.1 regression green |
| 1.3 | OCR / searchable PDF | `features/RELEASE_V1_3.md` | 7–10 days | Scanner done (OCR builds on scans) |
| 1.4 | Sign, watermark, protect, unlock | `features/RELEASE_V1_4.md` | 9–13 days | PDF spike T11.0 passes |
| 1.5 | My Documents + expiry reminders + app lock | `features/RELEASE_V1_5.md` | 9–13 days | 1.3 shipped (search uses OCR text) |
| **Total** | | | **37–54 working days** | |

**Shipping:** each version is designed to ship on its own. You can still build them all and release once, but a version can't skip its own regression pass. The recommended path is to publish 1.0 while 1.1 is being built.

## 3. Navigation at full scale

Sixteen tools no longer fit one short grid, so Home is organised as:

```
┌──────────────────────────────────────┐
│ Hero: greeting · search · saved stat │
│ ★ Favourites (up to 6, pinned)       │  hidden until the user pins one
│ Quick actions chips                  │
│ Image        Compress · Resize · Convert · Images→PDF
│ PDF          Merge · Organize · Split · PDF→Images · Reduce
│ Scan & Text  Scan · Text recognition
│ Secure & Sign Sign · Watermark · Protect · Unlock
│ My Documents  (card: 3 recent docs + "Open library", v1.5)
│ Recent                                │
└──────────────────────────────────────┘
App bar: ? (tour) · 📁 My Documents (v1.5) · 🕘 History · ⚙︎ Settings
```

- **No bottom navigation bar.** Every page already has a bottom ad banner (ADR-035), and AdMob discourages banners next to navigation buttons. The app-bar icons and the tablet rail stay.
- Categories are collapsible sections (remembered per user). The tour gains steps for the new categories (`tour_version` bump per release; see TOUR.md FR-TOUR-10).
- Search synonyms grow with each tool (each spec lists its keywords).

## 4. Shared conventions for v1.1–v1.5 specs

Every release spec uses these so the pieces fit together.

### 4.1 IDs

| Item | v1.1 | v1.2 | v1.3 | v1.4 | v1.5 |
|---|---|---|---|---|---|
| Requirement prefixes | FR-BAT, FR-CNV, FR-SPL, FR-P2I, FR-EXT, FR-FAV, FR-SHR | FR-SCN | FR-OCR | FR-SIG, FR-WMK, FR-PRT, FR-UNL | FR-LIB, FR-REM, FR-LCK |
| Task IDs (milestone) | T8.x (M8) | T9.x (M9) | T10.x (M10) | T11.x (M11) | T12.x (M12) |
| ADRs (renumbered on merge, DECISIONS.md) | ADR-036–040 | ADR-041–043 | ADR-044–047 | ADR-048–053 | ADR-054–059 |
| Screen IDs | S21–S26 | S27–S29 | S30–S32 | S33–S38 | S39–S46 |
| Test regression IDs | R27–R36 | R37–R42 | R43–R48 | R49–R58 | R59–R68 |

### 4.2 New `ToolId` values and routes

| ToolId | Route | Category | Release |
|---|---|---|---|
| `imageConvert` | `/tool/image-convert` | image | 1.1 |
| `pdfSplit` | `/tool/pdf-split` | pdf | 1.1 |
| `pdfToImages` | `/tool/pdf-to-images` | pdf | 1.1 |
| `scanDocument` | `/tool/scan` | scan | 1.2 |
| `ocr` | `/tool/ocr` | scan | 1.3 |
| `pdfSign` | `/tool/pdf-sign` | secure | 1.4 |
| `pdfWatermark` | `/tool/pdf-watermark` | secure | 1.4 |
| `pdfProtect` | `/tool/pdf-protect` | secure | 1.4 |
| `pdfUnlock` | `/tool/pdf-unlock` | secure | 1.4 |
| — (feature) | `/library`, `/library/folder/:id`, `/library/doc/:id` | library | 1.5 |

New `ToolCategory` values: `scan`, `secure` (and `library` for the Home card only). Category colours are in §4.5.

### 4.3 Shared engine additions (one owner each)

| Capability | Introduced in | Interface (in `lib/core/`) | Used by |
|---|---|---|---|
| Multi-output jobs (N files + optional ZIP) | 1.1 | `MultiOutput` in `core/operation/` + `ZipBuilder` (`archive` package) | Batch, Convert, Split, PDF→Images, Scanner (JPG mode) |
| Save many / share many | 1.1 | `FileGateway.saveManyToFolder` (Android `OPEN_DOCUMENT_TREE`; iOS export picker with multiple URLs), `share(paths)` already supports lists | Same |
| Incoming files | 1.1 | `docukit_native.getIncomingFiles` + `IncomingFilesController` | S19 |
| Page-object editing (PDFium FFI) | 1.4 (extends the Balanced reducer's FFI) | `PdfStamper` in `core/pdf/` | Sign, Watermark, OCR text layer (1.3 may use it) |
| PDF encryption | 1.4 | `PdfSecurity` (native: iOS PDFKit, Android PdfBox-Android) | Protect, Unlock |
| Text recognition | 1.3 | `TextRecognizer` in `core/ocr/` | OCR, Scanner "make searchable", Library search |
| Document storage | 1.5 | `LibraryRepository` + `library_documents` tables | Library, "Save to My Documents" on Result |

### 4.4 Ads rules for new screens (from ADS.md + ADR-035)

| Screen type | Bottom banner key | Other ads |
|---|---|---|
| New tool screens (options + main button) | `ADMOB_BANNER_TOOLS`, with the 24 dp gap + divider | None |
| Full-screen editors and capture: camera scanner, crop/filter editor, signature pad, signature/watermark placement editor, OCR text-review screen | **None** (like the page preview) | None |
| Batch result list, Library screens, document detail | `ADMOB_BANNER_MAIN` | Library list: one native card in-feed after the 5th item (re-uses `ADMOB_NATIVE_HISTORY`) |
| Password entry, app-lock screen | **None** | None |
| Result screens (single and multi) | Existing rules (AD-2 card, AD-3 interstitial on Done) | — |

No new ad unit IDs are needed for v1.1–v1.5.

### 4.5 Category colours (extend UI_REFRESH §1)

| Category | Light gradient | Dark gradient |
|---|---|---|
| scan | `#0E7490 → #22B8CF` | `#2399B0 → #48C6D8` |
| secure | `#7C3AED → #C026D3` | `#8B5CF6 → #D04BDF` |
| library | `#334155 → #64748B` | `#5B6B80 → #8A97A8` |

Check white-on-gradient contrast ≥ 4.5:1 at the lightest stop in T8.1 (adjust the lightest stop if it fails).

### 4.6 Rules that keep applying
Everything in `CLAUDE.md` still holds: originals never modified, outputs validated before success, no fabricated progress, no logging of names/paths/content/passwords/OCR text, ARB strings only, semantics labels, both platforms, small reviewable commits with tests.

**New global rules from v1.1 on:**
- **Passwords (v1.4):** never stored, never logged, never in history `optionsJson`, cleared from memory (`Uint8List.fillRange(0)` where possible) after use.
- **OCR text (v1.3+):** treated like file content: never logged, never sent anywhere, stored only inside the Library index (v1.5), and deleted with the document.
- **Library files (v1.5):** stored only in the app sandbox, excluded from cloud backup by default (ADR-054), and deleted when the user deletes them.

## 5. Platform & store impact summary

| Release | New permissions | Min OS change | Privacy-label / Data safety change | App size impact (est.) |
|---|---|---|---|---|
| 1.1 | None (folder picker needs none) | — | None | +0.2 MB (`archive`) |
| 1.2 | iOS: camera (`NSCameraUsageDescription`). Android: none (ML Kit scanner runs in Google Play services) | — | Declare ML Kit's diagnostics collection, if any (verify Google's ML Kit data-disclosure page) | Android ~0 (Play services); iOS ~0 (VisionKit) |
| 1.3 | None | **iOS 15.5** (ML Kit text recognition requires it) | Same ML Kit note | Android: small if unbundled models; iOS +10–25 MB per script (spike T10.0 decides) |
| 1.4 | None | — | None | Android +3–5 MB (PdfBox-Android, if needed) |
| 1.5 | Notifications (Android 13+ `POST_NOTIFICATIONS`; iOS prompt), Face ID (`NSFaceIDUsageDescription`) | — | None (data stays local), but update the privacy policy: documents can be stored in the app | +0.5 MB |

## 6. Document map

```
docs/
  FULL_PRODUCT.md            ← this file
  features/
    RELEASE_V1_1.md          ← batch, convert, split, PDF→images, extract, favourites, share-in
    RELEASE_V1_2.md          ← scanner
    RELEASE_V1_3.md          ← OCR
    RELEASE_V1_4.md          ← sign, watermark, protect, unlock
    RELEASE_V1_5.md          ← My Documents, reminders, app lock
CHANGES_v3.md                ← merge guide + build order + prompts
```
