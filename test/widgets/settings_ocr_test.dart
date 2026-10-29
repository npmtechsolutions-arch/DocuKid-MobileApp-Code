// T10.9 — Settings "Text recognition language" (RELEASE_V1_3 §5): the shipped
// scripts only, and the choice is the default S30 and S29 start from.
import 'dart:async';

import 'package:docukit/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('Scan & text → Text recognition language: Latin by default, Devanagari picked and stored', (tester) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final row = find.text('Text recognition language');
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Latin (English, Spanish, French…)'), findsOneWidget);
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // the sheet slides in
    expect(find.text('Korean'), findsNothing, reason: 'not shipped (ADR-045)');
    await tester.tap(find.text('Devanagari (Hindi, Marathi…)').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // the sheet closes
    expect(h.store.get('ocr_script'), 'devanagari');
    expect(find.text('Devanagari (Hindi, Marathi…)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
