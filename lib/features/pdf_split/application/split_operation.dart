import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/multi_output.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/page_ranges.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/pdf/pdf_options.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';

enum SplitMode { ranges, everyN, each }

/// Split PDF options (RELEASE_V1_1 §2.4).
class SplitOptions extends ToolOptions {
  const SplitOptions({this.mode = SplitMode.ranges, this.ranges = '', this.everyN = 2});

  final SplitMode mode;

  /// Mode A text, in the §4.6 grammar.
  final String ranges;

  /// Mode B: pages per file.
  final int everyN;

  SplitOptions copyWith({SplitMode? mode, String? ranges, int? everyN}) =>
      SplitOptions(mode: mode ?? this.mode, ranges: ranges ?? this.ranges, everyN: everyN ?? this.everyN);

  @override
  Map<String, Object?> toJson() => {'mode': mode.name, 'ranges': ranges, 'n': everyN};

  static SplitOptions fromJson(Map<String, dynamic> j, SplitOptions d) => SplitOptions(
        mode: enumByName(SplitMode.values, j['mode'], d.mode),
        ranges: j['ranges'] as String? ?? d.ranges,
        everyN: (j['n'] as int?) ?? d.everyN,
      );
}

enum SplitError { onePage, eachCap, range }

/// What a split would produce: 0-based page groups (one per output), or why not.
class SplitPlan {
  const SplitPlan.groups(List<List<int>> this.groups)
      : error = null,
        rangeError = null;
  const SplitPlan.error(SplitError this.error, {this.rangeError}) : groups = null;
  final List<List<int>>? groups;
  final SplitError? error;
  final PageRangeError? rangeError;
}

/// Every N never makes more than [maxRangeParts] files.
int minEveryN(int pageCount) => ((pageCount + maxRangeParts - 1) ~/ maxRangeParts).clamp(1, 1 << 30);

/// FR-SPL-02…05. [endWords]: "end" and its ARB alias.
SplitPlan splitGroups(SplitOptions o, int pageCount, {Set<String> endWords = const {'end'}}) {
  if (pageCount < 2) return const SplitPlan.error(SplitError.onePage);
  switch (o.mode) {
    case SplitMode.ranges:
      final r = parsePageRanges(o.ranges, pageCount, endWords: endWords);
      if (r.error != null) return SplitPlan.error(SplitError.range, rangeError: r.error);
      return SplitPlan.groups([
        for (final part in r.parts!) [for (final pg in part.pages) pg - 1],
      ]);
    case SplitMode.everyN:
      final n = o.everyN.clamp(minEveryN(pageCount), pageCount - 1);
      return SplitPlan.groups([
        for (var start = 0; start < pageCount; start += n)
          [for (var i = start; i < start + n && i < pageCount; i++) i],
      ]);
    case SplitMode.each:
      if (pageCount > maxRangeParts) return const SplitPlan.error(SplitError.eachCap);
      return SplitPlan.groups([
        for (var i = 0; i < pageCount; i++) [i],
      ]);
  }
}

/// FR-SPL-06: ranges → `<base>_p1-3.pdf` / `<base>_p5.pdf`; every N / each →
/// `<base>_part01.pdf`, zero-padded to the output count (at least 2 digits).
String splitPartName(String inputName, SplitOptions o, List<int> group, int index, int total) {
  final base = safeBaseName(inputName);
  if (o.mode == SplitMode.ranges) {
    final a = group.first + 1, b = group.last + 1;
    return withExtension(a == b ? '${base}_p$a' : '${base}_p$a-$b', 'pdf');
  }
  final width = '$total'.length < 2 ? 2 : '$total'.length;
  return withExtension('${base}_part${'${index + 1}'.padLeft(width, '0')}', 'pdf');
}

/// Split PDF: one input → one output per group (S22). The source stays open
/// across items and is closed when the job ends (§4.7).
class SplitPdfOperation implements MultiToolOperation<SplitOptions> {
  SplitPdfOperation(this._engine, {this.endWords = const {'end'}});
  final PdfEngine _engine;
  final Set<String> endWords;
  PdfPageExtractor? _src;

  @override
  ToolId get tool => ToolId.pdfSplit;
  @override
  String get itemStepKey => 'stepSavingPages';
  @override
  ProgressUnit get itemUnit => ProgressUnit.files;

  List<List<int>> _groups(List<PickedFile> inputs, SplitOptions o) =>
      splitGroups(o, inputs.single.pdf?.pageCount ?? 0, endWords: endWords).groups ?? const [];

  @override
  Future<void> validateInputs(List<PickedFile> inputs, SplitOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    // FR-SPL-08: encrypted and broken PDFs are blocked like everywhere else.
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    final pages = f.pdf?.pageCount ?? 0;
    if (pages > Limits.organizerMaxPages) throw const AppError(AppErrorCode.invalidInput);
    if (splitGroups(o, pages, endWords: endWords).groups == null) throw const AppError(AppErrorCode.invalidInput);
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, SplitOptions o) {
    // Overlapping ranges can repeat pages: scale by pages written / pages in.
    final pages = inputs.single.pdf?.pageCount ?? 1;
    final written = _groups(inputs, o).fold<int>(0, (s, g) => s + g.length);
    return estimateBytes(tool.name, (inputs.single.sizeBytes * (written > pages ? written / pages : 1)).ceil());
  }

  @override
  int itemCount(List<PickedFile> inputs, SplitOptions o) => _groups(inputs, o).length;

  @override
  Future<RawOutput> executeItem(JobContext ctx, int i, List<PickedFile> inputs, SplitOptions o) async {
    final input = inputs.single;
    final groups = _groups(inputs, o);
    final src = _src ??= await _engine.openExtractor(input.path);
    final out = p.join(ctx.workDir.path, 'part_$i.pdf');
    await src.extract(groups[i], out);
    return RawOutput(
      path: out,
      suggestedName: splitPartName(input.displayName, o, groups[i], i, groups.length),
      mime: 'application/pdf',
      flags: {'pages': groups[i].length},
    );
  }

  @override
  Future<OutputMeta> validateItem(RawOutput out, int i, SplitOptions o) async {
    // FR-SPL-07: reopens, page count matches its range, first page renders.
    final pages = await validatePdfOutput(_engine, out.path, expectedPages: out.flags['pages'] as int);
    return OutputMeta(bytes: await File(out.path).length(), pages: pages);
  }

  @override
  Future<void> close() async {
    final src = _src;
    _src = null;
    await src?.close();
  }
}
