// T13.5 — the S48 controller (RELEASE_PRINT §3, §4.3–4.4, §8), written before
// the implementation: first build on open, 300 ms debounce, stale builds
// cancelled while the last good preview stays, settings remembered (not the
// range), range / no pages / locked / failed states, print outcomes, and the
// work folder removed on leaving (after a pending print).
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/pdf/page_ranges.dart';
import 'package:docukit/core/print/print_composer.dart';
import 'package:docukit/core/print/print_gateway.dart';
import 'package:docukit/core/print/print_settings.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/print/application/print_preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  late ProviderContainer c;
  late FakePrintComposer composer;
  late FakePrintGateway gateway;
  late AppPaths paths;
  late MemoryStore store;
  final provider = printPreviewProvider('end');

  Future<void> open(PrintRequest? request, {Map<String, Object> saved = const {}}) async {
    composer = FakePrintComposer();
    gateway = FakePrintGateway();
    paths = await tempPaths();
    store = MemoryStore({...saved});
    c = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(paths),
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(store, countryCode: 'US')),
      printComposerProvider.overrideWithValue(composer),
      printGatewayProvider.overrideWithValue(gateway),
      pdfEngineProvider.overrideWithValue(FakePdfEngine()),
    ]);
    addTearDown(c.dispose);
    if (request != null) c.read(printRequestProvider.notifier).set(request);
    c.listen(provider, (_, _) {});
  }

  PrintPreviewState st() => c.read(provider);
  PrintPreviewController ctl() => c.read(provider.notifier);

  Future<void> until(bool Function() ok, {String what = ''}) async {
    for (var i = 0; i < 300 && !ok(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ok(), isTrue, reason: 'timed out: $what');
  }

  Future<void> idle() => until(() => !st().building, what: 'build finished');

  final pdf = PrintRequest([fakePdf('Report.pdf', pages: 10)]);

  test('opens: builds once at once with the remembered settings (Letter in the US), in cache/jobs/print_*', () async {
    await open(pdf, saved: {SettingsRepository.kPrintPerSheet: 2});
    await until(() => st().output != null, what: 'first preview');
    expect(composer.calls, hasLength(1));
    expect(composer.calls.single.paper, PaperSize.letter);
    expect(composer.calls.single.perSheet, 2);
    expect(composer.sources.single, isA<PdfPrintSource>());
    expect(p.basename(p.dirname(composer.dirs.single)), startsWith(printJobPrefix));
    expect(p.dirname(p.dirname(composer.dirs.single)), paths.jobsRoot.path);
    expect(st().sheetCount, 2);
    expect(st().canPrint, isTrue);
    expect(st().available, isTrue);
  });

  test('no request → nothing to build, nothing to print', () async {
    await open(null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(composer.calls, isEmpty);
    expect(st().canPrint, isFalse);
  });

  test('images → ImagesPrintSource with the image layout', () async {
    await open(PrintRequest([fakeImage('a.jpg'), fakeImage('b.jpg')]));
    await idle();
    expect(composer.sources.single, isA<ImagesPrintSource>());
    expect((composer.sources.single as ImagesPrintSource).images, hasLength(2));
  });

  test('changes are debounced 300 ms: three quick changes → one build with the last settings', () async {
    await open(pdf);
    await idle();
    final s0 = st().settings;
    ctl().update(s0.copyWith(perSheet: 2));
    ctl().update(s0.copyWith(perSheet: 4));
    ctl().update(s0.copyWith(perSheet: 6));
    expect(st().canPrint, isFalse, reason: 'never print the old preview with the new settings');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(composer.calls, hasLength(1), reason: 'not yet');
    expect(st().building, isTrue);
    await until(() => composer.calls.length == 2, what: 'debounced build');
    await idle();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(composer.calls, hasLength(2));
    expect(composer.calls.last.perSheet, 6);
  });

  test('a newer change cancels the stale build; the last good preview stays until the new one is ready', () async {
    await open(pdf);
    await idle();
    final first = st().output!;
    composer.gate = Completer<void>();
    ctl().update(st().settings.copyWith(perSheet: 2));
    await until(() => composer.calls.length == 2, what: 'build 2 started');
    expect(st().building, isTrue);
    expect(st().output!.path, first.path, reason: 'last good kept while building');
    expect(st().progress?.total, 2, reason: 'real progress from the composer');
    ctl().update(st().settings.copyWith(perSheet: 4));
    await until(() => composer.calls.length == 3, what: 'build 3 started');
    composer.gate!.complete();
    composer.gate = null;
    await idle();
    expect(st().settings.perSheet, 4);
    expect(st().output!.path, isNot(first.path), reason: 'each build writes to its own folder');
    expect(File(st().output!.path).existsSync(), isTrue);
    expect(Directory(composer.dirs[0]).existsSync(), isFalse, reason: 'the replaced preview is removed');
    expect(Directory(composer.dirs[1]).existsSync(), isFalse, reason: 'the cancelled build is removed');
  });

  test('FR-PRN-15: settings are remembered, the page range is not', () async {
    await open(pdf);
    await idle();
    ctl().update(st().settings.copyWith(perSheet: 4, margins: PrintMargins.none, pages: const PageSelection.range('2-3')));
    await idle();
    expect(store.get(SettingsRepository.kPrintPerSheet), 4);
    expect(store.get(SettingsRepository.kPrintMargins), 'none');
    expect(SettingsRepository(store).readPrintSettings().pages, PageSelection.all);
  });

  test('an invalid range: an error, no build, Print disabled; fixing it builds again', () async {
    await open(pdf);
    await idle();
    ctl().update(st().settings.copyWith(pages: const PageSelection.range('3-99')));
    expect(st().rangeError?.kind, PageRangeErrorKind.pageMissing);
    expect(st().canPrint, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(composer.calls, hasLength(1));
    ctl().update(st().settings.copyWith(pages: const PageSelection.range('3-5')));
    expect(st().rangeError, isNull);
    await until(() => composer.calls.length == 2, what: 'rebuild');
  });

  test('no pages (Even on a 1-page PDF): noPages, no build, Print disabled', () async {
    await open(PrintRequest([fakePdf('One.pdf', pages: 1)]));
    await idle();
    ctl().update(st().settings.copyWith(pages: PageSelection.even));
    expect(st().noPages, isTrue);
    expect(st().canPrint, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(composer.calls, hasLength(1));
  });

  test('a password-protected PDF: locked, nothing built', () async {
    await open(PrintRequest([fakePdf('Secret.pdf', encrypted: true)]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(st().locked, isTrue);
    expect(composer.calls, isEmpty);
    expect(st().canPrint, isFalse);
  });

  test('a failed build: buildFailed, Print disabled; retry builds again', () async {
    await open(pdf);
    composer.error = Exception('boom');
    await until(() => composer.calls.isNotEmpty, what: 'first build');
    await idle();
    expect(st().buildFailed, isTrue);
    expect(st().canPrint, isFalse);
    composer.error = null;
    ctl().retry();
    await until(() => st().output != null, what: 'retried build');
    expect(st().buildFailed, isFalse);
  });

  test('cancel the build: stops it and keeps the last good preview', () async {
    await open(pdf);
    await idle();
    final first = st().output!;
    composer.gate = Completer<void>();
    ctl().update(st().settings.copyWith(perSheet: 2));
    await until(() => composer.calls.length == 2, what: 'build 2');
    ctl().cancelBuild();
    expect(st().building, isFalse);
    composer.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(st().output!.path, first.path);
  });

  test('print: the file and the name without its extension go to the gateway; outcomes are reported', () async {
    await open(pdf);
    await idle();
    expect(await ctl().print(), PrintOutcome.sent);
    expect(gateway.printed.single.jobName, 'Report');
    expect(gateway.printed.single.path, st().output!.path);
    expect(st().outcome, PrintOutcome.sent);
    gateway.outcome = PrintOutcome.failed;
    expect(await ctl().print(), PrintOutcome.failed);
    expect(st().outcome, PrintOutcome.failed);
    expect(st().printing, isFalse);
  });

  test('printing unavailable → Print disabled', () async {
    await open(pdf);
    gateway.isAvailable = false;
    ctl().retry();
    await until(() => !st().available, what: 'availability');
    await idle();
    expect(st().canPrint, isFalse);
  });

  test('leaving deletes the work folder; with a print still pending, only once it has finished', () async {
    await open(pdf);
    await idle();
    final job = p.dirname(p.dirname(st().output!.path));
    gateway.gate = Completer<void>();
    final printing = ctl().print();
    await until(() => st().printing, what: 'printing');
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(Directory(job).existsSync(), isTrue, reason: 'the dialog still reads the file');
    gateway.gate!.complete();
    await printing;
    await until(() => !Directory(job).existsSync(), what: 'deleted after the print');
  });

  test('leaving with nothing pending deletes the work folder at once', () async {
    await open(pdf);
    await idle();
    final job = p.dirname(p.dirname(st().output!.path));
    c.dispose();
    await until(() => !Directory(job).existsSync(), what: 'deleted');
  });
}
