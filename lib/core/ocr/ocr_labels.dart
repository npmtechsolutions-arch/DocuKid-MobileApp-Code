import '../../l10n/gen/app_localizations.dart';
import 'pdf_text_reader.dart';
import 'text_recognizer.dart';

/// "Text language" names (COPY §8.3, FR-OCR-04).
String ocrScriptLabel(AppLocalizations l, OcrScript s) => switch (s) {
      OcrScript.latin => l.ocrLangLatin,
      OcrScript.devanagari => l.ocrLangDevanagari,
      OcrScript.chinese => l.ocrLangChinese,
      OcrScript.japanese => l.ocrLangJapanese,
      OcrScript.korean => l.ocrLangKorean,
    };

/// The text-detection badge on a PDF tile (S30, FR-OCR-02).
String ocrTextBadge(AppLocalizations l, PdfTextSummary s) => switch (s.state) {
      PdfTextState.none => l.ocrBadgeNoText,
      PdfTextState.all => l.ocrBadgeHasText,
      PdfTextState.partial => l.ocrBadgePartial(s.withText, s.total),
    };
