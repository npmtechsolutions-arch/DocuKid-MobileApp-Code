import 'tool_catalog.dart';

/// English synonym table (FEATURE_SPECS §1.1). Move into ARB arrays when a
/// second locale is added.
const toolKeywords = <ToolId, List<String>>{
  ToolId.imageCompress: [
    'compress', 'compressor', 'reduce', 'smaller', 'shrink', 'kb', 'mb', 'size', 'photo size', 'image size',
    'reduce photo size', 'make picture smaller', 'lower quality', 'optimize image', 'jpg', 'jpeg', 'png', 'webp',
    'heic', 'upload limit', 'under 100kb', 'whatsapp',
    // 1.1 batch (RELEASE_V1_1 §4.10)
    'batch', 'many photos', 'multiple images', 'all photos', 'bulk',
  ],
  ToolId.imageResize: [
    'resize', 'resizer', 'dimension', 'dimensions', 'pixel', 'pixels', 'width', 'height', 'scale', 'crop',
    'passport', 'signature', 'passport photo', 'profile picture', 'dp', 'instagram', 'square', 'story', 'hd', '1080',
    'batch', 'many photos', 'multiple images', 'all photos', 'bulk',
  ],
  // 1.1 tools (RELEASE_V1_1 §4.10).
  ToolId.imageConvert: [
    'convert', 'heic', 'heic to jpg', 'png to jpg', 'jpg to png', 'webp', 'change format', 'format', 'iphone photo',
  ],
  ToolId.imageToPdf: [
    'image to pdf', 'photo to pdf', 'jpg to pdf', 'picture to pdf', 'convert', 'scan', 'notes', 'receipts',
    'gallery to pdf', 'png to pdf', 'make pdf', 'create pdf',
  ],
  ToolId.pdfMerge: [
    'merge', 'combine', 'join', 'append', 'together', 'one pdf', 'multiple pdf', 'unite', 'attach pdf',
  ],
  ToolId.pdfOrganize: [
    'organize', 'organise', 'reorder', 'rearrange', 'sort pages', 'rotate', 'rotate page', 'delete page',
    'remove page', 'move page', 'pages', 'arrange',
  ],
  ToolId.pdfCompress: [
    'compress pdf', 'reduce pdf', 'shrink pdf', 'pdf size', 'smaller pdf', 'optimize pdf', 'email limit', 'pdf kb',
    'pdf mb',
  ],
  ToolId.pdfSplit: [
    'split', 'separate', 'divide', 'cut pdf', 'break', 'extract pages', 'ranges', 'pages to pdf',
  ],
  ToolId.pdfToImages: [
    'pdf to jpg', 'pdf to png', 'pdf to image', 'export pages', 'page to photo', 'screenshot pdf',
  ],
  // 1.2 (RELEASE_V1_2 FR-SCN-25).
  ToolId.scanDocument: [
    'scan', 'scanner', 'camera', 'photo of document', 'paper', 'receipt', 'notes', 'digitize', 'capture',
    'document camera', 'cam scanner',
  ],
  // 1.3 (RELEASE_V1_3 §3.6).
  ToolId.ocr: [
    'ocr', 'text recognition', 'recognize text', 'recognise text', 'extract text', 'copy text', 'scan to text',
    'image to text', 'picture to text', 'photo to text', 'searchable pdf', 'make pdf searchable', 'read text',
    'text from image', 'convert to text', 'txt',
  ],
  // 1.4 (RELEASE_V1_4 §4.9). Never keywords suggesting a bypass (ADR-053).
  ToolId.pdfSign: [
    'sign', 'signature', 'e-sign', 'esign', 'autograph', 'initials', 'fill and sign', 'sign document', 'sign contract',
    'add signature',
  ],
  ToolId.pdfWatermark: ['watermark', 'stamp', 'confidential', 'draft', 'logo on pdf', 'mark pages', 'copyright'],
  ToolId.pdfProtect: ['password', 'protect', 'lock', 'encrypt', 'secure pdf', 'add password', 'password protect'],
  ToolId.pdfUnlock: ['unlock', 'remove password', 'decrypt', 'open locked pdf'],
};
