import 'dart:convert';
import 'dart:io';

import 'ocr_layout.dart';
import 'text_recognizer.dart';

/// The `.txt` output (FR-OCR-09): UTF-8, LF only. Every page starts with
/// `--- Page {n} ---` and a blank line, so pages are separated by
/// `\n\n--- Page {n} ---\n\n`. The marker is part of the file format (like
/// output file names), not UI copy, so it isn't translated.
String pageMarker(int n) => '--- Page $n ---';

String _clean(String text) => text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trimRight();

String _chunk(int index, String text) => '${index == 0 ? '' : '\n\n'}${pageMarker(index + 1)}\n\n${_clean(text)}';

String formatOcrTxt(List<String> pages) =>
    pages.isEmpty ? '' : '${[for (final (i, t) in pages.indexed) _chunk(i, t)].join()}\n';

/// Writes the `.txt` page by page, reading each page's text only when it's
/// written (the text stays in the job's work dir until then, §4.3).
Future<void> writeOcrTxt(String path, int pageCount, Future<String> Function(int index) pageText) async {
  final sink = File(path).openWrite(encoding: utf8);
  try {
    for (var i = 0; i < pageCount; i++) {
      sink.write(_chunk(i, await pageText(i)));
    }
    if (pageCount > 0) sink.write('\n');
    await sink.flush();
  } finally {
    await sink.close();
  }
}

/// Copy all (S31): pages joined by a blank line, without markers.
String joinForCopy(List<String> pages) => [
      for (final t in pages)
        if (_clean(t).trim().isNotEmpty) _clean(t).trim(),
    ].join('\n\n');

/// A page's text in reading order (§4.5).
String ocrPageText(OcrPage page) => sortedPage(page).text;

/// §4.10: the file exists, is valid UTF-8, and has the markers for pages
/// 1…[pageCount] in order and no more.
Future<bool> isValidOcrTxt(String path, {required int pageCount}) async {
  final String text;
  try {
    text = utf8.decode(await File(path).readAsBytes());
  } on FileSystemException {
    return false;
  } on FormatException {
    return false;
  }
  if (pageCount == 0) return text.isEmpty;
  if (!text.startsWith('${pageMarker(1)}\n\n')) return false;
  var at = 0;
  for (var n = 2; n <= pageCount; n++) {
    at = text.indexOf('\n\n${pageMarker(n)}\n\n', at);
    if (at < 0) return false;
  }
  return !text.contains('\n\n${pageMarker(pageCount + 1)}\n\n', at);
}
