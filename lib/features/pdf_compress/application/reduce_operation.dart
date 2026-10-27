import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';

class ReduceOptions extends ToolOptions {
  const ReduceOptions({this.level = ReduceLevel.balanced});
  final ReduceLevel level;

  @override
  Map<String, Object?> toJson() => {'level': level.name};
}

class ReducePdfOperation implements ToolOperation<ReduceOptions> {
  ReducePdfOperation(this._pdf, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final PdfEngine _pdf;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.pdfCompress;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, ReduceOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ReduceOptions o) => estimateBytes(tool.name, inputs.single.sizeBytes);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, ReduceOptions o) async {
    final input = inputs.single;
    final out = p.join(ctx.workDir.path, 'reduced.pdf');
    await _pdf.reduce(input.path, out, o.level, ctx);
    return RawOutput(
      path: out,
      suggestedName: defaultOutputName(NamingTool.pdfCompress, firstInputName: input.displayName, now: _now()),
      mime: 'application/pdf',
      flags: {'level': o.level.name},
    );
  }

  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ReduceOptions o) async {
    final pages = await validatePdfOutput(_pdf, out.path, expectedPages: inputs.single.pdf!.pageCount, renderLast: true);
    return OutputMeta(bytes: await File(out.path).length(), pages: pages, flags: out.flags);
  }
}

final reduceOperationProvider =
    Provider<ReducePdfOperation>((ref) => ReducePdfOperation(ref.watch(pdfEngineProvider), clock: ref.watch(clockProvider)));

class ReduceController extends Notifier<ReduceOptions> {
  @override
  ReduceOptions build() {
    final init = initialOptions(ref, ToolId.pdfCompress);
    final d = ref.read(settingsProvider).reduceLevel;
    // Strong is never the default (FR-CMP-02), even from Settings.
    final level = enumByName(ReduceLevel.values, init?['level'], d == ReduceLevel.strong ? ReduceLevel.balanced : d);
    return ReduceOptions(level: level);
  }

  void set(ReduceLevel level) {
    state = ReduceOptions(level: level);
    writeOptionsDraft(ref, ToolId.pdfCompress, state.toJson());
  }
}

final reduceOptionsProvider = NotifierProvider.autoDispose<ReduceController, ReduceOptions>(ReduceController.new);

/// FR-CMP-06 pre-analysis, keyed by the input copy's path.
final pdfAnalysisProvider = FutureProvider.autoDispose.family<PdfAnalysis, (String, int)>(
  (ref, key) => ref.watch(pdfEngineProvider).analyse(key.$1, key.$2),
);
