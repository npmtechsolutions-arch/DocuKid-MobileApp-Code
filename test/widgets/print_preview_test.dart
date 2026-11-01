// T13.5 — S48 Print preview (RELEASE_PRINT §3, §3.3, §3.5, §8): the sheet
// view and counts, the Print button's states (no file, invalid range, no
// pages, building, ready, locked, unavailable), outcomes (sent snackbar,
// silent cancel, failure banner), the help sheet, image layouts with the
// passport count, the banner with its gap, and no interstitial after printing.
import 'dart:async';

import 'package:docukit/core/ads/ads_service.dart';
import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/print/print_gateway.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/print/application/print_preview_controller.dart';
import 'package:docukit/features/print/presentation/print_help_sheet.dart';
import 'package:docukit/features/print/presentation/print_preview_screen.dart';
import 'package:docukit/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

class _CountingAds extends NoAdsService {
  var interstitials = 0;
  @override
  Future<FullScreenAd?> loadInterstitial() async {
    interstitials++;
    return null;
  }
}

void main() {
  late TestHarness h;

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, PrintRequest? request, {AdsService ads = const NoAdsService()}) async {
    tester.view.physicalSize = const Size(420, 2400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app(ads: ads));
    await tester.pump(const Duration(milliseconds: 100));
    final home = tester.element(find.byType(HomeScreen));
    ProviderScope.containerOf(home).read(printRequestProvider.notifier).set(request);
    unawaited(GoRouter.of(home).push('/print/preview'));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  VoidCallback? printButton(WidgetTester tester, String label) => tester
      .widget<ButtonStyleButton>(find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()))
      .onPressed;

  final pdf = PrintRequest([fakePdf('Report.pdf', pages: 10)]);

  testWidgets('ready: sheet view, "Sheet 1 of 2", thumbnails, Print 2 sheets enabled, banner with the gap, help in the app bar',
      (tester) async {
    await open(tester, pdf);
    expect(find.byType(PrintPreviewScreen), findsOneWidget);
    expect(find.text('Print preview'), findsOneWidget);
    expect(find.text('Sheet 1 of 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('prn-sheets')), findsOneWidget);
    expect(find.byKey(const ValueKey('prn-thumbs')), findsOneWidget);
    expect(printButton(tester, 'Print 2 sheets'), isNotNull);
    expect(find.text('Copies, colour and two-sided printing are set in the next step.'), findsOneWidget);
    final banner = tester.widget<AppBottomBanner>(
        find.descendant(of: find.byType(PrintPreviewScreen), matching: find.byType(AppBottomBanner)));
    expect(banner.separated, isTrue, reason: '24 dp gap + divider');
    expect(find.byTooltip("Can't find your printer?"), findsOneWidget);
    // PDF input: Pages and Pages per sheet; no image Layout.
    expect(find.text('Pages per sheet'), findsOneWidget);
    expect(find.text('Passport photo sheet'), findsNothing);
    await finish(tester);
  });

  testWidgets('Print → system dialog → "Sent to printer"; no interstitial', (tester) async {
    final ads = _CountingAds();
    await open(tester, pdf, ads: ads);
    await tester.tap(find.text('Print 2 sheets'));
    await settle(tester);
    expect(h.printGateway.printed.single.jobName, 'Report');
    expect(find.text('Sent to printer'), findsOneWidget);
    expect(ads.interstitials, 0);
    await finish(tester);
  });

  testWidgets('cancelled → no message; failed → banner with help and Try again', (tester) async {
    await open(tester, pdf);
    h.printGateway.outcome = PrintOutcome.cancelled;
    await tester.tap(find.text('Print 2 sheets'));
    await settle(tester);
    expect(find.text('Sent to printer'), findsNothing);
    expect(find.byKey(const ValueKey('prn-failed')), findsNothing);
    h.printGateway.outcome = PrintOutcome.failed;
    await tester.tap(find.text('Print 2 sheets'));
    await settle(tester);
    expect(find.text('Printing failed. Check that the printer is on and connected.'), findsOneWidget);
    final failed = find.byKey(const ValueKey('prn-failed'));
    expect(find.descendant(of: failed, matching: find.text("Can't find your printer?")), findsOneWidget);
    h.printGateway.outcome = PrintOutcome.sent;
    await tester.tap(find.descendant(of: failed, matching: find.text('Try again')));
    await settle(tester);
    expect(h.printGateway.printed, hasLength(3));
    expect(find.text('Sent to printer'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('invalid range → field error, Print disabled with "Fix the page range"; fixing it re-enables', (tester) async {
    await open(tester, pdf);
    await tester.ensureVisible(find.text('Range'));
    await tester.tap(find.text('Range'));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('prn-range')), '3-99');
    await settle(tester);
    expect(find.text('Enter pages like 1-3, 5'), findsOneWidget);
    expect(find.text('Fix the page range'), findsOneWidget);
    expect(printButton(tester, 'Print 2 sheets'), isNull);
    await tester.enterText(find.byKey(const ValueKey('prn-range')), '3-5');
    await settle(tester, 20);
    expect(find.text('Fix the page range'), findsNothing);
    expect(printButton(tester, 'Print 2 sheets'), isNotNull);
    await finish(tester);
  });

  testWidgets('no pages (Even on 1 page) → message, Print disabled', (tester) async {
    await open(tester, PrintRequest([fakePdf('One.pdf', pages: 1)]));
    await tester.ensureVisible(find.text('Even'));
    await tester.tap(find.text('Even'));
    await settle(tester);
    expect(find.text('No pages to print with these settings.'), findsNWidgets(2), reason: 'banner + button helper');
    expect(printButton(tester, 'Print 2 sheets'), isNull);
    await finish(tester);
  });

  testWidgets('building: the last preview dimmed with progress and Cancel; Print disabled; Cancel keeps it', (tester) async {
    await open(tester, pdf);
    h.printComposer.gate = Completer<void>();
    await tester.ensureVisible(find.text('4'));
    await tester.tap(find.text('4'));
    await settle(tester);
    expect(find.byKey(const ValueKey('prn-cancel-build')), findsOneWidget);
    expect(find.text('Preparing sheet 1 of 2…'), findsOneWidget);
    expect(printButton(tester, 'Print 2 sheets'), isNull);
    expect(find.text('Sheet 1 of 2'), findsOneWidget, reason: 'the last good preview stays');
    await tester.ensureVisible(find.byKey(const ValueKey('prn-cancel-build')));
    await tester.tap(find.byKey(const ValueKey('prn-cancel-build')));
    await settle(tester);
    expect(find.byKey(const ValueKey('prn-cancel-build')), findsNothing);
    expect(printButton(tester, 'Print 2 sheets'), isNotNull);
    h.printComposer.gate!.complete();
    await settle(tester);
    await finish(tester);
  });

  testWidgets('no file → nothing built, Print disabled', (tester) async {
    await open(tester, null);
    expect(h.printComposer.calls, isEmpty);
    expect(printButton(tester, 'Print 0 sheets'), isNull);
    await finish(tester);
  });

  testWidgets('a password-protected PDF → "Unlock it first", nothing built', (tester) async {
    await open(tester, PrintRequest([fakePdf('Secret.pdf', encrypted: true)]));
    expect(find.text('This PDF is password-protected. Unlock it first, then print.'), findsNWidgets(2));
    expect(h.printComposer.calls, isEmpty);
    await finish(tester);
  });

  testWidgets('printing unavailable → Share instead, with the reason', (tester) async {
    await open(tester, pdf);
    h.printGateway.isAvailable = false;
    // Re-check, as after a failed build.
    final ctx = tester.element(find.byType(PrintPreviewScreen));
    ProviderScope.containerOf(ctx).read(printPreviewProvider('end').notifier).retry();
    await settle(tester);
    expect(find.text("Printing isn't available on this device."), findsOneWidget);
    expect(printButton(tester, 'Share'), isNotNull);
    await finish(tester);
  });

  testWidgets('images: Layout instead of Pages per sheet; the passport sheet sets 4 × 6 in and shows "8 photos"',
      (tester) async {
    await open(tester, PrintRequest([fakeImage('face.jpg'), fakeImage('b.jpg')]));
    expect(find.text('Pages per sheet'), findsNothing);
    expect(find.text('Layout'), findsOneWidget);
    await tester.ensureVisible(find.text('Passport photo sheet'));
    await tester.tap(find.text('Passport photo sheet'));
    await settle(tester, 20);
    expect(find.text('8 photos on 4 × 6 in'), findsOneWidget);
    expect(h.printComposer.calls.last.margins.name, 'none');
    expect(h.printComposer.calls.last.scaling.name, 'actual');
    expect(find.text('Scaling'), findsNothing, reason: 'the passport sheet always fills its photos');
    await finish(tester);
  });

  testWidgets('help sheet: the platform steps, the Save as PDF tip (Android) and the receipt-printer line', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PrintHelpSheet(ios: false)),
    ));
    await tester.pump();
    expect(find.text("Can't find your printer?"), findsOneWidget);
    expect(find.textContaining('Default Print Service'), findsOneWidget);
    expect(find.textContaining('Mopria'), findsOneWidget);
    expect(find.textContaining('Save as PDF'), findsOneWidget);
    expect(find.textContaining('receipt printers'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PrintHelpSheet(ios: true)),
    ));
    await tester.pump();
    expect(find.textContaining('AirPrint'), findsOneWidget);
    expect(find.textContaining('Save as PDF'), findsNothing);
    expect(find.textContaining('receipt printers'), findsOneWidget);
  });
}
