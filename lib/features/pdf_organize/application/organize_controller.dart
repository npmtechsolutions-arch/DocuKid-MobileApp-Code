import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/files/file_naming.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/page_edit.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/providers.dart';
import '../../../core/validation/input_validator.dart';
import '../../../core/validation/output_validator.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import '../../tools/tool_inputs.dart';

class OrganizeOptions extends ToolOptions {
  const OrganizeOptions(this.edits, {this.extract = false});
  final List<PageEdit> edits;

  /// Extract (FR-EXT-01): [edits] are only the selected pages, in UI order.
  final bool extract;

  @override
  Map<String, Object?> toJson() => {'pages': edits.length, if (extract) 'mode': 'extract'};
}

class OrganizePdfOperation implements ToolOperation<OrganizeOptions> {
  OrganizePdfOperation(this._pdf, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final PdfEngine _pdf;
  final DateTime Function() _now;

  @override
  ToolId get tool => ToolId.pdfOrganize;

  @override
  Future<void> validateInputs(List<PickedFile> inputs, OrganizeOptions o) async {
    if (inputs.length != 1) throw const AppError(AppErrorCode.notEnoughFiles, count: 1);
    final f = inputs.single;
    if (!f.status.isValid) throw AppError(f.status.error!, fileDisplayName: f.displayName);
    if (o.edits.isEmpty) throw const AppError(AppErrorCode.invalidInput);
    final n = f.pdf!.pageCount;
    if (n > Limits.organizerMaxPages || o.edits.any((e) => e.sourceIndex < 0 || e.sourceIndex >= n)) {
      throw const AppError(AppErrorCode.invalidInput);
    }
  }

  @override
  int estimateRequiredBytes(List<PickedFile> inputs, OrganizeOptions o) => estimateBytes(tool.name, inputs.single.sizeBytes);

  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, OrganizeOptions o) async {
    final out = p.join(ctx.workDir.path, 'organized.pdf');
    await _pdf.organize(inputs.single.path, o.edits, out, ctx);
    return RawOutput(
      path: out,
      suggestedName: defaultOutputName(o.extract ? NamingTool.pdfExtract : NamingTool.pdfOrganize,
          firstInputName: inputs.single.displayName, now: _now()),
      mime: 'application/pdf',
    );
  }

  /// ARCHITECTURE §5.4: page count == edits, and pages 1 and N have the
  /// expected (possibly swapped) size, which proves the rotation was applied.
  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, OrganizeOptions o) async {
    final pages = await validatePdfOutput(_pdf, out.path, expectedPages: o.edits.length);
    final src = inputs.single.pdf!;
    final meta = await _pdf.inspect(out.path);
    if (src.pageSizes.length == src.pageCount && meta.pageSizes.length == pages) {
      for (final i in {0, pages - 1}) {
        final e = o.edits[i];
        final (sw, sh) = src.pageSizes[e.sourceIndex];
        final (ew, eh) = e.rotationQuarterTurns.isOdd ? (sh, sw) : (sw, sh);
        final (ow, oh) = meta.pageSizes[i];
        if ((ow - ew).abs() > 1.5 || (oh - eh).abs() > 1.5) {
          throw const AppError(AppErrorCode.outputValidationFailed);
        }
      }
    }
    return OutputMeta(bytes: await File(out.path).length(), pages: pages);
  }
}

final organizeOperationProvider =
    Provider<OrganizePdfOperation>((ref) => OrganizePdfOperation(ref.watch(pdfEngineProvider), clock: ref.watch(clockProvider)));

class OrganizeState {
  const OrganizeState({
    required this.pages,
    required this.pageCount,
    this.selected = const {},
    this.canUndo = false,
    this.canRedo = false,
  });
  final List<PageEdit> pages;
  final int pageCount;

  /// Selected *positions* in [pages].
  final Set<int> selected;
  final bool canUndo, canRedo;

  bool get dirty => !isIdentity(pages, pageCount);

  OrganizeState copyWith({List<PageEdit>? pages, Set<int>? selected, bool? canUndo, bool? canRedo, int? pageCount}) =>
      OrganizeState(
        pages: pages ?? this.pages,
        pageCount: pageCount ?? this.pageCount,
        selected: selected ?? this.selected,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
      );
}

enum EditResult { ok, wouldEmpty }

class OrganizeController extends Notifier<OrganizeState> {
  late EditHistory _history;
  String? _forPath;

  @override
  OrganizeState build() {
    final file = ref.watch(toolInputsProvider(ToolId.pdfOrganize).select((s) => s.single));
    final n = file?.status.isValid == true ? file!.pdf!.pageCount : 0;
    var initial = identityEdits(n);
    // Draft restore of the page list (FR-LIFE-03, P1 for the edit stack).
    final draft = readOptionsDraft(ref, ToolId.pdfOrganize);
    if (file != null && draft != null && draft['path'] == file.path) {
      final restored = [for (final e in (draft['pages'] as List? ?? const [])) PageEdit.fromJson((e as Map).cast<String, dynamic>())];
      if (restored.isNotEmpty && restored.every((e) => e.sourceIndex < n)) initial = restored;
    }
    _forPath = file?.path;
    _history = EditHistory(initial);
    return OrganizeState(pages: initial, pageCount: n);
  }

  void _commit(List<PageEdit> next, {Set<int>? selected}) {
    _history.push(next);
    _emit(selected: selected ?? const {});
  }

  void _emit({Set<int>? selected}) {
    state = state.copyWith(
      pages: _history.current,
      selected: selected ?? state.selected,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    );
    if (_forPath != null) {
      writeOptionsDraft(ref, ToolId.pdfOrganize, {
        'path': _forPath,
        'pages': [for (final e in _history.current) e.toJson()],
      });
    }
  }

  void toggle(int pos) {
    final s = {...state.selected};
    s.contains(pos) ? s.remove(pos) : s.add(pos);
    state = state.copyWith(selected: s);
  }

  void selectAll() => state = state.copyWith(selected: {for (var i = 0; i < state.pages.length; i++) i});
  void selectNone() => state = state.copyWith(selected: const {});
  void invert() => state = state.copyWith(selected: {
        for (var i = 0; i < state.pages.length; i++)
          if (!state.selected.contains(i)) i,
      });

  void rotateSelected(int delta) {
    if (state.selected.isEmpty) return;
    _commit(rotatePages(state.pages, state.selected, delta), selected: state.selected);
  }

  EditResult deleteSelected() {
    if (state.selected.isEmpty) return EditResult.ok;
    try {
      _commit(deletePages(state.pages, state.selected));
      return EditResult.ok;
    } on EmptyDocumentException {
      return EditResult.wouldEmpty;
    }
  }

  void moveOnePage(int from, int to) => _commit(moveOne(state.pages, from, to), selected: const {});

  /// Accessible move: block placed at [toIndex] after removing the selection.
  void moveSelectedTo(int toIndex) {
    if (state.selected.isEmpty) return;
    final moved = movePages(state.pages, state.selected, toIndex);
    final start = toIndex.clamp(0, state.pages.length - state.selected.length);
    _commit(moved, selected: {for (var i = 0; i < state.selected.length; i++) start + i});
  }

  /// FR-EXT-01: the selected pages in their current order and rotation. The
  /// session's pages and edit stack are not touched (FR-EXT-02).
  List<PageEdit> selectedEdits() => [
        for (var i = 0; i < state.pages.length; i++)
          if (state.selected.contains(i)) state.pages[i],
      ];

  void undo() {
    if (_history.undo()) _emit(selected: const {});
  }

  void redo() {
    if (_history.redo()) _emit(selected: const {});
  }

  void reset() => _commit(identityEdits(state.pageCount));
}

final organizeProvider = NotifierProvider.autoDispose<OrganizeController, OrganizeState>(OrganizeController.new);
