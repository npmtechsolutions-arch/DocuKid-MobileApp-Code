// S17 "What DocuKit can access" (RELEASE_V1_2 §6, T9.8): the Camera row.
import 'dart:async';

import 'package:docukit/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('Privacy & About lists Photos, Files, Photos (add only) and Camera', (tester) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/settings/privacy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text("Camera, only while you're scanning"), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Only the photos you pick'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
