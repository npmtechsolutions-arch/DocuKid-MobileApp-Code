import 'tool_catalog.dart';

/// English synonym table (FEATURE_SPECS §1.1). Move into ARB arrays when a
/// second locale is added.
const toolKeywords = <ToolId, List<String>>{
  ToolId.imageCompress: [
    'compress', 'compressor', 'reduce', 'smaller', 'shrink', 'kb', 'mb', 'size', 'photo size', 'image size',
    'reduce photo size', 'make picture smaller', 'lower quality', 'optimize image', 'jpg', 'jpeg', 'png', 'webp',
    'heic', 'upload limit', 'under 100kb', 'whatsapp',
  ],
  ToolId.imageResize: [
    'resize', 'resizer', 'dimension', 'dimensions', 'pixel', 'pixels', 'width', 'height', 'scale', 'crop',
    'passport', 'signature', 'passport photo', 'profile picture', 'dp', 'instagram', 'square', 'story', 'hd', '1080',
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
};
