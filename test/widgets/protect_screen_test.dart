// T11.3 — S37 Protect PDF (RELEASE_V1_4 §3, §8.2; FR-PRT-01…04, 07):
// fields, inline errors, strength, the weak-password dialog, the always-visible
// warning, "already has a password" → Unlock, hygiene, 200% text, Result.
import 'dart:async';

import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/pdf_thumbnail.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_protect/presentation/protect_screen.dart';
import 'package:docukit/features/secure/secure_tool_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

const _noRecover = "If you forget this password, nobody can open the file — DocuKit can't recover it.";

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, {List<dynamic> picked = const [], double textScale = 1}) async {
    tester.view.physicalSize = const Size(400, 1200) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = picked.cast();
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-protect'));
    await tester.pumpAndSettle();
    if (picked.isNotEmpty) {
      await tester.tap(find.byType(PickerDropCard));
      await settle(tester);
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  PrimaryActionBar bar(WidgetTester tester) => tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));
  TextField field(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(ValueKey(key)));
  Future<void> type(WidgetTester tester, String pw, [String? confirm]) async {
    await tester.enterText(find.byKey(const ValueKey('prt-password')), pw);
    await tester.enterText(find.byKey(const ValueKey('prt-confirm')), confirm ?? pw);
    await tester.pump();
  }

  testWidgets('the real screen replaces the shell; empty → Choose PDF; the warning is always visible', (tester) async {
    await open(tester);
    expect(find.byType(ProtectScreen), findsOneWidget);
    expect(find.byType(SecureToolShell), findsNothing);
    expect(bar(tester).onPressed, isNull);
    expect(bar(tester).helper, 'Choose PDF');
    expect(find.text(_noRecover), findsOneWidget);
    await finish(tester);
  });

  testWidgets('fields: masked, no autocorrect / suggestions / autofill; show-hide toggle with tooltips (FR-PRT-02)',
      (tester) async {
    await open(tester, picked: [fakePdf('bank_statement.pdf')]);
    for (final k in ['prt-password', 'prt-confirm']) {
      final f = field(tester, k);
      expect((f.obscureText, f.autocorrect, f.enableSuggestions, f.autofillHints, f.enableIMEPersonalizedLearning),
          (true, false, false, null, false));
    }
    expect(find.byTooltip('Show password'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(field(tester, 'prt-password').obscureText, isFalse);
    expect(field(tester, 'prt-confirm').obscureText, isTrue);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('inline errors and strength; Run only when valid (FR-PRT-02/03)', (tester) async {
    await open(tester, picked: [fakePdf('bank_statement.pdf')]);
    await type(tester, '12345');
    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await type(tester, 'a' * 65);
    expect(find.text('Use 64 characters or fewer'), findsOneWidget);
    await type(tester, 'प' * 43);
    expect(find.text('This password is too long. Use fewer characters.'), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await type(tester, 'abcdefg1', 'abcdefg2');
    expect(find.text("Passwords don't match"), findsOneWidget);
    expect(find.bySemanticsLabel('Strength: OK'), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await type(tester, 'Abcdefgh1234');
    expect(find.text("Passwords don't match"), findsNothing);
    expect(find.bySemanticsLabel('Strength: Strong'), findsOneWidget);
    expect(bar(tester).onPressed, isNotNull);
    expect(find.text(_noRecover), findsOneWidget);
    await finish(tester);
  });

  testWidgets('weak: "Change it" keeps you here; "Use anyway" runs, clears both fields, Result shows the lock and note',
      (tester) async {
    await open(tester, picked: [fakePdf('bank_statement.pdf')]);
    await type(tester, 'abcdef');
    expect(find.bySemanticsLabel('Strength: Weak'), findsOneWidget);
    await tester.tap(find.text('Protect PDF').last);
    await tester.pumpAndSettle();
    expect(find.text('This password is easy to guess'), findsOneWidget);
    await tester.tap(find.text('Change it'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ProtectScreen)));
    expect(container.read(jobsProvider), isEmpty);
    expect(field(tester, 'prt-password').controller!.text, 'abcdef');

    await tester.tap(find.text('Protect PDF').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use anyway'));
    await tester.pump();
    expect(container.read(jobsProvider).values.single.tool.name, 'pdfProtect');
    expect(field(tester, 'prt-password').controller!.text, isEmpty, reason: 'FR-PRT-07');
    expect(field(tester, 'prt-confirm').controller!.text, isEmpty);
    await settle(tester, 40);
    expect(h.security.protectedWith, ['abcdef']);
    expect(find.byType(LockedPdfPreview), findsOneWidget);
    expect(find.text('Keep the password somewhere safe.'), findsOneWidget);
    final done = container.read(jobsProvider).values.single.state as JobCompleted;
    expect(done.result.outputName, 'bank_statement_protected.pdf');
    await finish(tester);
  });

  testWidgets('a locked or owner-restricted PDF → "already has a password" + Unlock PDF; Run disabled (FR-PRT-01)',
      (tester) async {
    await open(tester, picked: [fakePdf('locked.pdf', encrypted: true)]);
    expect(find.text('This PDF already has a password.'), findsOneWidget);
    await type(tester, 'Abcdefgh1234');
    expect(bar(tester).onPressed, isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Unlock PDF'));
    await tester.pumpAndSettle();
    expect(GoRouter.of(tester.element(find.byType(SecureToolShell))).state.uri.path, '/tool/pdf-unlock');
    await finish(tester);

    final owner = fakePdf('restricted.pdf');
    await open(tester);
    h.security.protection[owner.path] = PdfProtection.ownerOnly;
    h.gateway.nextPdfs = [owner];
    await tester.tap(find.byType(PickerDropCard));
    await settle(tester);
    expect(find.text('This PDF already has a password.'), findsOneWidget);
    await type(tester, 'Abcdefgh1234');
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('S18 "Try again" after a failure goes back to S37 with empty fields; no re-run (FR-PRT-07)', (tester) async {
    await open(tester, picked: [fakePdf('bank_statement.pdf')]);
    h.security.failProtect = true;
    await type(tester, 'Abcdefgh1234');
    await tester.tap(find.text('Protect PDF').last);
    await settle(tester, 40);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.byType(ProtectScreen), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(ProtectScreen)));
    expect(container.read(jobsProvider), isEmpty, reason: 'dismissed, nothing restarted');
    expect(field(tester, 'prt-password').controller!.text, isEmpty);
    expect(h.security.protectedWith, isEmpty);
    await finish(tester);
  });

  testWidgets('200% text: the warning, fields and errors don\'t overflow (§8.2)', (tester) async {
    await open(tester, picked: [fakePdf('a_rather_long_bank_statement_file_name_2026.pdf')], textScale: 2);
    await type(tester, 'abc', 'abd');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text(_noRecover), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(_noRecover), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
