// T8.10 — Organizer Extract (RELEASE_V1_1 FR-EXT-01…03, S07 update).
import 'dart:async';

import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/pdf/page_edit.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_organize/application/organize_controller.dart';
import 'package:docukit/features/pdf_organize/presentation/organize_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

/// Records what Extract sends, then stops the job.
class CapturingOrganize extends OrganizePdfOperation {
  CapturingOrganize() : super(FakePdfEngine());
  OrganizeOptions? got;
  @override
  Future<void> validateInputs(List<PickedFile> inputs, OrganizeOptions o) async {
    got = o;
    throw const AppError(AppErrorCode.processingFailed);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('Extract sends the selected pages in UI order with their rotation; the Organizer keeps its edits', (tester) async {
    tester.view.physicalSize = const Size(400, 1000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create()))!;
    final op = CapturingOrganize();
    await tester.pumpWidget(h.app(overrides: [organizeOperationProvider.overrideWithValue(op)]));
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = [fakePdf('contract.pdf', pages: 5)];
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    unawaited(router.push('/tool/pdf-organize'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PickerDropCard));
    await tester.pumpAndSettle();

    // Select page 4, then page 2 (selection order mustn't matter), rotate them right.
    // Tiles also handle double-tap, so a single tap lands after the double-tap window.
    await tester.tap(find.bySemanticsLabel(RegExp('^Page 4 of 5')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.bySemanticsLabel(RegExp('^Page 2 of 5')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Extract'), findsOneWidget, reason: 'in the selection bar');
    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extract'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final got = op.got!;
    expect(got.extract, isTrue);
    expect([for (final e in got.edits) (e.sourceIndex, e.rotationQuarterTurns)], [(1, 1), (3, 1)]);
    expect(got.toJson()['mode'], 'extract');

    // FR-EXT-02: back on the Organizer, nothing changed.
    final container = ProviderScope.containerOf(tester.element(find.byType(OrganizeScreen, skipOffstage: false)));
    final s = container.read(organizeProvider);
    expect(s.pages, hasLength(5));
    expect([for (final e in s.pages) e.rotationQuarterTurns], [0, 1, 0, 1, 0]);
    expect(s.canUndo, isTrue, reason: 'the edit stack is intact');

    // History records the job as pdfOrganize with mode = extract.
    final rows = await tester.runAsync(() => HistoryRepository(h.db).watchPage(limit: 5).first);
    expect(rows!.single.tool?.name, 'pdfOrganize');
    expect(rows.single.options['mode'], 'extract');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('extract name and options (FR-EXT-03)', () {
    const o = OrganizeOptions([PageEdit(0)], extract: true);
    expect(o.toJson(), {'pages': 1, 'mode': 'extract'});
    expect(const OrganizeOptions([PageEdit(0)]).toJson().containsKey('mode'), isFalse);
  });
}
