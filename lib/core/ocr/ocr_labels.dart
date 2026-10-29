import '../../l10n/gen/app_localizations.dart';
import 'text_recognizer.dart';

/// "Text language" names (COPY §8.3, FR-OCR-04).
String ocrScriptLabel(AppLocalizations l, OcrScript s) => switch (s) {
      OcrScript.latin => l.ocrLangLatin,
      OcrScript.devanagari => l.ocrLangDevanagari,
      OcrScript.chinese => l.ocrLangChinese,
      OcrScript.japanese => l.ocrLangJapanese,
      OcrScript.korean => l.ocrLangKorean,
    };
