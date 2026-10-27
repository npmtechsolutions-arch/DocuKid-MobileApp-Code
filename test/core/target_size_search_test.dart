import 'package:docukit/core/image/target_size_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake encoder: bytes grow linearly with quality and with scale².
Encoder fake(int Function(int q, double scale) size, List<(int, double)> log) =>
    (q, s, attempt) async {
      log.add((q, s));
      return EncodeAttempt(quality: q, scale: s, bytes: size(q, s), path: 'a$attempt');
    };

void main() {
  test('finds the highest quality that fits within 8 attempts', () async {
    final log = <(int, double)>[];
    final r = await searchTargetSize(targetBytes: 50000, encode: fake((q, s) => q * 1000, log));
    expect(r.targetMissed, isFalse);
    expect(r.best.bytes, lessThanOrEqualTo(50000));
    expect(r.best.quality, 50);
    expect(r.attempts, lessThanOrEqualTo(8));
  });

  test('shrinks dimensions when even q=10 is too big', () async {
    final log = <(int, double)>[];
    final r = await searchTargetSize(
      targetBytes: 20000,
      encode: fake((q, s) => (q * 1000 + 30000 * s * s).round(), log),
    );
    expect(log.any((e) => e.$2 < 1.0), isTrue, reason: 'scale must drop below 1');
    expect(r.attempts, lessThanOrEqualTo(8));
    if (!r.targetMissed) expect(r.best.bytes, lessThanOrEqualTo(20000));
  });

  test('target missed returns the last attempt with the flag', () async {
    final log = <(int, double)>[];
    final r = await searchTargetSize(targetBytes: 10, encode: fake((q, s) => 1000000, log));
    expect(r.targetMissed, isTrue);
    expect(r.attempts, 8);
    expect(r.best.path, 'a8');
  });

  test('never exceeds maxAttempts', () async {
    final log = <(int, double)>[];
    await searchTargetSize(targetBytes: 55555, encode: fake((q, s) => (q * 1111 * s).round(), log), maxAttempts: 8);
    expect(log.length, lessThanOrEqualTo(8));
  });

  test('cancellation is checked before each attempt', () async {
    var calls = 0;
    expect(
      () => searchTargetSize(
        targetBytes: 1,
        encode: (q, s, a) async => EncodeAttempt(quality: q, scale: s, bytes: 999, path: 'x'),
        checkCancelled: () {
          if (++calls > 2) throw StateError('cancelled');
        },
      ),
      throwsStateError,
    );
  });
}
