import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../errors/app_error.dart';
import '../files/paths.dart';
import '../operation/tool_operation.dart';
import '../pdf/pdfium_raw_ops.dart';
import 'print_settings.dart';

/// What gets printed (RELEASE_PRINT §4.3). Images arrive in T13.3.
sealed class PrintSource {
  const PrintSource();
}

final class PdfPrintSource extends PrintSource {
  const PdfPrintSource(this.path);

  /// A working copy; it isn't modified.
  final String path;
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

/// Vector placement with PDFium page XObjects in pdfrx's PDFium worker (ADR-070).
class PdfiumPrintComposer implements PrintComposer {
  const PdfiumPrintComposer();

  static const fileName = 'print.pdf';

  @override
  Future<PrintOutput> compose(PrintSource src, PrintSettings s, JobContext ctx, {Set<String> endWords = const {'end'}}) {
    return switch (src) {
      PdfPrintSource(:final path) => _pdf(path, s, ctx, endWords),
    };
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
