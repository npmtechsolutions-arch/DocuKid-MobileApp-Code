// T10.1 — the TextRecognizer contract (RELEASE_V1_3 §4.2): the OCR model,
// the mapping from ML Kit's result, script availability (ADR-045) and the
// ocrModelUnavailable copy. Written before the implementation.
import 'dart:ui';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/errors/error_copy.dart';
import 'package:docukit/core/ocr/mlkit_text_recognizer.dart';
import 'package:docukit/core/ocr/ocr_labels.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;

import '../helpers/fakes.dart';

Map<String, Object?> _rect(num l, num t, num r, num b) => {'left': l, 'top': t, 'right': r, 'bottom': b};
List<Map<String, Object?>> _pts(num l, num t, num r, num b) => [
      {'x': l, 'y': t},
      {'x': r, 'y': t},
      {'x': r, 'y': b},
      {'x': l, 'y': b},
    ];

Map<String, Object?> _el(String text, num l, num t, num r, num b, {double? conf}) => {
      'text': text,
      'rect': _rect(l, t, r, b),
      'points': _pts(l, t, r, b),
      'recognizedLanguages': <String>[],
      'confidence': conf,
      'angle': 0.0,
      'symbols': <Object?>[],
    };

Map<String, Object?> _line(List<Map<String, Object?>> els) {
  final l = els.map((e) => (e['rect']! as Map)['left'] as num).reduce((a, b) => a < b ? a : b);
  final r = els.map((e) => (e['rect']! as Map)['right'] as num).reduce((a, b) => a > b ? a : b);
  final t = (els.first['rect']! as Map)['top'] as num, b = (els.first['rect']! as Map)['bottom'] as num;
  return {
    'text': els.map((e) => e['text']).join(' '),
    'rect': _rect(l, t, r, b),
    'points': _pts(l, t, r, b),
    'recognizedLanguages': <String>[],
    'confidence': 0.9,
    'angle': 0.0,
    'elements': els,
  };
}

Map<String, Object?> _block(List<Map<String, Object?>> lines) => {
      'text': lines.map((l) => l['text']).join('\n'),
      'rect': lines.first['rect'],
      'points': lines.first['points'],
      'recognizedLanguages': <String>[],
      'lines': lines,
    };

OcrPage _page() => const OcrPage(imageWidth: 1000, imageHeight: 1400, lines: [
      OcrLine(text: 'Meeting notes', box: Rect.fromLTRB(100, 100, 600, 150), corners: [
        Offset(100, 100), Offset(600, 100), Offset(600, 150), Offset(100, 150), //
      ], words: [
        OcrWord(text: 'Meeting', box: Rect.fromLTRB(100, 100, 330, 150), corners: [], confidence: 0.95),
        OcrWord(text: 'notes', box: Rect.fromLTRB(350, 100, 600, 150), corners: []),
      ]),
      OcrLine(text: 'Budget', box: Rect.fromLTRB(100, 200, 300, 250), corners: [], words: [
        OcrWord(text: 'Budget', box: Rect.fromLTRB(100, 200, 300, 250), corners: []),
      ]),
    ]);

void main() {
  group('OcrPage', () {
    test('word count and text (lines joined with \\n)', () {
      expect(_page().wordCount, 3);
      expect(_page().text, 'Meeting notes\nBudget');
      expect(const OcrPage(imageWidth: 1, imageHeight: 1, lines: []).wordCount, 0);
    });

    test('JSON round trip keeps boxes, corners and confidence (work-dir file, §4.3)', () {
      final back = OcrPage.fromJson(_page().toJson());
      expect((back.imageWidth, back.imageHeight, back.wordCount, back.text), (1000, 1400, 3, 'Meeting notes\nBudget'));
      expect(back.lines.first.box, const Rect.fromLTRB(100, 100, 600, 150));
      expect(back.lines.first.corners, hasLength(4));
      expect(back.lines.first.words.first.confidence, 0.95);
      expect(back.lines.first.words.last.confidence, isNull);
    });
  });

  group('mapping from ML Kit', () {
    test('blocks → lines in ML Kit order; elements → words; boxes and corners kept', () {
      final r = mlkit.RecognizedText.fromJson({
        'text': '',
        'blocks': [
          _block([
            _line([_el('Meeting', 100, 100, 330, 150, conf: 0.97), _el('notes', 350, 100, 600, 150)]),
            _line([_el('Budget', 100, 200, 300, 250)]),
          ]),
          _block([
            _line([_el('Q2', 700, 100, 800, 150)]),
          ]),
        ],
      });
      final page = ocrPageFrom(r, imageWidth: 1000, imageHeight: 1400);
      expect(page.lines.map((l) => l.text), ['Meeting notes', 'Budget', 'Q2']);
      expect(page.wordCount, 4);
      expect(page.lines.first.words.first.box, const Rect.fromLTRB(100, 100, 330, 150));
      expect(page.lines.first.words.first.confidence, 0.97);
      expect(page.lines.first.corners.first, const Offset(100, 100));
      expect((page.imageWidth, page.imageHeight), (1000, 1400));
    });

    test('blank lines and elements are dropped', () {
      final r = mlkit.RecognizedText.fromJson({
        'text': '',
        'blocks': [
          _block([
            _line([_el('  ', 0, 0, 10, 10)]),
            _line([_el('Hello', 0, 20, 50, 30), _el('', 60, 20, 70, 30)]),
          ]),
        ],
      });
      final page = ocrPageFrom(r, imageWidth: 100, imageHeight: 100);
      expect(page.lines.map((l) => l.words.map((w) => w.text).toList()), [
        ['Hello'],
      ]);
    });
  });

  group('scripts (ADR-045)', () {
    test('Android ships Latin + Devanagari (bundled); iOS Latin until the Xcode round', () {
      expect(bundledScripts(android: true), {OcrScript.latin, OcrScript.devanagari});
      expect(bundledScripts(android: false), {OcrScript.latin});
    });

    test('a script that isn\'t shipped → ocrModelUnavailable, with the script', () async {
      final r = MlKitTextRecognizer(scripts: const {OcrScript.latin});
      expect(await r.availableScripts(), {OcrScript.latin});
      await r.ensureModel(OcrScript.latin);
      await expectLater(
        r.ensureModel(OcrScript.korean),
        throwsA(isA<AppError>()
            .having((e) => e.code, 'code', AppErrorCode.ocrModelUnavailable)
            .having((e) => e.script, 'script', 'korean')),
      );
      await expectLater(r.recognize('/nope.jpg', OcrScript.korean),
          throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.ocrModelUnavailable)));
      await r.dispose();
    });

    test('ML Kit\'s script for each OcrScript', () {
      expect(mlkitScript(OcrScript.latin), mlkit.TextRecognitionScript.latin);
      expect(mlkitScript(OcrScript.devanagari), mlkit.TextRecognitionScript.devanagiri);
      expect(mlkitScript(OcrScript.chinese), mlkit.TextRecognitionScript.chinese);
    });
  });

  test('ocrModelUnavailable copy names the language (COPY §4)', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final c = errorCopy(l, const AppError(AppErrorCode.ocrModelUnavailable, script: 'devanagari'));
    expect(c.title, 'Text recognition isn\'t ready');
    expect(c.body,
        'The Devanagari (Hindi, Marathi…) model couldn\'t be downloaded. Connect to the internet once and try again, or choose Latin.');
    expect(ocrScriptLabel(l, OcrScript.latin), 'Latin (English, Spanish, French…)');
  });

  group('FakeTextRecognizer', () {
    test('returns the queued pages in order, records calls, and fails on request', () async {
      final f = FakeTextRecognizer()
        ..pages = [_page()]
        ..failOn = {'/b.jpg'};
      expect((await f.recognize('/a.jpg', OcrScript.latin)).wordCount, 3);
      expect((await f.recognize('/c.jpg', OcrScript.latin)).wordCount, 0, reason: 'past the queue → empty page');
      await expectLater(f.recognize('/b.jpg', OcrScript.latin), throwsA(isA<AppError>()));
      expect(f.calls, ['/a.jpg', '/c.jpg', '/b.jpg']);
      await f.dispose();
      expect(f.disposed, isTrue);
    });
  });
}
