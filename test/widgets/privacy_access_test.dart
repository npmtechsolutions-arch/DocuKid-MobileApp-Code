// S17 "What DocuKit can access" (RELEASE_V1_2 §6, T9.8): the Camera row; the
// 1.3 OCR point; the 1.4 passwords/signatures point and policy text (T11.9).
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
    // 1.3 (RELEASE_V1_3 §6).
    await tester.scrollUntilVisible(find.text('Text recognition stays on your phone'), -200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text("Text recognition runs on your phone. DocuKit doesn't upload your files or the text found in them."),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('1.4 (RELEASE_V1_4 §6): "Passwords and signatures"; protected PDFs only with your password; the policy says so',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    unawaited(router.push('/settings/privacy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('Passwords and signatures'), 200, scrollable: find.byType(Scrollable).last);
    expect(
        find.text("Passwords you enter are used once and never saved. Saved signatures stay only on this phone and aren't included in backups."),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('Password-protected files'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining("doesn't open or unlock"), findsNothing, reason: 'no longer true in 1.4');
    expect(find.textContaining('only with the password you type'), findsOneWidget);
    unawaited(router.push('/settings/policy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Saved signatures are stored only on your device and are not included in backups. '
        'Passwords you enter are used once and never saved.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('1.5 (RELEASE_V1_5 §6, T12.9): "My Documents and reminders" in Privacy & About and in the policy', (tester) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    unawaited(router.push('/settings/privacy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('My Documents and reminders'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining("Documents you save to My Documents stay on this phone. They aren't included in cloud backups"),
        findsOneWidget);
    unawaited(router.push('/settings/policy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        find.text("If you save documents to My Documents, they're stored only on your device, aren't included in cloud backups, "
            'and are deleted when you delete them or uninstall DocuKit. Reminders are local notifications created on your device.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('1.6 (RELEASE_PRINT §6, T13.7): "Printing" in Privacy & About and in the policy', (tester) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    unawaited(router.push('/settings/privacy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('Printing'), 200, scrollable: find.byType(Scrollable).last);
    const text = "When you print, the document goes to the printer or print service you choose in the print dialog. "
        "Some printer makers' print services may send it through their own servers; that's set by the service you install, "
        'not by DocuKit.';
    expect(find.text(text), findsOneWidget);
    unawaited(router.push('/settings/policy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text(text), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
