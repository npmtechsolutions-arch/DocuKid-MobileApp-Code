import 'package:docukit/core/files/file_naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeBaseName', () {
    test('strips the extension and illegal characters', () {
      expect(safeBaseName('a/b\\c:d*e?f"g<h>i|j.pdf'), 'a_b_c_d_e_f_g_h_i_j');
    });
    test('control characters become underscores', () {
      expect(safeBaseName('bad\u0001name.jpg'), 'bad_name');
    });
    test('collapses whitespace and trims dots/spaces', () {
      expect(safeBaseName('  ..my   file.. .jpg'), 'my file');
    });
    test('empty → DocuKit', () {
      expect(safeBaseName(''), 'DocuKit');
      expect(safeBaseName('...'), 'DocuKit');
      expect(safeBaseName('.jpg'), 'jpg'); // a dotfile has no extension
    });
    test('keeps emoji and non-Latin text', () {
      expect(safeBaseName('emoji_名前_📷 (copy).jpg'), 'emoji_名前_📷 (copy)');
    });
    test('truncates to 120 UTF-16 units', () {
      expect(safeBaseName('${'a' * 200}.jpg').length, 120);
    });
    test('never splits a surrogate pair', () {
      final s = '${'a' * 119}📷📷';
      final out = safeBaseName(s, removeExtension: false);
      expect(out.length, 119); // the emoji at 119–120 would be split → dropped
      expect(out, 'a' * 119);
    });
  });

  group('defaultOutputName', () {
    final now = DateTime(2026, 10, 22, 14, 5);
    test('per tool', () {
      expect(defaultOutputName(NamingTool.imageCompress, firstInputName: 'IMG_2041.HEIC', now: now, ext: 'jpg'),
          'IMG_2041_compressed.jpg');
      expect(
          defaultOutputName(NamingTool.imageResize,
              firstInputName: 'photo.jpg', now: now, ext: 'jpg', width: 413, height: 531),
          'photo_413x531.jpg');
      expect(defaultOutputName(NamingTool.imageToPdf, now: now), 'Images_20261022_1405.pdf');
      expect(defaultOutputName(NamingTool.pdfMerge, now: now), 'Merged_20261022_1405.pdf');
      expect(defaultOutputName(NamingTool.pdfOrganize, firstInputName: 'contract.pdf', now: now), 'contract_edited.pdf');
      expect(defaultOutputName(NamingTool.pdfCompress, firstInputName: 'brochure.pdf', now: now), 'brochure_reduced.pdf');
    });
  });

  group('uniqueName', () {
    test('appends (n) before the extension', () {
      final taken = {'a.pdf', 'a (1).pdf'};
      expect(uniqueName('a.pdf', taken.contains), 'a (2).pdf');
      expect(uniqueName('b.pdf', taken.contains), 'b.pdf');
    });
  });

  group('uniqueNames (save many, ZIP entries; RELEASE_V1_1 §4.4/§4.5)', () {
    test('de-duplicates within the list, case-insensitively, keeping order', () {
      expect(uniqueNames(['a.jpg', 'b.jpg', 'a.jpg', 'A.JPG', 'a (1).jpg']),
          ['a.jpg', 'b.jpg', 'a (1).jpg', 'A (2).JPG', 'a (1) (1).jpg']);
    });
    test('sanitises each name the same way as outputs', () {
      expect(uniqueNames(['x/y.jpg', 'x:y.jpg']), ['x_y.jpg', 'x_y (1).jpg']);
    });
  });

  group('withExtension / safeOutputName', () {
    test('keeps the extension and sanitises the base', () {
      expect(withExtension('my:report', 'pdf'), 'my_report.pdf');
      expect(safeOutputName('x/y.jpg'), 'x_y.jpg');
    });
    test('long names stay within 120 units including the extension', () {
      expect(withExtension('a' * 300, 'pdf').length, 120);
    });
  });
}
