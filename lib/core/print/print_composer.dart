import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfColor, PdfPageFormat, PdfPoint;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' show PdfDocument, Pdfrx, PdfrxEntryFunctions;

import '../errors/app_error.dart';
import '../files/paths.dart';
import '../files/picked_file.dart';
import '../image/image_engine.dart';
import '../image/image_options.dart';
import '../operation/tool_operation.dart';
import '../pdf/pdf_engine.dart';
import '../pdf/pdfium_raw_ops.dart';
import 'print_geometry.dart';
import 'print_settings.dart';

/// What gets printed (RELEASE_PRINT §4.3).
sealed class PrintSource {
  const PrintSource();
}

final class PdfPrintSource extends PrintSource {
  const PdfPrintSource(this.path);

  /// A working copy; it isn't modified.
  final String path;
}

final class ImagesPrintSource extends PrintSource {
  const ImagesPrintSource(this.images);

  /// 1–100 images with their header metadata (FR-PRN-01); the passport
  /// sheet uses the first.
  final List<PickedFile> images;
}

/// The print-ready PDF, re-opened and checked (ARCHITECTURE §5.4).
class PrintOutput {
  const PrintOutput({required this.path, required this.sheetCount, required this.sheetSizesPt});
  final String path;
  final int sheetCount;
  final List<Size> sheetSizesPt;
}

abstract interface class PrintComposer {
  /// Builds `print.pdf` in ctx.workDir, replacing any earlier one, and
  /// reports Determinate(sheet, totalSheets). [endWords] are the range words
  /// for the last page. Throws AppError(invalidInput) for a bad range or no
  /// pages, encryptedDocument, corruptFile or processingFailed;
  /// CancelledException when cancelled.
  Future<PrintOutput> compose(PrintSource src, PrintSettings s, JobContext ctx, {Set<String> endWords = const {'end'}});
}

/// PDFs: vector placement with PDFium page XObjects in pdfrx's PDFium worker
/// (ADR-070). Images: normalised one at a time like Images to PDF (ADR-012),
/// then laid out with `pdf` in an isolate, in chunks that PDFium merges.
class PdfiumPrintComposer implements PrintComposer {
  /// [images] and [pdf] are needed for image input only.
  const PdfiumPrintComposer({this.images, this.pdf});
  final ImageEngine? images;
  final PdfEngine? pdf;

  static const fileName = 'print.pdf';
  static const chunkSheets = 20;

  /// The most an image needs at its printed size (§4.3).
  static const imageDpi = 300;

  @override
  Future<PrintOutput> compose(PrintSource src, PrintSettings s, JobContext ctx, {Set<String> endWords = const {'end'}}) {
    return switch (src) {
      PdfPrintSource(:final path) => _pdf(path, s, ctx, endWords),
      ImagesPrintSource(images: final files) => _images(files, s, ctx),
    };
  }

  Future<PrintOutput> _images(List<PickedFile> files, PrintSettings s, JobContext ctx) async {
    ctx.cancel.throwIfCancelled();
    final engine = images, merger = pdf;
    if (engine == null || merger == null) throw StateError('Image printing needs an ImageEngine and a PdfEngine');
    final out = p.join(ctx.workDir.path, fileName);
    final temps = <String>[];
    try {
      await deleteQuietly(File(out));
      final sizes = <Size>[];
      for (final f in files) {
        final m = f.image;
        if (m == null) throw const AppError(AppErrorCode.corruptFile);
        sizes.add(imageSizePt(m.width, m.height));
      }
      final plan = planImageSheets(sizes, s);
      if (plan.isEmpty) throw const AppError(AppErrorCode.invalidInput);

      // One JPEG per image and turn, big enough for its largest placement.
      final need = <(int, int), double>{};
      for (final sheet in plan) {
        for (final pg in sheet.pages) {
          final key = (pg.source, pg.placement.quarterTurn);
          need[key] = math.max(need[key] ?? 0, math.max(pg.placement.rect.width, pg.placement.rect.height));
        }
      }
      final jpegs = <(int, int), String>{};
      for (final (i, MapEntry(key: key, value: longPt)) in need.entries.indexed) {
        ctx.cancel.throwIfCancelled();
        ctx.report(Determinate(i, need.length, 'stepPreparing', unit: ProgressUnit.images));
        final (src, turn) = key;
        final meta = files[src].image!;
        final path = p.join(ctx.workDir.path, 'print_img_$i.jpg');
        temps.add(path);
        await engine.transform(
          files[src].path,
          path,
          ImageTransform(
            format: ImageFormat.jpeg,
            quality: 90,
            maxLongEdge: math.min((longPt / 72 * imageDpi).ceil(), math.max(meta.width, meta.height)),
            extraRotation: turn == 1 ? 270 : 0, // a quarter anticlockwise, like PDF pages
            stripMetadata: true,
          ),
          meta: meta,
        );
        jpegs[key] = path;
      }

      final sheets = [
        for (final sheet in plan)
          _ImageSheet(sheet.size, [
            for (final pg in sheet.pages) (jpegs[(pg.source, pg.placement.quarterTurn)]!, pg.cell, pg.placement.rect),
          ]),
      ];
      final cutMarks = s.imageLayout == ImageLayout.passportSheet;
      if (sheets.length <= chunkSheets) {
        ctx.cancel.throwIfCancelled();
        ctx.report(Determinate(0, sheets.length, 'stepPreparing'));
        await Isolate.run(() => _writeImageSheets(sheets, out, cutMarks));
      } else {
        final chunks = <String>[];
        for (var start = 0; start < sheets.length; start += chunkSheets) {
          ctx.cancel.throwIfCancelled();
          ctx.report(Determinate(start, sheets.length, 'stepPreparing'));
          final part = sheets.sublist(start, math.min(start + chunkSheets, sheets.length));
          final path = p.join(ctx.workDir.path, 'print_chunk_$start.pdf');
          temps.add(path);
          await Isolate.run(() => _writeImageSheets(part, path, cutMarks));
          chunks.add(path);
        }
        ctx.cancel.throwIfCancelled();
        await merger.combineFiles(chunks, out);
      }
      ctx.report(Determinate(sheets.length, sheets.length, 'stepPreparing'));
      final sheetSizes = [for (final sh in sheets) sh.size];
      await _validate(out, sheetSizes);
      return PrintOutput(path: out, sheetCount: sheetSizes.length, sheetSizesPt: sheetSizes);
    } catch (_) {
      await deleteQuietly(File(out));
      rethrow;
    } finally {
      for (final t in temps) {
        await deleteQuietly(File(t));
      }
    }
  }

  Future<PrintOutput> _pdf(String input, PrintSettings s, JobContext ctx, Set<String> endWords) async {
    ctx.cancel.throwIfCancelled();
    final out = p.join(ctx.workDir.path, fileName);
    final flag = calloc<Uint8>();
    final port = ReceivePort();
    final finished = Completer<void>();
    final cancelWatch = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (ctx.cancel.isCancelled) flag.value = 1;
    });
    port.listen((m) {
      if (m is List && m.length == 2) {
        ctx.report(Determinate(m[0] as int, m[1] as int, 'stepPreparing'));
        // A cancel from the progress listener reaches the worker by the next sheet.
        if (ctx.cancel.isCancelled) flag.value = 1;
      } else if (m == StampRequest.finished && !finished.isCompleted) {
        finished.complete();
      }
    });
    try {
      await deleteQuietly(File(out));
      final result = await PdfrxEntryFunctions.instance.compute(
        printSheetsInWorker,
        PrintSheetsRequest(
          input: input,
          output: out,
          settings: s,
          endWords: endWords,
          cancelFlagAddress: flag.address,
          progress: port.sendPort,
          modulePath: Pdfrx.pdfiumModulePath,
        ),
      );
      // Progress messages sent before the result must not be lost.
      await finished.future.timeout(const Duration(seconds: 2), onTimeout: () {});
      if (result.code != RawResult.ok) {
        throw switch (result.code) {
          RawResult.cancelled => const CancelledException(),
          RawResult.encrypted => const AppError(AppErrorCode.encryptedDocument),
          RawResult.corrupt => const AppError(AppErrorCode.corruptFile),
          RawResult.invalid => const AppError(AppErrorCode.invalidInput),
          _ => const AppError(AppErrorCode.processingFailed),
        };
      }
      final sizes = [for (final (w, h) in result.sheets) Size(w, h)];
      await _validate(out, sizes);
      return PrintOutput(path: out, sheetCount: sizes.length, sheetSizesPt: sizes);
    } catch (_) {
      await deleteQuietly(File(out));
      rethrow;
    } finally {
      cancelWatch.cancel();
      port.close();
      calloc.free(flag);
    }
  }

  /// Rule 2: the file opens, with one page per planned sheet at its size.
  static Future<void> _validate(String path, List<Size> sizes) async {
    PdfDocument? d;
    try {
      d = await PdfDocument.openFile(path);
      final pages = d.pages;
      if (pages.length != sizes.length) throw const AppError(AppErrorCode.outputValidationFailed);
      for (final (i, pg) in pages.indexed) {
        if ((pg.width - sizes[i].width).abs() > 1 || (pg.height - sizes[i].height).abs() > 1) {
          throw const AppError(AppErrorCode.outputValidationFailed);
        }
      }
    } on AppError {
      rethrow;
    } catch (_) {
      throw const AppError(AppErrorCode.outputValidationFailed);
    } finally {
      await d?.dispose();
    }
  }
}

/// One sheet of images: (JPEG, cell, placed rect), top-down points.
class _ImageSheet {
  const _ImageSheet(this.size, this.items);
  final Size size;
  final List<(String, Rect, Rect)> items;
}

/// FR-PRN-10: 1 mm ticks continuing each photo edge past its corners, so the
/// marks from neighbours meet in the middle of the 2 mm gap.
const _cutMarkPt = 72 / 25.4;
const _cutMarkGrey = PdfColor(0.75, 0.75, 0.75);

Future<void> _writeImageSheets(List<_ImageSheet> sheets, String out, bool cutMarks) async {
  final doc = pw.Document(compress: true);
  // One embedded image per JPEG, however many cells show it.
  final cache = <String, pw.MemoryImage>{};
  for (final sh in sheets) {
    final w = sh.size.width, h = sh.size.height;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(w, h, marginAll: 0),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.SizedBox(
        width: w,
        height: h,
        child: pw.Stack(children: [
          for (final (jpeg, cell, rect) in sh.items)
            pw.Positioned(
              left: cell.left,
              top: cell.top,
              // A Stack clips what overflows it: Fill and the passport cover crop.
              child: pw.SizedBox(
                width: cell.width,
                height: cell.height,
                child: pw.Stack(children: [
                  pw.Positioned(
                    left: rect.left - cell.left,
                    top: rect.top - cell.top,
                    child: pw.SizedBox(
                      width: rect.width,
                      height: rect.height,
                      child: pw.Image(cache[jpeg] ??= pw.MemoryImage(File(jpeg).readAsBytesSync()), fit: pw.BoxFit.fill),
                    ),
                  ),
                ]),
              ),
            ),
          if (cutMarks)
            pw.Positioned.fill(
              child: pw.CustomPaint(
                size: PdfPoint(w, h),
                painter: (canvas, _) {
                  canvas
                    ..setStrokeColor(_cutMarkGrey)
                    ..setLineWidth(0.2);
                  for (final (_, c, _) in sh.items) {
                    for (final (x, dx) in [(c.left, -1.0), (c.right, 1.0)]) {
                      for (final (y, dy) in [(c.top, -1.0), (c.bottom, 1.0)]) {
                        // The painter is y-up from the sheet's bottom-left.
                        canvas
                          ..moveTo(x, h - y)
                          ..lineTo(x + dx * _cutMarkPt, h - y)
                          ..moveTo(x, h - y)
                          ..lineTo(x, h - (y + dy * _cutMarkPt));
                      }
                    }
                  }
                  canvas.strokePath();
                },
              ),
            ),
        ]),
      ),
    ));
  }
  await File(out).writeAsBytes(await doc.save(), flush: true);
}
