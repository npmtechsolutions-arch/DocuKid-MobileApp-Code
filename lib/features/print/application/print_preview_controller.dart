import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/files/mime_sniffer.dart';
import '../../../core/files/paths.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/operation/tool_operation.dart';
import '../../../core/pdf/page_ranges.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/print/print_composer.dart';
import '../../../core/print/print_gateway.dart';
import '../../../core/print/print_geometry.dart';
import '../../../core/print/print_settings.dart';
import '../../../core/providers.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/settings/settings_repository.dart';

/// What S48 prints: one PDF or 1–100 images, already copied into the app
/// (FR-PRN-01, -02). The entry points set it, then open `/print/preview`.
class PrintRequest {
  const PrintRequest(this.files);
  final List<PickedFile> files;

  bool get isPdf => files.isNotEmpty && files.first.type == SniffedType.pdf;

  /// FR-PRN-11: the job is named after the file, without its extension.
  String get jobName => files.isEmpty ? '' : p.basenameWithoutExtension(files.first.displayName);

  /// A PDF that needs its password first (prn_locked).
  bool get locked => isPdf && (files.first.pdf == null || files.first.pdf!.isEncrypted);

  PrintSource get source => isPdf ? PdfPrintSource(files.first.path) : ImagesPrintSource(files);
}

class PrintRequestController extends Notifier<PrintRequest?> {
  @override
  PrintRequest? build() => null;

  void set(PrintRequest? r) => state = r;
}

final printRequestProvider = NotifierProvider<PrintRequestController, PrintRequest?>(PrintRequestController.new);

class PrintPreviewState {
  const PrintPreviewState({
    required this.request,
    required this.settings,
    this.output,
    this.building = false,
    this.progress,
    this.rangeError,
    this.noPages = false,
    this.buildFailed = false,
    this.printing = false,
    this.outcome,
    this.available = true,
  });

  final PrintRequest? request;
  final PrintSettings settings;

  /// The last good print-ready PDF; kept on screen while a rebuild runs.
  final PrintOutput? output;
  final bool building;

  /// Real sheet progress from the composer (FR-PRN-18).
  final Determinate? progress;
  final PageRangeError? rangeError;
  final bool noPages;
  final bool buildFailed;
  final bool printing;

  /// The last print's outcome; S48 shows the snackbar or the failure banner.
  final PrintOutcome? outcome;
  final bool available;

  bool get locked => request?.locked ?? false;
  int get sheetCount => output?.sheetCount ?? 0;

  bool get canPrint =>
      output != null &&
      !building &&
      !locked &&
      rangeError == null &&
      !noPages &&
      !buildFailed &&
      !printing &&
      available;

  PrintPreviewState copyWith({
    PrintSettings? settings,
    PrintOutput? Function()? output,
    bool? building,
    Determinate? Function()? progress,
    PageRangeError? Function()? rangeError,
    bool? noPages,
    bool? buildFailed,
    bool? printing,
    PrintOutcome? Function()? outcome,
    bool? available,
  }) =>
      PrintPreviewState(
        request: request,
        settings: settings ?? this.settings,
        output: output != null ? output() : this.output,
        building: building ?? this.building,
        progress: progress != null ? progress() : this.progress,
        rangeError: rangeError != null ? rangeError() : this.rangeError,
        noPages: noPages ?? this.noPages,
        buildFailed: buildFailed ?? this.buildFailed,
        printing: printing ?? this.printing,
        outcome: outcome != null ? outcome() : this.outcome,
        available: available ?? this.available,
      );
}

/// S48 (RELEASE_PRINT §3, §4.4). The family argument is the ARB word for the
/// last page in a range ("end" also works).
class PrintPreviewController extends Notifier<PrintPreviewState> {
  PrintPreviewController(this.endWord);
  final String endWord;

  /// §4.3: rebuild 300 ms after the last change.
  static Duration debounce = const Duration(milliseconds: 300);

  late String _jobId;
  late AppPaths _paths;
  late PdfEngine _pdf;
  late PrintComposer _composer;
  late PrintGateway _gateway;
  late SettingsRepository _settings;
  late HistoryRepository _history;
  late DateTime Function() _clock;

  /// The preview on screen (state can't be read while disposing).
  PrintOutput? _shown;
  Timer? _timer;

  /// R74: at most ~10 progress updates a second (each rebuilds S48); the
  /// first and the last always show.
  static const progressInterval = Duration(milliseconds: 100);
  var _lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
  CancelToken? _cancel;
  var _generation = 0;
  Future<PrintOutcome>? _pendingPrint;
  var _disposed = false;

  Set<String> get _endWords => {'end', endWord};

  @override
  PrintPreviewState build() {
    final request = ref.watch(printRequestProvider);
    _jobId = '$printJobPrefix${DateTime.now().microsecondsSinceEpoch}';
    // Captured once: cleanup runs after the provider is gone.
    _paths = ref.read(appPathsProvider);
    _pdf = ref.read(pdfEngineProvider);
    _composer = ref.read(printComposerProvider);
    _gateway = ref.read(printGatewayProvider);
    _settings = ref.read(settingsRepositoryProvider);
    _history = ref.read(historyRepositoryProvider);
    _clock = ref.read(clockProvider);
    ref.onDispose(_dispose);
    final buildable = request != null && request.files.isNotEmpty && !request.locked;
    final initial = PrintPreviewState(request: request, settings: _settings.readPrintSettings(), building: buildable);
    if (buildable) {
      // S48 open → compose(defaults) at once (§4.4).
      scheduleMicrotask(() {
        _checkAvailable();
        _validateThenBuild(initial.settings, now: true);
      });
    }
    return initial;
  }

  Directory get _jobDir => _paths.jobDir(_jobId);

  /// An option changed: remembered at once (FR-PRN-15), rebuilt after
  /// [debounce]. An invalid range or no pages shows at once and doesn't build.
  void update(PrintSettings s) {
    state = state.copyWith(settings: s, outcome: () => null);
    unawaited(_settings.writePrintSettings(s));
    _validateThenBuild(s);
  }

  /// After a failed build, or to re-check printing availability.
  void retry() {
    _checkAvailable();
    _validateThenBuild(state.settings, now: true);
  }

  /// Stops the running build; the last good preview stays (FR-PRN-18).
  void cancelBuild() {
    _timer?.cancel();
    _cancel?.cancel();
    _generation++;
    state = state.copyWith(building: false, progress: () => null);
  }

  /// Opens the system dialog on the current preview and reports the outcome.
  Future<PrintOutcome?> print({Rect? origin}) async {
    final out = state.output;
    final request = state.request;
    if (out == null || request == null || !state.canPrint) return null;
    state = state.copyWith(printing: true, outcome: () => null);
    final started = _clock();
    final pending = _gateway.print(out, jobName: request.jobName, origin: origin);
    _pendingPrint = pending;
    final outcome = await pending;
    _pendingPrint = null;
    if (outcome != PrintOutcome.cancelled) await _record(request, out, started, sent: outcome == PrintOutcome.sent);
    if (_disposed) {
      await _deleteJob();
    } else {
      state = state.copyWith(printing: false, outcome: () => outcome);
    }
    return outcome;
  }

  /// FR-PRN-17: sent or failed, with the sheet count; never on cancel. Best
  /// effort: History must not turn a print into an error.
  Future<void> _record(PrintRequest request, PrintOutput out, DateTime started, {required bool sent}) async {
    try {
      await _history.recordPrint(
        id: const Uuid().v7(),
        createdAt: started,
        duration: _clock().difference(started),
        inputs: [
          for (final f in request.files)
            InputRecord(
              displayName: f.displayName,
              mime: f.mime,
              sizeBytes: f.sizeBytes,
              meta: f.image != null
                  ? {'w': f.image!.width, 'h': f.image!.height}
                  : f.pdf != null
                      ? {'p': f.pdf!.pageCount}
                      : null,
            ),
        ],
        name: request.files.first.displayName,
        sheets: out.sheetCount,
        sent: sent,
      );
    } catch (_) {
      // Logged nowhere: no file names (rule 4); the print itself went through.
    }
  }

  void _checkAvailable() {
    unawaited(_gateway.available().then((ok) {
      if (!_disposed) state = state.copyWith(available: ok);
    }));
  }

  void _validateThenBuild(PrintSettings s, {bool now = false}) {
    final request = state.request;
    if (request == null || request.files.isEmpty || request.locked) return;
    PageRangeError? error;
    var none = false;
    if (request.isPdf) {
      final r = resolvePages(request.files.first.pdf!.pageCount, s.pages, endWords: _endWords);
      error = r.error;
      none = r.error == null && r.pages.isEmpty;
    }
    state = state.copyWith(rangeError: () => error, noPages: none, buildFailed: false);
    _timer?.cancel();
    if (error != null || none) {
      // Nothing to build: stop a running build, keep the last good preview.
      _cancel?.cancel();
      _generation++;
      state = state.copyWith(building: false, progress: () => null);
      return;
    }
    // Building from now on, so Print can't send the old preview with the
    // new settings during the debounce.
    state = state.copyWith(building: true);
    if (now) {
      unawaited(_build(s));
    } else {
      _timer = Timer(debounce, () => unawaited(_build(s)));
    }
  }

  Future<void> _build(PrintSettings s) async {
    final request = state.request!;
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final gen = ++_generation;
    final dir = Directory(p.join(_jobDir.path, 'build_$gen'));
    state = state.copyWith(building: true, progress: () => null);
    try {
      await dir.create(recursive: true);
      final out = await _composer.compose(
            request.source,
            s,
            JobContext(
              jobId: _jobId,
              workDir: dir,
              cancel: cancel,
              report: (pr) {
                if (_disposed || gen != _generation || pr is! Determinate) return;
                final now = DateTime.now();
                if (pr.done > 0 && pr.done < pr.total && now.difference(_lastProgressAt) < progressInterval) return;
                _lastProgressAt = now;
                state = state.copyWith(progress: () => pr);
              },
            ),
            endWords: _endWords,
          );
      if (_disposed || gen != _generation) {
        await deleteQuietly(dir);
        return;
      }
      final old = _shown;
      _shown = out;
      state = state.copyWith(output: () => out, building: false, progress: () => null, noPages: false, buildFailed: false);
      if (old != null) await _dropBuild(old.path);
    } on CancelledException {
      await deleteQuietly(dir);
    } on AppError catch (e) {
      await deleteQuietly(dir);
      if (_disposed || gen != _generation) return;
      state = state.copyWith(
        building: false,
        progress: () => null,
        noPages: e.code == AppErrorCode.invalidInput,
        buildFailed: e.code != AppErrorCode.invalidInput,
      );
    } catch (_) {
      await deleteQuietly(dir);
      if (_disposed || gen != _generation) return;
      state = state.copyWith(building: false, progress: () => null, buildFailed: true);
    }
  }

  /// The replaced preview: release the rendered document, then its folder.
  Future<void> _dropBuild(String path) async {
    try {
      await _pdf.close(path);
    } catch (_) {
      // Best effort.
    }
    await deleteQuietly(Directory(p.dirname(path)));
  }

  Future<void> _deleteJob() => deleteQuietly(_jobDir);

  void _dispose() {
    _disposed = true;
    _timer?.cancel();
    _cancel?.cancel();
    final out = _shown;
    if (out != null) unawaited(_pdf.close(out.path).catchError((_) {}));
    // Android keeps reading print.pdf until the job is final (§4.2): a pending
    // print deletes the folder when it returns; the launch sweep is the backstop.
    if (_pendingPrint == null) unawaited(_deleteJob());
  }
}

/// FR-PRN-07: with Actual size, some page or image is bigger than its cell
/// and would be cut off. [pdfPageSizes] are the PDF's visual page sizes (null
/// while unknown: no warning). The passport sheet always crops: never warned.
bool actualSizeOverflows(PrintRequest r, PrintSettings s, List<Size>? pdfPageSizes, {Set<String> endWords = const {'end'}}) {
  if (s.scaling != PrintScaling.actual || r.files.isEmpty || r.locked) return false;
  final List<SheetPlan> plan;
  if (r.isPdf) {
    if (pdfPageSizes == null) return false;
    final sel = resolvePages(pdfPageSizes.length, s.pages, endWords: endWords);
    if (sel.error != null) return false;
    plan = planPdfSheets(pdfPageSizes, sel.pages, s);
  } else {
    if (s.imageLayout == ImageLayout.passportSheet) return false;
    final sizes = [for (final f in r.files) if (f.image case final m?) imageSizePt(m.width, m.height)];
    if (sizes.length != r.files.length) return false;
    plan = planImageSheets(sizes, s);
  }
  return plan.any((sheet) => sheet.pages.any((pg) => pg.clip));
}

/// FR-PRN-10: how many passport photos fit, for "8 photos on 4 × 6 in".
int passportPhotoCount(PrintRequest r, PrintSettings s) {
  final m = r.files.isEmpty ? null : r.files.first.image;
  if (m == null) return 0;
  return passportSheet(paperSizePt(s.paper, document: imageSizePt(m.width, m.height)), s.margins).count;
}

final printPreviewProvider = NotifierProvider.autoDispose.family<PrintPreviewController, PrintPreviewState, String>(
  PrintPreviewController.new,
);
