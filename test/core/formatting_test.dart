import 'package:docukit/core/formatting/bytes_format.dart';
import 'package:docukit/core/formatting/date_format.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('bytes (base-1024)', () {
    test('under 1 KB', () => expect(formatBytes(999, locale: 'en'), '999 B'));
    test('one decimal below 10', () => expect(formatBytes((3.2 * 1024 * 1024).round(), locale: 'en'), '3.2 MB'));
    test('no decimal from 10 up', () => expect(formatBytes(410 * 1024, locale: 'en'), '410 KB'));
    test('18 MB', () => expect(formatBytes(18 * 1024 * 1024, locale: 'en'), '18 MB'));
    test('9.96 KB rounds to 10 KB, not 10.0', () => expect(formatBytes((9.96 * 1024).round(), locale: 'en'), '10 KB'));
    test('GB', () => expect(formatBytes(3 * 1024 * 1024 * 1024, locale: 'en'), '3.0 GB'));
    test('split unit', () => expect(splitBytes(2048, locale: 'en').unit, 'KB'));
  });

  test('percent change', () {
    expect(percentChange(3200, 410), -87);
    expect(percentChange(100, 120), 20);
    expect(percentChange(0, 5), 0);
  });

  group('dates', () {
    final now = DateTime(2026, 10, 22, 15);
    test('buckets', () {
      expect(dayBucket(DateTime(2026, 10, 22, 1), now), DayBucket.today);
      expect(dayBucket(DateTime(2026, 10, 21, 23), now), DayBucket.yesterday);
      expect(dayBucket(DateTime(2026, 10, 1), now), DayBucket.older);
    });
    test('older dates use d MMM yyyy', () {
      expect(formatWhen(DateTime(2026, 10, 1), now, locale: 'en'), '1 Oct 2026');
    });
  });

  test('durations', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(formatDuration(l, const Duration(milliseconds: 300), locale: 'en'), 'under a second');
    expect(formatDuration(l, const Duration(milliseconds: 2400), locale: 'en'), '2.4 s');
    expect(formatDuration(l, const Duration(seconds: 75), locale: 'en'), '1 min 15 s');
  });
}
