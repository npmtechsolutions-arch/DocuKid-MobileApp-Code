import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// The tool catalogue — single source of truth for Home, Search, History
/// (ARCHITECTURE §4). Adding a tool = an entry here + a feature folder + one
/// ToolOperation.
enum ToolId { imageCompress, imageResize, imageToPdf, pdfMerge, pdfOrganize, pdfCompress }

enum ToolCategory { image, pdf }

enum InputKind { images, pdfs, singleImage, singlePdf }

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
      };

  String subtitle(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.toolImageCompressSubtitle,
        ToolId.imageResize => l.toolImageResizeSubtitle,
        ToolId.imageToPdf => l.toolImageToPdfSubtitle,
        ToolId.pdfMerge => l.toolPdfMergeSubtitle,
        ToolId.pdfOrganize => l.toolPdfOrganizeSubtitle,
        ToolId.pdfCompress => l.toolPdfCompressSubtitle,
      };

  /// Home tour copy (TOUR.md §2): a new tool automatically gets a step.
  String tourTitle(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.tourImageCompressTitle,
        ToolId.imageResize => l.tourImageResizeTitle,
        ToolId.imageToPdf => l.tourImageToPdfTitle,
        ToolId.pdfMerge => l.tourPdfMergeTitle,
        ToolId.pdfOrganize => l.tourPdfOrganizeTitle,
        ToolId.pdfCompress => l.tourPdfCompressTitle,
      };

  String tourBody(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.tourImageCompressBody,
        ToolId.imageResize => l.tourImageResizeBody,
        ToolId.imageToPdf => l.tourImageToPdfBody,
        ToolId.pdfMerge => l.tourPdfMergeBody,
        ToolId.pdfOrganize => l.tourPdfOrganizeBody,
        ToolId.pdfCompress => l.tourPdfCompressBody,
      };

  String tourExample(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.tourImageCompressExample,
        ToolId.imageResize => l.tourImageResizeExample,
        ToolId.imageToPdf => l.tourImageToPdfExample,
        ToolId.pdfMerge => l.tourPdfMergeExample,
        ToolId.pdfOrganize => l.tourPdfOrganizeExample,
        ToolId.pdfCompress => l.tourPdfCompressExample,
      };

  String info(AppLocalizations l) => switch (id) {
        ToolId.imageCompress => l.infoImageCompress,
        ToolId.imageResize => l.infoImageResize,
        ToolId.imageToPdf => l.infoImageToPdf,
        ToolId.pdfMerge => l.infoPdfMerge,
        ToolId.pdfOrganize => l.infoPdfOrganize,
        ToolId.pdfCompress => l.infoPdfCompress,
      };
}

const toolCatalog = <ToolDescriptor>[
  ToolDescriptor(
    id: ToolId.imageCompress,
    category: ToolCategory.image,
    slug: 'image-compress',
    icon: Icons.compress_rounded,
    inputKind: InputKind.singleImage,
    minInputs: 1,
    maxInputs: 1,
  ),
  ToolDescriptor(
    id: ToolId.imageResize,
    category: ToolCategory.image,
    slug: 'image-resize',
    icon: Icons.aspect_ratio_rounded,
    inputKind: InputKind.singleImage,
    minInputs: 1,
    maxInputs: 1,
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
    id: ToolId.pdfCompress,
    category: ToolCategory.pdf,
    slug: 'pdf-compress',
    icon: Icons.folder_zip_rounded,
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
