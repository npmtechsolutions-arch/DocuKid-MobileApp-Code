// R16: when the system picker returns nothing (or throws) because the file
// couldn't be copied, low free space must be reported instead of silence.
import 'dart:async';

import 'package:docukit/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  const mb = 1024 * 1024;

  Future<TestHarness> openMerge(WidgetTester tester, {required int free, bool throws = false}) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await tester.runAsync(() => TestHarness.create());
    h!.device.free = free;
    h.gateway.throwOnPick = throws;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 200));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-merge'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Choose PDFs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('empty pick with < 300 MB free → "Not enough free space", amount needed', (tester) async {
    await openMerge(tester, free: 120 * mb);
    expect(find.textContaining('Not enough free space'), findsOneWidget);
    expect(find.textContaining('300 MB'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('picker throws while copying with < 300 MB free → same error', (tester) async {
    await openMerge(tester, free: 50 * mb, throws: true);
    expect(find.textContaining('Not enough free space'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('empty pick with plenty of space → a plain cancel: silent', (tester) async {
    await openMerge(tester, free: 2048 * mb);
    expect(find.textContaining('Not enough free space'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await finish(tester);
  });

  testWidgets('throw with plenty of space → silent too', (tester) async {
    await openMerge(tester, free: 2048 * mb, throws: true);
    expect(find.byType(SnackBar), findsNothing);
    await finish(tester);
  });
}
