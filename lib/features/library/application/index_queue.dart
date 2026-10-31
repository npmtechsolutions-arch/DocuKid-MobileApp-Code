import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/image/image_engine.dart';
import '../../../core/image/image_options.dart';
import '../../../core/image/page_image_encoder.dart';
import '../../../core/logging/log.dart';
import '../../../core/ocr/pdfrx_text_reader.dart';
import '../../../core/ocr/text_recognizer.dart';
import '../../../core/operation/jobs_controller.dart';
import '../../../core/pdf/pdf_engine.dart';
import '../../../core/platform/device_services.dart';
import '../../../core/providers.dart';
import '../../../data/library/library_repository.dart';
import '../../../data/settings/app_settings.dart';
import '../../../data/settings/settings_repository.dart';

/// A text layer shorter than this is treated as image-only (§4.6).
const minTextLayerChars = 40;

/// FR-LIB-16: why indexing waits, in the order it's checked.
enum IndexPause { user, background, busy, battery }

class IndexStatus {
  const IndexStatus({this.waiting = 0, this.working = false, this.paused});

  /// Documents queued or being indexed.
  final int waiting;

  /// A document is being read right now.
  final bool working;
  final IndexPause? paused;

  @override
  bool operator ==(Object other) => other is IndexStatus && other.waiting == waiting && other.working == working && other.paused == paused;
  @override
  int get hashCode => Object.hash(waiting, working, paused);
  @override
  String toString() => 'IndexStatus($waiting, working: $working, paused: $paused)';
}

/// ADR-055: OCR for scans when "Scans" is on, for everything else when
/// "Other PDFs and images" is on; "Make searchable now" always.
bool ocrAllowed(LibraryDoc d, AppSettings s, {bool manual = false}) =>
    manual || (d.source == DocSource.scan ? s.libIndexScans : s.libIndexOther);

/// Whether an unindexed document belongs in the queue: every PDF once (its
/// text layer is free to read), images only when OCR is allowed.
bool shouldQueue(LibraryDoc d, AppSettings s, {bool manual = false}) =>
    d.indexState == IndexState.none && ((d.isPdf && d.indexedAt == null) || ocrAllowed(d, s, manual: manual));

/// Reads a document's text: the PDF text layer, or OCR of one page / image.
abstract interface class DocTextSource {
  Future<int> pageCount(String path);

  /// All pages' existing text, joined (no OCR).
  Future<String> textLayer(String path);

  /// OCR of page [index] (0 for an image).
  Future<String> recognize(String path, {required bool isPdf, required int index, required OcrScript script, required Directory work});

  /// Frees the recognisers after a document.
  Future<void> release();
}

/// FR-LIB-15/16, §4.6 · the background index queue: one document at a time,
/// app process only (ADR-058); never alongside a tool job, below 20 %
/// battery while not charging, while backgrounded or while the user paused.
/// Resumes per page after a restart; a failure is retried once on the next
/// launch, then only from "Make searchable now". Never logs text or names.
class IndexQueue {
  IndexQueue({
    required LibraryRepository repo,
    required DocTextSource source,
    required SettingsRepository store,
    required AppSettings Function() settings,
    required Future<({int level, bool charging})> Function() battery,
    required bool Function() busy,
    required Directory workRoot,
    this.poll = const Duration(seconds: 20),
  })  : _repo = repo,
        _source = source,
        _store = store,
        _settings = settings,
        _battery = battery,
        _busy = busy,
        _workRoot = workRoot;

  final LibraryRepository _repo;
  final DocTextSource _source;
  final SettingsRepository _store;
  final AppSettings Function() _settings;
  final Future<({int level, bool charging})> Function() _battery;
  final bool Function() _busy;
  final Directory _workRoot;

  /// How often a paused queue looks again (battery, a finished job).
  final Duration poll;

  final _status = StreamController<IndexStatus>.broadcast();
  IndexStatus _last = const IndexStatus();
  StreamSubscription<LibraryChange>? _sub;
  Completer<void>? _wake;
  bool _running = false, _started = false, _disposed = false, _foreground = true, _batteryLow = false;

  Stream<IndexStatus> get statusStream => _status.stream;
  IndexStatus get status => _last;

  /// Launch: retry last launch's failures once, queue what the policy wants,
  /// then work.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _sub = _repo.changes.listen((c) {
      if (c.kind == LibraryChangeKind.added) unawaited(_queueByPolicy(ids: c.ids));
    });
    final retried = _store.readIndexRetried();
    for (final d in await _repo.docsWithIndexState({IndexState.failed})) {
      if (retried.contains(d.id)) continue;
      retried.add(d.id);
      await _repo.setIndexState(d.id, IndexState.queued);
    }
    await _store.writeIndexRetried(retried);
    await _queueByPolicy();
  }

  /// Settings changed (a switch on → existing documents join; Resume).
  Future<void> settingsChanged() async {
    if (!_started) return;
    await _queueByPolicy();
    _kick();
  }

  /// Something it may be waiting for changed (a tool job ended).
  void wake() => _kick();

  void setForeground(bool v) {
    _foreground = v;
    if (v) _kick();
  }

  /// "Make searchable now": OCR allowed, front of the queue (FR-LIB-15).
  Future<void> makeSearchableNow(String id) async {
    final manual = [id, ..._store.readIndexManual().where((x) => x != id)];
    await _store.writeIndexManual(manual);
    final d = await _repo.get(id);
    if (d != null && d.indexState != IndexState.indexing) await _repo.setIndexState(id, IndexState.queued);
    _kick();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    _kick();
    await _status.close();
  }

  // ---------------------------------------------------------------- loop

  Future<void> _queueByPolicy({List<String>? ids}) async {
    final s = _settings();
    final manual = _store.readIndexManual();
    final docs = ids == null
        ? await _repo.docsWithIndexState({IndexState.none})
        : [for (final id in ids) ?await _repo.get(id)];
    for (final d in docs) {
      if (shouldQueue(d, s, manual: manual.contains(d.id))) await _repo.setIndexState(d.id, IndexState.queued);
    }
    _kick();
  }

  void _kick() {
    _sleepTimer?.cancel();
    final w = _wake;
    _wake = null;
    if (w != null && !w.isCompleted) w.complete();
    if (!_running && _started && !_disposed) unawaited(_run());
  }

  Timer? _sleepTimer;

  /// Until [_kick] or [poll] (a cancellable timer: nothing left pending on dispose).
  Future<void> _sleep() {
    final w = _wake = Completer<void>();
    _sleepTimer = Timer(poll, () {
      if (!w.isCompleted) w.complete();
    });
    return w.future;
  }

  Future<IndexPause?> _pause() async {
    if (_settings().libIndexPaused) return IndexPause.user;
    if (!_foreground) return IndexPause.background;
    if (_busy()) return IndexPause.busy;
    _batteryLow = batteryLow(await _battery());
    return _batteryLow ? IndexPause.battery : null;
  }

  Future<void> _publish({required bool working, IndexPause? paused}) async {
    final waiting = (await _repo.docsWithIndexState({IndexState.queued, IndexState.indexing})).length;
    final s = IndexStatus(waiting: waiting, working: working && paused == null, paused: waiting == 0 ? null : paused);
    if (s != _last && !_disposed) {
      _last = s;
      _status.add(s);
    }
  }

  Future<LibraryDoc?> _next() async {
    final open = await _repo.docsWithIndexState({IndexState.indexing, IndexState.queued});
    if (open.isEmpty) return null;
    // A document interrupted mid-way first, then "Make searchable now" in
    // order, then the oldest.
    for (final d in open) {
      if (d.indexState == IndexState.indexing) return d;
    }
    final manual = _store.readIndexManual();
    for (final id in manual) {
      for (final d in open) {
        if (d.id == id) return d;
      }
    }
    return open.first;
  }

  Future<void> _run() async {
    _running = true;
    try {
      while (!_disposed) {
        final paused = await _pause();
        if (paused != null) {
          await _publish(working: false, paused: paused);
          if (_last.waiting == 0) break;
          await _sleep();
          continue;
        }
        final next = await _next();
        if (next == null) {
          await _publish(working: false);
          break;
        }
        await _publish(working: true);
        await _index(next);
      }
    } finally {
      _running = false;
    }
  }

  // ---------------------------------------------------------------- one document

  File _partial(String id) => File(p.join(_workRoot.path, '$id.txt'));

  Future<void> _finish(LibraryDoc d, String text, IndexState state) async {
    await _repo.setIndexedText(d.id, text, state: state);
    await _store.writeIndexProgress(null);
    await _store.writeIndexManual(_store.readIndexManual().where((x) => x != d.id).toList());
    final f = _partial(d.id);
    if (await f.exists()) await f.delete();
  }

  /// Returns early (the document stays `indexing`) when work must pause.
  Future<void> _index(LibraryDoc d) async {
    final path = _repo.absolutePath(d);
    final manual = _store.readIndexManual().contains(d.id);
    final progress = _store.readIndexProgress();
    var page = progress?.id == d.id ? progress!.page : 0;
    final partial = _partial(d.id);
    var text = page > 0 && await partial.exists() ? await partial.readAsString() : '';
    final work = Directory(p.join(_workRoot.path, 'pages'));
    try {
      if (d.indexState != IndexState.indexing) await _repo.setIndexState(d.id, IndexState.indexing);
      if (page == 0 && d.isPdf) {
        final layer = await _source.textLayer(path);
        if (layer.trim().length >= minTextLayerChars) return await _finish(d, layer, IndexState.done);
        if (!ocrAllowed(d, _settings(), manual: manual)) return await _finish(d, layer, IndexState.none);
      } else if (page == 0 && !ocrAllowed(d, _settings(), manual: manual)) {
        return await _finish(d, '', IndexState.none);
      }
      final pages = d.isPdf ? await _source.pageCount(path) : 1;
      await work.create(recursive: true);
      for (; page < pages; page++) {
        if (_disposed || await _pause() != null) {
          // Keep what's done; the loop resumes here (FR-LIB-16).
          await partial.parent.create(recursive: true);
          await partial.writeAsString(text);
          await _store.writeIndexProgress((id: d.id, page: page));
          return;
        }
        final t = await _source.recognize(path, isPdf: d.isPdf, index: page, script: _settings().ocrScript, work: work);
        text += '$t\n';
      }
      await _finish(d, text, IndexState.done);
    } on AppError catch (e) {
      Log.event('lib_index_failed', e.code.name);
      await _finish(d, '', IndexState.failed);
    } on Object catch (e) {
      Log.event('lib_index_failed', e.runtimeType.toString());
      await _finish(d, '', IndexState.failed);
    } finally {
      await _source.release();
      if (await work.exists()) await work.delete(recursive: true);
    }
  }
}

/// The real [DocTextSource]: pdfrx text, PDF pages rendered at 200 dpi, images
/// oriented and capped like the OCR tool, then the 1.3 recogniser.
class LibraryTextSource implements DocTextSource {
  LibraryTextSource({
    required PdfEngine pdfs,
    required ImageEngine images,
    required PageImageEncoder encoder,
    required Future<String> Function(String path) textLayer,
    required TextRecognizer Function() recognizer,
  })  : _pdfs = pdfs,
        _images = images,
        _encoder = encoder,
        _textLayer = textLayer,
        _newRecognizer = recognizer;

  final PdfEngine _pdfs;
  final ImageEngine _images;
  final PageImageEncoder _encoder;
  final Future<String> Function(String path) _textLayer;
  final TextRecognizer Function() _newRecognizer;
  TextRecognizer? _recognizer;
  PdfPageExtractor? _open;
  String? _openPath;
  List<(double, double)> _sizes = const [];

  static const dpi = 200, maxLongEdge = 4000;

  @override
  Future<int> pageCount(String path) async => (await _pdfs.inspect(path)).pageCount;

  @override
  Future<String> textLayer(String path) => _textLayer(path);

  @override
  Future<String> recognize(String path, {required bool isPdf, required int index, required OcrScript script, required Directory work}) async {
    final r = _recognizer ??= _newRecognizer();
    await r.ensureModel(script);
    final out = p.join(work.path, 'page.jpg');
    if (isPdf) {
      if (_openPath != path) {
        await _open?.close();
        _open = await _pdfs.openExtractor(path);
        _openPath = path;
        _sizes = (await _pdfs.inspect(path)).pageSizes;
      }
      final (wPt, hPt) = index < _sizes.length ? _sizes[index] : (595.0, 842.0);
      var w = wPt / 72 * dpi, h = hPt / 72 * dpi;
      final long = w > h ? w : h;
      if (long > maxLongEdge) {
        w = w * maxLongEdge / long;
        h = h * maxLongEdge / long;
      }
      final px = await _open!.renderPage(index, width: w.round(), height: h.round(), transparent: false);
      await _encoder.encode(px, out, format: ImageFormat.jpeg, quality: 85, keepAlpha: false);
    } else {
      await _images.transform(path, out, const ImageTransform(format: ImageFormat.jpeg, quality: 85, maxLongEdge: maxLongEdge));
    }
    return (await r.recognize(out, script)).text;
  }

  @override
  Future<void> release() async {
    await _open?.close();
    _open = null;
    _openPath = null;
    await _recognizer?.dispose();
    _recognizer = null;
  }
}

/// Overridden in widget tests (no PDFium or ML Kit there).
final docTextSourceProvider = Provider<DocTextSource>((ref) => LibraryTextSource(
      pdfs: ref.watch(pdfEngineProvider),
      images: ref.watch(imageEngineProvider),
      encoder: ref.watch(pageImageEncoderProvider),
      textLayer: pdfrxAllText,
      recognizer: ref.watch(textRecognizerFactoryProvider),
    ));

/// The app's one queue; `DocuKitApp` starts it 5 s after the first frame and
/// reports foreground / background.
final indexQueueProvider = Provider<IndexQueue>((ref) {
  final q = IndexQueue(
    repo: ref.watch(libraryRepositoryProvider),
    source: ref.watch(docTextSourceProvider),
    store: ref.watch(settingsRepositoryProvider),
    settings: () => ref.read(settingsProvider),
    battery: ref.watch(deviceServicesProvider).battery,
    busy: () => ref.read(jobsProvider.notifier).active != null,
    workRoot: Directory(p.join(ref.watch(appPathsProvider).cacheRoot.path, 'index')),
  );
  ref.listen(settingsProvider, (before, now) {
    if (before == null) return;
    if (before.libIndexScans != now.libIndexScans ||
        before.libIndexOther != now.libIndexOther ||
        before.libIndexPaused != now.libIndexPaused) {
      unawaited(q.settingsChanged());
    }
  });
  ref.onDispose(q.dispose);
  return q;
});

/// S46's status line.
final indexStatusProvider = StreamProvider<IndexStatus>((ref) async* {
  final q = ref.watch(indexQueueProvider);
  yield q.status;
  yield* q.statusStream;
});
