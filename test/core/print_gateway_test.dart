// T13.4 — the print gateway (RELEASE_PRINT §4.2, §8; ADR-069), written before
// the implementation: outcome mapping with a fake channel, the paper the
// dialog starts on, and a system flow around the dialog.

import 'package:docukit/core/platform/system_flow.dart';
import 'package:docukit/core/print/print_composer.dart';
import 'package:docukit/core/print/print_gateway.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const a4 = Size(595.28, 841.89);
const a4Land = Size(841.89, 595.28);

class _FakeNative extends DocukitNative {
  Object reply = 'sent';
  bool available = true;
  final calls = <Map<String, Object?>>[];
  bool flowWasActive = false;

  @override
  Future<String> printPdf(
    String path, {
    required String jobName,
    double? widthPt,
    double? heightPt,
    bool landscape = false,
    Rect? origin,
  }) async {
    flowWasActive = SystemFlow.active;
    calls.add({'path': path, 'jobName': jobName, 'w': widthPt, 'h': heightPt, 'landscape': landscape, 'origin': origin});
    final r = reply;
    if (r is Exception) throw r;
    return r as String;
  }

  @override
  Future<bool> printingAvailable() async {
    if (!available) throw PlatformException(code: 'x');
    return true;
  }
}

PrintOutput output(List<Size> sheets) => PrintOutput(path: '/w/print.pdf', sheetCount: sheets.length, sheetSizesPt: sheets);

void main() {
  late _FakeNative native;
  late NativePrintGateway gateway;
  setUp(() {
    native = _FakeNative();
    gateway = NativePrintGateway(native);
  });

  group('outcome mapping (FR-PRN-12)', () {
    for (final (reply, outcome) in [
      ('sent', PrintOutcome.sent),
      ('cancelled', PrintOutcome.cancelled),
      ('failed', PrintOutcome.failed),
      ('printed', PrintOutcome.failed),
      ('', PrintOutcome.failed),
    ]) {
      test('"$reply" → $outcome', () async {
        native.reply = reply;
        expect(await gateway.print(output([a4]), jobName: 'x'), outcome);
      });
    }
    test('a channel error → failed', () async {
      native.reply = PlatformException(code: 'boom');
      expect(await gateway.print(output([a4]), jobName: 'x'), PrintOutcome.failed);
    });
    test('a missing plugin → failed', () async {
      native.reply = MissingPluginException();
      expect(await gateway.print(output([a4]), jobName: 'x'), PrintOutcome.failed);
    });
  });

  test('passes the file path (never bytes), the job name, the paper and the iPad anchor; runs as a system flow', () async {
    const origin = Rect.fromLTWH(10, 20, 30, 40);
    await gateway.print(output([a4Land, a4Land]), jobName: 'Report', origin: origin);
    final c = native.calls.single;
    expect(c['path'], '/w/print.pdf');
    expect(c['jobName'], 'Report');
    expect(c['w'], closeTo(595.28, 0.01), reason: 'portrait-normalised');
    expect(c['h'], closeTo(841.89, 0.01));
    expect(c['landscape'], isTrue);
    expect(c['origin'], origin);
    expect(native.flowWasActive, isTrue, reason: 'the app lock ignores the print dialog');
    expect(SystemFlow.active, isFalse);
  });

  test('printingAvailable: the platform answer; an error → false', () async {
    expect(await gateway.available(), isTrue);
    native.available = false;
    expect(await gateway.available(), isFalse);
  });

  group('dialogPaper', () {
    test('one size: that size, portrait-normalised, with its orientation', () {
      final p = dialogPaper([a4Land]);
      expect((p.widthPt, p.heightPt, p.landscape), (a4.width, a4.height, true));
      expect(dialogPaper([a4]).landscape, isFalse);
    });
    test('mixed orientations (Auto): the one most sheets use; a tie follows the first sheet', () {
      expect(dialogPaper([a4, a4Land, a4]).landscape, isFalse);
      expect(dialogPaper([a4Land, a4, a4Land]).landscape, isTrue);
      expect(dialogPaper([a4Land, a4]).landscape, isTrue);
      expect(dialogPaper([a4, a4Land]).landscape, isFalse);
    });
    test('mixed sizes (Same as document): the most common size; a tie follows the first sheet', () {
      const letter = Size(612, 792);
      final p = dialogPaper([letter, a4, a4]);
      expect((p.widthPt, p.heightPt), (a4.width, a4.height));
      final q = dialogPaper([letter, a4]);
      expect((q.widthPt, q.heightPt), (612.0, 792.0));
    });
    test('sizes within 1 pt count as the same paper', () {
      final p = dialogPaper([const Size(595.0, 842.0), a4, const Size(612, 792)]);
      expect(p.widthPt, closeTo(595.0, 1));
    });
  });

  test('print work folders use the swept prefix', () => expect(printJobPrefix, 'print_'));
}
