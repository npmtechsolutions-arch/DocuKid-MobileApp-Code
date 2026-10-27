/// Target-size search (FEATURE_SPECS §3.5, FR-IMG-07).
library;

class EncodeAttempt {
  const EncodeAttempt({required this.quality, required this.scale, required this.bytes, required this.path});
  final int quality;
  final double scale;
  final int bytes;

  /// Where the encoder wrote this attempt.
  final String path;
}

class TargetSearchResult {
  const TargetSearchResult({required this.best, required this.targetMissed, required this.attempts});

  /// The chosen output: the largest-quality attempt that fits, or the last
  /// attempt when nothing fit.
  final EncodeAttempt best;
  final bool targetMissed;
  final int attempts;
}

typedef Encoder = Future<EncodeAttempt> Function(int quality, double scale, int attempt);

/// Binary-searches quality (then shrinks dimensions by 15%) within
/// [maxAttempts] encodes.
Future<TargetSearchResult> searchTargetSize({
  required int targetBytes,
  required Encoder encode,
  int maxAttempts = 8,
  void Function()? checkCancelled,
}) async {
  var lo = 10, hi = 95;
  var scale = 1.0;
  EncodeAttempt? best;
  EncodeAttempt? last;
  var attempts = 0;
  while (attempts < maxAttempts) {
    checkCancelled?.call();
    final q = (lo + hi) ~/ 2;
    attempts++;
    final r = await encode(q, scale, attempts);
    last = r;
    if (r.bytes <= targetBytes) {
      best = r; // later fits at the same scale always have a higher quality
      lo = q + 1;
    } else {
      hi = q - 1;
    }
    if (lo > hi) {
      if (best != null) break;
      // Even q=10 is too big → shrink the dimensions and search again.
      scale *= 0.85;
      lo = 10;
      hi = 85;
      if (scale < 0.2) break;
    }
  }
  return TargetSearchResult(best: best ?? last!, targetMissed: best == null, attempts: attempts);
}
