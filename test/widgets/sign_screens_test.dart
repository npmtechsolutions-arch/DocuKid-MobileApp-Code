// T11.7 — S33 Sign PDF + S35 placement editor (RELEASE_V1_4 §3, §8.2;
// FR-SIG-01, 05–08, 10, 11; R49/R50 in widget form): the banner on S33 and
// none on S35, locked files, saved tiles (tap / long-press delete), the S34 →
// S33 → S35 flow, drag + undo/redo, Pages… → all pages, the accessible sheet,
// date stamps, the leave dialog, and Save running the job.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/jobs_controller.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_stamper.dart';
import 'package:docukit/core/widgets/inputs.dart';
import 'package:docukit/core/widgets/tool_scaffold.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_sign/application/placement.dart';
import 'package:docukit/features/pdf_sign/application/sign_operation.dart';
import 'package:docukit/features/pdf_sign/application/sign_session.dart';
import 'package:docukit/features/pdf_sign/application/signature_models.dart';
import 'package:docukit/features/pdf_sign/application/signature_providers.dart';
import 'package:docukit/features/pdf_sign/presentation/placement_screen.dart';
import 'package:docukit/features/pdf_sign/presentation/sign_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

class _Stamper implements PdfStamper {
  List<Stamp>? got;
  @override
  Future<void> apply(String inPath, List<Stamp> stamps, String outPath, JobContext ctx) async {
    got = stamps;
    File(outPath).writeAsStringSync('%PDF signed');
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late Directory dir;
  late _Stamper stamper;
  late String sigPng;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sign_ui');
    stamper = _Stamper();
    sigPng = p.join(dir.path, 'sig.png');
    final im = img.Image(width: 300, height: 100, numChannels: 4);
    img.fillRect(im, x1: 10, y1: 40, x2: 290, y2: 60, color: img.ColorRgba8(20, 40, 160, 255));
    File(sigPng).writeAsBytesSync(img.encodePng(im));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PickedFile pdf(String name, {int pages = 6, bool locked = false}) => PickedFile(
        path: p.join(dir.path, name),
        displayName: name,
        type: SniffedType.pdf,
        sizeBytes: 1000,
        pdf: locked ? null : PdfMeta(pageCount: pages, pageSizes: List.filled(pages, (595.0, 842.0))),
        status: locked ? const ValidationStatus.invalid(AppErrorCode.encryptedDocument) : const ValidationStatus.ok(),
      );

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester, 20);
  }

  Future<void> open(WidgetTester tester, {List<PickedFile> picked = const []}) async {
    tester.view.physicalSize = const Size(420, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app(overrides: [
      signOperationProvider.overrideWith((ref) => SignPdfOperation(stamper,
          validatePages: (_, e) async => e, stampVisible: (_, _, _, _) async => true)),
    ]));
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = picked;
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-sign'));
    await settle(tester);
    if (picked.isNotEmpty) {
      await tester.tap(find.byType(PickerDropCard));
      await settle(tester);
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen, skipOffstage: false)));
  PrimaryActionBar bar(WidgetTester tester) => tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));

  Future<void> saveSignature(WidgetTester tester, SignatureKind k) =>
      tester.runAsync(() => c(tester).read(savedSignaturesProvider.notifier).save(sigPng, k)).then((_) {});

  /// S33 with a file and the first saved signature chosen, then S35.
  Future<void> toEditor(WidgetTester tester, {int pages = 6}) async {
    await open(tester, picked: [pdf('lease.pdf', pages: pages)]);
    await saveSignature(tester, SignatureKind.draw);
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Saved signature 1'));
    await tester.pump();
    await tester.tap(find.text('Place signature on pages'));
    await settle(tester, 20);
    expect(find.byType(PlacementScreen), findsOneWidget);
  }

  EditorView editor(WidgetTester tester) => c(tester).read(placementEditorProvider);

  testWidgets('S33: banner with gap, the not-certified note, Place needs a file and a signature',
      (tester) async {
    await open(tester);
    expect(find.byType(SignScreen), findsOneWidget);
    expect(find.byType(AppBottomBanner), findsOneWidget);
    expect(find.text("This adds an image of your signature. It isn't a certified digital signature."), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('a locked PDF → "Unlock it first" with Unlock PDF (FR-SIG-01)', (tester) async {
    await open(tester, picked: [pdf('locked.pdf', locked: true)]);
    expect(find.text('This PDF is password-protected. Unlock it first.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Unlock PDF'), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('saved tiles: tap chooses (Place enabled); long-press deletes after a confirm (FR-SIG-10)', (tester) async {
    await open(tester, picked: [pdf('lease.pdf')]);
    await saveSignature(tester, SignatureKind.draw);
    await saveSignature(tester, SignatureKind.type);
    await settle(tester);
    expect(find.bySemanticsLabel('Saved signature 2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Saved signature 2'));
    await tester.pump();
    expect(bar(tester).onPressed, isNotNull);
    await tester.longPress(find.bySemanticsLabel('Saved signature 2'));
    await settle(tester);
    expect(find.text('Delete this saved signature?'), findsOneWidget);
    await act(tester, find.text('Delete').last);
    expect(c(tester).read(savedSignaturesProvider).length, 1);
    expect(bar(tester).onPressed, isNull, reason: 'the chosen one is gone');
    await finish(tester);
  });

  testWidgets('R49 flow: Draw → S34 "Not now" → back on S33 with the new tile chosen → S35 (no ads), one placement',
      (tester) async {
    await open(tester, picked: [pdf('lease.pdf')]);
    await tester.tap(find.text('Draw'));
    await settle(tester);
    final pad = tester.getCenter(find.byKey(const ValueKey('sig-pad')));
    final g = await tester.startGesture(pad - const Offset(60, 0));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(20, 5));
    }
    await g.up();
    await tester.pump();
    await act(tester, find.widgetWithText(FilledButton, 'Done'));
    await act(tester, find.text('Not now'));
    expect(find.byType(SignScreen), findsOneWidget);
    expect(find.bySemanticsLabel('New signature'), findsOneWidget);
    expect(c(tester).read(savedSignaturesProvider), isEmpty, reason: 'R49: not saved');
    await tester.tap(find.text('Place signature on pages'));
    await settle(tester, 20);
    expect(find.byType(PlacementScreen), findsOneWidget);
    expect(find.byType(AppBottomBanner), findsNothing, reason: 'S35 has no ads');
    final only = editor(tester).placements.single;
    expect(only.pageIndex, 0);
    expect(only.rect.right, closeTo(595 - 29.75, 0.5), reason: 'bottom-right, 30% of the width');
    expect(only.rect.width, closeTo(178.5, 0.5));
    await finish(tester);
  });

  testWidgets('drag moves the placement; undo / redo; "Pages…" → All pages puts it on all 6 pages', (tester) async {
    await toEditor(tester);
    final before = editor(tester).placements.single.rect;
    await tester.drag(find.byKey(ValueKey('body-${editor(tester).placements.single.id}')), const Offset(-60, -80));
    await tester.pump();
    final moved = editor(tester).placements.single.rect;
    expect(moved.left, lessThan(before.left - 20));
    expect(moved.top, lessThan(before.top - 20));
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(editor(tester).placements.single.rect, before, reason: 'one drag = one step');
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(editor(tester).placements.single.rect, moved);
    await tester.tap(find.text('Pages…'));
    await settle(tester);
    await tester.tap(find.text('All pages'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);
    expect(editor(tester).placements.map((p) => p.pageIndex).toSet(), {0, 1, 2, 3, 4, 5});
    expect(editor(tester).placements.every((p) => p.rect == moved), isTrue, reason: 'same relative position, same size pages');
    await finish(tester);
  });

  testWidgets('Pages… → a range: invalid text shows the error; "2-3" adds pages 2 and 3', (tester) async {
    await toEditor(tester);
    await tester.tap(find.text('Pages…'));
    await settle(tester);
    await tester.tap(find.text('Pages'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('sig-range')), '9');
    await tester.pump();
    expect(find.textContaining("doesn't exist"), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sig-range')), '2-3');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);
    expect(editor(tester).placements.map((p) => p.pageIndex).toList()..sort(), [0, 1, 2]);
    await finish(tester);
  });

  testWidgets('the accessible sheet: Move to top left, Rotate 90°, Remove → Save disabled with the helper', (tester) async {
    await toEditor(tester);
    await tester.tap(find.bySemanticsLabel('More options for this item'));
    await settle(tester);
    await tester.tap(find.text('Top left'));
    await settle(tester);
    expect(editor(tester).placements.single.rect.topLeft, const Offset(29.75, 29.75));
    await tester.tap(find.bySemanticsLabel('More options for this item'));
    await settle(tester);
    await tester.tap(find.text('Rotate 90°'));
    await settle(tester);
    expect(editor(tester).placements.single.rotation, 90);
    await tester.tap(find.bySemanticsLabel('More options for this item'));
    await settle(tester);
    await tester.tap(find.text('Remove'));
    await settle(tester);
    expect(editor(tester).placements, isEmpty);
    expect(bar(tester).onPressed, isNull);
    expect(bar(tester).helper, 'Add your signature to at least one page.');
    await finish(tester);
  });

  testWidgets('+ Date: pre-filled with today in the locale format; adds a date placement (FR-SIG-07)', (tester) async {
    await toEditor(tester);
    await tester.tap(find.text('Date'));
    await settle(tester);
    final field = tester.widget<TextField>(find.byKey(const ValueKey('stamp-text')));
    expect(field.controller!.text, isNotEmpty);
    expect(field.controller!.text, contains('${DateTime.now().year}'));
    await act(tester, find.text('Add'));
    expect(editor(tester).placements.map((p) => p.kind), containsAll([PlacementKind.signature, PlacementKind.date]));
    await finish(tester);
  });

  testWidgets('leaving with placements asks first', (tester) async {
    await toEditor(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Leave without finishing?'), findsOneWidget);
    expect(find.byType(PlacementScreen), findsOneWidget, reason: 'still open until the user chooses');
    await finish(tester);
  });

  testWidgets('R50 in widget form: on all 6 pages → Save → the job stamps 6 pages; history has counts only', (tester) async {
    await toEditor(tester);
    await tester.tap(find.text('Pages…'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);
    await act(tester, find.text('Save signed PDF'));
    await settle(tester, 30);
    final job = c(tester).read(jobsProvider).values.single;
    final done = job.state as JobCompleted;
    expect(done.result.outputName, 'lease_signed.pdf');
    expect(done.result.meta.flags['stamped'], 6);
    expect(stamper.got!.length, 6);
    final row = (await tester.runAsync(() => h.db.select(h.db.operations).get()))!.single;
    expect(row.optionsJson, '{"placements":6,"pages":6}');
    await finish(tester);
  });
}
