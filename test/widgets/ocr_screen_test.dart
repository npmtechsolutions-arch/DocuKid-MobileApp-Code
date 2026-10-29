// T10.6 — S30 Text Recognition (RELEASE_V1_3 §3.1, FR-OCR-01–04): every
// state of the screen, the language choice, and Run.
import 'dart:async';

import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/job/job_screen.dart';
import 'package:docukit/features/ocr/application/ocr_options.dart';
import 'package:docukit/features/ocr/application/ocr_options_controller.dart';
import 'package:docukit/features/ocr/presentation/ocr_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit/features/tools/tool_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/ocr'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(OcrScreen)));

  FilledButton runButton(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton).last);

  Future<void> pickPdf(WidgetTester tester, {List<bool>? textPages, int pages = 3}) async {
    final pdf = fakePdf('scanned_notes.pdf', pages: pages);
    h.gateway.nextPdfs = [pdf];
    if (textPages != null) h.textReader.flags = {pdf.path: textPages};
    await tester.tap(find.text('Choose PDF'));
    await settle(tester);
  }

  testWidgets('empty: Choose images / Choose PDF, the hint, the results and language cards; Run disabled', (tester) async {
    await open(tester);
    expect(find.text('Text Recognition'), findsWidgets);
    expect(find.text('Choose images'), findsOneWidget);
    expect(find.text('Choose PDF'), findsOneWidget);
    expect(find.text('Up to 50 images or one PDF'), findsWidgets);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Searchable PDF'), findsOneWidget);
    expect(find.text('Review and copy text'), findsOneWidget);
    expect(find.text('Save as .txt'), findsOneWidget);
    expect(find.text('Text language'), findsWidgets);
    expect(runButton(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('images: "Recognise text (2 pages)"; Run starts one OCR job and opens Processing', (tester) async {
    await open(tester);
    h.gateway.nextImages = [fakeImage('a.jpg'), fakeImage('b.jpg')];
    await tester.tap(find.text('Choose images'));
    await settle(tester);
    expect(find.text('Recognise text (2 pages)'), findsOneWidget);
    expect(runButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Recognise text (2 pages)'));
    await tester.pump();
    final jobs = container(tester).read(jobsProvider).values.toList();
    expect((jobs.single.tool, jobs.single.multi), (ToolId.ocr, true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JobScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('one image: singular label "Recognise text (1 page)"', (tester) async {
    await open(tester);
    h.gateway.nextImages = [fakeImage('a.jpg')];
    await tester.tap(find.text('Choose images'));
    await settle(tester);
    expect(find.text('Recognise text (1 page)'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('PDF: "Checking for text…" holds Run, then the badge "No text yet" and the rebuild note', (tester) async {
    await open(tester);
    h.textReader.hold = Completer<void>();
    await pickPdf(tester);
    expect(find.text('Checking for text…'), findsOneWidget);
    expect(runButton(tester).onPressed, isNull);
    h.textReader.hold!.complete();
    await settle(tester);
    expect(find.text('No text yet'), findsOneWidget);
    expect(find.text('Recognise text (3 pages)'), findsOneWidget);
    expect(find.text("Recognised pages are rebuilt from images. Links and form fields on those pages won't work."),
        findsOneWidget);
    expect(runButton(tester).onPressed, isNotNull);
    await finish(tester);
  });

  testWidgets('partial PDF: badge, banner with counts, only the other pages counted (FR-OCR-02)', (tester) async {
    await open(tester);
    await pickPdf(tester, textPages: [true, false, false]);
    expect(find.text('Text on 1 of 3 pages'), findsOneWidget);
    expect(find.text('1 of 3 pages already have text. Only the other pages will be recognised.'), findsOneWidget);
    expect(find.text('Recognise text (2 pages)'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('fully text PDF: banner, "Already searchable" (disabled), "Get text"', (tester) async {
    await open(tester);
    await pickPdf(tester, textPages: [true, true, true]);
    expect(find.text('Already has text'), findsOneWidget);
    expect(find.text('This PDF already has text you can search and copy.'), findsOneWidget);
    expect(find.text('Already searchable'), findsOneWidget);
    final pdfBox = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Searchable PDF'));
    expect((pdfBox.value, pdfBox.onChanged), (false, null));
    expect(find.text('Get text'), findsOneWidget);
    expect(runButton(tester).onPressed, isNotNull);
    await finish(tester);
  });

  testWidgets('no result ticked → Run disabled with "Choose at least one result" (FR-OCR-03)', (tester) async {
    await open(tester);
    h.gateway.nextImages = [fakeImage('a.jpg')];
    await tester.tap(find.text('Choose images'));
    await settle(tester);
    for (final t in ['Searchable PDF', 'Review and copy text']) {
      await tester.tap(find.widgetWithText(CheckboxListTile, t));
      await tester.pump();
    }
    expect(find.text('Choose at least one result'), findsOneWidget);
    expect(runButton(tester).onPressed, isNull);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Save as .txt'));
    await tester.pump();
    expect(runButton(tester).onPressed, isNotNull);
    await finish(tester);
  });

  testWidgets('more than 30 pages: "This may take a few minutes. Keep DocuKit open."', (tester) async {
    await open(tester);
    await pickPdf(tester, textPages: List.filled(40, false), pages: 40);
    expect(find.text('This may take a few minutes. Keep DocuKit open.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('images and a PDF together (e.g. shared in) are refused, with Start over (FR-OCR-01)', (tester) async {
    await open(tester);
    h.gateway.nextImages = [fakeImage('a.jpg')];
    await tester.tap(find.text('Choose images'));
    await settle(tester);
    await container(tester).read(toolInputsProvider(ToolId.ocr).notifier).addPages([fakePdf('b.pdf')]);
    await settle(tester);
    expect(find.text('Choose images or one PDF, not both.'), findsWidgets);
    expect(runButton(tester).onPressed, isNull);
    await tester.tap(find.text('Start over'));
    await settle(tester);
    expect(find.text('Choose images'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('language: the shipped scripts; the choice is used and remembered (FR-OCR-04)', (tester) async {
    await open(tester);
    await tester.tap(find.byType(DropdownMenu<OcrScript>));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Devanagari (Hindi, Marathi…)'), findsWidgets);
    expect(find.text('Korean'), findsNothing, reason: 'not shipped (ADR-045)');
    await tester.tap(find.text('Devanagari (Hindi, Marathi…)').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.store.get('ocr_script'), 'devanagari');
    await finish(tester);
  });

  testWidgets('200% text on a small phone: no overflow in the empty, partial-PDF and no-output states', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    tester.view.physicalSize = const Size(360, 740) * 2;
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'empty state');
    tester.view.physicalSize = const Size(400, 1400) * 2; // reach "Choose PDF"
    await tester.pump();
    await pickPdf(tester, textPages: [true, false, false]);
    tester.view.physicalSize = const Size(360, 740) * 2;
    await tester.pump();
    expect(find.text('Text on 1 of 3 pages'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'partial PDF');
    // Layout check: set the no-output state directly (at 2× text the boxes sit under the sticky bar).
    container(tester).read(ocrOptionsProvider.notifier).set(const OcrOptions(searchablePdf: false, review: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Choose at least one result'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('semantics: the checkboxes and the language field are labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    for (final label in ['Searchable PDF', 'Review and copy text', 'Save as .txt']) {
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(label))), findsWidgets, reason: label);
    }
    expect(find.bySemanticsLabel(RegExp('Text language')), findsWidgets);
    handle.dispose();
    await finish(tester);
  });
}
