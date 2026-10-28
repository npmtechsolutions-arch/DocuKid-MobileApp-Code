// RELEASE_V1_1 §4.4 / FR-BAT-02 / FR-BAT-04 — save many and the share cap,
// through PluginFileGateway with the native channel mocked (T8.3). The real
// folder picker is checked on the emulator (integration_test/save_many_test.dart).
import 'package:docukit/core/files/file_gateway.dart';
import 'package:docukit/core/files/file_gateway_impl.dart';
import 'package:docukit/core/validation/input_validator.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('docukit/native.test');
  final calls = <MethodCall>[];
  late Map<String, Object?>? reply;
  late PluginFileGateway gateway;

  setUp(() async {
    calls.clear();
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply;
    });
    gateway = PluginFileGateway(
      paths: await tempPaths(),
      images: FakeImageEngine(),
      pdfs: FakePdfEngine(),
      native: DocukitNative(channel: channel),
    );
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  const items = [
    SaveItem(path: '/o/1.jpg', name: 'photo.jpg', mime: 'image/jpeg'),
    SaveItem(path: '/o/2.jpg', name: 'photo.jpg', mime: 'image/jpeg'),
    SaveItem(path: '/o/3.pdf', name: 'a:b.pdf', mime: 'application/pdf'),
  ];

  test('sends paths with unique, safe names and one mime each', () async {
    reply = {'status': 'saved', 'savedCount': 3, 'failedCount': 0, 'folderName': 'DocuKit'};
    await gateway.saveManyToFolder(items);
    expect(calls.single.method, 'saveManyToFolder');
    final sent = ((calls.single.arguments as Map)['items'] as List).cast<Map<Object?, Object?>>();
    expect(sent.map((m) => m['path']), ['/o/1.jpg', '/o/2.jpg', '/o/3.pdf']);
    expect(sent.map((m) => m['name']), ['photo.jpg', 'photo (1).jpg', 'a_b.pdf']);
    expect(sent.map((m) => m['mime']), ['image/jpeg', 'image/jpeg', 'application/pdf']);
  });

  test('saved: counts and the folder name come back', () async {
    reply = {'status': 'saved', 'savedCount': 2, 'failedCount': 1, 'folderName': 'DocuKit'};
    final r = await gateway.saveManyToFolder(items) as SavedMany;
    expect((r.saved, r.failed, r.folderName), (2, 1, 'DocuKit'));
  });

  test('cancelled and failed map to their outcomes', () async {
    reply = {'status': 'cancelled'};
    expect(await gateway.saveManyToFolder(items), isA<SaveManyCancelled>());
    reply = {'status': 'failed', 'code': 'busy'};
    expect(await gateway.saveManyToFolder(items), isA<SaveManyFailed>());
  });

  test('nothing to save: no picker is shown', () async {
    expect(await gateway.saveManyToFolder(const []), isA<SaveManyFailed>());
    expect(calls, isEmpty);
  });

  test('share refuses more than 50 files (FR-BAT-04: offer a ZIP instead)', () async {
    expect(Limits.maxShareFiles, 50);
    final paths = [for (var i = 0; i < 51; i++) '/o/$i.jpg'];
    expect(await gateway.share(paths, mime: 'image/jpeg'), ShareOutcome.tooMany);
  });
}
