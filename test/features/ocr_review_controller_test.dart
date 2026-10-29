// T10.7 — the S31 controller (RELEASE_V1_3 §3.3, FR-OCR-08/16): pages loaded
// lazily from the review folder, edits kept in memory only, Copy all, Share
// (long text → a file), Save .txt, the 2 MB edit limit. Written before the
// implementation.
import 'dart:io';

import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/ocr/ocr_text_file.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/features/ocr/application/ocr_review_controller.dart';
import 'package:docukit/features/ocr/application/ocr_review_files.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  late AppPaths paths;

  setUp(() async => paths = await tempPaths());

  Future<void> seed(String jobId, List<String> pages, {List<bool>? low}) async {
    final w = OcrReviewWriter(paths.reviewDir(jobId).path);
    for (final (i, t) in pages.indexed) {
      await w.page(i, t, OcrReviewPage(words: t.split(' ').length, lowText: low?[i] ?? false, existingText: false));
    }
    await w.finish(pages.length, baseName: 'notes');
  }

  Future<ProviderContainer> load(String jobId) async {
    final c = ProviderContainer(overrides: [appPathsProvider.overrideWithValue(paths)]);
    addTearDown(c.dispose);
    c.listen(ocrReviewProvider(jobId), (_, _) {});
    for (var i = 0; i < 20 && c.read(ocrReviewProvider(jobId)).loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c;
  }

  test('loads the manifest; page text on demand; low-text flags', () async {
    await seed('j', ['Meeting notes', 'Budget approved', ''], low: [false, false, true]);
    final c = await load('j');
    final s = c.read(ocrReviewProvider('j'));
    expect((s.loading, s.unavailable, s.files!.pages.length, s.tooLong), (false, false, 3, false));
    expect(s.files!.pages.map((pg) => pg.lowText), [false, false, true]);
    expect(await c.read(ocrReviewProvider('j').notifier).textOf(1), 'Budget approved');
  });

  test('edits stay in memory, mark the page, and feed Copy all / Save .txt — never the files', () async {
    await seed('j', ['Meeting notes', 'Budget approved']);
    final c = await load('j');
    final ctrl = c.read(ocrReviewProvider('j').notifier);
    ctrl.edit(0, 'Meeting notes — 14 March');
    final s = c.read(ocrReviewProvider('j'));
    expect((s.edited, s.isEdited(0), s.isEdited(1)), (true, true, false));
    expect(await ctrl.allText(), 'Meeting notes — 14 March\n\nBudget approved', reason: 'no page markers');
    expect(File(OcrReviewFiles.textPath(paths.reviewDir('j').path, 0)).readAsStringSync(), 'Meeting notes',
        reason: 'the recognised text on disk is unchanged');
    final txt = await ctrl.writeTxt();
    expect(p.basename(txt), 'notes_text.txt');
    expect(await isValidOcrTxt(txt, pageCount: 2), isTrue);
    expect(File(txt).readAsStringSync(), contains('Meeting notes — 14 March'));
    expect(p.isWithin(paths.reviewDir('j').path, txt), isTrue, reason: 'deleted with the review folder');
  });

  test('editing back to the original clears the mark', () async {
    await seed('j', ['A page']);
    final c = await load('j');
    final ctrl = c.read(ocrReviewProvider('j').notifier);
    ctrl.edit(0, 'Changed');
    await ctrl.editChecked(0, 'A page');
    expect(c.read(ocrReviewProvider('j')).edited, isFalse);
  });

  test('Share: short text as text; over 100,000 characters as a .txt file', () async {
    await seed('j', ['short']);
    final c = await load('j');
    final short = await c.read(ocrReviewProvider('j').notifier).shareable();
    expect((short.text, short.filePath), ('short', null));
    c.read(ocrReviewProvider('j').notifier).edit(0, 'x' * 100001);
    final long = await c.read(ocrReviewProvider('j').notifier).shareable();
    expect(long.text, isNull);
    expect(p.basename(long.filePath!), 'notes_text.txt');
    expect(File(long.filePath!).lengthSync(), greaterThan(100000));
  });

  test('more than 2 MB of text: editing off (§3.3)', () async {
    await seed('j', ['a' * (1024 * 1024 + 10), 'b' * (1024 * 1024)]);
    final c = await load('j');
    expect(c.read(ocrReviewProvider('j')).tooLong, isTrue);
  });

  test('no review folder (left Result, or after a restart) → unavailable', () async {
    final c = await load('gone');
    final s = c.read(ocrReviewProvider('gone'));
    expect((s.loading, s.unavailable), (false, true));
  });

  test('Copy text on Result: from the review folder, or from the .txt when only that was saved', () async {
    await seed('j', ['One', 'Two']);
    expect(await ocrTextForCopy(reviewDir: paths.reviewDir('j').path), 'One\n\nTwo');
    final txt = File(p.join(paths.cacheRoot.path, 'x_text.txt'))..writeAsStringSync(formatOcrTxt(['First', 'Second']));
    expect(await ocrTextForCopy(txtPath: txt.path), 'First\n\nSecond');
    expect(await ocrTextForCopy(), '');
  });
}
