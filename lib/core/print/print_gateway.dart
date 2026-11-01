import 'dart:ui';

import 'package:docukit_native/docukit_native.dart';

import '../platform/system_flow.dart';
import 'print_composer.dart';

/// FR-PRN-12: what the system reports. Never "printed": phones only know the
/// job was handed over.
enum PrintOutcome { sent, cancelled, failed }

/// Print work folders are `cache/jobs/print_<id>`; the launch sweep removes
/// them whatever their age (FR-PRN-13).
const printJobPrefix = 'print_';

/// The system print dialog (RELEASE_PRINT §4.2, ADR-069).
abstract interface class PrintGateway {
  /// False only where printing is switched off (iOS profiles).
  Future<bool> available();

  /// Opens the dialog on [out] and waits for the job's final state. [origin]
  /// anchors the iPad popover.
  Future<PrintOutcome> print(PrintOutput out, {required String jobName, Rect? origin});
}

/// The paper the dialog starts on, portrait-normalised: the size most sheets
/// use, in the orientation most sheets use; ties follow the first sheet.
/// Android's dialog takes one paper for the whole job.
({double widthPt, double heightPt, bool landscape}) dialogPaper(List<Size> sheets) {
  Size portrait(Size s) => s.width <= s.height ? s : Size(s.height, s.width);
  final counts = <Size, int>{};
  Size? key(Size s) {
    final p = portrait(s);
    for (final k in counts.keys) {
      if ((k.width - p.width).abs() <= 1 && (k.height - p.height).abs() <= 1) return k;
    }
    return null;
  }

  for (final s in sheets) {
    final k = key(s) ?? portrait(s);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  // Map order is insertion order, so the first sheet's size wins a tie.
  var best = counts.keys.first;
  for (final e in counts.entries) {
    if (e.value > counts[best]!) best = e.key;
  }
  final land = sheets.where((s) => s.width > s.height).length;
  final port = sheets.length - land;
  final landscape = land == port ? sheets.first.width > sheets.first.height : land > port;
  return (widthPt: best.width, heightPt: best.height, landscape: landscape);
}

class NativePrintGateway implements PrintGateway {
  NativePrintGateway(this._native);
  final DocukitNative _native;

  @override
  Future<bool> available() async {
    try {
      return await _native.printingAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PrintOutcome> print(PrintOutput out, {required String jobName, Rect? origin}) async {
    final paper = dialogPaper(out.sheetSizesPt);
    try {
      final status = await SystemFlow.run(
        () => _native.printPdf(
          out.path,
          jobName: jobName,
          widthPt: paper.widthPt,
          heightPt: paper.heightPt,
          landscape: paper.landscape,
          origin: origin,
        ),
      );
      return switch (status) {
        'sent' => PrintOutcome.sent,
        'cancelled' => PrintOutcome.cancelled,
        _ => PrintOutcome.failed,
      };
    } catch (_) {
      return PrintOutcome.failed;
    }
  }
}
