import 'package:docukit/core/pdf/page_edit.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> src(List<PageEdit> l) => [for (final e in l) e.sourceIndex];

void main() {
  test('identity detection', () {
    expect(isIdentity(identityEdits(3), 3), isTrue);
    expect(isIdentity(identityEdits(3), 4), isFalse);
    expect(isIdentity(rotatePages(identityEdits(3), [0], 1), 3), isFalse);
    expect(isIdentity(moveOne(identityEdits(3), 0, 2), 3), isFalse);
  });

  test('move multiple keeps their relative order', () {
    final out = movePages(identityEdits(6), [4, 1], 0);
    expect(src(out), [1, 4, 0, 2, 3, 5]);
  });

  test('move to end', () {
    expect(src(movePages(identityEdits(4), [0, 1], 99)), [2, 3, 0, 1]);
  });

  test('moveOne', () {
    expect(src(moveOne(identityEdits(4), 3, 0)), [3, 0, 1, 2]);
  });

  test('rotate wraps both ways', () {
    var l = rotatePages(identityEdits(2), [0], 1);
    l = rotatePages(l, [0], 1);
    l = rotatePages(l, [0], 1);
    l = rotatePages(l, [0], 1);
    expect(l[0].rotationQuarterTurns, 0);
    expect(rotatePages(identityEdits(1), [0], -1)[0].rotationQuarterTurns, 3);
  });

  test('rotate touches only selected pages', () {
    final l = rotatePages(identityEdits(3), [1], 1);
    expect([for (final e in l) e.rotationQuarterTurns], [0, 1, 0]);
  });

  test('delete', () {
    expect(src(deletePages(identityEdits(4), [1, 2])), [0, 3]);
  });

  test('deleting every page is blocked', () {
    expect(() => deletePages(identityEdits(2), [0, 1]), throwsA(isA<EmptyDocumentException>()));
  });

  group('EditHistory', () {
    test('undo/redo', () {
      final h = EditHistory(identityEdits(3));
      h.push(deletePages(h.current, [0]));
      h.push(rotatePages(h.current, [0], 1));
      expect(h.canUndo, isTrue);
      expect(h.undo(), isTrue);
      expect(src(h.current), [1, 2]);
      expect(h.current[0].rotationQuarterTurns, 0);
      expect(h.redo(), isTrue);
      expect(h.current[0].rotationQuarterTurns, 1);
      expect(h.redo(), isFalse);
    });

    test('a new edit clears redo', () {
      final h = EditHistory(identityEdits(3));
      h.push(deletePages(h.current, [0]));
      h.undo();
      h.push(rotatePages(h.current, [0], 1));
      expect(h.canRedo, isFalse);
    });

    test('caps at 50 steps', () {
      final h = EditHistory(identityEdits(2));
      for (var i = 0; i < 80; i++) {
        h.push(rotatePages(h.current, [0], 1));
      }
      expect(h.undoDepth, 50);
      var undos = 0;
      while (h.undo()) {
        undos++;
      }
      expect(undos, 50);
    });
  });
}
