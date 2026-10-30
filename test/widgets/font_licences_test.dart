// Bundled fonts must show their OFL on the licences page: Plus Jakarta Sans
// (headings, ADR-032), the Noto fonts of the OCR text layer (ADR-046) and the
// typed-signature fonts (ADR-067).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('the licences page lists every bundled font with its OFL', (tester) async {
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump();
    final entries = (await tester.runAsync(() => LicenseRegistry.licenses.toList()))!;
    String? textOf(String package) {
      for (final e in entries) {
        if (e.packages.contains(package)) return e.paragraphs.map((p) => p.text).join('\n');
      }
      return null;
    }

    for (final font in ['Plus Jakarta Sans', 'Noto Sans', 'Noto Sans Devanagari', 'Dancing Script', 'Sacramento', 'Mr Dafoe']) {
      expect(textOf(font), contains('SIL Open Font License'), reason: font);
    }
    expect(textOf('Noto Sans'), contains('The Noto Project Authors'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
