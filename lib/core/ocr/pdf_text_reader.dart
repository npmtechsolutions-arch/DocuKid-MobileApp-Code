/// Reads the text a PDF already has (RELEASE_V1_3 §4.6): which pages need
/// recognising, and the existing text for Review / `.txt` without OCR.
/// `PdfrxTextReader` in the app; fakes in tests.
abstract interface class PdfTextReader {
  /// One flag per page: true when the page already has text.
  Future<List<bool>> textPages(String path);

  /// The existing text of page [index] (0-based).
  Future<String> pageText(String path, int index);
}

/// A page counts as having text with at least this many non-space characters
/// (a page number alone doesn't).
const minPageTextChars = 20;

final _space = RegExp(r'\s');

bool hasEnoughText(String text) => text.replaceAll(_space, '').length >= minPageTextChars;

enum PdfTextState { none, partial, all }

/// What the S30 badge and banners say about one PDF (FR-OCR-02).
class PdfTextSummary {
  const PdfTextSummary._(this.withText, this.total);

  factory PdfTextSummary.of(List<bool> textPages) => PdfTextSummary._(textPages.where((t) => t).length, textPages.length);

  final int withText, total;

  int get withoutText => total - withText;

  PdfTextState get state => withText == 0
      ? PdfTextState.none
      : withText == total
          ? PdfTextState.all
          : PdfTextState.partial;
}
