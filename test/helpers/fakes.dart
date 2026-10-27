import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/platform/device_services.dart';
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
