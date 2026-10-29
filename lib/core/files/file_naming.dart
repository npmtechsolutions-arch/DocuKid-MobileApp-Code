import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

/// File naming (ARCHITECTURE §6.3, FR-FILE-03).
///
/// Note: Unicode NFC normalisation is not applied — Dart has no built-in
/// normaliser and adding one needs an ADR (see DECISIONS ADR-018).
const maxNameUnits = 120;

final _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
final _spaces = RegExp(r'\s+');

String stripExtension(String name) {
  final ext = p.extension(name);
  if (ext.isEmpty || ext.length > 6) return name;
  return name.substring(0, name.length - ext.length);
}

String safeBaseName(String input, {bool removeExtension = true}) {
  var s = removeExtension ? stripExtension(input) : input;
  s = s.replaceAll(_illegal, '_').replaceAll(_spaces, ' ');
  s = _trimDotsAndSpaces(s);
  if (s.isEmpty) return 'DocuKit';
  return truncateUnits(s, maxNameUnits);
}

String _trimDotsAndSpaces(String s) {
  var start = 0;
  var end = s.length;
  while (start < end && (s[start] == '.' || s[start] == ' ')) {
    start++;
  }
  while (end > start && (s[end - 1] == '.' || s[end - 1] == ' ')) {
    end--;
  }
  return s.substring(start, end);
}

/// Truncates to [max] UTF-16 units without splitting a surrogate pair.
String truncateUnits(String s, int max) {
  if (s.length <= max) return s;
  var end = max;
  final unit = s.codeUnitAt(end - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) end--; // high surrogate would be orphaned
  return s.substring(0, end);
}

enum NamingTool { imageCompress, imageResize, imageToPdf, pdfMerge, pdfOrganize, pdfExtract, pdfCompress }

/// Scan Document (FR-SCN-16): `Scan_yyyyMMdd_HHmm`, then `.pdf` or `_p01.jpg`….
String defaultScanBaseName(DateTime now) => 'Scan_${DateFormat('yyyyMMdd_HHmm').format(now)}';

/// The JPG for page [index] (0-based) of a scan saved as images.
String scanJpgName(String base, int index) => '${base}_p${(index + 1).toString().padLeft(2, '0')}.jpg';

/// Text Recognition's `.txt` output (FR-OCR-09): `<base>_text.txt`.
String ocrTxtName(String base) => '${base}_text.txt';

String defaultOutputName(
  NamingTool tool, {
  String? firstInputName,
  required DateTime now,
  String ext = 'pdf',
  int? width,
  int? height,
}) {
  final base = safeBaseName(firstInputName ?? 'DocuKit');
  final stamp = DateFormat('yyyyMMdd_HHmm').format(now);
  return switch (tool) {
    NamingTool.imageCompress => '${base}_compressed.$ext',
    NamingTool.imageResize => '${base}_${width ?? 0}x${height ?? 0}.$ext',
    NamingTool.imageToPdf => 'Images_$stamp.pdf',
    NamingTool.pdfMerge => 'Merged_$stamp.pdf',
    NamingTool.pdfOrganize => '${base}_edited.pdf',
    NamingTool.pdfExtract => '${base}_extract.pdf', // FR-EXT-03
    NamingTool.pdfCompress => '${base}_reduced.pdf',
  };
}

/// Appends " (n)" before the extension until [exists] is false.
String uniqueName(String name, bool Function(String candidate) exists) {
  if (!exists(name)) return name;
  final ext = p.extension(name);
  final base = name.substring(0, name.length - ext.length);
  for (var n = 1;; n++) {
    final candidate = '$base ($n)$ext';
    if (!exists(candidate)) return candidate;
  }
}

String uniqueIn(Directory dir, String name) =>
    uniqueName(name, (c) => File(p.join(dir.path, c)).existsSync());

/// Joins a user-edited base name with a fixed extension (D3).
String withExtension(String base, String ext) {
  final b = safeBaseName(base, removeExtension: false);
  final e = ext.startsWith('.') ? ext : '.$ext';
  return truncateUnits(b, maxNameUnits - e.length) + e;
}

/// Keeps the extension and sanitises the base (FR-FILE-03).
String safeOutputName(String name) {
  final ext = p.extension(name);
  final base = ext.isEmpty ? name : name.substring(0, name.length - ext.length);
  return withExtension(base, ext.isEmpty ? 'bin' : ext);
}

/// Safe names, unique within the list ignoring case (folders and ZIP readers
/// on Windows/macOS are case-insensitive), in input order: save many and ZIP
/// entries (RELEASE_V1_1 §4.4/§4.5).
List<String> uniqueNames(List<String> names) {
  final used = <String>{};
  final out = <String>[];
  for (final n in names) {
    final name = uniqueName(safeOutputName(n), (c) => used.contains(c.toLowerCase()));
    used.add(name.toLowerCase());
    out.add(name);
  }
  return out;
}
