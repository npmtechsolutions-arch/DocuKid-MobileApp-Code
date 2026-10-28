// T8.3 acceptance (RELEASE_V1_1 §9): save 50 files into a folder the user
// picks, through the real gateway and the system folder picker. Interactive:
// pick a folder and tap "Use this folder" → "Allow" when the picker opens
// (run twice into the same folder to see the provider add " (1)").
//
//   flutter test integration_test/save_many_test.dart -d <android device>
import 'dart:io';

import 'package:docukit/core/files/file_gateway.dart';
import 'package:docukit/core/files/file_gateway_impl.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save 50 files to a picked folder', (tester) async {
    final tmp = await getTemporaryDirectory();
    final src = Directory(p.join(tmp.path, 'save_many_src'))..createSync(recursive: true);
    addTearDown(() => src.deleteSync(recursive: true));
    final items = [
      for (var i = 0; i < 50; i++)
        SaveItem(
          path: (File(p.join(src.path, 'out_$i.jpg'))..writeAsBytesSync(List.filled(1024 * 1024, i))).path,
          name: 'DocuKit_test_$i.jpg',
          mime: 'image/jpeg',
        ),
    ];
    final support = await getApplicationSupportDirectory();
    final gateway = PluginFileGateway(
      paths: AppPaths(cacheRoot: tmp, supportRoot: support),
      images: FakeImageEngine(),
      pdfs: FakePdfEngine(),
      native: DocukitNative(),
    );
    final sw = Stopwatch()..start();
    final r = await gateway.saveManyToFolder(items);
    sw.stop();
    // Timing includes the time spent in the picker; counts are what matter.
    // ignore: avoid_print
    print('SAVE_MANY ${r.runtimeType} ${r is SavedMany ? '${r.saved}/${r.failed} folder=${r.folderName}' : ''} ${sw.elapsedMilliseconds}ms');
    expect(r, isA<SavedMany>());
    expect((r as SavedMany).saved, 50);
    expect(r.failed, 0);
    expect(r.folderName, isNotNull);
    // Originals untouched (rule 1).
    for (final i in items) {
      expect(File(i.path).lengthSync(), 1024 * 1024);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
