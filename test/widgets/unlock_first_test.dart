// T11.4 — "Unlock it first" (RELEASE_V1_4 FR-UNL-08, R56): tools that can't
// use a password-protected PDF send a COPY of it to Unlock PDF; the source
// tool keeps its list. Also S18's locked-file copy and action.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/errors/error_copy.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_compress/presentation/reduce_screen.dart';
import 'package:docukit/features/pdf_merge/presentation/merge_screen.dart';
import 'package:docukit/features/pdf_unlock/presentation/unlock_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tools/tool_inputs.dart';
import 'package:docukit/l10n/gen/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

const _unlockFirst = 'This PDF is password-protected. Unlock it first.';

/// Fails like a tool that found a protected PDF mid-job.
class _EncryptedTool implements ToolOperation<ToolOptions> {
  @override
  ToolId get tool => ToolId.pdfCompress;
  @override
  Future<void> validateInputs(List<PickedFile> inputs, ToolOptions o) async =>
      throw const AppError(AppErrorCode.encryptedDocument);
  @override
  int estimateRequiredBytes(List<PickedFile> inputs, ToolOptions o) => 0;
  @override
  Future<RawOutput> execute(JobContext ctx, List<PickedFile> inputs, ToolOptions o) => throw UnimplementedError();
  @override
  Future<OutputMeta> validateOutput(RawOutput out, List<PickedFile> inputs, ToolOptions o) => throw UnimplementedError();
}

class _NoOptions extends ToolOptions {
  const _NoOptions();
  @override
  Map<String, Object?> toJson() => const {};
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late Directory files;

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  /// A real file (the hand-off copies it), picked as a PDF.
  Future<PickedFile> pdfFile(WidgetTester tester, String name, {bool locked = false}) async {
    final f = (await tester.runAsync(() => File(p.join(files.path, name)).writeAsString('%PDF')))!;
    final fake = fakePdf(name, encrypted: locked);
    return PickedFile(
        path: f.path, displayName: name, type: SniffedType.pdf, sizeBytes: 4, pdf: fake.pdf, status: fake.status);
  }

  Future<void> open(WidgetTester tester, String route, List<PickedFile> picked) async {
    tester.view.physicalSize = const Size(400, 1200) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = picked;
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push(route));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PickerDropCard));
    await settle(tester);
  }

  setUp(() => files = Directory.systemTemp.createTempSync('unlock_first'));
  tearDown(() => files.deleteSync(recursive: true));

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen, skipOffstage: false)));

  /// S38 is open with a copy of [name] (a new path in Unlock's own draft).
  void expectUnlockWith(WidgetTester tester, String name, String sourcePath) {
    expect(find.byType(UnlockScreen), findsOneWidget);
    final f = container(tester).read(toolInputsProvider(ToolId.pdfUnlock)).single!;
    expect(f.displayName, name);
    expect(f.path, isNot(sourcePath));
    expect(File(f.path).existsSync(), isTrue);
    expect(File(sourcePath).existsSync(), isTrue, reason: 'copied, not moved');
  }

  testWidgets('R56 Merge: 🔒 badge + "Unlock it first" banner → S38 with that file; Merge keeps both files', (tester) async {
    h = (await tester.runAsync(() => TestHarness.create()))!;
    final a = await pdfFile(tester, 'a.pdf'), locked = await pdfFile(tester, 'statement.pdf', locked: true);
    await open(tester, '/tool/pdf-merge', [a, locked]);
    expect(find.text('Password-protected'), findsOneWidget);
    expect(find.text(_unlockFirst), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Unlock PDF'));
    await settle(tester);
    expectUnlockWith(tester, 'statement.pdf', locked.path);
    GoRouter.of(tester.element(find.byType(UnlockScreen))).pop();
    await settle(tester);
    expect(find.byType(MergeScreen), findsOneWidget);
    expect(container(tester).read(toolInputsProvider(ToolId.pdfMerge)).files.length, 2);
    await finish(tester);
  });

  testWidgets('a single-PDF tool (Size Reducer): the primary action becomes Unlock PDF with the helper', (tester) async {
    h = (await tester.runAsync(() => TestHarness.create()))!;
    final locked = await pdfFile(tester, 'statement.pdf', locked: true);
    await open(tester, '/tool/pdf-compress', [locked]);
    final bar = tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));
    expect((bar.label, bar.helper), ('Unlock PDF', _unlockFirst));
    await tester.tap(find.text('Unlock PDF').last);
    await settle(tester);
    expectUnlockWith(tester, 'statement.pdf', locked.path);
    await finish(tester);
  });

  for (final route in ['/tool/pdf-organize', '/tool/pdf-split', '/tool/pdf-to-images', '/tool/ocr']) {
    testWidgets('$route: a locked PDF → Unlock PDF as the primary action', (tester) async {
      h = (await tester.runAsync(() => TestHarness.create()))!;
      final locked = await pdfFile(tester, 'statement.pdf', locked: true);
      if (route == '/tool/ocr') {
        h.gateway.nextPdfs = [locked];
        tester.view.physicalSize = const Size(400, 1400) * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(h.app());
        await tester.pump(const Duration(milliseconds: 100));
        unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push(route));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose PDF'));
        await settle(tester);
      } else {
        await open(tester, route, [locked]);
      }
      final bar = tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));
      expect((bar.label, bar.helper, bar.onPressed != null), ('Unlock PDF', _unlockFirst, true));
      await finish(tester);
    });
  }

  testWidgets('Protect: "already has a password" → Unlock PDF opens S38 with the file', (tester) async {
    h = (await tester.runAsync(() => TestHarness.create()))!;
    final locked = await pdfFile(tester, 'statement.pdf', locked: true);
    await open(tester, '/tool/pdf-protect', [locked]);
    await tester.tap(find.widgetWithText(TextButton, 'Unlock PDF'));
    await settle(tester);
    expectUnlockWith(tester, 'statement.pdf', locked.path);
    await finish(tester);
  });

  test('S18 copy for a locked file: Unlock PDF first, Choose another second; the old "can\'t open yet" text is gone', () {
    final l = AppLocalizationsEn();
    final c = errorCopy(l, const AppError(AppErrorCode.encryptedDocument));
    expect((c.primary, c.secondary), (ErrorAction.unlockPdf, ErrorAction.chooseAnother));
    expect(errorActionLabel(l, ErrorAction.unlockPdf), 'Unlock PDF');
    expect(c.body, 'Unlock it first, then try again.');
  });

  testWidgets('S18 "Unlock PDF" → S38 with the tool\'s locked file; the error is dismissed', (tester) async {
    h = (await tester.runAsync(() => TestHarness.create()))!;
    final locked = await pdfFile(tester, 'statement.pdf', locked: true);
    await open(tester, '/tool/pdf-compress', [locked]);
    final router = GoRouter.of(tester.element(find.byType(ReduceScreen)));
    final id = container(tester).read(jobsProvider.notifier).start(_EncryptedTool(), [locked], const _NoOptions());
    unawaited(router.push('/job/$id'));
    await settle(tester, 30);
    expect(find.text('This PDF is password-protected'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock PDF').last);
    await settle(tester);
    expectUnlockWith(tester, 'statement.pdf', locked.path);
    expect(container(tester).read(jobsProvider), isEmpty);
    await finish(tester);
  });
}
