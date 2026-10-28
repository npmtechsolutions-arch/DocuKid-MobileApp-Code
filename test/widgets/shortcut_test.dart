// T9.9 — the Android launcher shortcut "Scan" (FR-SCN-22, ADR-065): the route
// arrives from the relay activity (cold or warm) and is pushed on top of
// whatever DocuKit shows, never replacing it. The relay itself is checked on
// the emulator.
import 'dart:async';

import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/onboarding/onboarding_screen.dart';
import 'package:docukit/features/pdf_split/presentation/split_screen.dart';
import 'package:docukit/features/scan/presentation/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> open(WidgetTester tester, {String? cold, bool onboarded = true}) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = (await tester.runAsync(() => TestHarness.create(onboarded: onboarded)))!;
    h.native.pendingRoute = cold;
    await tester.pumpWidget(h.app());
    await settle(tester);
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('cold start from the shortcut: Scan opens and the scanner starts (autostart)', (tester) async {
    final h = await open(tester, cold: '/tool/scan?autostart=1');
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(h.scanner.scans, hasLength(1));
    // Back goes Home: Scan was pushed on top.
    expect(GoRouter.of(tester.element(find.byType(ScanScreen))).canPop(), isTrue);
    await finish(tester);
  });

  testWidgets('warm: pushed over the tool that was open, which stays underneath', (tester) async {
    final h = await open(tester);
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-split'));
    await settle(tester);
    expect(find.byType(SplitScreen), findsOneWidget);
    h.native.sendRoute('/tool/scan?autostart=1');
    await settle(tester);
    expect(find.byType(ScanScreen), findsOneWidget);
    GoRouter.of(tester.element(find.byType(ScanScreen))).pop();
    await settle(tester);
    expect(find.byType(SplitScreen), findsOneWidget, reason: 'nothing below was cleared');
    await finish(tester);
  });

  testWidgets('autostart waits until DocuKit is in front (a picker may still cover it)', (tester) async {
    final h = await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    h.native.sendRoute('/tool/scan?autostart=1');
    await settle(tester);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(h.scanner.scans, isEmpty, reason: 'not while something else is on top');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(h.scanner.scans, hasLength(1));
    await finish(tester);
  });

  testWidgets('already on Scan: not opened twice', (tester) async {
    final h = await open(tester);
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/scan'));
    await settle(tester);
    h.native.sendRoute('/tool/scan?autostart=1');
    await settle(tester);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(h.scanner.scans, isEmpty);
    await finish(tester);
  });

  testWidgets('a route that is not a shortcut is ignored', (tester) async {
    final h = await open(tester);
    h.native.sendRoute('/settings');
    h.native.sendRoute('/tool/pdf-merge');
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(GoRouter.of(tester.element(find.byType(HomeScreen))).canPop(), isFalse);
    await finish(tester);
  });

  testWidgets('first run: waits for onboarding, then opens Scan', (tester) async {
    await open(tester, cold: '/tool/scan?autostart=1', onboarded: false);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(ScanScreen), findsNothing);
    await tester.tap(find.text('Get started'));
    await settle(tester);
    expect(find.byType(ScanScreen), findsOneWidget);
    await finish(tester);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  await tester.pump();
}
