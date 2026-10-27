import 'package:docukit/app/theme/theme.dart';
import 'package:docukit/features/job/job_visuals.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> ring(WidgetTester tester, int before, int after) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: SavingsRing(before: before, after: after))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('smaller output: −87% smaller', (tester) async {
    await ring(tester, 1000, 130);
    expect(find.text('−87%'), findsOneWidget);
    expect(find.text('smaller'), findsOneWidget);
  });

  testWidgets('bigger output: +132% larger, never "0% smaller"', (tester) async {
    await ring(tester, 10000, 23200);
    expect(find.text('+132%'), findsOneWidget);
    expect(find.text('larger'), findsOneWidget);
    expect(find.text('smaller'), findsNothing);
  });
}
