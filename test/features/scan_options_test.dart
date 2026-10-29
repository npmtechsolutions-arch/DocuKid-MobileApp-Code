// T9.5 — ScanOptions (RELEASE_V1_2 §4.2, FR-SCN-13…16) and the options
// controller, written before the implementation.
import 'package:docukit/core/files/file_naming.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/core/scan/scan_options.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/scan/application/scan_options_controller.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tools/options_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults: PDF, A4, High, default name, not searchable', () {
    const o = ScanOptions();
    expect((o.format, o.pageSize, o.quality, o.baseName, o.makeSearchable),
        (ScanOutputFormat.pdf, ScanPageSize.a4, ScanQuality.high, null, false));
  });

  test('JSON round trip; history JSON has no page names (§5)', () {
    const o = ScanOptions(format: ScanOutputFormat.jpg, pageSize: ScanPageSize.fitToScan, quality: ScanQuality.compact);
    final j = o.toJson();
    expect(j, {'format': 'jpg', 'pageSize': 'fitToScan', 'quality': 'compact'});
    final back = ScanOptions.fromJson(j, const ScanOptions());
    expect((back.format, back.pageSize, back.quality), (ScanOutputFormat.jpg, ScanPageSize.fitToScan, ScanQuality.compact));
  });

  test('unknown JSON values fall back to the defaults', () {
    final o = ScanOptions.fromJson({'format': 'tiff', 'pageSize': 7}, const ScanOptions(pageSize: ScanPageSize.letter));
    expect((o.format, o.pageSize), (ScanOutputFormat.pdf, ScanPageSize.letter));
  });

  test('file names: Scan_yyyyMMdd_HHmm.pdf, or _p01.jpg… (FR-SCN-16)', () {
    final now = DateTime(2026, 10, 28, 14, 5);
    expect(defaultScanBaseName(now), 'Scan_20261028_1405');
    const pdf = ScanOptions();
    expect(pdf.displayName(now), 'Scan_20261028_1405.pdf');
    const jpg = ScanOptions(format: ScanOutputFormat.jpg, baseName: 'Receipt');
    expect(jpg.displayName(now), 'Receipt_p01.jpg');
    expect(scanJpgName('Receipt', 0), 'Receipt_p01.jpg');
    expect(scanJpgName('Receipt', 11), 'Receipt_p12.jpg');
  });

  group('controller', () {
    ProviderContainer make({Map<String, Object> store = const {}}) {
      final repo = SettingsRepository(MemoryStore(store));
      final c = ProviderContainer(overrides: [settingsRepositoryProvider.overrideWithValue(repo)]);
      c.listen(scanOptionsProvider, (_, _) {});
      addTearDown(c.dispose);
      return c;
    }

    test('page size comes from the scan setting (Letter by locale, FR-SCN-14)', () {
      expect(make(store: {'scan_page_size': 'letter'}).read(scanOptionsProvider).pageSize, ScanPageSize.letter);
      expect(make().read(scanOptionsProvider).pageSize, ScanPageSize.a4);
    });

    test('changes are kept in the options draft (survive process death)', () {
      final c = make();
      c.read(scanOptionsProvider.notifier).set(const ScanOptions(format: ScanOutputFormat.jpg));
      final draft = c.read(settingsRepositoryProvider).readDraft(optionsDraftKey(ToolId.scanDocument));
      expect(draft, contains('"format":"jpg"'));
      final restored = make(store: {'draft_${optionsDraftKey(ToolId.scanDocument)}': draft!});
      expect(restored.read(scanOptionsProvider).format, ScanOutputFormat.jpg);
    });
  });

  group('settings (scan_default_format, scan_page_size, scan_quality — §5)', () {
    test('defaults: pdf, a4 (letter by locale), high', () {
      expect((const AppSettings().scanFormat, const AppSettings().scanQuality), (ScanOutputFormat.pdf, ScanQuality.high));
      expect(SettingsRepository(MemoryStore(), countryCode: 'US').load().scanPageSize, ScanPageSize.letter);
      expect(SettingsRepository(MemoryStore(), countryCode: 'IN').load().scanPageSize, ScanPageSize.a4);
    });

    test('stored values: pdf|jpg, a4|letter|fit, high|compact; junk falls back', () async {
      final store = MemoryStore();
      final repo = SettingsRepository(store);
      await repo.save(const AppSettings(
          scanFormat: ScanOutputFormat.jpg, scanPageSize: ScanPageSize.fitToScan, scanQuality: ScanQuality.compact));
      expect((store.get('scan_default_format'), store.get('scan_page_size'), store.get('scan_quality')), ('jpg', 'fit', 'compact'));
      final back = repo.load();
      expect((back.scanFormat, back.scanPageSize, back.scanQuality),
          (ScanOutputFormat.jpg, ScanPageSize.fitToScan, ScanQuality.compact));
      final junk = SettingsRepository(MemoryStore({'scan_default_format': 'tiff', 'scan_page_size': 'a3'})).load();
      expect((junk.scanFormat, junk.scanPageSize), (ScanOutputFormat.pdf, ScanPageSize.a4));
    });

    test('Make searchable (1.3): scan_make_searchable, off by default; the language is ocr_script', () async {
      expect(SettingsRepository(MemoryStore()).load().scanMakeSearchable, isFalse);
      final store = MemoryStore({'scan_make_searchable': true, 'ocr_script': 'devanagari'});
      final c = ProviderContainer(overrides: [settingsRepositoryProvider.overrideWithValue(SettingsRepository(store))]);
      addTearDown(c.dispose);
      c.listen(scanOptionsProvider, (_, _) {});
      final o = c.read(scanOptionsProvider);
      expect((o.makeSearchable, o.ocrScript), (true, OcrScript.devanagari));
      c.read(scanOptionsProvider.notifier).set(o.copyWith(makeSearchable: false, ocrScript: OcrScript.latin));
      await Future<void>.delayed(Duration.zero);
      expect((store.get('scan_make_searchable'), store.get('ocr_script')), (false, 'latin'));
    });

    test('searchable only for PDF output', () {
      expect(const ScanOptions(makeSearchable: true).searchable, isTrue);
      expect(const ScanOptions(makeSearchable: true, format: ScanOutputFormat.jpg).searchable, isFalse);
    });

    test('S29 starts from the remembered choice and remembers the next one', () async {
      final repo = SettingsRepository(MemoryStore({'scan_default_format': 'jpg', 'scan_page_size': 'letter'}));
      final c = ProviderContainer(overrides: [settingsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      c.listen(scanOptionsProvider, (_, _) {});
      final o = c.read(scanOptionsProvider);
      expect((o.format, o.pageSize, o.quality), (ScanOutputFormat.jpg, ScanPageSize.letter, ScanQuality.high));
      c.read(scanOptionsProvider.notifier).set(o.copyWith(quality: ScanQuality.compact, format: ScanOutputFormat.pdf));
      await Future<void>.delayed(Duration.zero);
      final s = c.read(settingsProvider);
      expect((s.scanFormat, s.scanQuality), (ScanOutputFormat.pdf, ScanQuality.compact));
    });
  });
}

