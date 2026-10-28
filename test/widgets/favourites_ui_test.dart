// T8.11 — Favourites on Home, the long-press sheet, S26 and the tool ⋮
// (RELEASE_V1_1 FR-FAV-01…03, §8.2: row hidden when empty, 7th pin
// message, a11y custom action).
import 'dart:async';
import 'dart:convert';

import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/favourites/favourites_controller.dart';
import 'package:docukit/features/favourites/favourites_ui.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<TestHarness> open(WidgetTester tester, {List<ToolId> pinned = const []}) async {
    tester.view.physicalSize = const Size(400, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = (await tester.runAsync(() => TestHarness.create(store: {
          if (pinned.isNotEmpty) SettingsRepository.kFavouriteTools: jsonEncode([for (final t in pinned) t.name]),
        })))!;
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  List<ToolId> favs(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen))).read(favouritesProvider);

  Finder card(String title) => find.ancestor(of: find.text(title), matching: find.byType(ToolCard));

  testWidgets('no row when nothing is pinned; long-press → Add → the row appears (FR-FAV-01/02)', (tester) async {
    await open(tester);
    expect(find.byType(FavouriteChip), findsNothing);
    expect(find.text('Favourites'), findsNothing);
    await tester.longPress(card('Merge PDFs'));
    await tester.pumpAndSettle();
    expect(find.text('Combine files into one'), findsWidgets, reason: 'the sheet shows the description');
    await tester.tap(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.widgetWithText(FavouriteChip, 'Merge PDFs'), findsOneWidget);
    expect(favs(tester), [ToolId.pdfMerge]);
    // The same sheet now offers Remove.
    await tester.longPress(card('Merge PDFs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from favourites'));
    await tester.pumpAndSettle();
    expect(find.byType(FavouriteChip), findsNothing);
    await finish(tester);
  });

  testWidgets('the row keeps the pinned order', (tester) async {
    await open(tester, pinned: [ToolId.pdfSplit, ToolId.imageCompress, ToolId.pdfMerge]);
    // The row scrolls sideways and builds only the chips on screen.
    final chips = tester.widgetList<FavouriteChip>(find.byType(FavouriteChip)).map((c) => c.tool.id).toList();
    expect(chips, [ToolId.pdfSplit, ToolId.imageCompress, ToolId.pdfMerge].take(chips.length));
    expect(chips.length, greaterThanOrEqualTo(2));
    await finish(tester);
  });

  testWidgets('a 7th pin shows "You can pin up to 6 tools. Remove one first." (FR-FAV-02)', (tester) async {
    final six = [ToolId.imageCompress, ToolId.imageResize, ToolId.imageConvert, ToolId.imageToPdf, ToolId.pdfMerge, ToolId.pdfOrganize];
    await open(tester, pinned: six);
    await tester.longPress(card('Split PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to favourites'));
    await tester.pump();
    expect(find.text('You can pin up to 6 tools. Remove one first.'), findsOneWidget);
    expect(favs(tester), six);
    await finish(tester);
  });

  testWidgets('each card has the a11y custom action "Add to favourites" (FR-FAV-01)', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(
      tester.getSemantics(card('Image Resizer')),
      isSemantics(customActions: [const CustomSemanticsAction(label: 'Add to favourites')]),
    );
    handle.dispose();
    await finish(tester);
  });

  testWidgets('Edit → S26: Move down and Remove; Done closes (FR-FAV-03)', (tester) async {
    await open(tester, pinned: [ToolId.pdfMerge, ToolId.pdfSplit, ToolId.imageCompress]);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    expect(find.text('Move up'), findsNothing, reason: 'first item can only go down');
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    expect(favs(tester), [ToolId.pdfSplit, ToolId.pdfMerge, ToolId.imageCompress]);
    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from favourites'));
    await tester.pumpAndSettle();
    expect(favs(tester), [ToolId.pdfSplit, ToolId.pdfMerge]);
    expect(find.byTooltip('Drag to reorder'), findsNWidgets(2));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Drag to reorder'), findsNothing);
    await finish(tester);
  });

  testWidgets('a tool screen\'s ⋮ pins and unpins the tool (FR-FAV-01)', (tester) async {
    await open(tester);
    unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/tool/pdf-split'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));
    expect(container.read(favouritesProvider), [ToolId.pdfSplit]);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from favourites'));
    await tester.pumpAndSettle();
    expect(container.read(favouritesProvider), isEmpty);
    await finish(tester);
  });
}
