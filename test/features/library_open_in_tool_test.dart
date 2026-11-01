// T12.4 — "Open in tool…" (RELEASE_V1_5 FR-LIB-10/11): only tools that take
// the selection are offered.
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/features/library/application/open_in_tool.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryDoc doc(String mime, [int i = 0]) => LibraryDoc(
      id: '$i',
      folderId: null,
      name: 'd$i',
      relPath: 'library/$i/d',
      mime: mime,
      sizeBytes: 1,
      sha256: '$i',
      source: DocSource.import,
      addedAt: DateTime(2026),
    );

List<LibraryDoc> many(String mime, int n) => [for (var i = 0; i < n; i++) doc(mime, i)];

void main() {
  const pdf = 'application/pdf', jpg = 'image/jpeg', png = 'image/png';

  test('one PDF: the single-PDF tools, OCR, Merge (add more there), Print (1.6)', () {
    expect(toolsForLibrary([doc(pdf)]), [
      ToolId.pdfCompress,
      ToolId.pdfOrganize,
      ToolId.pdfSplit,
      ToolId.pdfToImages,
      ToolId.pdfMerge,
      ToolId.ocr,
      ToolId.pdfSign,
      ToolId.pdfWatermark,
      ToolId.pdfProtect,
      ToolId.pdfUnlock,
      ToolId.print,
    ]);
  });

  test('2–20 PDFs → Merge; more than Merge takes → nothing', () {
    expect(toolsForLibrary(many(pdf, 2)), [ToolId.pdfMerge]);
    expect(toolsForLibrary(many(pdf, 20)), [ToolId.pdfMerge]);
    expect(toolsForLibrary(many(pdf, 21)), isEmpty);
  });

  test('images (mixed formats are fine) → the image tools, OCR, Print; limited by each tool\'s maximum', () {
    final tools = [ToolId.imageCompress, ToolId.imageResize, ToolId.imageConvert, ToolId.imageToPdf, ToolId.ocr, ToolId.print];
    expect(toolsForLibrary([doc(jpg), doc(png, 1)]), tools);
    expect(toolsForLibrary(many(jpg, 50)), tools);
    expect(toolsForLibrary(many(jpg, 51)), [ToolId.imageToPdf, ToolId.print], reason: 'only Images to PDF and Print take up to 100');
    expect(toolsForLibrary(many(jpg, 101)), isEmpty);
  });

  test('PDFs and images together, or nothing → no tool', () {
    expect(toolsForLibrary([doc(pdf), doc(jpg, 1)]), isEmpty);
    expect(toolsForLibrary(const []), isEmpty);
    expect(isMixedSelection([doc(pdf), doc(jpg, 1)]), isTrue);
    expect(isMixedSelection([doc(pdf), doc(pdf, 1)]), isFalse);
  });
}
