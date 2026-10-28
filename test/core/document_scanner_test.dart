// T9.3 — NativeDocumentScanner maps the plugin's answers onto the app's
// scanner contract (RELEASE_V1_2 §4.2); the enums must stay in step.
import 'package:docukit/core/scan/document_scanner.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('docukit/native.scanner_test');
  late Object? reply;
  final scanner = NativeDocumentScanner(DocukitNative(channel: channel));

  setUp(() {
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => reply);
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('the enums match the plugin\'s', () {
    expect(ScannerAvailability.values.map((e) => e.name), NativeScanAvailability.values.map((e) => e.name));
    expect(ScanPrepareResult.values.map((e) => e.name), NativeScanPrepare.values.map((e) => e.name));
  });

  test('availability and prepare', () async {
    reply = {'status': 'needsDownload'};
    expect(await scanner.availability(), ScannerAvailability.needsDownload);
    reply = {'status': 'offline'};
    expect(await scanner.prepare(), ScanPrepareResult.offline);
  });

  test('scan outcomes', () async {
    reply = {'status': 'completed', 'pagePaths': ['/in/page_001.jpg'], 'truncated': true};
    final done = await scanner.scan(maxPages: 50, destDir: '/in') as ScanCompleted;
    expect(done.pagePaths, ['/in/page_001.jpg']);
    expect(done.truncated, isTrue);
    reply = {'status': 'cancelled'};
    expect(await scanner.scan(maxPages: 50, destDir: '/in'), isA<ScanCancelled>());
    for (final code in ScanErrorCode.values) {
      reply = {'status': 'failed', 'errorCode': code.name};
      expect((await scanner.scan(maxPages: 50, destDir: '/in') as ScanFailed).code, code);
    }
    reply = {'status': 'failed', 'errorCode': 'busy'};
    expect((await scanner.scan(maxPages: 50, destDir: '/in') as ScanFailed).code, ScanErrorCode.unknown);
  });

  test('restored scan', () async {
    reply = {
      'destDir': '/in',
      'result': {'status': 'completed', 'pagePaths': ['/in/page_002.jpg']},
    };
    final r = await scanner.takeRestored();
    expect(r!.destDir, '/in');
    expect((r.outcome as ScanCompleted).pagePaths, ['/in/page_002.jpg']);
    reply = null;
    expect(await scanner.takeRestored(), isNull);
  });
}
