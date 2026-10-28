// T9.4 — S27 Scan entry (RELEASE_V1_2 §3, §8): ready, checking, preparing,
// offline, unavailable (Android / iOS wording), camera denied, unknown — each
// with its actions; pages returned; ?autostart=1. The ad slot is checked in
// banner_placement_test.dart.
import 'dart:async';

import 'package:docukit/core/scan/document_scanner.dart';
import 'package:docukit/core/widgets/common.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/image_to_pdf/presentation/image_to_pdf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  late TestHarness h;

  Future<void> open(WidgetTester tester, {String route = '/tool/scan'}) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    h = (await tester.runAsync(TestHarness.create))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 300));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push(route));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Lets the real directory/file IO of a scan finish between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('ready: title, body, Start scanning and Choose photos instead', (tester) async {
    await open(tester);
    expect(find.text('Scan Document'), findsWidgets);
    expect(find.text('Scan pages with your camera'), findsOneWidget);
    expect(find.text('Edges are found and straightened for you.'), findsOneWidget);
    expect(find.text('Start scanning'), findsOneWidget);
    expect(find.text('Have photos already?'), findsOneWidget);
    expect(find.text('Choose photos instead'), findsOneWidget);
    expect(h.scanner.scans, isEmpty, reason: 'no autostart');
    await finish(tester);
  });

  testWidgets('Choose photos instead → Images to PDF', (tester) async {
    await open(tester);
    await tester.tap(find.text('Choose photos instead'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ImageToPdfScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('pages returned → the page count shows, Start is gone', (tester) async {
    await open(tester);
    h.scanner.pagesToWrite = 3;
    await start(tester);
    expect(h.scanner.scans.single.maxPages, 50);
    expect(find.text('3 pages'), findsOneWidget);
    expect(find.text('Add pages'), findsOneWidget);
    expect(find.text('Start scanning'), findsNothing);
    await finish(tester);
  });

  testWidgets('cancelled → still the entry, no banner', (tester) async {
    await open(tester);
    h.scanner.nextOutcome = const ScanCancelled();
    await start(tester);
    expect(find.text('Start scanning'), findsOneWidget);
    expect(find.byType(InlineBanner), findsNothing);
    await finish(tester);
  });

  testWidgets('checking: the button shows a spinner and is disabled', (tester) async {
    await open(tester);
    final hold = Completer<void>();
    h.scanner.holdAvailability = hold;
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();
    final button = tester.widget<FilledButton>(find.byKey(const ValueKey('scan-start')));
    expect(button.onPressed, isNull);
    expect(find.descendant(of: find.byKey(const ValueKey('scan-start')), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    hold.complete();
    await tester.pump();
    await settle(tester);
    expect(find.text('2 pages'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('preparing: progress and Cancel, no Start; Cancel → back to the entry', (tester) async {
    await open(tester);
    h.scanner.nextAvailability = ScannerAvailability.needsDownload;
    h.scanner.nextPrepare = null;
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Getting the scanner ready…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Start scanning'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Start scanning'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const ValueKey('scan-start')));
    expect(button.onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 61)); // the cancelled wait runs out unseen
    expect(find.text('Start scanning'), findsOneWidget);
    expect(find.byType(InlineBanner), findsNothing);
    expect(h.scanner.scans, isEmpty);
    await finish(tester);
  });

  final banners = <String, (ScanErrorCode, String, List<String>)>{
    'offline': (ScanErrorCode.offline,
        'The scanner needs a one-time download. Connect to the internet and try again.', ['Try again']),
    'no Play services': (ScanErrorCode.noPlayServices,
        "Scanning needs Google Play services, which isn't on this phone.", ['Choose photos instead']),
    'device unsupported (iOS)': (ScanErrorCode.unsupported, "This device can't scan documents.", ['Choose photos instead']),
    'camera denied': (ScanErrorCode.cameraDenied, "DocuKit can't use the camera. Allow it in Settings.",
        ['Open Settings', 'Choose photos instead']),
    'unknown': (ScanErrorCode.unknown, 'The scanner closed unexpectedly. Try again.', ['Try again']),
  };
  for (final e in banners.entries) {
    testWidgets('${e.key}: banner text and actions', (tester) async {
      await open(tester);
      final (code, text, actions) = e.value;
      h.scanner.nextOutcome = ScanFailed(code);
      await start(tester);
      expect(find.text(text), findsOneWidget);
      final banner = find.ancestor(of: find.text(text), matching: find.byType(InlineBanner));
      for (final a in actions) {
        expect(find.descendant(of: banner, matching: find.widgetWithText(TextButton, a)), findsOneWidget, reason: a);
      }
      await finish(tester);
    });
  }

  testWidgets('Try again opens the scanner again', (tester) async {
    await open(tester);
    h.scanner.nextOutcome = const ScanFailed(ScanErrorCode.offline);
    await start(tester);
    h.scanner.nextOutcome = null;
    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pump();
    await settle(tester);
    expect(h.scanner.scans, hasLength(2));
    expect(find.text('2 pages'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Open Settings asks the system (camera denied)', (tester) async {
    await open(tester);
    h.scanner.nextAvailability = ScannerAvailability.cameraDenied;
    await start(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Open Settings'));
    await tester.pump();
    expect(h.device.settingsOpened, 1);
    expect(h.scanner.scans, isEmpty);
    await finish(tester);
  });

  testWidgets('a banner can be dismissed', (tester) async {
    await open(tester);
    h.scanner.nextOutcome = const ScanFailed(ScanErrorCode.unknown);
    await start(tester);
    await tester.tap(find.descendant(of: find.byType(InlineBanner), matching: find.byType(IconButton)));
    await tester.pump();
    expect(find.text('The scanner closed unexpectedly. Try again.'), findsNothing);
    await finish(tester);
  });

  testWidgets('?autostart=1 opens the scanner after the first frame (FR-SCN-24)', (tester) async {
    await open(tester, route: '/tool/scan?autostart=1');
    await settle(tester);
    expect(h.scanner.scans, hasLength(1));
    expect(find.text('2 pages'), findsOneWidget);
    await finish(tester);
  });
}
