// RELEASE_PRINT §5 / FR-PRN-04, -15: print settings defaults and what is
// remembered (T13.1), written before the implementation.
import 'package:docukit/core/print/print_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults (§5): locale paper, auto, fit, narrow, 1 per sheet, full page', () {
    final s = SettingsRepository(MemoryStore(), countryCode: 'IN').readPrintSettings();
    expect(s.paper, PaperSize.a4);
    expect(s.orientation, PrintOrientation.auto);
    expect(s.pages, PageSelection.all);
    expect(s.perSheet, 1);
    expect(s.imageLayout, ImageLayout.fullPage);
    expect(s.scaling, PrintScaling.fit);
    expect(s.margins, PrintMargins.narrow);
  });

  test('Letter in US/CA/MX/PH, A4 elsewhere and with no country', () {
    for (final c in ['US', 'ca', 'MX', 'PH']) {
      expect(SettingsRepository(MemoryStore(), countryCode: c).readPrintSettings().paper, PaperSize.letter, reason: c);
    }
    for (final c in ['GB', 'DE', null]) {
      expect(SettingsRepository(MemoryStore(), countryCode: c).readPrintSettings().paper, PaperSize.a4, reason: c);
    }
  });

  test('FR-PRN-15: paper, orientation, scaling, margins, per sheet and layout persist; the page range does not', () async {
    final store = MemoryStore();
    await SettingsRepository(store, countryCode: 'US').writePrintSettings(
      const PrintSettings(
        paper: PaperSize.in5x7,
        orientation: PrintOrientation.landscape,
        pages: PageSelection.range('2-4, 7'),
        perSheet: 6,
        imageLayout: ImageLayout.passportSheet,
        scaling: PrintScaling.actual,
        margins: PrintMargins.none,
      ),
    );
    expect(store.get(SettingsRepository.kPrintPaper), 'in5x7');
    expect(store.get(SettingsRepository.kPrintOrientation), 'landscape');
    expect(store.get(SettingsRepository.kPrintScaling), 'actual');
    expect(store.get(SettingsRepository.kPrintMargins), 'none');
    expect(store.get(SettingsRepository.kPrintPerSheet), 6);
    expect(store.get(SettingsRepository.kPrintImageLayout), 'passportSheet');

    final back = SettingsRepository(store, countryCode: 'US').readPrintSettings();
    expect(back.paper, PaperSize.in5x7);
    expect(back.orientation, PrintOrientation.landscape);
    expect(back.perSheet, 6);
    expect(back.imageLayout, ImageLayout.passportSheet);
    expect(back.scaling, PrintScaling.actual);
    expect(back.margins, PrintMargins.none);
    expect(back.pages, PageSelection.all, reason: 'the range is not remembered');
  });

  test('unknown or out-of-range stored values fall back to the defaults', () {
    final s = SettingsRepository(
      MemoryStore({
        SettingsRepository.kPrintPaper: 'a3',
        SettingsRepository.kPrintOrientation: 7,
        SettingsRepository.kPrintScaling: 'stretch',
        SettingsRepository.kPrintMargins: '',
        SettingsRepository.kPrintPerSheet: 3,
        SettingsRepository.kPrintImageLayout: 'collage',
      }),
      countryCode: 'US',
    ).readPrintSettings();
    expect(s.paper, PaperSize.letter);
    expect(s.orientation, PrintOrientation.auto);
    expect(s.scaling, PrintScaling.fit);
    expect(s.margins, PrintMargins.narrow);
    expect(s.perSheet, 1);
    expect(s.imageLayout, ImageLayout.fullPage);
  });

  test('copyWith and equality', () {
    const a = PrintSettings();
    final b = a.copyWith(perSheet: 4, pages: const PageSelection.range('1-3'));
    expect(b.perSheet, 4);
    expect(b.pages, const PageSelection.range('1-3'));
    expect(b.paper, a.paper);
    expect(b, a.copyWith(perSheet: 4, pages: const PageSelection.range('1-3')));
    expect(b == a, isFalse);
    expect(const PageSelection.range('1') == const PageSelection.range('2'), isFalse);
  });

  test('image layouts map to images per sheet; the passport sheet has its own grid', () {
    expect(ImageLayout.fullPage.perSheet, 1);
    expect(ImageLayout.twoUp.perSheet, 2);
    expect(ImageLayout.fourUp.perSheet, 4);
    expect(ImageLayout.passportSheet.perSheet, isNull);
  });

  test('perSheetOptions', () => expect(perSheetOptions, [1, 2, 4, 6]));
}
