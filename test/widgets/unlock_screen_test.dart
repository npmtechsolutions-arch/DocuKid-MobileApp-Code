// T11.4 — S38 Unlock PDF (RELEASE_V1_4 §3, §8.2; FR-UNL-01…07): the field,
// the wrong-password inline error (no history row, field kept), success
// (field cleared), unprotected / owner-restricted notices, 200% text.
import 'dart:async';

import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_unlock/application/unlock_operation.dart';
import 'package:docukit/features/pdf_unlock/presentation/unlock_screen.dart';
import 'package:docukit/features/secure/secure_tool_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

const _wrong = "That password didn't work. Check it and try again.";
const _needPw = "You need the file's password. DocuKit can't unlock files without it.";

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
    h.security.passwords['statement.pdf'] = 'Test-1234';
    await tester.pumpWidget(h.app(overrides: [
      // The fake engine can't render; page validation is the operation's own unit test.
      unlockOperationProvider.overrideWith(
          (ref) => UnlockPdfOperation(ref.watch(pdfSecurityProvider), validatePages: (_, expected) async => expected)),
    ]));
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = picked.cast();
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-unlock'));
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
  TextField field(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const ValueKey('unl-password'), skipOffstage: false));
  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(UnlockScreen, skipOffstage: false)));

  testWidgets('the real screen replaces the shell; empty → Choose PDF; the "need the password" note', (tester) async {
    await open(tester);
    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.byType(SecureToolShell), findsNothing);
    expect((bar(tester).onPressed, bar(tester).helper), (null, 'Choose PDF'));
    expect(find.text(_needPw), findsOneWidget);
    await finish(tester);
  });

  testWidgets('locked PDF: masked field without suggestions; Unlock enabled when non-empty (FR-UNL-02)', (tester) async {
    await open(tester, picked: [fakePdf('statement.pdf', encrypted: true)]);
    final f = field(tester);
    expect((f.obscureText, f.autocorrect, f.enableSuggestions, f.autofillHints, f.enableIMEPersonalizedLearning),
        (true, false, false, null, false));
    expect(bar(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('unl-password')), 'x');
    await tester.pump();
    expect(bar(tester).onPressed, isNotNull, reason: 'any non-empty password: no length or byte rule on Unlock');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field(tester).obscureText, isFalse);
    await finish(tester);
  });

  testWidgets('wrong password: back on S38, inline error, field still filled, no job, no history; typing clears it',
      (tester) async {
    await open(tester, picked: [fakePdf('statement.pdf', encrypted: true)]);
    await tester.enterText(find.byKey(const ValueKey('unl-password')), 'test-1234');
    await tester.pump();
    await tester.tap(find.text('Unlock PDF').last);
    await settle(tester, 30);
    expect(find.byType(UnlockScreen), findsOneWidget, reason: 'not the Error screen');
    expect(find.text(_wrong), findsOneWidget);
    expect(field(tester).controller!.text, 'test-1234', reason: 'FR-UNL-03');
    expect(container(tester).read(jobsProvider), isEmpty);
    expect(await tester.runAsync(() => h.db.select(h.db.operations).get()), isEmpty);
    expect(h.security.unlockedWith, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('unl-password')), 'Test-1234');
    await tester.pump();
    expect(find.text(_wrong), findsNothing);
    await finish(tester);
  });

  testWidgets('right password → Result (statement_unlocked.pdf, a history row); the field is cleared', (tester) async {
    await open(tester, picked: [fakePdf('statement.pdf', encrypted: true)]);
    await tester.enterText(find.byKey(const ValueKey('unl-password')), 'Test-1234');
    await tester.pump();
    await tester.tap(find.text('Unlock PDF').last);
    await settle(tester, 40);
    final job = container(tester).read(jobsProvider).values.single;
    expect((job.state as JobCompleted).result.outputName, 'statement_unlocked.pdf');
    expect(h.security.unlockedWith, ['Test-1234']);
    expect(field(tester).controller!.text, isEmpty, reason: 'FR-UNL-07');
    final rows = (await tester.runAsync(() => h.db.select(h.db.operations).get()))!;
    expect((rows.single.status, rows.single.optionsJson), ('SUCCESS', '{}'));
    await finish(tester);
  });

  testWidgets('unprotected → "doesn\'t have a password"; owner-restricted → "keeps its restrictions"; Unlock disabled',
      (tester) async {
    await open(tester, picked: [fakePdf('plain.pdf')]);
    expect(find.text("This PDF doesn't have a password."), findsOneWidget);
    expect(field(tester).enabled, isFalse);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);

    final restricted = fakePdf('restricted.pdf');
    await open(tester);
    h.security.protection[restricted.path] = PdfProtection.ownerOnly;
    h.gateway.nextPdfs = [restricted];
    await tester.tap(find.byType(PickerDropCard));
    await settle(tester);
    expect(find.text('This PDF opens without a password. It has restrictions set by its creator, which DocuKit keeps.'),
        findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('200% text: the error and notes don\'t overflow (§8.2)', (tester) async {
    await open(tester, picked: [fakePdf('statement.pdf', encrypted: true)], textScale: 2);
    await tester.enterText(find.byKey(const ValueKey('unl-password')), 'nope');
    await tester.pump();
    await tester.tap(find.text('Unlock PDF').last);
    await settle(tester, 30);
    await tester.scrollUntilVisible(find.text(_needPw), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(_wrong), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
