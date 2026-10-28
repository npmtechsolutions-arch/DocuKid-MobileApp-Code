// T8.13 acceptance: every 1.1 string in COPY.md §8.1 exists in app_en.arb;
// T9.4 adds the 1.2 strings (§8.2). CLAUDE.md rule 8: COPY and ARB stay in step.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Not ARB strings by design (noted in COPY.md).
const notInArb = {'org_extract_done_name'}; // a file-name pattern, built in file_naming.dart

String camel(String snake) {
  final parts = snake.split('_');
  return parts.first + parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
}

/// "fav_add / remove" → fav_add, fav_remove; "inc_images_section / pdfs_section"
/// → inc_images_section, inc_pdfs_section (each alternative replaces as many
/// trailing segments as it has).
List<String> expand(String cell) {
  final alts = cell.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final first = alts.first;
  final segs = first.split('_');
  return [
    first,
    for (final a in alts.skip(1)) [...segs.take(segs.length - a.split('_').length), a].join('_'),
  ];
}

void main() {
  for (final (section, next, min) in [('8.1', '8.2', 60), ('8.2', '8.3', 30)]) {
    test('COPY.md §$section keys are all in app_en.arb', () {
      final copy = File('docs/COPY.md').readAsStringSync();
      final start = copy.indexOf('### $section ');
      final end = copy.indexOf('### $next ');
      expect(start, greaterThan(0));
      final arb = (jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map).keys.toSet();
      final keys = <String>[];
      for (final line in copy.substring(start, end).split('\n')) {
        final m = RegExp(r'^\|\s*([a-z0-9_ /]+?)\s*\|').firstMatch(line);
        if (m == null) continue;
        keys.addAll(expand(m.group(1)!));
      }
      expect(keys.length, greaterThan(min), reason: 'parsed the §$section table');
      final missing = [for (final k in keys) if (!notInArb.contains(k) && !arb.contains(camel(k))) '$k → ${camel(k)}'];
      expect(missing, isEmpty);
    });
  }

  test('expansion rule', () {
    expect(expand('fav_add / remove'), ['fav_add', 'fav_remove']);
    expect(expand('inc_images_section / pdfs_section'), ['inc_images_section', 'inc_pdfs_section']);
    expect(expand('p2i_res_72 / 150 / 300'), ['p2i_res_72', 'p2i_res_150', 'p2i_res_300']);
    expect(camel('tool_pdf_to_images_title'), 'toolPdfToImagesTitle');
  });

  test('the privacy policy says shared files stay on the device (RELEASE_V1_1 §6)', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    const sentence = 'Files you share into DocuKit from other apps are copied into the app and processed only on your device.';
    expect([for (var i = 1; i <= 5; i++) arb['privPolicyBody$i'] as String].any((p) => p.contains(sentence)), isTrue);
    expect(File('docs/RELEASE.md').readAsStringSync(), contains(sentence), reason: 'the hosted policy template matches');
  });
}
