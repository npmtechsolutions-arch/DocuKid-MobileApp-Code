import 'dart:async';
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/operation/multi_output.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/core/scan/document_scanner.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

Future<AppPaths> tempPaths() async {
  final root = await Directory.systemTemp.createTemp('docukit_test_');
  final cache = Directory(p.join(root.path, 'cache'))..createSync();
  final support = Directory(p.join(root.path, 'support'))..createSync();
  return AppPaths(cacheRoot: cache, supportRoot: support);
}

class FakeDevice implements DeviceServices {
  FakeDevice({this.free = 1 << 40});
  int free;
  int begun = 0, ended = 0;
  @override
  Future<int> freeBytes() async => free;
  @override
  Future<int> beginBackgroundTask(String name) async => ++begun;
  @override
  Future<void> endBackgroundTask(int token) async => ended++;
  @override
  Future<void> protectOutput(String path) async {}
  int settingsOpened = 0;
  @override
  Future<void> openAppSettings() async => settingsOpened++;
}

class FakeOptions extends ToolOptions {
  const FakeOptions();
  @override
  Map<String, Object?> toJson() => {'x': 1};
}

enum FakeMode { success, failValidate, failExecute, throwUnknown, cancelMidway, badOutput }

/// A "copy file" tool used to exercise the JobRunner (TASKS T1.7/T1.11).
class FakeCopyTool implements ToolOperation<FakeOptions> {
  FakeCopyTool(this.mode, {this.estimate = 10});
  final FakeMode mode;
  final int estimate;
  String? workDirSeen;

  @override
  ToolId get tool => ToolId.imageCompress;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, FakeOptions options) async {
    if (mode == FakeMode.failValidate) throw const AppError(AppErrorCode.notEnoughFiles, count: 2);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, FakeOptions options) => estimate;

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, FakeOptions options) async {
    workDirSeen = ctx.workDir.path;
    final out = p.join(ctx.workDir.path, 'out.bin');
    await File(out).writeAsBytes([1, 2, 3]);
    ctx.report(const Determinate(1, 2, 'stepCompressing'));
    if (mode == FakeMode.cancelMidway) {
      ctx.cancel.cancel();
      ctx.cancel.throwIfCancelled();
    }
    if (mode == FakeMode.failExecute) throw const AppError(AppErrorCode.corruptFile);
    if (mode == FakeMode.throwUnknown) throw StateError('/secret/path/name.jpg');
    return RawOutput(path: out, suggestedName: 'my:out.bin', mime: 'application/octet-stream');
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, FakeOptions options) async {
    if (mode == FakeMode.badOutput) throw const AppError(AppErrorCode.outputValidationFailed);
    return OutputMeta(bytes: await File(out.path).length());
  }
}

PickedFile fakeInput(String path, {int size = 100}) => PickedFile(
      path: path,
      displayName: 'photo.jpg',
      type: SniffedType.jpeg,
      sizeBytes: size,
      image: const ImageMeta(format: SniffedType.jpeg, width: 10, height: 10),
    );

/// Writes `i + 1` bytes per item. [fail] maps item index → what that item does.
class FakeMultiTool implements MultiToolOperation<FakeOptions> {
  FakeMultiTool(this.n, {this.fail = const {}, this.cancelAt, this.estimate = 10, this.name});
  final int n;
  final Map<int, Object> fail;
  final int? cancelAt;
  final int estimate;

  /// Same suggested name for every item when set (adoption must de-duplicate).
  final String? name;
  final executed = <int>[];
  String? workDirSeen;
  CancelToken? token;

  @override
  ToolId get tool => ToolId.imageCompress;
  @override
  String get itemStepKey => 'stepCompressing';
  @override
  ProgressUnit get itemUnit => ProgressUnit.images;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, FakeOptions options) async {}
  @override
  int estimateRequiredBytes(List<PickedFile> inputs, FakeOptions options) => estimate;
  @override
  int itemCount(List<PickedFile> inputs, FakeOptions options) => n;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, FakeOptions options) async {
    executed.add(i);
    workDirSeen = ctx.workDir.path;
    final f = fail[i];
    if (f != null) throw f;
    final out = File(p.join(ctx.workDir.path, 'raw_$i.bin'))..writeAsBytesSync(List.filled(i + 1, i));
    if (cancelAt == i) ctx.cancel.cancel();
    return RawOutput(path: out.path, suggestedName: name ?? 'out_$i.jpg', mime: 'image/jpeg');
  }

  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, FakeOptions options) async =>
      OutputMeta(bytes: File(out.path).lengthSync(), width: 10, height: 10);

  int closed = 0;
  @override
  Future<void> close() async => closed++;
}

/// The system document scanner, scripted (RELEASE_V1_2 §4.2, T9.3).
class FakeDocumentScanner implements DocumentScanner {
  ScannerAvailability nextAvailability = ScannerAvailability.ready;

  /// What prepare() answers; null never answers (to test the time limit).
  ScanPrepareResult? nextPrepare = ScanPrepareResult.ready;

  /// What the next scan returns; null writes [pagesToWrite] JPEGs into destDir.
  ScanOutcome? nextOutcome;
  int pagesToWrite = 2;
  bool truncate = false;

  /// What takeRestored() returns once.
  RestoredScanResult? restored;

  final scans = <({int maxPages, String destDir, bool allowGalleryImport})>[];
  int prepares = 0;

  /// While set and not completed, availability() waits (the "checking" state).
  Completer<void>? holdAvailability;

  @override
  Future<ScannerAvailability> availability() async {
    await holdAvailability?.future;
    return nextAvailability;
  }

  @override
  Future<ScanPrepareResult> prepare() {
    prepares++;
    final r = nextPrepare;
    return r == null ? Completer<ScanPrepareResult>().future : Future.value(r);
  }

  @override
  Future<ScanOutcome> scan({required int maxPages, required String destDir, bool allowGalleryImport = true}) async {
    scans.add((maxPages: maxPages, destDir: destDir, allowGalleryImport: allowGalleryImport));
    if (nextOutcome != null) return nextOutcome!;
    final dir = Directory(destDir)..createSync(recursive: true);
    final start = dir.listSync().length + 1;
    final paths = [
      for (var i = 0; i < pagesToWrite && i < maxPages; i++)
        (File(p.join(dir.path, 'page_${(start + i).toString().padLeft(3, '0')}.jpg'))
              ..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]))
            .path,
    ];
    return ScanCompleted(paths, truncated: truncate);
  }

  @override
  Future<RestoredScanResult?> takeRestored() async {
    final r = restored;
    restored = null;
    return r;
  }
}

/// Returns [pages] in call order (an empty page once they run out); paths in
/// [failOn] throw processingFailed. Only [scripts] are available.
class FakeTextRecognizer implements TextRecognizer {
  List<OcrPage> pages = [];
  Set<String> failOn = {};
  Set<OcrScript> scripts = {OcrScript.latin, OcrScript.devanagari};

  /// Overrides [pages] per path, e.g. to answer differently for a rotation.
  OcrPage? Function(String path)? byPath;

  final calls = <String>[];
  final ensured = <OcrScript>[];
  bool disposed = false;

  @override
  Future<Set<OcrScript>> availableScripts() async => scripts;

  @override
  Future<void> ensureModel(OcrScript script) async {
    ensured.add(script);
    if (!scripts.contains(script)) throw AppError(AppErrorCode.ocrModelUnavailable, script: script.name);
  }

  @override
  Future<OcrPage> recognize(String imagePath, OcrScript script) async {
    final i = calls.length;
    calls.add(imagePath);
    if (failOn.contains(imagePath)) throw const AppError(AppErrorCode.processingFailed);
    final custom = byPath?.call(imagePath);
    if (custom != null) return custom;
    return i < pages.length ? pages[i] : const OcrPage(imageWidth: 1, imageHeight: 1, lines: []);
  }

  @override
  Future<void> dispose() async => disposed = true;
}
