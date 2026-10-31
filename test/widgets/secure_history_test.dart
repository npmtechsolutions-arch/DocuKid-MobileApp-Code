// T11.10 — R57 (RELEASE_V1_4 §5.3, FR-PRT-07, FR-UNL-07): Protect / Unlock
// history entries: no password anywhere in Details, the protected output shows
// a lock instead of a page, and "Run again" opens the tool with an empty field.
import 'dart:async';
import 'dart:io';

import 'package:docukit/core/widgets/pdf_thumbnail.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/features/history/details_screen.dart';
import 'package:docukit/features/home/home_screen.dart';
import 'package:docukit/features/pdf_protect/presentation/protect_screen.dart';
import 'package:docukit/features/pdf_unlock/presentation/unlock_screen.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  /// A finished job as the runner records it: options `{}` and the output file.
  Future<void> row(TestHarness h, String id, ToolId tool, String name, Map<String, Object?> meta) async {
    final repo = HistoryRepository(h.db);
    final now = DateTime(2026, 10, 31, 9);
    await repo.insertRunning(id: id, tool: tool, createdAt: now, inputs: const [], options: const {});
    final dir = Directory(p.join(h.paths.outputsRoot.path, id))..createSync(recursive: true);
    File(p.join(dir.path, name)).writeAsStringSync('%PDF');
    await repo.complete(id,
        finishedAt: now,
        duration: const Duration(seconds: 2),
        outputName: name,
        outputMime: 'application/pdf',
        outputBytes: 4,
        outputRelPath: p.join(id, name),
        outputMeta: meta);
  }

  for (final (tool, name, meta, screen) in [
    (ToolId.pdfProtect, 'statement_protected.pdf', {'bytes': 4, 'pages': 3, 'encrypted': true}, ProtectScreen),
    (ToolId.pdfUnlock, 'statement_unlocked.pdf', {'bytes': 4, 'pages': 3}, UnlockScreen),
  ]) {
    testWidgets('R57 ${tool.name}: Details has no password; Run again opens the tool with an empty password field',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final h = (await tester.runAsync(TestHarness.create))!;
      await tester.runAsync(() => row(h, 'op-1', tool, name, meta));
      await tester.pumpWidget(h.app());
      await tester.pump(const Duration(milliseconds: 100));
      unawaited(GoRouter.of(tester.element(find.byType(HomeScreen))).push('/history/op-1'));
      await settle(tester);
      expect(find.byType(DetailsScreen), findsOneWidget);
      // Nothing that looks like a password field or value is on the page.
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('assword'), findsNothing);
      if (tool == ToolId.pdfProtect) expect(find.byType(LockedPdfPreview), findsOneWidget, reason: "can't render without it");
      await tester.scrollUntilVisible(find.text('Run again with these settings'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Run again with these settings'));
      await settle(tester);
      expect(find.byType(screen), findsOneWidget);
      for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(f.controller!.text, isEmpty, reason: 'no password restored');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
