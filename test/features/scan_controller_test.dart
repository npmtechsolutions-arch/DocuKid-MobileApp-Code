// T9.3 — ScanController (RELEASE_V1_2 §4.4, §8: completed → pages for review;
// cancelled → nothing; each failure → its banner; page limit 50 − existing),
// written before the implementation.
import 'dart:async';

import 'package:docukit/core/files/file_gateway.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/core/scan/document_scanner.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/scan/application/scan_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  late FakeDocumentScanner scanner;
  late FakeGateway gateway;
  late AppPaths paths;
  late ProviderContainer c;
  const draft = 'draft-1';

  setUp(() async {
    scanner = FakeDocumentScanner();
    gateway = FakeGateway();
    paths = await tempPaths();
    c = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(paths),
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(MemoryStore())),
      fileGatewayProvider.overrideWithValue(gateway as FileGateway),
      documentScannerProvider.overrideWithValue(scanner),
      scanPrepareTimeoutProvider.overrideWithValue(const Duration(milliseconds: 50)),
    ]);
    // Keep the auto-dispose controller alive, as S27 does while it's shown.
    c.listen(scanControllerProvider, (_, _) {});
  });
  tearDown(() => c.dispose());

  ScanController ctl() => c.read(scanControllerProvider.notifier);
  ScanFlowState st() => c.read(scanControllerProvider);
  String inDir() => paths.jobIn(draft).path;

  test('completed: the pages come back in order, inside the draft in/ folder', () async {
    scanner.pagesToWrite = 3;
    final pages = await ctl().scan(draftId: draft, existing: 0);
    expect(pages.map((f) => p.basename(f.path)), ['page_001.jpg', 'page_002.jpg', 'page_003.jpg']);
    expect(pages.every((f) => p.isWithin(inDir(), f.path)), isTrue);
    expect(scanner.scans.single.destDir, inDir());
    expect(scanner.scans.single.allowGalleryImport, isTrue);
    expect(st().phase, ScanPhase.idle);
    expect(st().banner, isNull);
    expect(st().notice, isNull);
  });

  test('page limit: maxPages = 50 − pages already in the scan (FR-SCN-02)', () async {
    await ctl().scan(draftId: draft, existing: 0);
    await ctl().scan(draftId: draft, existing: 47);
    expect(scanner.scans.map((s) => s.maxPages), [50, 3]);
    expect(ScanController.maxPages, 50);
  });

  test('rescan one page asks for exactly 1 (FR-SCN-21)', () async {
    await ctl().scan(draftId: draft, existing: 12, limit: 1);
    expect(scanner.scans.single.maxPages, 1);
  });

  test('at 50 pages the scanner is not opened and the limit notice shows', () async {
    final pages = await ctl().scan(draftId: draft, existing: 50);
    expect(pages, isEmpty);
    expect(scanner.scans, isEmpty);
    expect(st().notice, ScanNotice.limitReached);
    ctl().dismissNotice();
    expect(st().notice, isNull);
  });

  test('cancelled: nothing changes, no banner (FR-SCN-04)', () async {
    scanner.nextOutcome = const ScanCancelled();
    final pages = await ctl().scan(draftId: draft, existing: 4);
    expect(pages, isEmpty);
    expect(st(), const ScanFlowState());
  });

  test('truncated: the pages kept plus the "only the first 50" notice', () async {
    scanner
      ..pagesToWrite = 1
      ..truncate = true;
    final pages = await ctl().scan(draftId: draft, existing: 49);
    expect(pages, hasLength(1));
    expect(st().notice, ScanNotice.truncated);
  });

  group('each failure → its banner', () {
    const expected = {
      ScanErrorCode.offline: ScanBanner.moduleOffline,
      ScanErrorCode.moduleUnavailable: ScanBanner.moduleOffline,
      ScanErrorCode.noPlayServices: ScanBanner.noPlayServices,
      ScanErrorCode.unsupported: ScanBanner.unsupported,
      ScanErrorCode.cameraDenied: ScanBanner.cameraDenied,
      ScanErrorCode.storage: ScanBanner.storage,
      ScanErrorCode.unknown: ScanBanner.unknown,
    };
    test('covers every code', () => expect(expected.keys.toSet(), ScanErrorCode.values.toSet()));
    for (final e in expected.entries) {
      test('${e.key.name} → ${e.value.name}', () async {
        scanner.nextOutcome = ScanFailed(e.key);
        final pages = await ctl().scan(draftId: draft, existing: 0);
        expect(pages, isEmpty);
        expect(st().banner, e.value);
        expect(st().phase, ScanPhase.idle);
        ctl().dismissBanner();
        expect(st().banner, isNull);
      });
    }
  });

  group('checked before launch', () {
    const expected = {
      ScannerAvailability.noPlayServices: ScanBanner.noPlayServices,
      ScannerAvailability.unsupported: ScanBanner.unsupported,
      ScannerAvailability.cameraDenied: ScanBanner.cameraDenied,
    };
    for (final e in expected.entries) {
      test('${e.key.name} → ${e.value.name}, scanner not opened', () async {
        scanner.nextAvailability = e.key;
        await ctl().scan(draftId: draft, existing: 0);
        expect(scanner.scans, isEmpty);
        expect(st().banner, e.value);
      });
    }
  });

  group('first-time download (FR-SCN-07)', () {
    setUp(() => scanner.nextAvailability = ScannerAvailability.needsDownload);

    test('ready after the download → the scanner opens', () async {
      final pages = await ctl().scan(draftId: draft, existing: 0);
      expect(scanner.prepares, 1);
      expect(pages, hasLength(2));
      expect(st().banner, isNull);
    });

    test('"Getting the scanner ready" shows while it downloads', () async {
      scanner.nextPrepare = null; // never answers
      final run = ctl().scan(draftId: draft, existing: 0);
      await Future<void>.delayed(Duration.zero);
      expect(st().phase, ScanPhase.preparing);
      await run;
    });

    test('Cancel while getting ready: back to the entry, the scanner never opens', () async {
      final answer = Completer<ScanPrepareResult>();
      final slow = _PreparingScanner(answer.future);
      final c2 = ProviderContainer(overrides: [
        appPathsProvider.overrideWithValue(paths),
        fileGatewayProvider.overrideWithValue(gateway as FileGateway),
        documentScannerProvider.overrideWithValue(slow),
      ]);
      addTearDown(c2.dispose);
      c2.listen(scanControllerProvider, (_, _) {});
      final run = c2.read(scanControllerProvider.notifier).scan(draftId: draft, existing: 0);
      await Future<void>.delayed(Duration.zero);
      expect(c2.read(scanControllerProvider).phase, ScanPhase.preparing);
      c2.read(scanControllerProvider.notifier).cancelPreparing();
      expect(c2.read(scanControllerProvider), const ScanFlowState());
      answer.complete(ScanPrepareResult.ready); // the download finishes later
      expect(await run, isEmpty);
      expect(slow.scans, 0);
      expect(c2.read(scanControllerProvider), const ScanFlowState());
    });

    test('offline → the one-time download banner, scanner not opened', () async {
      scanner.nextPrepare = ScanPrepareResult.offline;
      await ctl().scan(draftId: draft, existing: 0);
      expect(scanner.scans, isEmpty);
      expect(st().banner, ScanBanner.moduleOffline);
    });

    test('failed → the same banner', () async {
      scanner.nextPrepare = ScanPrepareResult.failed;
      await ctl().scan(draftId: draft, existing: 0);
      expect(st().banner, ScanBanner.moduleOffline);
    });

    test('no answer within the time limit → the same banner', () async {
      scanner.nextPrepare = null;
      await ctl().scan(draftId: draft, existing: 0);
      expect(scanner.scans, isEmpty);
      expect(st().banner, ScanBanner.moduleOffline);
      expect(st().phase, ScanPhase.idle);
      expect(c.read(scanPrepareTimeoutProvider), const Duration(milliseconds: 50));
    });

    test('Retry after going online works', () async {
      scanner.nextPrepare = ScanPrepareResult.offline;
      await ctl().scan(draftId: draft, existing: 0);
      scanner.nextPrepare = ScanPrepareResult.ready;
      final pages = await ctl().scan(draftId: draft, existing: 0);
      expect(pages, hasLength(2));
      expect(st().banner, isNull);
    });
  });

  test('the default wait for the download is 60 s', () {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);
    expect(plain.read(scanPrepareTimeoutProvider), const Duration(seconds: 60));
  });

  test('a second tap while the scanner is open is ignored', () async {
    final gate = Completer<ScanOutcome>();
    final slow = _SlowScanner(gate.future);
    final c2 = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(paths),
      fileGatewayProvider.overrideWithValue(gateway as FileGateway),
      documentScannerProvider.overrideWithValue(slow),
    ]);
    addTearDown(c2.dispose);
    c2.listen(scanControllerProvider, (_, _) {});
    final first = c2.read(scanControllerProvider.notifier).scan(draftId: draft, existing: 0);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(scanControllerProvider).phase, ScanPhase.scanning);
    expect(await c2.read(scanControllerProvider.notifier).scan(draftId: draft, existing: 0), isEmpty);
    gate.complete(const ScanCancelled());
    await first;
    expect(slow.calls, 1);
  });

  group('result after process death (FR-SCN-20)', () {
    test('for this draft → its pages', () async {
      scanner.restored = (destDir: inDir(), outcome: ScanCompleted(['${inDir()}/page_003.jpg']));
      final pages = await ctl().takeRestored(draft);
      expect(pages!.single.path, '${inDir()}/page_003.jpg');
    });

    test('for another draft, cancelled, or nothing → null', () async {
      scanner.restored = (destDir: '/elsewhere', outcome: const ScanCompleted(['/elsewhere/page_001.jpg']));
      expect(await ctl().takeRestored(draft), isNull);
      scanner.restored = (destDir: inDir(), outcome: const ScanCancelled());
      expect(await ctl().takeRestored(draft), isNull);
      expect(await ctl().takeRestored(draft), isNull);
    });
  });
}

class _SlowScanner implements DocumentScanner {
  _SlowScanner(this.result);
  final Future<ScanOutcome> result;
  int calls = 0;

  @override
  Future<ScannerAvailability> availability() async => ScannerAvailability.ready;
  @override
  Future<ScanPrepareResult> prepare() async => ScanPrepareResult.ready;
  @override
  Future<ScanOutcome> scan({required int maxPages, required String destDir, bool allowGalleryImport = true}) {
    calls++;
    return result;
  }

  @override
  Future<RestoredScanResult?> takeRestored() async => null;
}

class _PreparingScanner implements DocumentScanner {
  _PreparingScanner(this.ready);
  final Future<ScanPrepareResult> ready;
  int scans = 0;

  @override
  Future<ScannerAvailability> availability() async => ScannerAvailability.needsDownload;
  @override
  Future<ScanPrepareResult> prepare() => ready;
  @override
  Future<ScanOutcome> scan({required int maxPages, required String destDir, bool allowGalleryImport = true}) async {
    scans++;
    return const ScanCancelled();
  }

  @override
  Future<RestoredScanResult?> takeRestored() async => null;
}
