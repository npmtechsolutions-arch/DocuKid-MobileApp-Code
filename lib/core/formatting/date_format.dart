import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';

enum DayBucket { today, yesterday, older }

DayBucket dayBucket(DateTime t, DateTime now) {
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff <= 0) return DayBucket.today;
  if (diff == 1) return DayBucket.yesterday;
  return DayBucket.older;
}

/// COPY §6: today/yesterday → time only; otherwise `d MMM yyyy`.
String formatWhen(DateTime t, DateTime now, {String? locale}) {
  if (dayBucket(t, now) == DayBucket.older) return DateFormat('d MMM yyyy', locale).format(t);
  return DateFormat.jm(locale).format(t);
}

String formatDate(DateTime t, {String? locale}) => DateFormat('d MMM yyyy', locale).format(t);

String formatDateTime(DateTime t, {String? locale}) =>
    '${DateFormat('d MMM yyyy', locale).format(t)}, ${DateFormat.jm(locale).format(t)}';

/// COPY §6 durations.
String formatDuration(AppLocalizations l, Duration d, {String? locale}) {
  if (d.inMilliseconds < 1000) return l.durUnderSecond;
  if (d.inSeconds < 60) {
    final s = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1)
        .format(d.inMilliseconds / 1000);
    return l.durSeconds(s);
  }
  return l.durMinutes(d.inMinutes, d.inSeconds % 60);
}
