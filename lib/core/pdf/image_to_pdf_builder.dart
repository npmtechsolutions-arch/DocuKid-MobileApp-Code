import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../errors/app_error.dart';
import '../files/picked_file.dart';
import '../image/image_engine.dart';
import '../image/image_options.dart';
import '../operation/tool_operation.dart';
import 'image_to_pdf_layout.dart';
import 'pdf_engine.dart';
import 'pdf_options.dart';

class ImageToPdfItem {
  const ImageToPdfItem(this.file, this.quarterTurns);
  final PickedFile file;
  final int quarterTurns;
}

class ImageToPdfSettings {
  const ImageToPdfSettings({
    required this.size,
    required this.orientation,
    required this.fit,
    required this.margin,
    required this.quality,
    this.imageDpi = 150,
    this.savingStepKey = 'stepSavingPages',
  });
  final PdfPageSize size;
  final PdfOrientation orientation;
  final PdfFit fit;
  final PdfMargin margin;
  final PdfImageQuality quality;

  /// Page size for [PdfPageSize.image]: 150 dpi, or 200 for Fit to scan.
  final int imageDpi;

  /// Progress label while the pages are written ("Saving your scan…" for Scan).
  final String savingStepKey;
}

/// One image failed; the UI offers "Remove and continue" (FR-I2P-05).
class ImageItemFailed extends AppError {
  const ImageItemFailed(super.code, {required this.index, super.fileDisplayName});
  final int index;
}

/// ADR-012: normalise each image to an oriented JPEG one at a time (native),
/// then lay out pages with `pdf` in an isolate, always in chunks of
/// [chunkPages] that PDFium merges, so memory stays flat however many images
/// there are (TESTING §6: 100 × 12 MP used +369 MB in one document).
class ImageToPdfBuilder {
  ImageToPdfBuilder(this._images, this._pdf);
  final ImageEngine _images;
  final PdfEngine _pdf;

  static const chunkPages = 20;

  Future<String> build(List<ImageToPdfItem> items, ImageToPdfSettings s, JobContext ctx) async {
    final prepared = <_PreparedPage>[];
    for (var i = 0; i < items.length; i++) {
      ctx.cancel.throwIfCancelled();
      ctx.report(Determinate(i, items.length, 'stepBuildingPdf', unit: ProgressUnit.images));
      final item = items[i];
      final meta = item.file.image;
      if (meta == null) throw ImageItemFailed(AppErrorCode.corruptFile, index: i, fileDisplayName: item.file.displayName);
      final (w, h) = rotatedSize(meta.width, meta.height, item.quarterTurns);
      final layout = layoutImagePage(
        imageWidth: w,
        imageHeight: h,
        size: s.size,
        orientation: s.orientation,
        fit: s.fit,
        margin: s.margin,
        dpiCap: s.quality.dpiCap,
        imageDpi: s.imageDpi,
      );
      final out = p.join(ctx.workDir.path, 'img_$i.jpg');
      try {
        await _images.transform(
          item.file.path,
          out,
          ImageTransform(
            format: ImageFormat.jpeg,
            quality: s.quality.jpegQuality,
            maxLongEdge: math.min(layout.maxLongEdgePx, math.max(w, h)),
            extraRotation: item.quarterTurns * 90,
            stripMetadata: true,
          ),
          meta: meta,
        );
      } on AppError catch (e) {
        if (e.code == AppErrorCode.cancelled) rethrow;
        throw ImageItemFailed(e.code, index: i, fileDisplayName: item.file.displayName);
      }
      prepared.add(_PreparedPage(out, layout));
    }

    ctx.cancel.throwIfCancelled();
    ctx.report(Indeterminate(s.savingStepKey));
    final finalPath = p.join(ctx.workDir.path, 'images.pdf');
    if (prepared.length <= chunkPages) {
      // A single chunk is already the whole document: nothing to merge.
      await Isolate.run(() => _writePdf(prepared, finalPath));
      return finalPath;
    }
    final chunks = <String>[];
    for (var start = 0; start < prepared.length; start += chunkPages) {
      ctx.cancel.throwIfCancelled();
      final part = prepared.sublist(start, math.min(start + chunkPages, prepared.length));
      final path = p.join(ctx.workDir.path, 'chunk_$start.pdf');
      await Isolate.run(() => _writePdf(part, path));
      chunks.add(path);
    }
    await _pdf.combineFiles(chunks, finalPath);
    return finalPath;
  }
}

class _PreparedPage {
  const _PreparedPage(this.jpegPath, this.layout);
  final String jpegPath;
  final PageLayout layout;
}

Future<void> _writePdf(List<_PreparedPage> pages, String out) async {
  final doc = pw.Document(compress: true);
  for (final page in pages) {
    final l = page.layout;
    final image = pw.MemoryImage(File(page.jpegPath).readAsBytesSync());
    final pw.Widget child = l.fills
        ? pw.Positioned(
            left: l.boxLeft,
            top: l.boxTop,
            child: pw.SizedBox(width: l.boxWidth, height: l.boxHeight, child: pw.Image(image, fit: pw.BoxFit.cover)),
          )
        : pw.Positioned(
            left: l.drawLeft,
            top: l.drawTop,
            child: pw.SizedBox(width: l.drawWidth, height: l.drawHeight, child: pw.Image(image, fit: pw.BoxFit.fill)),
          );
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(l.pageWidth, l.pageHeight, marginAll: 0),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.SizedBox(
        width: l.pageWidth,
        height: l.pageHeight,
        child: pw.Stack(children: [child]),
      ),
    ));
  }
  await File(out).writeAsBytes(await doc.save(), flush: true);
}
