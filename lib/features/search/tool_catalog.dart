import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// The tool catalogue — single source of truth for Home, Search, History
/// (ARCHITECTURE §4). Adding a tool = an entry here + a feature folder + one
/// ToolOperation.
/// Stored by `name` (history rows, settings), never by index, so new values
/// can go anywhere. Declaration order is not display order: see [toolCatalog].
enum ToolId {
  imageCompress,
  imageResize,
  imageToPdf,
  pdfMerge,
  pdfOrganize,
  pdfCompress,
  imageConvert,
  pdfSplit,
  pdfToImages,
  scanDocument,
  // 1.3 Text Recognition (RELEASE_V1_3).
  ocr,
  // 1.4 Secure & Sign (RELEASE_V1_4).
  pdfSign,
  pdfWatermark,
  pdfProtect,
  pdfUnlock,
  // 1.6 Print (RELEASE_PRINT).
  print,
}

/// `scan` is Home's "Scan & Text" section (1.2; OCR joins it in 1.3);
/// `secure` is "Secure & Sign" (1.4).
enum ToolCategory {
  image,
  pdf,
  scan,
  secure;

  /// Tools whose output is a PDF (history's PDFs filter, search's "pdf" boost).
  bool get makesPdf => this == pdf || this == secure;
}

/// `camera`: pages come from the system scanner, not a picker (1.2).
/// `imagesOrPdf`: up to the maximum of images, or exactly one PDF (OCR, 1.3).
enum InputKind { images, pdfs, singleImage, singlePdf, camera, imagesOrPdf }

class ToolDescriptor {
  const ToolDescriptor({
    required this.id,
    required this.category,
    required this.slug,
    required this.icon,
    required this.inputKind,
    required this.minInputs,
    required this.maxInputs,
  });

  final ToolId id;
  final ToolCategory category;

  /// Route segment, e.g. `image-compress` → `/tool/image-compress`.
  final String slug;
  final IconData icon;
  final InputKind inputKind;
  final int minInputs, maxInputs;

  String get route => '/tool/$slug';

  String title(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.toolImageCompressTitle,
        ToolId.imageResize => l.toolImageResizeTitle,
        ToolId.imageToPdf => l.toolImageToPdfTitle,
        ToolId.pdfMerge => l.toolPdfMergeTitle,
        ToolId.pdfOrganize => l.toolPdfOrganizeTitle,
        ToolId.pdfCompress => l.toolPdfCompressTitle,
        ToolId.imageConvert => l.toolImageConvertTitle,
        ToolId.pdfSplit => l.toolPdfSplitTitle,
        ToolId.pdfToImages => l.toolPdfToImagesTitle,
        ToolId.scanDocument => l.toolScanTitle,
        ToolId.ocr => l.toolOcrTitle,
        ToolId.pdfSign => l.toolPdfSignTitle,
        ToolId.pdfWatermark => l.toolPdfWatermarkTitle,
        ToolId.pdfProtect => l.toolPdfProtectTitle,
        ToolId.pdfUnlock => l.toolPdfUnlockTitle,
        ToolId.print => l.toolPrintTitle,
      };

  String subtitle(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.toolImageCompressSubtitle,
        ToolId.imageResize => l.toolImageResizeSubtitle,
        ToolId.imageToPdf => l.toolImageToPdfSubtitle,
        ToolId.pdfMerge => l.toolPdfMergeSubtitle,
        ToolId.pdfOrganize => l.toolPdfOrganizeSubtitle,
        ToolId.pdfCompress => l.toolPdfCompressSubtitle,
        ToolId.imageConvert => l.toolImageConvertSubtitle,
        ToolId.pdfSplit => l.toolPdfSplitSubtitle,
        ToolId.pdfToImages => l.toolPdfToImagesSubtitle,
        ToolId.scanDocument => l.toolScanSubtitle,
        ToolId.ocr => l.toolOcrSubtitle,
        ToolId.pdfSign => l.toolPdfSignSubtitle,
        ToolId.pdfWatermark => l.toolPdfWatermarkSubtitle,
        ToolId.pdfProtect => l.toolPdfProtectSubtitle,
        ToolId.pdfUnlock => l.toolPdfUnlockSubtitle,
        ToolId.print => l.toolPrintSubtitle,
      };

  /// Home tour copy (TOUR.md §2): a new tool automatically gets a step.
  String tourTitle(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.tourImageCompressTitle,
        ToolId.imageResize => l.tourImageResizeTitle,
        ToolId.imageToPdf => l.tourImageToPdfTitle,
        ToolId.pdfMerge => l.tourPdfMergeTitle,
        ToolId.pdfOrganize => l.tourPdfOrganizeTitle,
        ToolId.pdfCompress => l.tourPdfCompressTitle,
        ToolId.imageConvert => l.tourImageConvertTitle,
        ToolId.pdfSplit => l.tourPdfSplitTitle,
        ToolId.pdfToImages => l.tourPdfToImagesTitle,
        ToolId.scanDocument => l.tourScanTitle,
        ToolId.ocr => l.tourOcrTitle,
        // 1.4: the tool's own title and subtitle (RELEASE_V1_4 §4.9).
        ToolId.pdfSign || ToolId.pdfWatermark || ToolId.pdfProtect || ToolId.pdfUnlock => title(l),
        ToolId.print => l.tourPrintTitle,
      };

  String tourBody(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.tourImageCompressBody,
        ToolId.imageResize => l.tourImageResizeBody,
        ToolId.imageToPdf => l.tourImageToPdfBody,
        ToolId.pdfMerge => l.tourPdfMergeBody,
        ToolId.pdfOrganize => l.tourPdfOrganizeBody,
        ToolId.pdfCompress => l.tourPdfCompressBody,
        ToolId.imageConvert => l.tourImageConvertBody,
        ToolId.pdfSplit => l.tourPdfSplitBody,
        ToolId.pdfToImages => l.tourPdfToImagesBody,
        ToolId.scanDocument => l.tourScanBody,
        ToolId.ocr => l.tourOcrBody,
        ToolId.pdfSign || ToolId.pdfWatermark || ToolId.pdfProtect || ToolId.pdfUnlock => subtitle(l),
        ToolId.print => l.tourPrintBody,
      };

  String tourExample(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.tourImageCompressExample,
        ToolId.imageResize => l.tourImageResizeExample,
        ToolId.imageToPdf => l.tourImageToPdfExample,
        ToolId.pdfMerge => l.tourPdfMergeExample,
        ToolId.pdfOrganize => l.tourPdfOrganizeExample,
        ToolId.pdfCompress => l.tourPdfCompressExample,
        ToolId.imageConvert => l.tourImageConvertExample,
        ToolId.pdfSplit => l.tourPdfSplitExample,
        ToolId.pdfToImages => l.tourPdfToImagesExample,
        ToolId.scanDocument => l.tourScanExample,
        ToolId.ocr => l.tourOcrExample,
        ToolId.pdfSign => l.tourPdfSignExample,
        ToolId.pdfWatermark => l.tourPdfWatermarkExample,
        ToolId.pdfProtect => l.tourPdfProtectExample,
        ToolId.pdfUnlock => l.tourPdfUnlockExample,
        ToolId.print => l.tourPrintExample,
      };

  /// ⓘ sheet text; null until the tool's copy exists (the 1.1 tools get theirs
  /// with their screens, T8.5/T8.7/T8.9).
  String? info(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.infoImageCompress,
        ToolId.imageResize => l.infoImageResize,
        ToolId.imageToPdf => l.infoImageToPdf,
        ToolId.pdfMerge => l.infoPdfMerge,
        ToolId.pdfOrganize => l.infoPdfOrganize,
        ToolId.pdfCompress => l.infoPdfCompress,
        ToolId.imageConvert || ToolId.pdfSplit || ToolId.pdfToImages || ToolId.scanDocument || ToolId.ocr => null,
        // 1.4 tools get their ⓘ text with their screens (T11.3–T11.8).
        ToolId.pdfSign || ToolId.pdfWatermark || ToolId.pdfProtect || ToolId.pdfUnlock => null,
        ToolId.print => null,
      };
}

/// Display order for Home, Search ties and the tour (RELEASE_V1_1 §4.10).
const toolCatalog = <ToolDescriptor>[
  ToolDescriptor(
    id: ToolId.imageCompress,
    category: ToolCategory.image,
    slug: 'image-compress',
    icon: Icons.compress_rounded,
    inputKind: InputKind.images,
    minInputs: 1,
    maxInputs: 50, // FR-BAT-10: 2+ switches to the batch layout (S21)
  ),
  ToolDescriptor(
    id: ToolId.imageResize,
    category: ToolCategory.image,
    slug: 'image-resize',
    icon: Icons.aspect_ratio_rounded,
    inputKind: InputKind.images,
    minInputs: 1,
    maxInputs: 50, // FR-BAT-10
  ),
  ToolDescriptor(
    id: ToolId.imageConvert,
    category: ToolCategory.image,
    slug: 'image-convert',
    icon: Icons.swap_horiz_rounded,
    inputKind: InputKind.images,
    minInputs: 1,
    maxInputs: 50,
  ),
  ToolDescriptor(
    id: ToolId.imageToPdf,
    category: ToolCategory.image,
    slug: 'image-to-pdf',
    icon: Icons.picture_as_pdf_rounded,
    inputKind: InputKind.images,
    minInputs: 1,
    maxInputs: 100,
  ),
  ToolDescriptor(
    id: ToolId.pdfMerge,
    category: ToolCategory.pdf,
    slug: 'pdf-merge',
    icon: Icons.call_merge_rounded,
    inputKind: InputKind.pdfs,
    minInputs: 2,
    maxInputs: 20,
  ),
  ToolDescriptor(
    id: ToolId.pdfOrganize,
    category: ToolCategory.pdf,
    slug: 'pdf-organize',
    icon: Icons.grid_view_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
  ToolDescriptor(
    id: ToolId.pdfSplit,
    category: ToolCategory.pdf,
    slug: 'pdf-split',
    icon: Icons.call_split_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
  ToolDescriptor(
    id: ToolId.pdfToImages,
    category: ToolCategory.pdf,
    slug: 'pdf-to-images',
    icon: Icons.photo_library_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
  ToolDescriptor(
    id: ToolId.pdfCompress,
    category: ToolCategory.pdf,
    slug: 'pdf-compress',
    icon: Icons.folder_zip_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
  // 1.6: last in the PDF section (RELEASE_PRINT §3.4). One PDF or up to 100 images.
  ToolDescriptor(
    id: ToolId.print,
    category: ToolCategory.pdf,
    slug: 'print',
    icon: Icons.print_rounded,
    inputKind: InputKind.imagesOrPdf,
    minInputs: 1,
    maxInputs: 100, // FR-PRN-01
  ),
  ToolDescriptor(
    id: ToolId.scanDocument,
    category: ToolCategory.scan,
    slug: 'scan',
    icon: Icons.document_scanner_rounded,
    inputKind: InputKind.camera,
    minInputs: 1,
    maxInputs: 50, // FR-SCN-02
  ),
  ToolDescriptor(
    id: ToolId.ocr,
    category: ToolCategory.scan,
    slug: 'ocr',
    icon: Icons.text_fields_rounded,
    inputKind: InputKind.imagesOrPdf,
    minInputs: 1,
    maxInputs: 50, // FR-OCR-01: 50 images (or one PDF)
  ),
  // 1.4 Secure & Sign (RELEASE_V1_4 §4.9): one PDF each.
  ToolDescriptor(
    id: ToolId.pdfSign,
    category: ToolCategory.secure,
    slug: 'pdf-sign',
    icon: Icons.draw_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
  ToolDescriptor(
    id: ToolId.pdfWatermark,
    category: ToolCategory.secure,
    slug: 'pdf-watermark',
    icon: Icons.branding_watermark_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
  ToolDescriptor(
    id: ToolId.pdfProtect,
    category: ToolCategory.secure,
    slug: 'pdf-protect',
    icon: Icons.lock_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
  ToolDescriptor(
    id: ToolId.pdfUnlock,
    category: ToolCategory.secure,
    slug: 'pdf-unlock',
    icon: Icons.lock_open_rounded,
    inputKind: InputKind.singlePdf,
    minInputs: 1,
    maxInputs: 1,
  ),
];

ToolDescriptor toolById(ToolId id) => toolCatalog.firstWhere((t) => t.id == id);

ToolDescriptor? toolBySlug(String slug) {
  for (final t in toolCatalog) {
    if (t.slug == slug) return t;
  }
  return null;
}

ToolId? toolIdByName(String? name) {
  for (final t in ToolId.values) {
    if (t.name == name) return t;
  }
  return null;
}
