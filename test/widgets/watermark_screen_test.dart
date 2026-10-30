// T11.8 — S36 Watermark PDF (RELEASE_V1_4 §3, §8.2; FR-WMK-01…08, 10):
// banner, live preview from the layout maths, text/image modes, tile, page
// modes and range errors, the run (fake stamper), and the remembered text style.
import 'dart:async';
import 'dart:convert';
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
import 'package:docukit/features/pdf_watermark/application/watermark_layout.dart';
import 'package:docukit/features/pdf_watermark/application/watermark_operation.dart';
import 'package:docukit/features/pdf_watermark/presentation/watermark_screen.dart';
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
    File(outPath).writeAsStringSync('%PDF marked');
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late Directory dir;
  late _Stamper stamper;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wmk_ui');
    stamper = _Stamper();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PickedFile pdf({int pages = 4, bool locked = false}) => PickedFile(
        path: p.join(dir.path, 'report.pdf'),
        displayName: 'report.pdf',
        type: SniffedType.pdf,
        sizeBytes: 1000,
        pdf: locked ? null : PdfMeta(pageCount: pages, pageSizes: List.filled(pages, (595.0, 842.0))),
        status: locked ? const ValidationStatus.invalid(AppErrorCode.encryptedDocument) : const ValidationStatus.ok(),
      );

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    }
    await tester.pump();
  }

  Future<void> act(WidgetTester tester, Future<void> Function() f) async {
    await tester.runAsync(() async {
      await f();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester, 20);
  }

  Future<void> open(WidgetTester tester, {List<PickedFile> picked = const [], Map<String, Object> store = const {}}) async {
    tester.view.physicalSize = const Size(420, 1800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create(store: store)))!;
    await tester.pumpWidget(h.app(overrides: [
      watermarkOperationProvider.overrideWith((ref) => WatermarkPdfOperation(stamper,
          validatePages: (_, e) async => e, stampVisible: (_, _, _, _) async => true)),
    ]));
    await tester.pump(const Duration(milliseconds: 100));
    h.gateway.nextPdfs = picked;
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-watermark'));
    await settle(tester);
    if (picked.isNotEmpty) {
      await tester.tap(find.byType(PickerDropCard));
      await settle(tester, 20);
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  PrimaryActionBar bar(WidgetTester tester) => tester.widget<PrimaryActionBar>(find.byType(PrimaryActionBar));
  Finder stamps() =>
      find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('wmk-stamp-'));
  ProviderContainer c(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen, skipOffstage: false)));

  testWidgets('S36: banner with gap; empty → Choose PDF; the "on top" note', (tester) async {
    await open(tester);
    expect(find.byType(WatermarkScreen), findsOneWidget);
    expect(find.byType(AppBottomBanner), findsOneWidget);
    expect(find.text('The watermark is added on top of the page.'), findsOneWidget);
    expect((bar(tester).onPressed, bar(tester).helper), (null, 'Choose PDF'));
    await finish(tester);
  });

  testWidgets('live preview: "CONFIDENTIAL" diagonal on page 1; empty text → no stamp + "Enter watermark text"',
      (tester) async {
    await open(tester, picked: [pdf()]);
    expect(stamps(), findsOneWidget);
    expect(bar(tester).onPressed, isNotNull);
    expect(find.text('-35°'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wmk-text')), '');
    await settle(tester);
    expect(stamps(), findsNothing);
    expect((bar(tester).onPressed, bar(tester).helper), (null, 'Enter watermark text'));
    await finish(tester);
  });

  testWidgets('Tile → 12 stamps on the preview; the position resets the rotation (centre → 0°)', (tester) async {
    await open(tester, picked: [pdf()]);
    await tester.tap(find.byKey(const ValueKey('wmk-position')));
    await settle(tester);
    await tester.tap(find.text('Tile').last);
    await settle(tester);
    expect(stamps(), findsNWidgets(12));
    await tester.tap(find.byKey(const ValueKey('wmk-position')));
    await settle(tester);
    await tester.tap(find.text('Centre').last);
    await settle(tester);
    expect(find.text('0°'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('pages: Even → page 1 has no stamp, page 2 has; Range "1-999" → the error, Run disabled', (tester) async {
    await open(tester, picked: [pdf()]);
    await tester.tap(find.text('Even'));
    await settle(tester);
    expect(stamps(), findsNothing, reason: 'page 1 is odd');
    await tester.drag(find.byKey(const ValueKey('wmk-preview')), const Offset(-400, 0));
    await settle(tester);
    expect(stamps(), findsOneWidget, reason: 'page 2');
    await tester.tap(find.text('Range'));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('wmk-range')), '1-999');
    await settle(tester);
    expect(find.text('Use page numbers like 1-3, 5'), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('image mode: "Choose image" until a logo is picked; a PNG is used as is; size defaults to 30%',
      (tester) async {
    await open(tester, picked: [pdf()]);
    await tester.tap(find.text('Image'));
    await settle(tester);
    expect(find.text('Choose image'), findsWidgets);
    expect(bar(tester).onPressed, isNull);
    expect(find.text('30%'), findsOneWidget);
    final logo = p.join(dir.path, 'logo.png');
    File(logo).writeAsBytesSync(img.encodePng(img.Image(width: 200, height: 100, numChannels: 4)));
    h.gateway.nextImages = [
      PickedFile(
          path: logo,
          displayName: 'logo.png',
          type: SniffedType.png,
          sizeBytes: 1,
          image: const ImageMeta(format: SniffedType.png, width: 200, height: 100, hasAlpha: true)),
    ];
    await act(tester, () => tester.tap(find.widgetWithText(PickerDropCard, 'Choose image')));
    expect(stamps(), findsOneWidget);
    expect(bar(tester).onPressed, isNotNull);
    await finish(tester);
  });

  testWidgets('Run: the job stamps the selected pages; the text style is remembered (FR-WMK-10), style-only history',
      (tester) async {
    await open(tester, picked: [pdf()]);
    await tester.tap(find.text('Odd'));
    await settle(tester);
    await act(tester, () => tester.tap(find.text('Add watermark')));
    await settle(tester, 20);
    final done = c(tester).read(jobsProvider).values.single.state as JobCompleted;
    expect(done.result.outputName, 'report_watermarked.pdf');
    expect(stamper.got!.map((s) => s.pageIndex).toSet(), {0, 2});
    expect(stamper.got!.every((s) => s.opacity == 0.25), isTrue);
    final saved = jsonDecode(h.store.get('wmk_last_text_style')! as String) as Map;
    expect((saved['text'], saved['position'], saved['opacity']), ('CONFIDENTIAL', 'diagonal', 25));
    final row = (await tester.runAsync(() => h.db.select(h.db.operations).get()))!.single;
    expect(row.optionsJson, isNot(contains('CONFIDENTIAL')));
    await finish(tester);
  });

  testWidgets('the remembered style is the starting point next time', (tester) async {
    await open(tester, picked: [pdf()], store: {
      'wmk_last_text_style': const WatermarkTextStyle(
              text: 'DRAFT', colour: 0xFF1565C0, bold: false, position: WatermarkPosition.topRight, sizePct: 40, opacityPct: 50, rotation: 0)
          .toJson(),
    });
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('Top right'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a locked PDF → "Unlock it first" (FR-WMK-01)', (tester) async {
    await open(tester, picked: [pdf(locked: true)]);
    expect(find.text('This PDF is password-protected. Unlock it first.'), findsOneWidget);
    expect(bar(tester).onPressed, isNull);
    await finish(tester);
  });
}
