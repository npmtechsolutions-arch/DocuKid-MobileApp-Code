// T10.3 — existing-text detection (RELEASE_V1_3 §4.6, FR-OCR-02): the rule,
// the per-PDF summary, the badge text and the background provider. The real
// PDFium reader is checked in pdf_engine_host_test (OCR-07/08/09). Written
// before the implementation.
import 'dart:async';
import 'dart:ui';

import 'package:docukit/core/ocr/ocr_labels.dart';
import 'package:docukit/core/ocr/pdf_text_reader.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/features/ocr/application/text_detection.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reader implements PdfTextReader {
  _Reader(this.flags);
  final List<bool> flags;
  final calls = <String>[];
  Completer<void>? hold;

  @override
  Future<List<bool>> textPages(String path) async {
    calls.add(path);
    await hold?.future;
    return flags;
  }

  @override
  Future<String> pageText(String path, int index) async => 'page $index';
}

void main() {
  test('a page has text with ≥ 20 non-space characters (§4.6)', () {
    expect(hasEnoughText(''), isFalse);
    expect(hasEnoughText('  3  '), isFalse, reason: 'a page number alone');
    expect(hasEnoughText('a b c d e f g h i j k l m n o p q r s'), isFalse, reason: '19 letters');
    expect(hasEnoughText('a b c d e f g h i j k l m n o p q r s t'), isTrue, reason: '20 letters');
    expect(hasEnoughText('Meeting notes — 14 March\nBudget approved'), isTrue);
  });

  test('summary: none, partial with counts, all', () {
    final none = PdfTextSummary.of(const [false, false, false]);
    expect((none.state, none.withText, none.withoutText, none.total), (PdfTextState.none, 0, 3, 3));
    final partial = PdfTextSummary.of(const [true, false, false]);
    expect((partial.state, partial.withText, partial.withoutText), (PdfTextState.partial, 1, 2));
    final all = PdfTextSummary.of(const [true, true]);
    expect((all.state, all.withoutText), (PdfTextState.all, 0));
    expect(PdfTextSummary.of(const []).state, PdfTextState.none);
  });

  test('badge text (COPY §8.3)', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(ocrTextBadge(l, PdfTextSummary.of(const [false, false])), 'No text yet');
    expect(ocrTextBadge(l, PdfTextSummary.of(const [true, true])), 'Already has text');
    expect(ocrTextBadge(l, PdfTextSummary.of(const [true, false, false])), 'Text on 1 of 3 pages');
    expect(l.ocrCheckingText, 'Checking for text…');
  });

  test('provider: runs once per file in the background, then gives the flags', () async {
    final reader = _Reader(const [true, false])..hold = Completer<void>();
    final c = ProviderContainer(overrides: [pdfTextReaderProvider.overrideWithValue(reader)]);
    addTearDown(c.dispose);
    final sub = c.listen(pdfTextPagesProvider('/in/a.pdf'), (_, _) {});
    expect(c.read(pdfTextPagesProvider('/in/a.pdf')).isLoading, isTrue, reason: '"Checking for text…"');
    reader.hold!.complete();
    expect(await c.read(pdfTextPagesProvider('/in/a.pdf').future), [true, false]);
    c.read(pdfTextPagesProvider('/in/a.pdf'));
    expect(reader.calls, ['/in/a.pdf']);
    sub.close();
  });
}
