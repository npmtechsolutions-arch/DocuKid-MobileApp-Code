import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/search/tool_catalog.dart';
import '../errors/app_error.dart';
import '../operation/tool_operation.dart';
import 'file_naming.dart';
import 'paths.dart';

/// One file to put in a ZIP: its path on disk and the name it should have.
class ZipItem {
  const ZipItem(this.path, this.name);
  final String path, name;
}

/// FR-BAT-03: `DocuKit_<tool>_<yyyyMMdd_HHmm>.zip`.
String zipFileName(ToolId tool, DateTime now) => 'DocuKit_${tool.name}_${DateFormat('yyyyMMdd_HHmm').format(now)}.zip';

const _alreadyCompressed = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', '.pdf', '.zip'};

/// Images and PDFs are already compressed: STORE them (no time or battery
/// spent for nothing); anything else is deflated.
CompressionType compressionFor(String name) =>
    _alreadyCompressed.contains(p.extension(name).toLowerCase()) ? CompressionType.none : CompressionType.deflate;

/// Builds [outPath] by streaming each file from disk (RELEASE_V1_1 §4.5,
/// ADR-060: `addArchiveFile` with STORE entries; `addFile` buffers and always
/// deflates). Runs in a worker isolate; [onProgress] gets (entries written,
/// total). Cancel stops after the current entry. Entry names are made safe
/// and unique. The result is reopened and its entry count checked before
/// this returns; on any failure no file is left at [outPath].
///
/// Throws [CancelledException], or [AppError] (processingFailed /
/// outputValidationFailed). Returns the entry count.
Future<int> buildZip(
  List<ZipItem> items,
  String outPath, {
  CancelToken? cancel,
  void Function(int done, int total)? onProgress,
}) async {
  try {
    cancel?.throwIfCancelled();
    final names = uniqueNames([for (final i in items) i.name]);
    final entries = [for (var i = 0; i < items.length; i++) (items[i].path, names[i])];
    await _runWorker(entries, outPath, cancel, onProgress);
    cancel?.throwIfCancelled();
    final count = await Isolate.run(() => _entryCount(outPath));
    if (count != items.length) throw const AppError(AppErrorCode.outputValidationFailed);
    return count;
  } catch (e) {
    await deleteQuietly(File(outPath));
    if (e is CancelledException || e is AppError) rethrow;
    throw const AppError(AppErrorCode.processingFailed);
  }
}

Future<void> _runWorker(
  List<(String, String)> entries,
  String outPath,
  CancelToken? cancel,
  void Function(int, int)? onProgress,
) async {
  final port = ReceivePort();
  final done = Completer<void>();
  SendPort? toWorker;
  final isolate = await Isolate.spawn(_zipWorker, (port.sendPort, entries, outPath), onExit: port.sendPort);
  try {
    port.listen((msg) {
      switch (msg) {
        case SendPort():
          toWorker = msg;
          if (cancel?.isCancelled ?? false) msg.send(true);
        case int():
          onProgress?.call(msg, entries.length);
          if (cancel?.isCancelled ?? false) toWorker?.send(true);
        case 'done':
          if (!done.isCompleted) done.complete();
        case 'cancelled':
          if (!done.isCompleted) done.completeError(const CancelledException());
        default:
          // 'error', or the isolate exited (onExit sends null) without finishing.
          if (!done.isCompleted) done.completeError(const AppError(AppErrorCode.processingFailed));
      }
    });
    await done.future;
  } finally {
    port.close();
    isolate.kill();
  }
}

/// Worker: writes the ZIP entry by entry, yielding between entries so a
/// cancel message can arrive. Sends its inbox, then n after each entry, then
/// 'done' / 'cancelled' / 'error'. Never sends names or paths.
Future<void> _zipWorker((SendPort, List<(String, String)>, String) args) async {
  final (out, entries, outPath) = args;
  final inbox = ReceivePort();
  var cancelled = false;
  inbox.listen((_) => cancelled = true);
  out.send(inbox.sendPort);
  final enc = ZipFileEncoder()..create(outPath);
  var result = 'done';
  try {
    for (var i = 0; i < entries.length; i++) {
      await Future<void>.delayed(Duration.zero);
      if (cancelled) {
        result = 'cancelled';
        break;
      }
      final (path, name) = entries[i];
      final input = InputFileStream(path);
      try {
        enc.addArchiveFile(ArchiveFile.stream(name, input)..compression = compressionFor(name));
      } finally {
        input.closeSync();
      }
      out.send(i + 1);
    }
  } catch (_) {
    result = 'error';
  } finally {
    try {
      enc.closeSync();
    } catch (_) {
      result = 'error';
    }
    inbox.close();
  }
  out.send(result);
}

/// Reads the central directory back (ADR-060: `decodeStream`).
int _entryCount(String zip) {
  final input = InputFileStream(zip);
  try {
    return ZipDecoder().decodeStream(input).files.length;
  } finally {
    input.closeSync();
  }
}
