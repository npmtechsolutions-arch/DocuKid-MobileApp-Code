// T12.5 — the background index queue (RELEASE_V1_5 §4.6, FR-LIB-15/16,
// ADR-055/058) on the real LibraryRepository (in-memory DB, temp files) with a
// fake text source: the policy, the text layer without OCR, the order
// (interrupted → "Make searchable now" → oldest), the pauses (user,
// background, a tool job, low battery), per-page resume after a restart, and
// one automatic retry of a failure.
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/library/application/index_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// What each library file "contains", by display name (the file's content).
class FakeSource implements DocTextSource {
  final layers = <String, String>{};
  final pages = <String, int>{};
  final failing = <String>{};
  final calls = <String>[];
  void Function(String name, int page)? onRecognize;

  String _name(String path) => File(path).readAsStringSync();

  @override
  Future<int> pageCount(String path) async => pages[_name(path)] ?? 1;

  @override
  Future<String> textLayer(String path) async {
    final n = _name(path);
    if (failing.contains(n)) throw const AppError(AppErrorCode.corruptFile);
    return layers[n] ?? '';
  }

  @override
  Future<String> recognize(String path, {required bool isPdf, required int index, required OcrScript script, required Directory work}) async {
    final n = _name(path);
    if (failing.contains(n)) throw const AppError(AppErrorCode.processingFailed);
    calls.add('$n#$index');
    onRecognize?.call(n, index);
    return 'word$index of $n';
  }

  @override
  Future<void> release() async {}
}

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LibraryRepositoryImpl repo;
  late SettingsRepository store;
  late FakeSource source;
  var settings = const AppSettings();
  var battery = (level: 80, charging: false);
  var busy = false;
  final queues = <IndexQueue>[];

  setUp(() {
    db = memoryDb();
    tmp = Directory.systemTemp.createTempSync('lib_index');
    repo = LibraryRepositoryImpl(db, Directory(p.join(tmp.path, 'support'))..createSync());
    store = SettingsRepository(MemoryStore());
    source = FakeSource();
    settings = const AppSettings();
    battery = (level: 80, charging: false);
    busy = false;
  });
  tearDown(() async {
    for (final q in queues) {
      await q.dispose();
    }
    queues.clear();
    await repo.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  IndexQueue queue() {
    final q = IndexQueue(
      repo: repo,
      source: source,
      store: store,
      settings: () => settings,
      battery: () async => battery,
      busy: () => busy,
      workRoot: Directory(p.join(tmp.path, 'index')),
      poll: const Duration(milliseconds: 30),
    );
    queues.add(q);
    return q;
  }

  /// Content = name, so the fake source can tell files apart.
  Future<LibraryDoc> add(String name, {DocSource source = DocSource.import, bool pdf = true}) async {
    final f = File(p.join(tmp.path, name))..writeAsStringSync(name);
    final r = await repo.addFile(f.path, displayName: name, source: source, mime: pdf ? 'application/pdf' : 'image/jpeg');
    return (r as Added).doc;
  }

  Future<IndexState> state(LibraryDoc d) async => (await repo.get(d.id))!.indexState;

  /// Waits until nothing is queued or indexing, or [until] holds.
  Future<void> settle({bool Function(IndexStatus)? until, IndexQueue? q}) async {
    // Up to ~15 s of real time: a full parallel run once took longer than 5 s.
    for (var i = 0; i < 750; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (until != null && q != null) {
        if (until(q.status)) return;
      } else if ((await repo.docsWithIndexState({IndexState.queued, IndexState.indexing})).isEmpty) {
        return;
      }
    }
  }

  Future<List<String>> found(String q) async => [for (final h in await repo.search(q).first) h.doc.name];

  test('ADR-055 defaults: a scan is OCR\'d; an imported image waits; a PDF with text is indexed from its text layer, no OCR', () async {
    source.layers['Lease.pdf'] = 'This lease agreement is made between the landlord and the tenant.';
    final scan = await add('Scan.pdf', source: DocSource.scan);
    final photo = await add('receipt.jpg', pdf: false);
    final lease = await add('Lease.pdf');
    await queue().start();
    await settle();
    expect(await state(scan), IndexState.done);
    expect(await state(lease), IndexState.done);
    expect(await state(photo), IndexState.none, reason: '"Other PDFs and images" is off');
    expect(source.calls, ['Scan.pdf#0'], reason: 'the lease had text: no OCR');
    expect(await found('landlord'), ['Lease.pdf']);
    expect(await found('word0'), ['Scan.pdf']);
  });

  test('an image-only PDF with "Other" off: its short text layer is kept, not searchable, not queued again', () async {
    source.layers['bill.pdf'] = 'p. 1';
    final bill = await add('bill.pdf');
    await queue().start();
    await settle();
    final d = (await repo.get(bill.id))!;
    expect((d.indexState, d.indexedAt != null), (IndexState.none, true));
    expect(source.calls, isEmpty);
    await queues.single.dispose();
    queues.clear();
    await queue().start();
    await settle();
    expect(source.calls, isEmpty, reason: 'checked once already');

    // Turning "Other PDFs and images" on queues it (owner-approved default).
    settings = settings.copyWith(libIndexOther: true);
    await queues.single.settingsChanged();
    await settle();
    expect(await state(bill), IndexState.done);
    expect(source.calls, ['bill.pdf#0']);
  });

  test('documents added while running are picked up (LibraryChange added)', () async {
    final q = queue();
    await q.start();
    await settle();
    final scan = await add('Scan.pdf', source: DocSource.scan);
    await settle();
    expect(await state(scan), IndexState.done);
  });

  test('"Make searchable now": OCR even with "Other" off, and ahead of older queued documents', () async {
    source.pages['old1.pdf'] = 1;
    final old1 = await add('old1.pdf', source: DocSource.scan);
    final old2 = await add('old2.pdf', source: DocSource.scan);
    final photo = await add('receipt.jpg', pdf: false);
    settings = settings.copyWith(libIndexPaused: true);
    final q = queue();
    await q.start();
    await q.makeSearchableNow(photo.id);
    // All three queued (the photo after start) and held by the user's Pause.
    await settle(q: q, until: (s) => s == const IndexStatus(waiting: 3, paused: IndexPause.user));
    expect(q.status, const IndexStatus(waiting: 3, paused: IndexPause.user));
    settings = settings.copyWith(libIndexPaused: false);
    await q.settingsChanged();
    await settle();
    expect(source.calls, ['receipt.jpg#0', 'old1.pdf#0', 'old2.pdf#0']);
    expect([await state(old1), await state(old2), await state(photo)], everyElement(IndexState.done));
    expect(store.readIndexManual(), isEmpty);
  });

  for (final (name, pause, set, clear) in <(String, IndexPause, void Function(), void Function())>[
    ('a tool job is running', IndexPause.busy, () => busy = true, () => busy = false),
    ('battery 15 % and not charging', IndexPause.battery, () => battery = (level: 15, charging: false),
        () => battery = (level: 15, charging: true)),
  ]) {
    test('waits while $name, then carries on by itself', () async {
      final scan = await add('Scan.pdf', source: DocSource.scan);
      set();
      final q = queue();
      await q.start();
      await settle(q: q, until: (s) => s.paused == pause);
      expect(q.status.paused, pause);
      expect(await state(scan), IndexState.queued);
      clear();
      await settle(q: q, until: (s) => s == const IndexStatus());
      expect(await state(scan), IndexState.done);
      expect(q.status, const IndexStatus());
    });
  }

  test('backgrounded: waits; back in the foreground: carries on', () async {
    final scan = await add('Scan.pdf', source: DocSource.scan);
    final q = queue()..setForeground(false);
    await q.start();
    await settle(q: q, until: (s) => s.paused == IndexPause.background);
    expect(await state(scan), IndexState.queued);
    q.setForeground(true);
    await settle();
    expect(await state(scan), IndexState.done);
  });

  test('FR-LIB-16 resume: stops after page 1 when the battery runs low; a restart continues at page 2, keeping page 1\'s text', () async {
    source.pages['Scan.pdf'] = 3;
    final scan = await add('Scan.pdf', source: DocSource.scan);
    source.onRecognize = (_, page) {
      if (page == 0) battery = (level: 12, charging: false);
    };
    final first = queue();
    await first.start();
    await settle(q: first, until: (s) => s.paused == IndexPause.battery);
    expect(source.calls, ['Scan.pdf#0']);
    expect(await state(scan), IndexState.indexing);
    expect(store.readIndexProgress(), (id: scan.id, page: 1));
    await first.dispose();
    queues.remove(first);

    source.onRecognize = null;
    battery = (level: 90, charging: false);
    await queue().start();
    await settle();
    expect(source.calls, ['Scan.pdf#0', 'Scan.pdf#1', 'Scan.pdf#2']);
    expect(await state(scan), IndexState.done);
    expect(await found('word0'), ['Scan.pdf'], reason: 'page 1 survived the restart');
    expect(await found('word2'), ['Scan.pdf']);
    expect(store.readIndexProgress(), isNull);
  });

  test('a failure is retried once on the next launch, then only on request', () async {
    source.failing.add('Bad.pdf');
    final bad = await add('Bad.pdf', source: DocSource.scan);
    Future<void> launch() async {
      for (final q in queues) {
        await q.dispose();
      }
      queues.clear();
      await queue().start();
      await settle();
    }

    await launch();
    expect(await state(bad), IndexState.failed);
    await launch();
    expect(await state(bad), IndexState.failed);
    expect(store.readIndexRetried(), [bad.id]);
    source.failing.clear();
    await launch();
    expect(await state(bad), IndexState.failed, reason: 'retried once already');
    await queues.single.makeSearchableNow(bad.id);
    await settle();
    expect(await state(bad), IndexState.done);
  });
}
