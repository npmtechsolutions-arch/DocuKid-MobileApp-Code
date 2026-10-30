// T11.6 — S34 signature creator + Settings → Saved signatures (RELEASE_V1_4
// §3, FR-SIG-02/03/04/10, §5.2): no ads on S34, Done disabled while empty,
// draw (undo/clear, colour/thickness remembered), type (3 fonts), photo
// (background cleanup), the opt-in save sheet (max 3), discard on back, and
// deleting saved signatures; Android backup rules exclude app files.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/ads/bottom_banner.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_sign/application/signature_models.dart';
import 'package:docukit/features/pdf_sign/application/signature_providers.dart';
import 'package:docukit/features/pdf_sign/presentation/signature_creator_screen.dart';
import 'package:docukit/features/settings/saved_signatures_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  late TestHarness h;
  late Future<Object?> result;

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      // Advance the clock too, so page transitions finish.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
  }

  /// A tap whose handler renders images or writes files needs real time.
  Future<void> act(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester, 20);
  }

  Future<void> open(WidgetTester tester, String mode, {Size size = const Size(400, 800)}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    result = GoRouter.of(tester.element(find.byType(HomeScreen))).push<Object?>('/tool/pdf-sign/create?mode=$mode');
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  FilledButton done(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'));
  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen, skipOffstage: false)));

  Future<void> draw(WidgetTester tester) async {
    final pad = tester.getCenter(find.byKey(const ValueKey('sig-pad')));
    final g = await tester.startGesture(pad - const Offset(80, 0));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(20, 6));
    }
    await g.up();
    await tester.pump();
  }

  Future<CreatedSignature> finishWith(WidgetTester tester, String choice) async {
    await act(tester, find.widgetWithText(FilledButton, 'Done'));
    expect(find.text('Save this signature for next time?'), findsOneWidget);
    await act(tester, find.text(choice));
    return (await tester.runAsync(() => result.timeout(const Duration(seconds: 5))))! as CreatedSignature;
  }

  testWidgets('draw: no ads; pad label; Done only with ink; undo / clear; landscape hint in portrait', (tester) async {
    await open(tester, 'draw');
    expect(find.byType(SignatureCreatorScreen), findsOneWidget);
    expect(find.byType(AppBottomBanner), findsNothing, reason: 'S34 has no ads (FR-SEC-03)');
    expect(find.bySemanticsLabel(RegExp('^Signature pad\\. Draw with one finger')), findsOneWidget);
    expect(find.text('Turn your phone for more room'), findsOneWidget);
    expect(done(tester).onPressed, isNull);
    await draw(tester);
    expect(done(tester).onPressed, isNotNull);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(done(tester).onPressed, isNull);
    await draw(tester);
    await draw(tester);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(done(tester).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('draw → Done → "Not now": a transparent PNG in the Sign draft; nothing saved; colour remembered',
      (tester) async {
    await open(tester, 'draw');
    await tester.tap(find.bySemanticsLabel('Blue'));
    await tester.tap(find.bySemanticsLabel('Thick'));
    await tester.pump();
    expect(h.store.get('sig_last_colour'), 'blue');
    expect(h.store.get('sig_last_thickness'), 'thick');
    await draw(tester);
    final sig = await finishWith(tester, 'Not now');
    expect((sig.kind, sig.savedId), (SignatureKind.draw, null));
    expect(p.split(sig.pngPath), containsAllInOrder(['jobs', 'sig']), reason: 'in the draft, deleted with it');
    final png = img.decodePng(File(sig.pngPath).readAsBytesSync())!;
    expect(png.getPixel(0, 0).a, 0);
    expect(container(tester).read(savedSignaturesProvider), isEmpty);
    await finish(tester);
  });

  testWidgets('"Save" keeps a copy in signatures/; at 3 the sheet says so and offers only "Not now"', (tester) async {
    await open(tester, 'draw');
    await draw(tester);
    final sig = await finishWith(tester, 'Save');
    final saved = container(tester).read(savedSignaturesProvider);
    expect(saved.single.id, sig.savedId);
    final repo = container(tester).read(signatureRepositoryProvider);
    expect(File(repo.pathOf(saved.single)).existsSync(), isTrue);
    expect(h.device.protectedPaths, contains(repo.dir.path), reason: 'excluded from backup (iOS)');
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() => container(tester).read(savedSignaturesProvider.notifier).save(sig.pngPath, SignatureKind.draw));
    }
    result = GoRouter.of(tester.element(find.byType(HomeScreen))).push<Object?>('/tool/pdf-sign/create?mode=draw');
    await settle(tester);
    await draw(tester);
    await act(tester, find.widgetWithText(FilledButton, 'Done'));
    expect(find.text('You can keep up to 3 signatures. Delete one to save this.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    await act(tester, find.text('Not now'));
    expect(container(tester).read(savedSignaturesProvider).length, 3);
    await finish(tester);
  });

  testWidgets('back with ink asks "Discard this signature?"; Cancel stays, Discard leaves', (tester) async {
    await open(tester, 'draw');
    await draw(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Discard this signature?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.byType(SignatureCreatorScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.byType(SignatureCreatorScreen), findsNothing);
    await finish(tester);
  });

  testWidgets('type: three live previews in the bundled fonts; Done needs a name; renders a PNG', (tester) async {
    await open(tester, 'type');
    expect(done(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('sig-name')), 'Neha Patel');
    await tester.pump();
    final previews = tester.widgetList(find.text('Neha Patel')).whereType<Text>().map((t) => t.style?.fontFamily).toSet();
    expect(previews, containsAll(['DancingScript', 'Sacramento', 'MrDafoe']));
    await tester.tap(find.bySemanticsLabel(RegExp('^Style 2')));
    await tester.pump();
    final sig = await finishWith(tester, 'Not now');
    expect(sig.kind, SignatureKind.type);
    expect(sig.aspect, greaterThan(2), reason: 'a name is wide');
    await finish(tester);
  });

  testWidgets('photo: the picked image is cleaned on a checkerboard; the slider re-runs it; Done keeps the ink',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    h = (await tester.runAsync(() => TestHarness.create()))!;
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('sigphoto')))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = img.Image(width: 300, height: 120);
    img.fill(photo, color: img.ColorRgb8(240, 238, 230));
    img.fillRect(photo, x1: 100, y1: 50, x2: 200, y2: 70, color: img.ColorRgb8(25, 50, 160));
    final src = p.join(dir.path, 'IMG_24.jpg');
    File(src).writeAsBytesSync(img.encodeJpg(photo, quality: 95));
    h.gateway.nextImages = [
      PickedFile(
          path: src,
          displayName: 'IMG_24.jpg',
          type: SniffedType.jpeg,
          sizeBytes: 1,
          image: const ImageMeta(format: SniffedType.jpeg, width: 300, height: 120)),
    ];
    h.images.onTransform = (inPath, outPath, t) async {
      File(outPath).writeAsBytesSync(File(inPath).readAsBytesSync());
      return EncodedImage(path: outPath, bytes: 1, width: 300, height: 120, format: ImageFormat.jpeg);
    };
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    result = GoRouter.of(tester.element(find.byType(HomeScreen))).push<Object?>('/tool/pdf-sign/create?mode=photo');
    await settle(tester, 40);
    expect(find.text('Background cleanup'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget, reason: 'the cleaned preview');
    expect(done(tester).onPressed, isNotNull);
    // Slide to 0: nothing is dark enough → the "No ink found" note, Done disabled.
    await tester.runAsync(() async {
      await tester.drag(find.byType(Slider), const Offset(-600, 0));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await settle(tester, 40);
    expect(find.text('No ink found. Try moving Background cleanup.'), findsOneWidget);
    expect(done(tester).onPressed, isNull);
    await tester.runAsync(() async {
      // A drag starts at the slider's centre (≈ 50), so a small one lands near the default.
      await tester.drag(find.byType(Slider), const Offset(10, 0));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await settle(tester, 40);
    expect(done(tester).onPressed, isNotNull);
    final sig = await finishWith(tester, 'Not now');
    expect(sig.kind, SignatureKind.photo);
    final png = img.decodePng(File(sig.pngPath).readAsBytesSync())!;
    expect((png.width, png.height), (101, 21), reason: 'cropped to the ink');
    await finish(tester);
  });

  testWidgets('Settings → Saved signatures: lists them, deletes one (file gone), then all', (tester) async {
    tester.view.physicalSize = const Size(400, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    h = (await tester.runAsync(() => TestHarness.create()))!;
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    final c = container(tester);
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('sigset')))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    final png = p.join(dir.path, 's.png');
    File(png).writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 4, numChannels: 4)));
    for (final k in [SignatureKind.draw, SignatureKind.type]) {
      await tester.runAsync(() => c.read(savedSignaturesProvider.notifier).save(png, k));
    }
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/settings'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Saved signatures').last, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Saved signatures').last);
    await settle(tester);
    expect(find.byType(SavedSignaturesScreen), findsOneWidget);
    expect(find.byTooltip('Delete'), findsNWidgets(2));
    final first = c.read(savedSignaturesProvider).first;
    final firstPath = c.read(signatureRepositoryProvider).pathOf(first);
    await tester.tap(find.byTooltip('Delete').first);
    await settle(tester);
    expect(find.text('Delete this saved signature?'), findsOneWidget);
    await act(tester, find.text('Delete').last);
    expect(File(firstPath).existsSync(), isFalse);
    expect(find.byTooltip('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete all saved signatures'));
    await settle(tester);
    await act(tester, find.text('Delete').last);
    expect(find.text('No saved signatures.'), findsOneWidget);
    expect(c.read(savedSignaturesProvider), isEmpty);
    await finish(tester);
  });

  test('Android: no backup and no device transfer for any app files, so signatures/ is excluded (ADR-023/050)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>([\\s\\S]*?)</$section>').firstMatch(rules)!.group(1)!;
      expect(body, contains('<exclude domain="file" />'), reason: '$section: appSupport (files/) excluded');
      expect(body, contains('<exclude domain="root" />'), reason: section);
    }
  });
}
