// T10.2 — the `.txt` output (FR-OCR-09), Copy all (S31) and the `.txt`
// check of §4.10. Written before the implementation.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:docukit/core/files/file_naming.dart';
import 'package:docukit/core/ocr/ocr_text_file.dart';
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ocr_txt'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('every page starts with its marker; pages are separated by \\n\\n--- Page n ---\\n\\n', () {
    expect(formatOcrTxt(['Hello', 'World', 'End']),
        '--- Page 1 ---\n\nHello\n\n--- Page 2 ---\n\nWorld\n\n--- Page 3 ---\n\nEnd\n');
  });

  test('LF only; trailing blanks trimmed; an empty page keeps its marker', () {
    expect(formatOcrTxt(['a\r\nb\rc  \n\n', '', 'z']), '--- Page 1 ---\n\na\nb\nc\n\n--- Page 2 ---\n\n\n\n--- Page 3 ---\n\nz\n');
    expect(formatOcrTxt(const []), '');
  });

  test('Copy all joins the pages with a blank line, no markers, empty pages skipped', () {
    expect(joinForCopy(['One\r\ntwo ', '', '  ', 'Three']), 'One\ntwo\n\nThree');
    expect(joinForCopy(const []), '');
  });

  test('page text is in reading order (§4.5)', () {
    OcrLine l(String t, double top) =>
        OcrLine(text: t, box: Rect.fromLTRB(0, top, 100, top + 40), corners: const [], words: [
          OcrWord(text: t, box: Rect.fromLTRB(0, top, 100, top + 40), corners: const []),
        ]);
    expect(ocrPageText(OcrPage(imageWidth: 1, imageHeight: 1, lines: [l('second', 200), l('first', 100)])),
        'first\nsecond');
  });

  test('written as UTF-8 (Devanagari, accents), page by page', () async {
    final path = p.join(dir.path, 'out.txt');
    final pages = ['Café über', 'भारत एक विशाल देश है।'];
    await writeOcrTxt(path, pages.length, (i) async => pages[i]);
    final bytes = File(path).readAsBytesSync();
    expect(utf8.decode(bytes), formatOcrTxt(pages));
    expect(bytes, isNot(contains(13)), reason: 'no CR');
    expect(await isValidOcrTxt(path, pageCount: 2), isTrue);
  });

  test('validation: wrong marker count, out of order, or not UTF-8 → invalid', () async {
    Future<bool> check(List<int> bytes, int n) async {
      final f = File(p.join(dir.path, 'v.txt'))..writeAsBytesSync(bytes);
      return isValidOcrTxt(f.path, pageCount: n);
    }

    expect(await check(utf8.encode(formatOcrTxt(['a', 'b'])), 3), isFalse);
    expect(await check(utf8.encode('--- Page 2 ---\n\na\n\n--- Page 1 ---\n\nb\n'), 2), isFalse);
    expect(await check([0xFF, 0xFE, 0x41], 1), isFalse);
    expect(await isValidOcrTxt(p.join(dir.path, 'missing.txt'), pageCount: 1), isFalse);
    // A recognised line that looks like a marker is inside a page, not a page.
    expect(await check(utf8.encode(formatOcrTxt(['x\n--- Page 9 ---', 'y'])), 2), isTrue);
  });

  test('pagesFromTxt reverses formatOcrTxt (Copy text from a .txt, FR-OCR-16)', () {
    final pages = ['One\nline two', '', 'Three'];
    expect(pagesFromTxt(formatOcrTxt(pages)), pages);
    expect(pagesFromTxt(''), isEmpty);
    expect(pagesFromTxt(formatOcrTxt(['x\n--- Page 9 ---\ny'])), ['x\n--- Page 9 ---\ny'],
        reason: 'a marker-like line inside a page stays (no blank line before it)');
  });

  test('file name: <base>_text.txt (FR-OCR-09)', () {
    expect(ocrTxtName('scanned_notes'), 'scanned_notes_text.txt');
  });
}
