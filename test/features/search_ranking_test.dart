import 'package:docukit/features/search/search_ranking.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l;
  setUpAll(() async => l = await AppLocalizations.delegate.load(const Locale('en')));

  ToolId? top(String q) {
    final r = searchTools(q, (id) => toolById(id).title(l));
    return r.isEmpty ? null : r.first.tool;
  }

  // FEATURE_SPECS §1.2 test cases.
  test('"reduce photo size" → Image Compressor', () => expect(top('reduce photo size'), ToolId.imageCompress));
  test('"compress pdf" → Reduce PDF Size (not the image tool)', () => expect(top('compress pdf'), ToolId.pdfCompress));
  test('"passport" → Image Resizer', () => expect(top('passport'), ToolId.imageResize));
  test('"jpg to pdf" → Images to PDF', () => expect(top('jpg to pdf'), ToolId.imageToPdf));
  test('"rotate" → Organize Pages', () => expect(top('rotate'), ToolId.pdfOrganize));
  test('"COMBINE" → Merge PDFs (case-insensitive)', () => expect(top('COMBINE'), ToolId.pdfMerge));
  test('"xyz" → nothing', () => expect(top('xyz'), isNull));
  test('empty query → nothing', () => expect(top('   '), isNull));
  test('accent-insensitive', () => expect(top('cömbine'), ToolId.pdfMerge));
  test('"make picture smaller" → compressor', () => expect(top('make picture smaller'), ToolId.imageCompress));
  test('"kb" → compressor', () => expect(top('kb'), ToolId.imageCompress));
  test('"join pdf" → merger', () => expect(top('join pdf'), ToolId.pdfMerge));

  // FR-HOME-08 (RELEASE_V1_1 §2.9 / §4.10): the 1.1 tools and batch synonyms.
  test('"heic to jpg" → Convert Image', () => expect(top('heic to jpg'), ToolId.imageConvert));
  test('"split" → Split PDF', () => expect(top('split'), ToolId.pdfSplit));
  test('"pdf to jpg" → PDF to Images', () => expect(top('pdf to jpg'), ToolId.pdfToImages));
  test('"batch" → Image Compressor', () => expect(top('batch'), ToolId.imageCompress));
  test('"many photos" → Image Compressor', () => expect(top('many photos'), ToolId.imageCompress));
  test('"png to jpg" → Convert Image', () => expect(top('png to jpg'), ToolId.imageConvert));
  test('"pdf to png" → PDF to Images', () => expect(top('pdf to png'), ToolId.pdfToImages));
  test('"extract pages" → Split PDF', () => expect(top('extract pages'), ToolId.pdfSplit));

  // FR-SCN-25 (RELEASE_V1_2): Scan Document.
  for (final q in ['scan', 'scanner', 'camera', 'photo of document', 'paper', 'receipt', 'digitize', 'capture',
      'document camera', 'cam scanner']) {
    test('"$q" → Scan Document', () => expect(top(q), ToolId.scanDocument));
  }
  test('"jpg to pdf" still → Images to PDF', () => expect(top('jpg to pdf'), ToolId.imageToPdf));

  test('matched phrase is reported', () {
    final r = searchTools('reduce photo size', (id) => toolById(id).title(l));
    expect(r.first.matchedPhrase, 'reduce photo size');
  });

  test('normalisation', () {
    expect(normalizeQuery('  Héllo,   WORLD! '), 'hello world');
  });
}
