// T11.0 spike (RELEASE_V1_4 §4.2, §4.4): PDFium image objects on the host.
// 1) a BGRA bitmap with alpha keeps its transparency; 2) the §4.4 placement
// maths on /Rotate 0/90/180/270 with and without an inset crop box;
// opacity baked into alpha; output size per stamped page. Spike code: it
// records answers for ADR-048; production code comes in T11.5.
//
//   PDFIUM_PATH=… flutter test test/core/pdf_stamp_spike_host_test.dart   (see tool/test_pdf_host.sh)
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart' as pdfrx show PdfDocument, PdfrxEntryFunctions, Pdfrx, pdfrxInitialize;

/// x' = a·x + c·y + e ; y' = b·x + d·y + f (PDF's [a b c d e f]).
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  final double a, b, c, d, e, f;
  static Affine scale(double sx, double sy) => Affine(sx, 0, 0, sy, 0, 0);
  static Affine translate(double tx, double ty) => Affine(1, 0, 0, 1, tx, ty);

  /// Counter-clockwise in a y-up space.
  static Affine rotate(double deg) {
    final r = deg * math.pi / 180, cs = math.cos(r), sn = math.sin(r);
    return Affine(cs, sn, -sn, cs, 0, 0);
  }

  /// this · o (apply o first).
  Affine operator *(Affine o) => Affine(
        a * o.a + c * o.b,
        b * o.a + d * o.b,
        a * o.c + c * o.d,
        b * o.c + d * o.d,
        a * o.e + c * o.f + e,
        b * o.e + d * o.f + f,
      );
  (double, double) apply(double x, double y) => (a * x + c * y + e, b * x + d * y + f);
}

/// §4.4: crop box in user space, /Rotate clockwise.
class PageGeo {
  const PageGeo(this.cx0, this.cy0, this.cx1, this.cy1, this.rot);
  final double cx0, cy0, cx1, cy1;
  final int rot;
  (double, double) toUser(double vx, double vy) => switch (rot) {
        0 => (cx0 + vx, cy1 - vy),
        90 => (cx0 + vy, cy0 + vx),
        180 => (cx1 - vx, cy0 + vy),
        _ => (cx1 - vy, cy1 - vx),
      };
}

Affine placementMatrix(PageGeo g, double vx, double vy, double w, double h, double stampRotDeg) {
  final s = Affine.scale(w, h) * Affine.translate(-0.5, -0.5);
  final r = Affine.rotate(-stampRotDeg);
  final pr = Affine.rotate(g.rot.toDouble());
  final (ux, uy) = g.toUser(vx + w / 2, vy + h / 2);
  return Affine.translate(ux, uy) * pr * r * s;
}

class StampReq {
  const StampReq(this.input, this.output, this.module, this.rotations, this.crop, this.stamps, this.alpha,
      {this.shared = false, this.logo = false});
  final String input, output;
  final String? module;

  /// One form XObject referenced from every page instead of a bitmap per page.
  final bool shared;

  /// A noisy 600×600 opaque "logo" (compresses badly) instead of the marker.
  final bool logo;
  final List<int> rotations; // quarter turns per page (fixture setup)
  final bool crop; // inset the crop box by 36 pt (fixture setup)
  final List<(int, double, double, double, double, double)> stamps; // page, vx, vy, w, h, rotDeg
  final int alpha; // the marker's alpha (opacity baked in)
}

const bmpW = 200, bmpH = 100;

/// Runs in pdfrx's PDFium worker. Returns '' or an error.
String stampInWorker(StampReq r) {
  final pd = pdfium.getPdfium(modulePath: r.module);
  return using((arena) {
    final doc = pd.FPDF_LoadDocument(r.input.toNativeUtf8(allocator: arena).cast(), nullptr);
    if (doc == nullptr) return 'load';
    // The stamp: transparent, with a marker in its top-left quarter.
    final (sw, sh) = r.logo ? (600, 600) : (bmpW, bmpH);
    final buf = calloc<Uint8>(sw * sh * 4);
    final a = r.alpha;
    final rnd = math.Random(7);
    if (r.logo) {
      for (var i = 0; i < sw * sh * 4; i += 4) {
        buf[i] = rnd.nextInt(256);
        buf[i + 1] = rnd.nextInt(256);
        buf[i + 2] = 255;
        buf[i + 3] = 255;
      }
    }
    for (var y = 0; y < sh ~/ 4; y++) {
      for (var x = 0; x < sw ~/ 4; x++) {
        final i = (y * sw + x) * 4;
        // BGRA with *straight* alpha: PDFium writes the colour as is and the
        // alpha as the SMask (a premultiplied 50% red came out as 25%).
        buf[i] = 0;
        buf[i + 1] = 0;
        buf[i + 2] = 255;
        buf[i + 3] = a;
      }
    }
    // Shared: the stamp on a 1×1 pt page of its own document → one XObject.
    pdfium.FPDF_DOCUMENT? stampDoc;
    pdfium.FPDF_XOBJECT? xobj;
    if (r.shared) {
      stampDoc = pd.FPDF_CreateNewDocument();
      final sp = pd.FPDFPage_New(stampDoc, 0, 1, 1);
      final bmp = pd.FPDFBitmap_CreateEx(sw, sh, pdfium.FPDFBitmap_BGRA, buf.cast(), sw * 4);
      final obj = pd.FPDFPageObj_NewImageObj(stampDoc);
      final pages = arena<pdfium.FPDF_PAGE>()..value = sp;
      pd.FPDFImageObj_SetBitmap(pages, 1, obj, bmp);
      pd.FPDFImageObj_SetMatrix(obj, 1, 0, 0, 1, 0, 0);
      pd.FPDFPage_InsertObject(sp, obj);
      pd.FPDFPage_GenerateContent(sp);
      pd.FPDFBitmap_Destroy(bmp);
      pd.FPDF_ClosePage(sp);
      xobj = pd.FPDF_NewXObjectFromPage(doc, stampDoc, 0);
      if (xobj == nullptr) return 'xobject';
    }
    try {
      for (var i = 0, n = pd.FPDF_GetPageCount(doc); i < n; i++) {
        final page = pd.FPDF_LoadPage(doc, i);
        if (r.rotations.isNotEmpty) pd.FPDFPage_SetRotation(page, r.rotations[i % r.rotations.length]);
        if (r.crop) pd.FPDFPage_SetCropBox(page, 36, 36, 595 - 36, 842 - 36);
        final g = PageGeo(r.crop ? 36 : 0, r.crop ? 36 : 0, r.crop ? 559 : 595, r.crop ? 806 : 842,
            r.rotations.isEmpty ? 0 : r.rotations[i % r.rotations.length] * 90);
        for (final (pg, vx, vy, w, h, rd) in r.stamps) {
          if (pg != i && pg != -1) continue;
          final m = placementMatrix(g, vx, vy, w, h, rd);
          if (xobj != null) {
            final form = pd.FPDF_NewFormObjectFromXObject(xobj);
            if (pd.FPDFPageObj_SetMatrix(form, arena<pdfium.FS_MATRIX>()
                  ..ref.a = m.a
                  ..ref.b = m.b
                  ..ref.c = m.c
                  ..ref.d = m.d
                  ..ref.e = m.e
                  ..ref.f = m.f) ==
                0) {
              return 'formMatrix';
            }
            pd.FPDFPage_InsertObject(page, form);
            continue;
          }
          final bmp = pd.FPDFBitmap_CreateEx(sw, sh, pdfium.FPDFBitmap_BGRA, buf.cast(), sw * 4);
          final obj = pd.FPDFPageObj_NewImageObj(doc);
          final pages = arena<pdfium.FPDF_PAGE>()..value = page;
          if (pd.FPDFImageObj_SetBitmap(pages, 1, obj, bmp) == 0) return 'setBitmap';
          if (pd.FPDFImageObj_SetMatrix(obj, m.a, m.b, m.c, m.d, m.e, m.f) == 0) return 'setMatrix';
          pd.FPDFPage_InsertObject(page, obj);
          pd.FPDFBitmap_Destroy(bmp);
        }
        if (pd.FPDFPage_GenerateContent(page) == 0) return 'generate';
        pd.FPDF_ClosePage(page);
      }
      return _save(pd, doc, r.output) ? '' : 'save';
    } finally {
      if (xobj != null) pd.FPDF_CloseXObject(xobj);
      if (stampDoc != null) pd.FPDF_CloseDocument(stampDoc);
      calloc.free(buf);
      pd.FPDF_CloseDocument(doc);
    }
  });
}

RandomAccessFile? _sink;
int _writeBlock(Pointer<pdfium.FPDF_FILEWRITE_> self, Pointer<Void> data, int size) {
  _sink!.writeFromSync(data.cast<Uint8>().asTypedList(size));
  return 1;
}

bool _save(pdfium.PDFium pd, pdfium.FPDF_DOCUMENT doc, String out, {int flags = pdfium.FPDF_NO_INCREMENTAL}) {
  final cb = NativeCallable<Int Function(Pointer<pdfium.FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)>.isolateLocal(
      _writeBlock,
      exceptionalReturn: 0);
  final fw = calloc<pdfium.FPDF_FILEWRITE_>();
  final raf = File(out).openSync(mode: FileMode.write);
  try {
    _sink = raf;
    fw.ref
      ..version = 1
      ..WriteBlock = cb.nativeFunction;
    return pd.FPDF_SaveAsCopy(doc, fw, flags) != 0;
  } finally {
    _sink = null;
    raf.closeSync();
    calloc.free(fw);
    cb.close();
  }
}

void main() {
  if (Platform.environment['PDFIUM_PATH'] == null) {
    test('PDF stamping spike', () {}, skip: 'Set PDFIUM_PATH (see tool/test_pdf_host.sh)');
    return;
  }
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('stamp_spike');
    await pdfrx.pdfrxInitialize(tmpPath: tmp.path);
  });

  /// [pages] A4 pages filled with solid blue.
  Future<String> base(String name, int pages) async {
    final doc = pw.Document();
    for (var i = 0; i < pages; i++) {
      doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Container(color: const PdfColor(0, 0, 1))));
    }
    final path = p.join(tmp.path, name);
    File(path).writeAsBytesSync(await doc.save());
    return path;
  }

  Future<void> stamp(StampReq r) async {
    final err = await pdfrx.PdfrxEntryFunctions.instance.compute(stampInWorker, r);
    expect(err, '', reason: 'PDFium step failed: $err');
  }

  /// Rendered at 1 px per point in visual space: (b, g, r) at (x, y).
  Future<(int, int, int) Function(int, int)> render(String path, int page) async {
    final d = await pdfrx.PdfDocument.openFile(path);
    final pg = d.pages[page];
    final w = pg.width.round(), h = pg.height.round();
    final im = (await pg.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF))!;
    final Uint8List px = Uint8List.fromList(im.pixels);
    im.dispose();
    await d.dispose();
    return (int x, int y) {
      final i = (y * w + x) * 4;
      return (px[i], px[i + 1], px[i + 2]);
    };
  }

  bool isRed((int, int, int) c) => c.$3 > 200 && c.$1 < 60 && c.$2 < 60;
  bool isBlue((int, int, int) c) => c.$1 > 200 && c.$3 < 60;

  for (final crop in [false, true]) {
    test('placement on /Rotate 0/90/180/270${crop ? ' with a 36 pt crop box' : ''}: marker where the editor put it; '
        'transparency kept', () async {
      final input = await base('rot${crop ? '_crop' : ''}.pdf', 4);
      final out = p.join(tmp.path, 'rot${crop ? '_crop' : ''}_out.pdf');
      // Visual top-left (40, 60), 200×100 pt, on every page.
      await stamp(StampReq(input, out, pdfrx.Pdfrx.pdfiumModulePath, const [0, 1, 2, 3], crop, const [(-1, 40, 60, 200, 100, 0)], 255));
      for (var i = 0; i < 4; i++) {
        final at = await render(out, i);
        // The marker is the stamp's top-left quarter: (40..90, 60..85).
        expect(isRed(at(65, 72)), isTrue, reason: 'page ${i * 90}°: marker at the visual top-left of the stamp');
        expect(isRed(at(41, 61)), isTrue, reason: 'page ${i * 90}°: marker corner (±1 pt)');
        expect(isBlue(at(38, 58)), isTrue, reason: 'page ${i * 90}°: outside the stamp');
        expect(isBlue(at(180, 140)), isTrue, reason: 'page ${i * 90}°: transparent part of the stamp shows the page');
        expect(isBlue(at(92, 72)), isTrue, reason: 'page ${i * 90}°: marker ends at 90 (±1 pt)');
      }
    });
  }

  test('a stamp rotated 90° clockwise: the marker moves to its top-right', () async {
    final input = await base('srot.pdf', 1);
    final out = p.join(tmp.path, 'srot_out.pdf');
    // Centre (140, 110); rotated 90° cw the 200×100 stamp spans x 90..190, y 10..210.
    await stamp(StampReq(input, out, pdfrx.Pdfrx.pdfiumModulePath, const [], false, const [(0, 40, 60, 200, 100, 90)], 255));
    final at = await render(out, 0);
    // Its top-left quarter (in image terms) is now the top-right: x 165..190, y 10..60.
    expect(isRed(at(178, 35)), isTrue);
    expect(isBlue(at(100, 35)), isTrue);
  });

  test('opacity baked into alpha: a 50% marker blends with the page', () async {
    final input = await base('alpha.pdf', 1);
    final out = p.join(tmp.path, 'alpha_out.pdf');
    await stamp(StampReq(input, out, pdfrx.Pdfrx.pdfiumModulePath, const [], false, const [(0, 40, 60, 200, 100, 0)], 128));
    final c = (await render(out, 0))(65, 72);
    // ignore: avoid_print
    print('SPIKE 50% marker over blue → BGR $c');
    expect(c.$3, inInclusiveRange(90, 170), reason: 'half red');
    expect(c.$1, inInclusiveRange(90, 170), reason: 'half the blue page');
  });

  test('size: one stamp on each of 300 pages', () async {
    final input = await base('p300.pdf', 300);
    final out = p.join(tmp.path, 'p300_out.pdf');
    final sw = Stopwatch()..start();
    await stamp(StampReq(input, out, pdfrx.Pdfrx.pdfiumModulePath, const [], false, const [(-1, 40, 60, 200, 100, 0)], 255));
    final before = File(input).lengthSync(), after = File(out).lengthSync();
    // ignore: avoid_print
    print('SPIKE 300 pages: ${before}B → ${after}B, +${((after - before) / 300 / 1024).toStringAsFixed(2)} KB/page '
        'for a $bmpW×$bmpH stamp, ${sw.elapsedMilliseconds}ms');
    expect(await Isolate.run(() => File(out).existsSync()), isTrue);
  });

  test('shared XObject: the same placement on rotated/cropped pages, transparency kept', () async {
    final input = await base('shared_rot.pdf', 4);
    final out = p.join(tmp.path, 'shared_rot_out.pdf');
    await stamp(StampReq(input, out, pdfrx.Pdfrx.pdfiumModulePath, const [0, 1, 2, 3], true, const [(-1, 40, 60, 200, 100, 0)], 255,
        shared: true));
    for (var i = 0; i < 4; i++) {
      final at = await render(out, i);
      expect(isRed(at(65, 72)), isTrue, reason: 'page ${i * 90}°');
      expect(isBlue(at(180, 140)), isTrue, reason: 'page ${i * 90}°: transparent');
    }
  });

  test('size, 300 pages with a 600×600 photo-like logo: a bitmap per page vs one shared XObject', () async {
    final input = await base('logo300.pdf', 300);
    final perPage = p.join(tmp.path, 'logo300_each.pdf'), shared = p.join(tmp.path, 'logo300_shared.pdf');
    const st = [(-1, 300.0, 600.0, 200.0, 200.0, 0.0)];
    await stamp(StampReq(input, perPage, pdfrx.Pdfrx.pdfiumModulePath, const [], false, st, 255, logo: true));
    await stamp(StampReq(input, shared, pdfrx.Pdfrx.pdfiumModulePath, const [], false, st, 255, logo: true, shared: true));
    final b = File(input).lengthSync();
    double kb(String f) => (File(f).lengthSync() - b) / 300 / 1024;
    // ignore: avoid_print
    print('SPIKE logo 600×600 on 300 pages: per page +${kb(perPage).toStringAsFixed(1)} KB/page, '
        'shared +${kb(shared).toStringAsFixed(2)} KB/page');
    expect(kb(shared), lessThan(30));
  });
}
