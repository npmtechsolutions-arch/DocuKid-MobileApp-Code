// T11.6 — signature creator logic (RELEASE_V1_4 §4.7, §5, §8.1; FR-SIG-02,
// 04, 10), written before the implementation: stroke smoothing and ink
// bounds, the PNG export (transparent, cropped to the ink + 8 px), photo
// background removal on a synthetic image, and the saved-signature repository
// (opt-in, max 3, deletes files at once).
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/pdf_sign/application/ink.dart';
import 'package:docukit/features/pdf_sign/application/photo_signature.dart';
import 'package:docukit/features/pdf_sign/application/signature_models.dart';
import 'package:docukit/features/pdf_sign/application/signature_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('sig'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('ink (FR-SIG-02)', () {
    test('smoothing: a midpoint quadratic path through the stroke; one point is a dot', () {
      final path = smoothStrokePath(const [Offset(0, 0), Offset(10, 0), Offset(20, 10), Offset(30, 10)]);
      final b = path.getBounds();
      expect(b.left, closeTo(0, 0.01));
      expect(b.right, closeTo(30, 0.01));
      expect(b.bottom, lessThanOrEqualTo(10.01));
      final dot = smoothStrokePath(const [Offset(5, 5)]).getBounds();
      expect(dot.width, greaterThan(0), reason: 'a tap leaves a mark');
    });

    test('bounds: every stroke, widened by half the pen; empty strokes → null', () {
      final strokes = [
        const InkStroke([Offset(10, 20), Offset(50, 25)]),
        const InkStroke([Offset(30, 60)]),
      ];
      expect(inkBounds(strokes, 4), const Rect.fromLTRB(8, 18, 52, 62));
      expect(inkBounds(const [], 4), isNull);
    });

    test('thickness and colour values', () {
      expect(InkThickness.values.map((t) => t.width), orderedEquals([2.0, 3.5, 5.5]));
      expect(InkColour.black.color, const Color(0xFF111111));
      expect(InkColour.blue.color, const Color(0xFF1A3FB0));
    });

    testWidgets('export: transparent PNG cropped to the ink + 8 px at 3×, ink in the chosen colour', (tester) async {
      final out = p.join(dir.path, 'sig.png');
      final r = (await tester.runAsync(() => exportInkPng(
            const [InkStroke([Offset(100, 100), Offset(200, 100)])],
            colour: InkColour.blue,
            thickness: InkThickness.medium,
            outPath: out,
          )))!;
      final im = img.decodePng(File(out).readAsBytesSync())!;
      // 100 + 3.5 pt wide, 3.5 tall, at 3× → 311 × 11 px, + 2 × 8 px padding.
      expect((im.width, im.height), (r.widthPx, r.heightPx));
      expect(im.width, inInclusiveRange(325, 329));
      expect(im.height, inInclusiveRange(25, 29));
      expect(im.getPixel(0, 0).a, 0);
      expect(im.getPixel(im.width ~/ 2, im.height ~/ 2).a, 255);
      final ink = im.getPixel(im.width ~/ 2, im.height ~/ 2);
      expect((ink.r, ink.g, ink.b), (0x1A, 0x3F, 0xB0));
    });
  });

  group('photo background removal (FR-SIG-04, §8.1)', () {
    // Off-white paper with blue ink in the middle and a light grey smudge.
    img.Image photo() {
      final im = img.Image(width: 300, height: 120);
      img.fill(im, color: img.ColorRgb8(240, 238, 230));
      img.fillRect(im, x1: 100, y1: 50, x2: 200, y2: 70, color: img.ColorRgb8(25, 50, 160));
      img.fillRect(im, x1: 20, y1: 10, x2: 40, y2: 20, color: img.ColorRgb8(200, 200, 200));
      return im;
    }

    test('default cleanup 55: ink kept (darkened 20%, still blue), paper and light smudges transparent, cropped', () {
      final out = removeSignatureBackground(photo(), cleanup: 55)!;
      expect((out.width, out.height), (101, 21), reason: 'cropped to the ink');
      final ink = out.getPixel(50, 10);
      expect(ink.a, 255);
      expect((ink.r, ink.g, ink.b), (20, 40, 128), reason: 'darkened 20%; blue stays blue');
      expect(out.numChannels, 4);
    });

    test('the slider: 0 keeps almost nothing, 100 keeps the smudge too; a blank page → null', () {
      expect(removeSignatureBackground(photo(), cleanup: 0), isNull, reason: 'threshold 0: nothing is dark enough');
      final all = removeSignatureBackground(photo(), cleanup: 100)!;
      expect(all.width, greaterThan(101), reason: 'the grey smudge counts as ink at 100');
      final blank = img.Image(width: 50, height: 50);
      img.fill(blank, color: img.ColorRgb8(245, 245, 245));
      expect(removeSignatureBackground(blank, cleanup: 55), isNull);
    });

    test('long edge ≤ 2000 px before processing', () {
      final big = img.Image(width: 4000, height: 1000);
      img.fill(big, color: img.ColorRgb8(240, 240, 240));
      img.fillRect(big, x1: 1000, y1: 400, x2: 3000, y2: 600, color: img.ColorRgb8(0, 0, 0));
      final out = removeSignatureBackground(big, cleanup: 55)!;
      expect(out.width, lessThanOrEqualTo(1001));
    });
  });

  group('saved signatures (FR-SIG-10, §5.1–5.2)', () {
    late MemoryStore store;
    late SignatureRepository repo;
    final protected = <String>[];
    Future<String> png(String name) async =>
        (File(p.join(dir.path, name))..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4, numChannels: 4)))).path;

    setUp(() {
      store = MemoryStore({});
      protected.clear();
      repo = SignatureRepository(SettingsRepository(store), Directory(p.join(dir.path, 'support', 'signatures')),
          protect: (path) async => protected.add(path), clock: () => DateTime(2026, 10, 30, 9));
    });

    test('nothing saved by default; save copies into signatures/ (excluded from backup) and indexes it', () async {
      expect(repo.list(), isEmpty);
      final src = await png('a.png');
      final s = await repo.save(src, SignatureKind.draw);
      expect(File(repo.pathOf(s)).existsSync(), isTrue);
      expect(p.dirname(repo.pathOf(s)), endsWith('signatures'));
      expect(File(src).existsSync(), isTrue, reason: 'a copy');
      expect(protected, containsAll([p.dirname(repo.pathOf(s)), repo.pathOf(s)]));
      final json = jsonDecode(store.get('saved_signatures')! as String) as List;
      expect(json.single, {'id': s.id, 'file': '${s.id}.png', 'createdAt': DateTime(2026, 10, 30, 9).toIso8601String(), 'kind': 'draw'});
      expect(repo.list().single.kind, SignatureKind.draw);
    });

    test('max 3: a fourth is refused (SignatureLimitReached), nothing written', () async {
      for (var i = 0; i < 3; i++) {
        await repo.save(await png('$i.png'), SignatureKind.type);
      }
      expect(repo.isFull, isTrue);
      await expectLater(repo.save(await png('x.png'), SignatureKind.photo), throwsA(isA<SignatureLimitReached>()));
      expect(Directory(p.join(dir.path, 'support', 'signatures')).listSync().length, 3);
    });

    test('delete removes the file at once; delete all empties both; a missing file drops out of the list', () async {
      final a = await repo.save(await png('a.png'), SignatureKind.draw);
      final b = await repo.save(await png('b.png'), SignatureKind.type);
      await repo.delete(a.id);
      expect(File(repo.pathOf(a)).existsSync(), isFalse);
      expect(repo.list().map((s) => s.id), [b.id]);
      File(repo.pathOf(b)).deleteSync();
      expect(repo.list(), isEmpty, reason: 'only signatures whose file exists');
      await repo.save(await png('c.png'), SignatureKind.draw);
      await repo.deleteAll();
      expect(repo.list(), isEmpty);
      expect(Directory(p.join(dir.path, 'support', 'signatures')).listSync(), isEmpty);
    });

    test('a damaged index reads as empty', () {
      store.setString('saved_signatures', '{not json');
      expect(repo.list(), isEmpty);
    });
  });
}
