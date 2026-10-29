import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The review folder of an OCR job (ADR-066): `page_<i>.txt` (UTF-8, reading
/// order), `thumb_<i>.jpg` and `manifest.json` with per-page counts. Written
/// in the job's work dir, then kept in `AppPaths.reviewDir(jobId)` for S31
/// until the user leaves Result/Review (ADR-047: nowhere else).
class OcrReviewPage {
  const OcrReviewPage({required this.words, required this.lowText, required this.existingText});

  final int words;

  /// < 3 recognised words (FR-OCR-11).
  final bool lowText;

  /// The PDF page already had text; it wasn't recognised (FR-OCR-07).
  final bool existingText;

  Map<String, Object?> toJson() => {'w': words, 'low': lowText, 'existing': existingText};

  factory OcrReviewPage.fromJson(Map<String, Object?> j) =>
      OcrReviewPage(words: j['w']! as int, lowText: j['low']! as bool, existingText: j['existing']! as bool);
}

class OcrReviewFiles {
  const OcrReviewFiles(this.dir, this.pages, {this.baseName = 'DocuKit'});

  final String dir;
  final List<OcrReviewPage> pages;

  /// For the `.txt` saved from Review: `<base>_text.txt` (FR-OCR-09).
  final String baseName;

  static String _manifest(String dir) => p.join(dir, 'manifest.json');
  static String textPath(String dir, int i) => p.join(dir, 'page_$i.txt');
  static String thumbPath(String dir, int i) => p.join(dir, 'thumb_$i.jpg');

  static Future<OcrReviewFiles> read(String dir) async {
    final j = jsonDecode(await File(_manifest(dir)).readAsString()) as Map;
    return OcrReviewFiles(
      dir,
      [for (final pg in j['pages'] as List) OcrReviewPage.fromJson((pg as Map).cast())],
      baseName: j['base'] as String? ?? 'DocuKit',
    );
  }

  /// One page's text, loaded only when it's shown (§4.3).
  Future<String> text(int i) async {
    final f = File(textPath(dir, i));
    return await f.exists() ? f.readAsString() : '';
  }

  String thumbnailPath(int i) => thumbPath(dir, i);
}

/// Writes the review folder page by page.
class OcrReviewWriter {
  OcrReviewWriter(this.dir) {
    Directory(dir).createSync(recursive: true);
  }

  final String dir;
  final _pages = <int, OcrReviewPage>{};

  Future<void> page(int i, String text, OcrReviewPage info) async {
    await File(OcrReviewFiles.textPath(dir, i)).writeAsString(text, flush: true);
    _pages[i] = info;
  }

  Future<String> readText(int i) => File(OcrReviewFiles.textPath(dir, i)).readAsString();

  String thumbPath(int i) => OcrReviewFiles.thumbPath(dir, i);

  Future<void> finish(int pageCount, {String baseName = 'DocuKit'}) async {
    final pages = [
      for (var i = 0; i < pageCount; i++)
        (_pages[i] ?? const OcrReviewPage(words: 0, lowText: true, existingText: false)).toJson(),
    ];
    await File(OcrReviewFiles._manifest(dir)).writeAsString(jsonEncode({'pages': pages, 'base': baseName}), flush: true);
  }
}
