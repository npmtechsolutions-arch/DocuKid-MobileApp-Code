import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:pdfrx/pdfrx.dart';

import '../errors/app_error.dart';
import '../files/paths.dart';
import '../operation/tool_operation.dart';
import 'pdfium_raw_ops.dart';

/// One image to draw on one page (RELEASE_V1_4 §4.2). Geometry is in the
/// page's visual space: rotation applied, origin top-left, units = points.
class Stamp {
  const Stamp({
    required this.pageIndex,
    required this.pngPath,
    required this.visualRect,
    this.rotationDegrees = 0,
    this.opacity = 1,
  });

  /// 0-based.
  final int pageIndex;

  /// RGBA PNG, transparent where empty.
  final String pngPath;

  /// The stamp's box before its own rotation.
  final Rect visualRect;

  /// Clockwise, about the box's centre.
  final double rotationDegrees;

  /// 0.1–1.0, baked into the image's alpha.
  final double opacity;
}

abstract interface class PdfStamper {
  /// Writes a NEW file at [outPath]; reports Determinate progress over the
  /// pages that get stamps. The input must not be encrypted.
  Future<void> apply(String inPath, List<Stamp> stamps, String outPath, JobContext ctx);
}

/// PDFium image objects, one shared form XObject per image (ADR-048), in
/// pdfrx's PDFium worker.
class PdfiumStamper implements PdfStamper {
  const PdfiumStamper();

  @override
  Future<void> apply(String inPath, List<Stamp> stamps, String outPath, JobContext ctx) async {
    ctx.cancel.throwIfCancelled();
    final flag = calloc<Uint8>();
    final port = ReceivePort();
    final finished = Completer<void>();
    final cancelWatch = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (ctx.cancel.isCancelled) flag.value = 1;
    });
    port.listen((m) {
      if (m is List && m.length == 2) {
        ctx.report(Determinate(m[0] as int, m[1] as int, 'stepAddingStamps'));
      } else if (m == StampRequest.finished && !finished.isCompleted) {
        finished.complete();
      }
    });
    try {
      final result = await PdfrxEntryFunctions.instance.compute(
        stampInWorker,
        StampRequest(
          input: inPath,
          output: outPath,
          stamps: [
            for (final s in stamps)
              (s.pageIndex, s.pngPath, s.visualRect, s.rotationDegrees, s.opacity.clamp(0.0, 1.0).toDouble()),
          ],
          cancelFlagAddress: flag.address,
          progress: port.sendPort,
          modulePath: Pdfrx.pdfiumModulePath,
        ),
      );
      // Progress messages sent before the result must not be lost.
      await finished.future.timeout(const Duration(seconds: 2), onTimeout: () {});
      if (result == RawResult.ok) return;
      await deleteQuietly(File(outPath));
      throw switch (result) {
        RawResult.cancelled => const CancelledException(),
        RawResult.encrypted => const AppError(AppErrorCode.encryptedDocument),
        RawResult.corrupt => const AppError(AppErrorCode.corruptFile),
        RawResult.invalid => const AppError(AppErrorCode.invalidInput),
        _ => const AppError(AppErrorCode.processingFailed),
      };
    } finally {
      cancelWatch.cancel();
      port.close();
      calloc.free(flag);
    }
  }
}
