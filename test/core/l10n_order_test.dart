import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: gen-l10n sorts *inferred* placeholders alphabetically, which
/// silently swapped "before → after" style arguments. Every multi-placeholder
/// string now declares its order in the ARB; these pin it.
void main() {
  late AppLocalizations l;
  setUpAll(() async => l = await AppLocalizations.delegate.load(const Locale('en')));

  test('before → after order', () {
    expect(l.histSizes('4.5 KB', '21 KB'), '4.5 KB → 21 KB');
    expect(l.resultA11ySummary('3 megabytes', '400 kilobytes'), 'Done. 3 megabytes to 400 kilobytes.');
  });

  test('version (build)', () => expect(l.setVersion('1.0.0', '7'), 'Version 1.0.0 (7)'));

  test('feedback body', () => expect(l.feedbackBody('1.0.0 (7)', 'android 14'), startsWith('App version: 1.0.0 (7)\nDevice OS: android 14')));

  test('target missed', () {
    expect(l.resultTargetMissed('112 KB', '100 KB'), 'Closest we could get: 112 KB (target 100 KB). Try a smaller max size.');
  });

  test('plural + extra placeholders', () {
    expect(l.histFilesPages(3, 47, '5.3 MB'), '3 files · 47 pages · 5.3 MB');
    expect(l.redAnalysis(36, 52, 'Image-heavy'), '36 pages · 52 images · Image-heavy');
  });
}
