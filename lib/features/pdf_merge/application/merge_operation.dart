import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';

class MergeOptions extends ToolOptions {
  const MergeOptions({this.outputName});
  final String? outputName;

  @override
  Map<String, Object?> toJson() => const {};
}

class MergePdfOperation implements ToolOperation<MergeOptions> {
  MergePdfOperation(this._pdf, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final PdfEngine _pdf;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.pdfMerge;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, MergeOptions o) async {
    if (inputs.length < 2) throw const AppError(AppErrorCode.notEnoughFiles, count: 2);
    if (inputs.length > Limits.mergeMaxFiles) throw const AppError(AppErrorCode.tooManyFiles, count: Limits.mergeMaxFiles);
    for (final f in inputs) {
      if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    }
    final pages = inputs.fold<int>(0, (s, f) => s + (f.pdf?.pageCount ?? 0));
    if (pages > Limits.mergeMaxPages) throw const AppError(AppErrorCode.invalidInput);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, MergeOptions o) =>
      estimateBytes(tool.name, inputs.fold(0, (s, f) => s + f.sizeBytes));

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, MergeOptions o) async {
    final out = p.join(ctx.workDir.path, 'merged.pdf');
    await _pdf.merge([for (final f in inputs) f.path], out, ctx);
    return RawOutput(
      path: out,
      suggestedName: o.outputName ?? defaultOutputName(NamingTool.pdfMerge, now: _now()),
      mime: 'application/pdf',
    );
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, MergeOptions o) async {
    final expected = inputs.fold<int>(0, (s, f) => s + f.pdf!.pageCount);
    final pages = await validatePdfOutput(_pdf, out.path, expectedPages: expected);
    return OutputMeta(bytes: await File(out.path).length(), pages: pages);
  }
}

class MergeController extends Notifier<MergeOptions> {
  @override
  MergeOptions build() {
    final init = initialOptions(ref, ToolId.pdfMerge);
    return MergeOptions(outputName: init?['name'] as String?);
  }

  void rename(String name) {
    state = MergeOptions(outputName: name);
    writeOptionsDraft(ref, ToolId.pdfMerge, {'name': name});
  }
}

final mergeOptionsProvider = NotifierProvider.autoDispose<MergeController, MergeOptions>(MergeController.new);
final mergeOperationProvider =
    Provider<MergePdfOperation>((ref) => MergePdfOperation(ref.watch(pdfEngineProvider), clock: ref.watch(clockProvider)));
