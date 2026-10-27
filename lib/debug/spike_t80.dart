// SPIKE T8.0 (RELEASE_V1_1 §9) — throwaway measurements, debug only.
// Delete with lib/debug/ once T8.3 lands. Results are timings, sizes and
// pass/fail flags only; no file names, paths or contents are reported.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

typedef Report = Map<String, Object?>;

int _mb(int bytes) => (bytes / (1024 * 1024)).round();

/// Samples this process's RSS every 20 ms while [work] runs (the work must run
/// in another isolate, or the timer can't fire).
Future<(T, int peakRss, int baseRss)> _withRss<T>(Future<T> Function() work) async {
  final base = ProcessInfo.currentRss;
  var peak = base;
  final t = Timer.periodic(const Duration(milliseconds: 20), (_) {
    final r = ProcessInfo.currentRss;
    if (r > peak) peak = r;
  });
  try {
    final v = await work();
    final r = ProcessInfo.currentRss;
    if (r > peak) peak = r;
    return (v, peak, base);
  } finally {
    t.cancel();
  }
}

/// Writes [count] files of [sizeMb] incompressible bytes (like JPEGs), 1 MB at a time.
Future<List<String>> makeInputs(Directory dir, {int count = 50, int sizeMb = 10}) async {
  dir.createSync(recursive: true);
  final r = math.Random(7);
  final chunk = Uint8List(1024 * 1024);
  final paths = <String>[];
  for (var i = 0; i < count; i++) {
    final path = p.join(dir.path, 'in_$i.jpg');
    final f = File(path);
    if (!f.existsSync() || f.lengthSync() != sizeMb * 1024 * 1024) {
      final raf = f.openSync(mode: FileMode.write);
      for (var m = 0; m < sizeMb; m++) {
        for (var k = 0; k < chunk.length; k++) {
          chunk[k] = r.nextInt(256);
        }
        raf.writeFromSync(chunk);
      }
      raf.closeSync();
    }
    paths.add(path);
  }
  return paths;
}

// ---------------------------------------------------------------- 1. ZIP

/// Builds a STORE zip with `ZipFileEncoder` + `addArchiveFile` (streams from disk).
void _zipStore(List<String> inputs, String out) {
  final enc = ZipFileEncoder()..create(out);
  for (var i = 0; i < inputs.length; i++) {
    final s = InputFileStream(inputs[i]);
    final f = ArchiveFile.stream('entry_$i.jpg', s)..compression = CompressionType.none;
    enc.addArchiveFile(f);
    s.closeSync();
  }
  enc.closeSync();
}

/// Same with the default `addFile` (deflate) to show the buffering difference.
Future<void> _zipDefault(List<String> inputs, String out) async {
  final enc = ZipFileEncoder()..create(out);
  for (var i = 0; i < inputs.length; i++) {
    await enc.addFile(File(inputs[i]), 'entry_$i.jpg');
  }
  await enc.close();
}

/// Reopens [zip], reading the central directory, and checks entry count + sizes.
(int entries, bool sizesOk) _validateZip(String zip, int expectEntries, int entrySize) {
  final s = InputFileStream(zip);
  try {
    final a = ZipDecoder().decodeStream(s);
    final ok = a.files.every((f) => f.size == entrySize);
    return (a.files.length, ok && a.files.length == expectEntries);
  } finally {
    s.closeSync();
  }
}

Future<Report> spikeZip(Directory work, {bool alsoDefault = true}) async {
  final inputs = await makeInputs(Directory(p.join(work.path, 'zip_in')));
  final total = inputs.fold<int>(0, (a, b) => a + File(b).lengthSync());
  final out = p.join(work.path, 'store.zip');
  final sw = Stopwatch()..start();
  final (_, peak, base) = await _withRss(() => Isolate.run(() => _zipStore(inputs, out)));
  final storeMs = sw.elapsedMilliseconds;
  final (entries, ok) = await Isolate.run(() => _validateZip(out, inputs.length, 10 * 1024 * 1024));
  final zipBytes = File(out).lengthSync();
  File(out).deleteSync();
  final report = <String, Object?>{
    'archive': '4.0.9',
    'inputsMb': _mb(total),
    'store.ms': storeMs,
    'store.zipMb': _mb(zipBytes),
    'store.rssBaseMb': _mb(base),
    'store.rssPeakMb': _mb(peak),
    'store.rssDeltaMb': _mb(peak - base),
    'store.validEntries': entries,
    'store.valid': ok,
  };
  if (alsoDefault) {
    final out2 = p.join(work.path, 'deflate.zip');
    final sw2 = Stopwatch()..start();
    final (_, peak2, base2) = await _withRss(() => Isolate.run(() => _zipDefault(inputs, out2)));
    report['defaultAddFile.ms'] = sw2.elapsedMilliseconds;
    report['defaultAddFile.rssDeltaMb'] = _mb(peak2 - base2);
    report['defaultAddFile.zipMb'] = _mb(File(out2).lengthSync());
    File(out2).deleteSync();
  }
  return report;
}

// ---------------------------------------------------------------- 2. WebP / HEIC encode

Uint8List _photoJpeg() {
  final r = math.Random(3);
  final im = img.Image(width: 2000, height: 1500);
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      im.setPixelRgb(x, y, (x * 255 ~/ im.width + r.nextInt(30)) % 256, (y * 255 ~/ im.height) % 256, 120);
    }
  }
  return img.encodeJpg(im, quality: 92);
}

Uint8List _alphaPng() {
  final im = img.Image(width: 600, height: 400, numChannels: 4);
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      im.setPixelRgba(x, y, 30, 120, 220, x < 300 ? 0 : 255);
    }
  }
  return img.encodePng(im);
}

String _magic(Uint8List? b) {
  if (b == null || b.length < 12) return 'none';
  if (b[0] == 0xFF && b[1] == 0xD8) return 'jpeg';
  if (b[0] == 0x89 && b[1] == 0x50) return 'png';
  if (String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  if (String.fromCharCodes(b.sublist(4, 8)) == 'ftyp') return 'ftyp:${String.fromCharCodes(b.sublist(8, 12))}';
  return 'unknown';
}

Future<Report> spikeEncodeFormats(Directory work) async {
  work.createSync(recursive: true);
  final photo = p.join(work.path, 'photo.jpg');
  File(photo).writeAsBytesSync(await Isolate.run(_photoJpeg));
  final alpha = p.join(work.path, 'alpha.png');
  File(alpha).writeAsBytesSync(await Isolate.run(_alphaPng));
  final report = <String, Object?>{'flutter_image_compress': '2.5.1'};
  for (final (label, src) in [('photo', photo), ('alpha', alpha)]) {
    for (final f in [CompressFormat.jpeg, CompressFormat.png, CompressFormat.webp, CompressFormat.heic]) {
      final key = '$label->${f.name}';
      final sw = Stopwatch()..start();
      try {
        final out = await FlutterImageCompress.compressWithFile(src, format: f, quality: 85, keepExif: false);
        report['$key.ms'] = sw.elapsedMilliseconds;
        report['$key.magic'] = _magic(out);
        report['$key.kb'] = out == null ? null : out.length ~/ 1024;
        if (f == CompressFormat.heic && out != null && out.isNotEmpty) {
          // Round trip: decode the HEIC natively back to JPEG and check its size.
          final back = await FlutterImageCompress.compressWithList(out, format: CompressFormat.jpeg, quality: 90);
          final dec = await Isolate.run(() => img.decodeJpg(back));
          report['$key.roundTrip'] = dec == null ? 'undecodable' : '${dec.width}x${dec.height}';
        }
        if (label == 'alpha' && f == CompressFormat.webp && out != null) {
          final dec = img.decodeWebP(out);
          report['alpha->webp.keepsAlpha'] =
              dec == null ? 'undecodable' : (dec.numChannels == 4 && dec.getPixel(10, 10).a < 128);
        }
      } catch (e) {
        report['$key.error'] = e.runtimeType.toString();
      }
    }
  }
  return report;
}

// ---------------------------------------------------------------- 3. P2I RGBA → JPEG/PNG

Future<Uint8List> _testPdf() async {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (_) => pw.Column(children: [
      pw.Text('DocuKit spike page', style: const pw.TextStyle(fontSize: 28)),
      for (var i = 0; i < 30; i++) pw.Text('Line $i — The quick brown fox jumps over the lazy dog.'),
      pw.Container(width: 400, height: 200, color: PdfColors.teal),
    ]),
  ));
  return Uint8List.fromList(await doc.save());
}

Uint8List _bgraToJpeg(Uint8List bgra, int w, int h, int q) {
  final im = img.Image.fromBytes(width: w, height: h, bytes: bgra.buffer, numChannels: 4, order: img.ChannelOrder.bgra);
  return img.encodeJpg(im.convert(numChannels: 3), quality: q);
}

Uint8List _bgraToPng(Uint8List bgra, int w, int h) {
  final im = img.Image.fromBytes(width: w, height: h, bytes: bgra.buffer, numChannels: 4, order: img.ChannelOrder.bgra);
  return img.encodePng(im.convert(numChannels: 3), level: 6);
}

/// 32-bit BMP (BI_BITFIELDS, BGRA) wrapper so the native codec can decode the raw pixels.
Uint8List _bgraToBmp(Uint8List bgra, int w, int h) {
  const header = 14 + 108;
  final out = Uint8List(header + bgra.length);
  final b = ByteData.view(out.buffer);
  out[0] = 0x42;
  out[1] = 0x4D;
  b.setUint32(2, out.length, Endian.little);
  b.setUint32(10, header, Endian.little);
  b.setUint32(14, 108, Endian.little); // BITMAPV4HEADER
  b.setInt32(18, w, Endian.little);
  b.setInt32(22, -h, Endian.little); // top-down
  b.setUint16(26, 1, Endian.little);
  b.setUint16(28, 32, Endian.little);
  b.setUint32(30, 3, Endian.little); // BI_BITFIELDS
  b.setUint32(34, bgra.length, Endian.little);
  b.setUint32(54, 0x00FF0000, Endian.little); // R
  b.setUint32(58, 0x0000FF00, Endian.little); // G
  b.setUint32(62, 0x000000FF, Endian.little); // B
  b.setUint32(66, 0xFF000000, Endian.little); // A
  b.setUint32(70, 0x73524742, Endian.little); // 'sRGB'
  out.setRange(header, out.length, bgra);
  return out;
}

Future<Report> spikeP2i(Directory work) async {
  work.createSync(recursive: true);
  final pdfPath = p.join(work.path, 'page.pdf');
  File(pdfPath).writeAsBytesSync(await Isolate.run(_testPdf));
  final doc = await PdfDocument.openFile(pdfPath);
  final report = <String, Object?>{'pdfrx': '2.10.1', 'image': '4.10.0'};
  try {
    final page = doc.pages.first;
    for (final dpi in [150, 300]) {
      final w = page.width * dpi / 72, h = page.height * dpi / 72;
      final swR = Stopwatch()..start();
      final rendered = await page.render(fullWidth: w, fullHeight: h, backgroundColor: 0xFFFFFFFF);
      final k = 'dpi$dpi';
      if (rendered == null) {
        report['$k.render'] = 'null';
        continue;
      }
      report['$k.px'] = '${rendered.width}x${rendered.height}';
      report['$k.renderMs'] = swR.elapsedMilliseconds;
      final pw0 = rendered.width, ph0 = rendered.height;
      final pixels = Uint8List.fromList(rendered.pixels);
      // C: ui.Image → PNG (engine encoder, UI isolate's raster thread).
      final swC = Stopwatch()..start();
      final uiImg = await rendered.createImage();
      final png = await uiImg.toByteData(format: ui.ImageByteFormat.png);
      uiImg.dispose();
      report['$k.uiPng.ms'] = swC.elapsedMilliseconds;
      report['$k.uiPng.kb'] = (png?.lengthInBytes ?? 0) ~/ 1024;
      rendered.dispose();
      // A: image package JPEG in an isolate.
      final swA = Stopwatch()..start();
      final (jpg, peakA, baseA) = await _withRss(() => Isolate.run(() => _bgraToJpeg(pixels, pw0, ph0, 90)));
      report['$k.dartJpeg.ms'] = swA.elapsedMilliseconds;
      report['$k.dartJpeg.kb'] = jpg.length ~/ 1024;
      report['$k.dartJpeg.rssDeltaMb'] = _mb(peakA - baseA);
      // B: image package PNG in an isolate.
      final swB = Stopwatch()..start();
      final pngB = await Isolate.run(() => _bgraToPng(pixels, pw0, ph0));
      report['$k.dartPng.ms'] = swB.elapsedMilliseconds;
      report['$k.dartPng.kb'] = pngB.length ~/ 1024;
      // D: BMP wrapper → native codec (flutter_image_compress) JPEG and PNG.
      final bmpPath = p.join(work.path, 'page_$dpi.bmp');
      File(bmpPath).writeAsBytesSync(await Isolate.run(() => _bgraToBmp(pixels, pw0, ph0)));
      for (final f in [CompressFormat.jpeg, CompressFormat.png]) {
        final swD = Stopwatch()..start();
        try {
          final out = await FlutterImageCompress.compressWithFile(bmpPath,
              format: f, quality: 90, minWidth: pw0, minHeight: ph0, keepExif: false);
          report['$k.nativeBmp->${f.name}.ms'] = swD.elapsedMilliseconds;
          report['$k.nativeBmp->${f.name}.magic'] = _magic(out);
          report['$k.nativeBmp->${f.name}.kb'] = out == null ? null : out.length ~/ 1024;
          if (out != null) {
            final dec = await Isolate.run(() => img.decodeImage(out));
            report['$k.nativeBmp->${f.name}.size'] = dec == null ? 'undecodable' : '${dec.width}x${dec.height}';
          }
        } catch (e) {
          report['$k.nativeBmp->${f.name}.error'] = e.runtimeType.toString();
        }
      }
      File(bmpPath).deleteSync();
    }
  } finally {
    await doc.dispose();
  }
  return report;
}

// ---------------------------------------------------------------- 4. SAF folder save

const _native = MethodChannel('docukit/native');

/// Opens the system folder picker; then times 50 × createFile + copy (Android only).
Future<Report> spikeSaveMany(Directory work, {int count = 50, int sizeMb = 1}) async {
  if (!Platform.isAndroid) return {'skipped': 'Android only (iOS: Xcode round)'};
  final inputs = await makeInputs(Directory(p.join(work.path, 'saf_in')), count: count, sizeMb: sizeMb);
  final res = await _native.invokeMapMethod<String, Object?>('spikeSaveManyToTree', {
    'paths': inputs,
    'mime': 'image/jpeg',
  });
  return {'fileMb': sizeMb, ...?res};
}
