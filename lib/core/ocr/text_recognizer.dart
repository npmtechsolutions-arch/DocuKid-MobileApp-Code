import 'dart:ui';

/// On-device text recognition (RELEASE_V1_3 §4.2): ML Kit on both platforms
/// (`MlKitTextRecognizer`). Tests use `FakeTextRecognizer`. Recognised text
/// is never logged and never stored outside the job's work dir and the
/// outputs the user chose (ADR-047).
abstract interface class TextRecognizer {
  /// Scripts this build can recognise (ADR-045: bundled models).
  Future<Set<OcrScript>> availableScripts();

  /// Makes sure [script] can run. Throws `AppError(ocrModelUnavailable)`.
  Future<void> ensureModel(OcrScript script);

  /// Recognises one **already oriented** image (EXIF applied, orientation 1),
  /// so the boxes are in its pixels on both platforms. Holds no more than one
  /// decoded image.
  Future<OcrPage> recognize(String imagePath, OcrScript script);

  /// Closes the recognisers opened for this job.
  Future<void> dispose();
}

/// ML Kit recognises one script per recogniser (FR-OCR-04).
enum OcrScript { latin, devanagari, chinese, japanese, korean }

class OcrWord {
  const OcrWord({required this.text, required this.box, required this.corners, this.confidence});

  final String text;

  /// Pixel coordinates in the oriented image.
  final Rect box;

  /// The 4 corner points (skewed text), or empty when unknown.
  final List<Offset> corners;

  /// 0–1 when the platform reports it (Android does; FR-OCR-18).
  final double? confidence;

  Map<String, Object?> toJson() =>
      {'t': text, 'b': _rectJson(box), 'c': _cornersJson(corners), if (confidence != null) 'p': confidence};

  factory OcrWord.fromJson(Map<String, Object?> j) => OcrWord(
        text: j['t']! as String,
        box: _rectFrom(j['b']),
        corners: _cornersFrom(j['c']),
        confidence: (j['p'] as num?)?.toDouble(),
      );
}

class OcrLine {
  const OcrLine({required this.text, required this.box, required this.corners, required this.words});

  final String text;
  final Rect box;
  final List<Offset> corners;
  final List<OcrWord> words;

  Map<String, Object?> toJson() =>
      {'t': text, 'b': _rectJson(box), 'c': _cornersJson(corners), 'w': [for (final w in words) w.toJson()]};

  factory OcrLine.fromJson(Map<String, Object?> j) => OcrLine(
        text: j['t']! as String,
        box: _rectFrom(j['b']),
        corners: _cornersFrom(j['c']),
        words: [for (final w in j['w']! as List) OcrWord.fromJson((w as Map).cast<String, Object?>())],
      );
}

class OcrPage {
  const OcrPage({required this.imageWidth, required this.imageHeight, required this.lines});

  /// The oriented pixel size that was recognised.
  final int imageWidth, imageHeight;

  /// In reading order once sorted (§4.5); as recognised before that.
  final List<OcrLine> lines;

  int get wordCount => lines.fold(0, (n, l) => n + l.words.length);
  String get text => lines.map((l) => l.text).join('\n');

  /// For the per-page file in the job's work dir (§4.3), never for logs.
  Map<String, Object?> toJson() => {'w': imageWidth, 'h': imageHeight, 'l': [for (final l in lines) l.toJson()]};

  factory OcrPage.fromJson(Map<String, Object?> j) => OcrPage(
        imageWidth: j['w']! as int,
        imageHeight: j['h']! as int,
        lines: [for (final l in j['l']! as List) OcrLine.fromJson((l as Map).cast<String, Object?>())],
      );
}

List<double> _rectJson(Rect r) => [r.left, r.top, r.right, r.bottom];
Rect _rectFrom(Object? j) {
  final v = [for (final n in j! as List) (n as num).toDouble()];
  return Rect.fromLTRB(v[0], v[1], v[2], v[3]);
}

List<double> _cornersJson(List<Offset> c) => [for (final o in c) ...[o.dx, o.dy]];
List<Offset> _cornersFrom(Object? j) {
  final v = [for (final n in j! as List) (n as num).toDouble()];
  return [for (var i = 0; i + 1 < v.length; i += 2) Offset(v[i], v[i + 1])];
}
