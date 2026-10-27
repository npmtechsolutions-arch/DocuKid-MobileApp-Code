// UI_REFRESH §8 "Delete page: light haptic": the Organizer gives a light
// impact when pages are deleted (and none when the delete is blocked), and the
// spec table says so.
import 'dart:async';
import 'dart:io';

import 'package:docukit/features/home/home_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('UI_REFRESH §8 lists a light haptic for Delete page', () {
    final row = File('docs/UI_REFRESH.md').readAsLinesSync().firstWhere((l) => l.startsWith('| Delete page |'));
    expect(row.split('|').map((c) => c.trim()).toList()[3], 'light');
  });

  Future<List<String>> organizer(WidgetTester tester, {required int pages, required int select}) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final h = await tester.runAsync(() => TestHarness.create());
    h!.gateway.nextPdfs = [fakePdf('doc.pdf', pages: pages)];
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 200));
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-organize'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Choose PDF').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (var i = 1; i <= select; i++) {
      await tester.tap(find.bySemanticsLabel(RegExp('^Page $i of $pages')));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50)); // tiles also take double-tap
    }
    haptics.clear(); // only the delete's haptics count
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return haptics;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('deleting a page gives a light haptic', (tester) async {
    final haptics = await organizer(tester, pages: 3, select: 1);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await finish(tester);
  });

  testWidgets('a blocked delete (the only page) gives no haptic', (tester) async {
    final haptics = await organizer(tester, pages: 1, select: 1);
    expect(haptics, isEmpty);
    await finish(tester);
  });
}
