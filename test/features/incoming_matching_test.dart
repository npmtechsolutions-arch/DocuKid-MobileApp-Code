// RELEASE_V1_1 §4.8 incoming → tool matching (FR-SHR-05…07), written before
// the implementation.
import 'package:docukit/features/incoming/incoming_matching.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ToolId> tools(IncomingSection s) => [for (final o in s.options) o.tool];

  test('1 image → Compress, Resize, Convert, Images to PDF, Print (1.6)', () {
    final r = matchIncoming(images: 1, pdfs: 0);
    expect(r.single.kind, IncomingKind.images);
    expect(tools(r.single),
        [ToolId.imageCompress, ToolId.imageResize, ToolId.imageConvert, ToolId.imageToPdf, ToolId.print]);
  });

  test('2–50 images → the same tools (batch)', () {
    expect(tools(matchIncoming(images: 2, pdfs: 0).single), tools(matchIncoming(images: 50, pdfs: 0).single));
  });

  test('1 PDF → Organize, Split, PDF to Images, Reduce, Merge (needs one more), Print (1.6)', () {
    final s = matchIncoming(images: 0, pdfs: 1).single;
    expect(tools(s),
        [ToolId.pdfOrganize, ToolId.pdfSplit, ToolId.pdfToImages, ToolId.pdfCompress, ToolId.pdfMerge, ToolId.print]);
    expect(s.options.firstWhere((o) => o.tool == ToolId.pdfMerge).needsMore, isTrue);
    expect(s.options.where((o) => o.needsMore), hasLength(1));
  });

  test('2–20 PDFs → Merge only', () {
    expect(tools(matchIncoming(images: 0, pdfs: 2).single), [ToolId.pdfMerge]);
    expect(tools(matchIncoming(images: 0, pdfs: 20).single), [ToolId.pdfMerge]);
    expect(matchIncoming(images: 0, pdfs: 2).single.options.single.needsMore, isFalse);
  });

  test('images + PDFs → two sections, images first (FR-SHR-07)', () {
    final r = matchIncoming(images: 3, pdfs: 1);
    expect(r.map((s) => s.kind), [IncomingKind.images, IncomingKind.pdfs]);
    expect(r.map((s) => s.count), [3, 1]);
  });

  test('nothing supported → no sections (the screen shows the error card)', () {
    expect(matchIncoming(images: 0, pdfs: 0), isEmpty);
  });

  test('limits: keep the first 50 images and 20 PDFs (FR-SHR-06)', () {
    expect(incomingLimits, (images: 50, pdfs: 20));
  });

  test('every offered tool exists in the catalogue and takes that kind of input', () {
    for (final (i, p) in [(1, 0), (5, 0), (0, 1), (0, 3), (2, 2)]) {
      for (final s in matchIncoming(images: i, pdfs: p)) {
        for (final o in s.options) {
          final kind = toolById(o.tool).inputKind;
          // imagesOrPdf (Print) takes either kind.
          if (kind == InputKind.imagesOrPdf) continue;
          final wantsImages = kind == InputKind.images || kind == InputKind.singleImage;
          expect(wantsImages, s.kind == IncomingKind.images, reason: '${o.tool}');
        }
      }
    }
  });
}
