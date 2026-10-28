// RELEASE_V1_2 §4.3 / T9.1 — the scanDocument channel contract, with the
// native side mocked. The real ML Kit scanner is checked by hand (R37, R41, R42).
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('docukit/native.scan_test');
  final calls = <MethodCall>[];
  late Object? reply;
  Object? Function()? throwing;
  final native = DocukitNative(channel: channel);

  setUp(() {
    calls.clear();
    reply = null;
    throwing = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (throwing != null) throwing!();
      return reply;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  group('scanDocument', () {
    test('sends the page limit, the destination folder and gallery import', () async {
      reply = {'status': 'cancelled'};
      await native.scanDocument(maxPages: 47, destDir: '/c/jobs/d1/in', allowGalleryImport: true);
      expect(calls.single.method, 'scanDocument');
      expect(calls.single.arguments, {'maxPages': 47, 'destDir': '/c/jobs/d1/in', 'allowGalleryImport': true});
    });

    test('completed: the page paths in order', () async {
      reply = {
        'status': 'completed',
        'pagePaths': ['/in/page_001.jpg', '/in/page_002.jpg'],
      };
      final r = await native.scanDocument(maxPages: 50, destDir: '/in') as NativeScanCompleted;
      expect(r.pagePaths, ['/in/page_001.jpg', '/in/page_002.jpg']);
      expect(r.truncated, isFalse);
    });

    test('completed with truncated (iOS kept only the first pages)', () async {
      reply = {
        'status': 'completed',
        'pagePaths': ['/in/page_001.jpg'],
        'truncated': true,
      };
      final r = await native.scanDocument(maxPages: 1, destDir: '/in') as NativeScanCompleted;
      expect(r.truncated, isTrue);
    });

    test('cancelled', () async {
      reply = {'status': 'cancelled'};
      expect(await native.scanDocument(maxPages: 50, destDir: '/in'), isA<NativeScanCancelled>());
    });

    for (final code in ['moduleUnavailable', 'offline', 'noPlayServices', 'unsupported', 'cameraDenied', 'storage']) {
      test('failed: $code passes through', () async {
        reply = {'status': 'failed', 'errorCode': code};
        final r = await native.scanDocument(maxPages: 50, destDir: '/in') as NativeScanFailed;
        expect(r.code, code);
      });
    }

    test('failed without a code, or a platform error → unknown / the error code', () async {
      reply = {'status': 'failed'};
      expect((await native.scanDocument(maxPages: 50, destDir: '/in') as NativeScanFailed).code, 'unknown');
      throwing = () => throw PlatformException(code: 'busy');
      expect((await native.scanDocument(maxPages: 50, destDir: '/in') as NativeScanFailed).code, 'busy');
    });

    test('no plugin (e.g. a platform without the scanner) → unsupported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      expect((await native.scanDocument(maxPages: 50, destDir: '/in') as NativeScanFailed).code, 'unsupported');
    });
  });

  group('scanAvailability', () {
    for (final s in NativeScanAvailability.values) {
      test('maps ${s.name}', () async {
        reply = {'status': s.name};
        expect(await native.scanAvailability(), s);
      });
    }

    test('an unknown answer or an error → unsupported', () async {
      reply = {'status': 'what'};
      expect(await native.scanAvailability(), NativeScanAvailability.unsupported);
      throwing = () => throw PlatformException(code: 'x');
      expect(await native.scanAvailability(), NativeScanAvailability.unsupported);
    });
  });

  group('prepareScanner', () {
    for (final s in NativeScanPrepare.values) {
      test('maps ${s.name}', () async {
        reply = {'status': s.name};
        expect(await native.prepareScanner(), s);
        expect(calls.last.method, 'prepareScanner');
      });
    }

    test('an error → failed', () async {
      throwing = () => throw PlatformException(code: 'x');
      expect(await native.prepareScanner(), NativeScanPrepare.failed);
    });
  });

  group('takeRestoredScan (FR-SCN-20)', () {
    test('nothing pending → null', () async {
      reply = null;
      expect(await native.takeRestoredScan(), isNull);
    });

    test('a result delivered after process death comes back once, with its folder', () async {
      reply = {
        'destDir': '/c/jobs/d1/in',
        'result': {
          'status': 'completed',
          'pagePaths': ['/c/jobs/d1/in/page_003.jpg'],
        },
      };
      final r = await native.takeRestoredScan();
      expect(r!.destDir, '/c/jobs/d1/in');
      expect((r.result as NativeScanCompleted).pagePaths, ['/c/jobs/d1/in/page_003.jpg']);
      expect(calls.single.method, 'takeRestoredScan');
    });

    test('an error → null', () async {
      throwing = () => throw PlatformException(code: 'x');
      expect(await native.takeRestoredScan(), isNull);
    });
  });
}
