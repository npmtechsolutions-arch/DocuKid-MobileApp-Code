// S10 labels for the OCR steps (RELEASE_V1_3 §3.2): "Recognising page n of N"
// carries its own count; the other steps keep the "n of N pages" line.
import 'dart:ui';

import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/features/job/job_screen.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l;
  setUpAll(() async => l = await AppLocalizations.delegate.load(const Locale('en')));

  test('OCR step keys have their own labels', () {
    expect(stepLabel(l, 'stepOcrPreparing'), 'Getting text recognition ready…');
    expect(stepLabel(l, 'stepOcrBuilding'), 'Building searchable PDF…');
  });

  test('"Recognising page 3 of 12": one line, no separate count; the bar still moves', () {
    final d = describeProgress(l, stepLabel(l, 'stepOcrPage'), const Determinate(2, 12, 'stepOcrPage'));
    expect((d.step, d.count, d.fraction), ('Recognising page 3 of 12', null, 2 / 12));
  });

  test('other steps keep the count line; indeterminate has neither', () {
    final d = describeProgress(l, 'Merging…', const Determinate(0, 4, 'stepMerging'));
    expect((d.step, d.count), ('Merging…', '1 of 4 pages'));
    expect(describeProgress(l, 'Building searchable PDF…', const Indeterminate('stepOcrBuilding')),
        (step: 'Building searchable PDF…', count: null, fraction: null));
  });
}
