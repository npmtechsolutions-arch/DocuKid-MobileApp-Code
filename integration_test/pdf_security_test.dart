// T11.2 on a device (RELEASE_V1_4 §8.3 rows 1–2, plus the wrong-password and
// owner-only checks): PdfSecurity with the real engines — PdfBox-Android for
// Protect, PDFium (then PdfBox) for Unlock.
//
//   flutter test integration_test/pdf_security_test.dart -d <android device>
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit/core/pdf/pdfium_security_ops.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final native = DocukitNative();
  const ops = PdfrxSecurityOps();
  final security = NativePdfSecurity(native, ops, nativeUnlock: Platform.isAndroid);
  late Directory dir;
  late String pdf01;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory(p.join((await AppPaths.resolve()).cacheRoot.path, 'it_pdf_security'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    // PDF-01 stand-in: text_10p.pdf, ten text-only pages.
    final doc = pw.Document();
    for (var i = 1; i <= 10; i++) {
      doc.addPage(pw.Page(
          build: (_) => pw.Column(children: [
                pw.Text('Statement page $i', style: const pw.TextStyle(fontSize: 28)),
                for (var l = 0; l < 20; l++) pw.Text('Line $l: balance ${1250 + l * i}.00 — account 0042-$i'),
              ])));
    }
    pdf01 = p.join(dir.path, 'text_10p.pdf');
    File(pdf01).writeAsBytesSync(await doc.save());
  });

  JobContext ctx() => JobContext(jobId: 'it_sec', workDir: dir, cancel: CancelToken(), report: (_) {});

  Future<int> pages(String path, {String? password}) async {
    final d = await PdfDocument.openFile(path, passwordProvider: password == null ? null : () => password);
    try {
      return d.pages.length;
    } finally {
      await d.dispose();
    }
  }

  Future<List<int>> firstPage(String path) async {
    final d = await PdfDocument.openFile(path);
    try {
      final im = (await d.pages.first.render(fullWidth: 1240, fullHeight: 1754, backgroundColor: 0xFFFFFFFF))!;
      final c = List<int>.of(im.pixels);
      im.dispose();
      return c;
    } finally {
      await d.dispose();
    }
  }

  testWidgets('Protect PDF-01 with Test-1234: needs the password, opens with it, same pages, source unchanged', (_) async {
    final before = sha(pdf01);
    final out = p.join(dir.path, 'protected.pdf');
    await security.protect(pdf01, out, userPassword: 'Test-1234', ctx: ctx());
    await expectLater(pages(out), throwsA(isA<PdfPasswordException>()));
    expect(await pages(out, password: 'Test-1234'), 10);
    expect(await security.inspect(out), PdfProtection.openPassword);
    expect(sha(pdf01), before);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('Protect then Unlock: opens without a password; pages and first-page render match (< 1%)', (_) async {
    final locked = p.join(dir.path, 'rt_locked.pdf'), out = p.join(dir.path, 'rt_unlocked.pdf');
    await security.protect(pdf01, locked, userPassword: 'Test-1234', ctx: ctx());
    final lockedSha = sha(locked);
    expect(await security.unlock(locked, out, password: 'Test-1234', ctx: ctx()), isA<Unlocked>());
    expect(await security.inspect(out), PdfProtection.none);
    expect(await pages(out), 10);
    expect(sha(locked), lockedSha, reason: 'the input is never changed');
    final a = await firstPage(pdf01), b = await firstPage(out);
    var diff = 0;
    for (var i = 0; i + 3 < a.length; i += 4) {
      if ((a[i] - b[i]).abs() > 8 || (a[i + 1] - b[i + 1]).abs() > 8 || (a[i + 2] - b[i + 2]).abs() > 8) diff++;
    }
    final share = diff / (a.length / 4);
    // ignore: avoid_print
    print('T11.2 round-trip first-page diff=${(share * 100).toStringAsFixed(3)}%');
    expect(share, lessThan(0.01));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('non-ASCII password: Protect, then PDFium alone and PdfSecurity both unlock', (_) async {
    const pw1 = 'पासवर्ड-Ünïcødé-密码';
    final locked = p.join(dir.path, 'u_locked.pdf');
    await security.protect(pdf01, locked, userPassword: pw1, ctx: ctx());
    final direct = await ops.removeSecurity(locked, p.join(dir.path, 'u_pdfium.pdf'), pw1);
    // ignore: avoid_print
    print('T11.2 PDFium non-ASCII unlock: $direct');
    expect(await security.unlock(locked, p.join(dir.path, 'u_out.pdf'), password: pw1, ctx: ctx()), isA<Unlocked>());
    expect(await pages(p.join(dir.path, 'u_out.pdf')), 10);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('wrong password → WrongPassword, no output left; owner-only → OwnerOnly, nothing written', (_) async {
    final locked = p.join(dir.path, 'w_locked.pdf'), out = p.join(dir.path, 'w_out.pdf');
    await security.protect(pdf01, locked, userPassword: 'Test-1234', ctx: ctx());
    expect(await security.unlock(locked, out, password: 'test-1234', ctx: ctx()), isA<WrongPassword>());
    expect(File(out).existsSync(), isFalse);

    final ownerOnly = p.join(dir.path, 'owner_only.pdf'), out2 = p.join(dir.path, 'o_out.pdf');
    final r = await native.protectPdf(
        inPath: pdf01, outPath: ownerOnly, userPassword: '', ownerPassword: randomOwnerPassword(), debugRestrict: true);
    expect(r['status'], 'ok');
    expect(await security.inspect(ownerOnly), PdfProtection.ownerOnly);
    expect(await security.unlock(ownerOnly, out2, password: 'anything', ctx: ctx()), isA<OwnerOnly>());
    expect(File(out2).existsSync(), isFalse);
    expect(await security.inspect(pdf01), PdfProtection.none);
  }, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() => dir.deleteSync(recursive: true));
}
