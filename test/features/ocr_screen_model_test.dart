// T10.6 — S30's decisions (RELEASE_V1_3 §3.1, FR-OCR-01–04) as a pure model,
// the options controller and the OCR settings (§5). Written before the
// implementation.
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/app_settings.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/ocr/application/ocr_options.dart';
import 'package:docukit/features/ocr/application/ocr_options_controller.dart';
import 'package:docukit/features/ocr/application/ocr_screen_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart' show fakeImage, fakePdf;

void main() {
  final img = fakeImage('a.jpg');
  OcrScreenModel model(List<PickedFile> files, {AsyncValue<List<bool>>? text, OcrOptions o = const OcrOptions()}) =>
      ocrScreenModel(files: files, textPages: text, options: o);

  group('screen model', () {
    test('empty: no run, the pick hint', () {
      final m = model(const []);
      expect((m.kind, m.canRun, m.helper), (OcrInputKind.none, false, OcrHelper.pick));
    });

    test('images: one page each; runs; long-job note above 30 pages', () {
      final m = model([img, fakeImage('b.jpg')]);
      expect((m.kind, m.canRun, m.pagesToRecognise, m.getText, m.helper), (OcrInputKind.images, true, 2, false, null));
      expect(m.showLongJob, isFalse);
      expect(model([for (var i = 0; i < 31; i++) fakeImage('$i.jpg')]).showLongJob, isTrue);
      expect(m.showRebuildNote, isFalse, reason: 'only for PDFs');
    });

    test('invalid files are left out; none valid → no run', () {
      const broken = PickedFile(
          path: '/x.jpg', displayName: 'x.jpg', type: SniffedType.jpeg, sizeBytes: 1, status: ValidationStatus.invalid(AppErrorCode.corruptFile));
      expect(model([img, broken]).pagesToRecognise, 1);
      expect((model([broken]).canRun, model([broken]).helper), (false, OcrHelper.chooseAnother));
      final locked = fakePdf('x.pdf', encrypted: true);
      expect((model([locked]).canRun, model([locked]).helper), (false, OcrHelper.chooseAnother));
    });

    test('mixed images and a PDF are refused (FR-OCR-01)', () {
      final m = model([img, fakePdf('a.pdf')], text: const AsyncData([false]));
      expect((m.kind, m.canRun, m.helper), (OcrInputKind.mixed, false, OcrHelper.mixed));
    });

    test('PDF: checking for text holds Run (§3.1 "Validating a PDF")', () {
      final m = model([fakePdf('a.pdf')], text: const AsyncLoading());
      expect((m.kind, m.checkingText, m.canRun), (OcrInputKind.pdf, true, false));
    });

    test('PDF with no text: every page recognised; rebuild note while the PDF output is on', () {
      final m = model([fakePdf('a.pdf', pages: 12)], text: AsyncData(List.filled(12, false)));
      expect((m.canRun, m.pagesToRecognise, m.getText, m.showRebuildNote), (true, 12, false, true));
      expect(model([fakePdf('a.pdf')], text: const AsyncData([false, false, false]), o: const OcrOptions(searchablePdf: false))
          .showRebuildNote, isFalse);
    });

    test('partial PDF: only the pages without text count (FR-OCR-02)', () {
      final m = model([fakePdf('a.pdf')], text: const AsyncData([true, false, false]));
      expect((m.pagesToRecognise, m.text!.withText, m.getText), (2, 1, false));
    });

    test('fully text PDF: "Get text", PDF output disabled and off, runs with text outputs', () {
      final m = model([fakePdf('a.pdf')], text: const AsyncData([true, true, true]));
      expect((m.getText, m.pdfOutputDisabled, m.effective.searchablePdf, m.canRun), (true, true, false, true));
      expect(m.showRebuildNote, isFalse);
      // Only "Searchable PDF" ticked → nothing to do (§4.11 ocrNothingToDo): a disabled state.
      final only = model([fakePdf('a.pdf')],
          text: const AsyncData([true, true, true]), o: const OcrOptions(searchablePdf: true, review: false, txt: false));
      expect((only.canRun, only.helper), (false, OcrHelper.chooseOutput));
    });

    test('no output ticked → "Choose at least one result" (FR-OCR-03)', () {
      final m = model([img], o: const OcrOptions(searchablePdf: false, review: false, txt: false));
      expect((m.canRun, m.helper), (false, OcrHelper.chooseOutput));
    });

    test('a detection error (damaged PDF) can\'t run', () {
      final m = model([fakePdf('a.pdf')], text: AsyncError(Exception(), StackTrace.empty));
      expect((m.canRun, m.helper), (false, OcrHelper.chooseAnother));
    });
  });

  group('options controller + settings (§5)', () {
    ProviderContainer make({Map<String, Object> store = const {}, String? language}) {
      final repo = SettingsRepository(MemoryStore(store), languageCode: language);
      final c = ProviderContainer(overrides: [settingsRepositoryProvider.overrideWithValue(repo)]);
      c.listen(ocrOptionsProvider, (_, _) {});
      addTearDown(c.dispose);
      return c;
    }

    test('defaults: PDF + Review on, .txt off, Latin, rotate retry on', () {
      final o = make().read(ocrOptionsProvider);
      expect((o.searchablePdf, o.review, o.txt, o.script, o.rotateRetry), (true, true, false, OcrScript.latin, true));
    });

    test('Hindi / Marathi devices start on Devanagari', () {
      expect(make(language: 'hi').read(ocrOptionsProvider).script, OcrScript.devanagari);
      expect(make(language: 'mr').read(ocrOptionsProvider).script, OcrScript.devanagari);
      expect(make(language: 'en').read(ocrOptionsProvider).script, OcrScript.latin);
    });

    test('choices are remembered in ocr_script / ocr_outputs; junk falls back', () async {
      final store = MemoryStore();
      final repo = SettingsRepository(store);
      final c = ProviderContainer(overrides: [settingsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      c.listen(ocrOptionsProvider, (_, _) {});
      c.read(ocrOptionsProvider.notifier).set(const OcrOptions(searchablePdf: false, txt: true, script: OcrScript.devanagari));
      await Future<void>.delayed(Duration.zero);
      expect(store.get('ocr_script'), 'devanagari');
      expect(store.get('ocr_outputs'), '{"pdf":false,"review":true,"txt":true}');
      final back = SettingsRepository(store).load();
      expect((back.ocrOutputPdf, back.ocrOutputTxt, back.ocrScript), (false, true, OcrScript.devanagari));
      final junk = SettingsRepository(MemoryStore({'ocr_script': 'klingon', 'ocr_outputs': 'not json'})).load();
      expect((junk.ocrScript, junk.ocrOutputPdf, junk.ocrOutputReview, junk.ocrOutputTxt), (OcrScript.latin, true, true, false));
    });

    test('rotate retry comes from ocr_rotate_retry', () {
      expect(make(store: {'ocr_rotate_retry': false}).read(ocrOptionsProvider).rotateRetry, isFalse);
      expect(const AppSettings().ocrRotateRetry, isTrue);
    });
  });
}
