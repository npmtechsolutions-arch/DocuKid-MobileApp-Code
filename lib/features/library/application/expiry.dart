import '../../../data/library/library_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'reminder_scheduler.dart';

/// Whole days from [now]'s date to [expiry] (negative = expired).
int daysUntil(DateTime expiry, DateTime now) =>
    DateTime(expiry.year, expiry.month, expiry.day).difference(DateTime(now.year, now.month, now.day)).inDays;

/// FR-REM-04: the "Expiring soon" window and the Home card's.
const expiringSoonDays = 60, homeExpiringDays = 30;

/// "Expires in 12 days" / "Expired 3 days ago".
String expiryLabel(AppLocalizations l, DateTime expiry, DateTime now) {
  final d = daysUntil(expiry, now);
  return d < 0 ? l.libExpiredAgo(-d) : l.libExpiresIn(d);
}

bool isExpired(LibraryDoc d, DateTime now) => d.expiryDate != null && daysUntil(d.expiryDate!, now) < 0;

/// "30 days before, 7 days before, On the day" in S44's order.
String offsetsLabel(AppLocalizations l, List<int> offsets) => [
      for (final o in reminderOffsets)
        if (offsets.contains(o)) offsetLabel(l, o),
    ].join(', ');

String offsetLabel(AppLocalizations l, int o) => switch (o) {
      30 => l.rmdD30,
      7 => l.rmdD7,
      1 => l.rmdD1,
      _ => l.rmdD0,
    };
