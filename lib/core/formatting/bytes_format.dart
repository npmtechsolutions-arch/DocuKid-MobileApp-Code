import 'package:intl/intl.dart';

/// Size formatting (COPY §6): base-1024, KB/MB/GB, 1 decimal below 10,
/// none from 10 upwards, < 1 KB → "n B".
class FormattedSize {
  const FormattedSize(this.value, this.unit);

  /// Locale-formatted number, e.g. "3.2".
  final String value;

  /// One of B, KB, MB, GB.
  final String unit;

  @override
  String toString() => '$value $unit';
}

FormattedSize splitBytes(int bytes, {String? locale}) {
  if (bytes < 1024) {
    return FormattedSize(NumberFormat.decimalPattern(locale).format(bytes < 0 ? 0 : bytes), 'B');
  }
  const units = ['KB', 'MB', 'GB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  // Round first so 9.96 KB doesn't print as "10.0".
  final oneDecimal = (v * 10).round() / 10;
  final useDecimal = oneDecimal < 10;
  final f = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: useDecimal ? 1 : 0);
  return FormattedSize(f.format(useDecimal ? oneDecimal : v.roundToDouble()), units[i]);
}

String formatBytes(int bytes, {String? locale}) => splitBytes(bytes, locale: locale).toString();

/// `round((after − before) / before × 100)` (COPY §6).
int percentChange(int before, int after) {
  if (before <= 0) return 0;
  return ((after - before) / before * 100).round();
}
