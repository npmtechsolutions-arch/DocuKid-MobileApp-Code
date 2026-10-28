import '../../core/pdf/page_ranges.dart';
import '../../l10n/gen/app_localizations.dart';

/// Inline message for a range error (§4.6, COPY range_err_*).
String rangeErrorText(AppLocalizations l, PageRangeError e, int total) => switch (e.kind) {
      PageRangeErrorKind.empty => l.rangeErrEmpty,
      PageRangeErrorKind.zero => l.rangeErrZero,
      PageRangeErrorKind.pageMissing => l.rangeErrPage(e.page!, total),
      PageRangeErrorKind.reversed => l.rangeErrReversed,
      PageRangeErrorKind.chars => l.rangeErrChars,
      PageRangeErrorKind.tooMany => l.splEachCap,
    };
