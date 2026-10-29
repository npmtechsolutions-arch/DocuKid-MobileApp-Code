// T11.0 spike on a device (RELEASE_V1_4 §9 items 4–5): PdfBox-Android 2.0.27.0
// (without BouncyCastle) protects with AES-256 and unlocks; PDFium unlock with
// FPDF_REMOVE_SECURITY; owner-only detection; a ~200 MB PDF. Spike code: it
// records the answers for ADR-049. No password is ever printed.
//
//   flutter test integration_test/pdf_security_spike_test.dart -d <android device>
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:docukit/core/files/paths.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

const pw1 = 'Test-1234';
const pwUnicode = 'Pässwörd-日本語-🔒';

class UnlockReq {
  const UnlockReq(this.input, this.output, this.password);
  final String input, output, password;
}

RandomAccessFile? _sink;
int _writeBlock(Pointer<pdfium.FPDF_FILEWRITE_> self, Pointer<Void> data, int size) {
  _sink!.writeFromSync(data.cast<Uint8>().asTypedList(size));
  return 1;
}

/// PDFium path for Unlock (§4.5): open with the password, save without security.
String pdfiumUnlockInWorker(UnlockReq r) {
  final pd = pdfium.getPdfium();
  return using((arena) {
    final doc = pd.FPDF_LoadDocument(
        r.input.toNativeUtf8(allocator: arena).cast(), r.password.toNativeUtf8(allocator: arena).cast());
    if (doc == nullptr) return 'load:${pd.FPDF_GetLastError()}';
    final cb = NativeCallable<Int Function(Pointer<pdfium.FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)>.isolateLocal(
        _writeBlock,
        exceptionalReturn: 0);
    final fw = arena<pdfium.FPDF_FILEWRITE_>();
    final raf = File(r.output).openSync(mode: FileMode.write);
    try {
      _sink = raf;
      fw.ref
        ..version = 1
        ..WriteBlock = cb.nativeFunction;
      return pd.FPDF_SaveAsCopy(doc, fw, pdfium.FPDF_REMOVE_SECURITY) != 0 ? '' : 'save';
    } finally {
      _sink = null;
      raf.closeSync();
      cb.close();
      pd.FPDF_CloseDocument(doc);
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final native = DocukitNative();
  late Directory dir;
  late String plain;
  final owner = String.fromCharCodes(List.generate(32, (_) => 33 + math.Random.secure().nextInt(90)));

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_security'))..createSync(recursive: true);
    final doc = pw.Document();
    for (var i = 1; i <= 3; i++) {
      doc.addPage(pw.Page(build: (_) => pw.Text('Bank statement page $i: balance 1,250.00')));
    }
    plain = p.join(dir.path, 'statement.pdf');
    File(plain).writeAsBytesSync(await doc.save());
  });

  Future<(int, String)> openWith(String path, {String? password}) async {
    final d = await PdfDocument.openFile(path, passwordProvider: password == null ? null : () => password);
    try {
      return (d.pages.length, (await d.pages.first.loadText())?.fullText ?? '');
    } finally {
      await d.dispose();
    }
  }

  Future<bool> needsPassword(String path) async {
    try {
      await openWith(path);
      return false;
    } on PdfPasswordException {
      return true;
    }
  }

  /// The /Encrypt dictionary as written (PdfBox writes it uncompressed).
  String encryptDict(String path) {
    final s = String.fromCharCodes(File(path).readAsBytesSync());
    final m = RegExp(r'/Filter\s*/Standard[^>]*?(?:>>[^>]*?)*?/V\s*\d[\s\S]{0,400}?/R\s*\d').firstMatch(s);
    final v = RegExp(r'/V\s+(\d)').firstMatch(s)?.group(1);
    final rr = RegExp(r'/R\s+(\d)').firstMatch(s)?.group(1);
    final cfm = RegExp(r'/CFM\s*/(\w+)').firstMatch(s)?.group(1);
    final len = RegExp(r'/Length\s+(\d+)\s*/CFM|/CFM\s*/\w+\s*/Length\s+(\d+)').firstMatch(s);
    return 'V=$v R=$rr CFM=$cfm keyLen=${len?.group(1) ?? len?.group(2)} found=${m != null}';
  }

  testWidgets('PdfBox protect AES-256: needs the password, opens with it, same pages and text', (_) async {
    final out = p.join(dir.path, 'protected.pdf');
    final sw = Stopwatch()..start();
    final r = await native.protectPdf(inPath: plain, outPath: out, userPassword: pw1, ownerPassword: owner);
    expect(r['status'], 'ok', reason: '$r');
    // ignore: avoid_print
    print('SPIKE protect ${sw.elapsedMilliseconds}ms /Encrypt: ${encryptDict(out)}');
    expect(await needsPassword(out), isTrue);
    final (pages, text) = await openWith(out, password: pw1);
    expect((pages, text.contains('Bank statement page 1')), (3, true));
    expect(await native.pdfProtection(out), 'openPassword');
    expect(await native.pdfProtection(plain), 'none');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('a non-ASCII password works both ways (PdfBox writes, PDFium reads)', (_) async {
    final out = p.join(dir.path, 'protected_unicode.pdf');
    expect((await native.protectPdf(inPath: plain, outPath: out, userPassword: pwUnicode, ownerPassword: owner))['status'], 'ok');
    var pdfiumOk = true;
    try {
      await openWith(out, password: pwUnicode);
    } on PdfPasswordException {
      pdfiumOk = false;
    }
    final unlocked = p.join(dir.path, 'unicode_unlocked.pdf');
    final u = await native.unlockPdf(inPath: out, outPath: unlocked, password: pwUnicode);
    // ignore: avoid_print
    print('SPIKE non-ASCII password: PDFium opens=$pdfiumOk, PdfBox unlock=${u['status']}');
    expect(u['status'], 'ok');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('PdfBox unlock: wrong → wrongPassword (no file); right → opens without a password', (_) async {
    final locked = p.join(dir.path, 'locked.pdf');
    await native.protectPdf(inPath: plain, outPath: locked, userPassword: pw1, ownerPassword: owner);
    final wrongOut = p.join(dir.path, 'wrong.pdf');
    expect((await native.unlockPdf(inPath: locked, outPath: wrongOut, password: 'nope'))['status'], 'wrongPassword');
    expect(File(wrongOut).existsSync(), isFalse);
    final out = p.join(dir.path, 'unlocked_pdfbox.pdf');
    expect((await native.unlockPdf(inPath: locked, outPath: out, password: pw1))['status'], 'ok');
    expect(await needsPassword(out), isFalse);
    expect((await openWith(out)).$1, 3);
    expect(await native.pdfProtection(out), 'none', reason: 'really unencrypted');
    expect((await native.unlockPdf(inPath: plain, outPath: p.join(dir.path, 'x.pdf'), password: pw1))['status'], 'notEncrypted');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('PDFium unlock with FPDF_REMOVE_SECURITY: wrong fails, right gives an unencrypted copy', (_) async {
    final locked = p.join(dir.path, 'locked2.pdf');
    await native.protectPdf(inPath: plain, outPath: locked, userPassword: pw1, ownerPassword: owner);
    final wrong = await PdfrxEntryFunctions.instance.compute(pdfiumUnlockInWorker, UnlockReq(locked, p.join(dir.path, 'w2.pdf'), 'nope'));
    final out = p.join(dir.path, 'unlocked_pdfium.pdf');
    final right = await PdfrxEntryFunctions.instance.compute(pdfiumUnlockInWorker, UnlockReq(locked, out, pw1));
    final protection = await native.pdfProtection(out);
    final hasEncrypt = String.fromCharCodes(File(out).readAsBytesSync()).contains('/Encrypt');
    // ignore: avoid_print
    print('SPIKE PDFium unlock: wrong=$wrong right="${right.isEmpty ? 'ok' : right}" output protection=$protection '
        '/Encrypt in output=$hasEncrypt');
    expect(wrong, startsWith('load:'));
    expect(right, '');
    expect(await needsPassword(out), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('owner-only PDF (no open password, printing off) → ownerOnly; opens without a password', (_) async {
    final out = p.join(dir.path, 'owner_only.pdf');
    expect((await native.protectPdf(inPath: plain, outPath: out, userPassword: '', ownerPassword: owner, debugRestrict: true))['status'],
        'ok');
    expect(await native.pdfProtection(out), 'ownerOnly');
    expect(await needsPassword(out), isFalse);
    // Keep it for later tasks' tests (PDF-16).
    // ignore: avoid_print
    print('SPIKE owner-only /Encrypt: ${encryptDict(out)}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('~200 MB PDF: PdfBox protect and unlock (temp-file memory mode)', (_) async {
    // ~200 MB written straight to disk: [pages] pages, each showing its own copy
    // of one noisy JPEG (DCTDecode), so memory stays flat while it's built.
    final rnd = math.Random(3);
    final noisy = img.Image(width: 1600, height: 1200);
    for (final px in noisy) {
      px
        ..r = rnd.nextInt(256)
        ..g = rnd.nextInt(256)
        ..b = rnd.nextInt(256);
    }
    final jpg = img.encodeJpg(noisy, quality: 95);
    const mb = 1024 * 1024;
    // ignore: avoid_print
    void step(String s) => print('SPIKE big step: $s rss=${(ProcessInfo.currentRss / mb).round()}MB');
    final big = p.join(dir.path, 'big.pdf');
    await jpegPdf(big, jpg, 1600, 1200, pages: (200 * mb / jpg.length).ceil());
    step('written');
    final size = File(big).lengthSync();
    final base = ProcessInfo.currentRss;
    var peak = base;
    final sampler = Timer.periodic(const Duration(milliseconds: 200), (_) => peak = math.max(peak, ProcessInfo.currentRss));
    final sw = Stopwatch()..start();
    final out = p.join(dir.path, 'big_protected.pdf');
    step('protect start');
    final r = await native.protectPdf(inPath: big, outPath: out, userPassword: pw1, ownerPassword: owner);
    step('protect end ${r['status']}');
    final protectMs = sw.elapsedMilliseconds;
    sw.reset();
    final u = r['status'] == 'ok'
        ? await native.unlockPdf(inPath: out, outPath: p.join(dir.path, 'big_unlocked.pdf'), password: pw1)
        : const {'status': 'skipped'};
    sampler.cancel();
    // ignore: avoid_print
    print('SPIKE big ${(size / mb).round()} MB: protect=${r['status']}${r['code'] == null ? '' : ' (${r['code']})'} '
        '${protectMs}ms, unlock=${u['status']} ${sw.elapsedMilliseconds}ms, '
        'rss base=${(base / mb).round()}MB peak=${(peak / mb).round()}MB (+${((peak - base) / mb).round()})');
    expect(size, greaterThan(150 * mb));
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// A minimal PDF streamed to [path]: [pages] pages of [w]×[h] pt, each with
/// its own image object holding [jpeg].
Future<void> jpegPdf(String path, List<int> jpeg, int w, int h, {required int pages}) async {
  final out = File(path).openSync(mode: FileMode.write);
  var pos = 0;
  final offsets = <int>[];
  void put(String s) {
    final b = s.codeUnits;
    out.writeFromSync(b);
    pos += b.length;
  }

  void obj(String body, {List<int>? stream}) {
    offsets.add(pos);
    put('${offsets.length} 0 obj\n$body\n');
    if (stream != null) {
      put('stream\n');
      out.writeFromSync(stream);
      pos += stream.length;
      put('\nendstream\n');
    }
    put('endobj\n');
  }

  put('%PDF-1.4\n');
  // 1 catalog, 2 pages; then per page: page, content, image.
  final kids = [for (var i = 0; i < pages; i++) '${3 + i * 3} 0 R'].join(' ');
  obj('<< /Type /Catalog /Pages 2 0 R >>');
  obj('<< /Type /Pages /Kids [$kids] /Count $pages >>');
  for (var i = 0; i < pages; i++) {
    final page = 3 + i * 3, content = page + 1, image = page + 2;
    obj('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] /Contents $content 0 R '
        '/Resources << /XObject << /Im $image 0 R >> >> >>');
    final c = 'q $w 0 0 $h 0 0 cm /Im Do Q'.codeUnits;
    obj('<< /Length ${c.length} >>', stream: c);
    obj('<< /Type /XObject /Subtype /Image /Width $w /Height $h /ColorSpace /DeviceRGB /BitsPerComponent 8 '
        '/Filter /DCTDecode /Length ${jpeg.length} >>', stream: jpeg);
  }
  final xref = pos;
  put('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    put('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  put('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  out.closeSync();
}
