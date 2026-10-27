// Generates the TESTING.md §3 fixtures needed by regression R3–R13, with no
// real personal content. Usage:
//   dart run tool/make_fixtures.dart <out-dir>
// then push them to a device, e.g.
//   adb push <out-dir>/. /sdcard/Download/fixtures/
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final _rnd = Random(42);

/// A photo-like image: smooth gradient + noise, so JPEG sizes are realistic.
img.Image photo(int w, int h, {int noise = 24, int hue = 0}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final n = _rnd.nextInt(noise * 2 + 1) - noise;
      im.setPixelRgb(
        x,
        y,
        ((x * 255 ~/ w) + n + hue).clamp(0, 255),
        ((y * 255 ~/ h) + n).clamp(0, 255),
        (((x + y) * 255 ~/ (w + h)) + n - hue).clamp(0, 255),
      );
    }
  }
  return im;
}

/// Upright reference: a dark block marks the top-left corner.
img.Image marked(int w, int h) {
  final im = photo(w, h, noise: 8);
  img.fillRect(im, x1: 0, y1: 0, x2: w ~/ 4, y2: h ~/ 4, color: img.ColorRgb8(20, 20, 20));
  return im;
}

Future<Uint8List> textPdf(int pages) async {
  final doc = pw.Document();
  for (var i = 0; i < pages; i++) {
    doc.addPage(pw.Page(
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Fixture page ${i + 1}', style: const pw.TextStyle(fontSize: 24)),
        for (var p = 0; p < 12; p++)
          pw.Paragraph(text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' * 3),
      ]),
    ));
  }
  return doc.save();
}

Future<Uint8List> imagePdf(int pages, {int w = 1240, int h = 1754, int quality = 88}) async {
  final doc = pw.Document();
  for (var i = 0; i < pages; i++) {
    final jpg = img.encodeJpg(photo(w, h, noise: 40, hue: i * 7 % 60), quality: quality);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Image(pw.MemoryImage(jpg), fit: pw.BoxFit.cover),
    ));
  }
  return doc.save();
}

Future<Uint8List> mixedSizesPdf() async {
  final doc = pw.Document();
  for (final f in [PdfPageFormat.a4, PdfPageFormat.letter, PdfPageFormat.a4.landscape]) {
    doc.addPage(pw.Page(pageFormat: f, build: (_) => pw.Center(child: pw.Text('${f.width.round()}×${f.height.round()} pt'))));
  }
  return doc.save();
}

/// A one-page PDF with a Standard security handler whose /U doesn't match the
/// empty password, so readers (PDFium) must ask for a user password.
Uint8List encryptedPdf() {
  final hex = List.generate(32, (_) => _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  final objs = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] >>',
    '<< /Filter /Standard /V 1 /R 2 /O <$hex> /U <$hex> /P -44 >>',
  ];
  final b = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objs.length; i++) {
    offsets.add(b.length);
    b.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
  }
  final xref = b.length;
  b.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write('trailer\n<< /Size ${objs.length + 1} /Root 1 0 R /Encrypt 4 0 R /ID [<$hex> <$hex>] >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(b.toString().codeUnits);
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/make_fixtures.dart <out-dir>');
    exit(64);
  }
  final out = Directory(args.first)..createSync(recursive: true);
  final only = args.length > 1 ? args[1] : null; // optional: regenerate one file
  void write(String name, List<int> bytes) {
    if (only != null && name != only) return;
    File('${out.path}/$name').writeAsBytesSync(bytes);
    stdout.writeln('${name.padRight(28)} ${(bytes.length / 1024).round()} KB');
  }

  write('photo_12mp.jpg', img.encodeJpg(photo(4000, 3000), quality: 92)); // IMG-01
  write('photo_48mp.jpg', img.encodeJpg(photo(8000, 6000), quality: 92)); // IMG-02
  for (var o = 1; o <= 8; o++) {
    // IMG-03..10: same pixels, EXIF orientation 1–8.
    final im = marked(1200, 800);
    im.exif.imageIfd.orientation = o;
    write('exif_orient_$o.jpg', img.encodeJpg(im, quality: 90));
  }
  final alpha = img.Image(width: 800, height: 600, numChannels: 4); // IMG-12
  img.fillCircle(alpha, x: 400, y: 300, radius: 250, color: img.ColorRgba8(230, 80, 40, 255));
  write('transparent.png', img.encodePng(alpha));
  write('already_small_20kb.jpg', img.encodeJpg(photo(400, 300, noise: 4), quality: 40)); // IMG-21

  write('text_10p.pdf', await textPdf(10)); // PDF-01
  // PDF-02: 300 DPI scans (Balanced only touches images above 160 DPI).
  write('scanned_30p.pdf', await imagePdf(30, w: 2480, h: 3508, quality: 75));
  write('mixed_sizes.pdf', await mixedSizesPdf()); // PDF-03
  write('encrypted_user_pw.pdf', encryptedPdf()); // PDF-05
  write('large_300p.pdf', await imagePdf(300, w: 600, h: 800, quality: 80)); // PDF-08
  write('one_page.pdf', await textPdf(1)); // PDF-10
}
