// T9.5 — ScanOptions (RELEASE_V1_2 §4.2, FR-SCN-13…16) and the options
// controller, written before the implementation.
import 'package:docukit/core/files/file_naming.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
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
  test('defaults: PDF, A4, High, default name, never searchable (ADR-043)', () {
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
    ProviderContainer make({Map<String, Object> store = const {}, PdfPageSize size = PdfPageSize.a4}) {
      final repo = SettingsRepository(MemoryStore(store));
      final c = ProviderContainer(overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        settingsProvider.overrideWith(() => _FixedSettings(AppSettings(pdfPageSize: size))),
      ]);
      c.listen(scanOptionsProvider, (_, _) {});
      addTearDown(c.dispose);
      return c;
    }

    test('page size follows the Images to PDF default (Letter in US/CA/MX/PH, FR-SCN-14)', () {
      expect(make(size: PdfPageSize.letter).read(scanOptionsProvider).pageSize, ScanPageSize.letter);
      expect(make(size: PdfPageSize.legal).read(scanOptionsProvider).pageSize, ScanPageSize.a4);
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
}

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this.s);
  final AppSettings s;
  @override
  AppSettings build() => s;
}
