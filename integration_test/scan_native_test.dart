// T9.1 acceptance (RELEASE_V1_2 §9): the real scanDocument channel on Android.
// The scanner UI itself can't be automated (R37, R40, R42 are manual).
//
//   flutter test integration_test/scan_native_test.dart -d <android device>
//   # on a device that has never downloaded the scanner, in airplane mode:
//   flutter test integration_test/scan_native_test.dart -d <device> --dart-define=SCAN_EXPECT=offline
import 'dart:io';

import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// What the device should report without overrides: `ready` (module installed),
/// `moduleUnavailable` (not installed, online) or `offline`.
const scanExpect = String.fromEnvironment('SCAN_EXPECT', defaultValue: 'moduleUnavailable');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final native = DocukitNative();
  late Directory dest;

  setUp(() async {
    dest = Directory(p.join((await getTemporaryDirectory()).path, 'scan_native', 'in'))..createSync(recursive: true);
  });

  tearDown(() async {
    await native.debugSetScanOverride(null);
    if (dest.existsSync()) dest.deleteSync(recursive: true);
  });

  testWidgets('no Play services (debug flag) → noPlayServices before launch', (tester) async {
    await native.debugSetScanOverride('noPlayServices');
    expect(await native.scanAvailability(), NativeScanAvailability.noPlayServices);
    final r = await native.scanDocument(maxPages: 50, destDir: dest.path);
    expect((r as NativeScanFailed).code, 'noPlayServices');
    expect(dest.listSync(), isEmpty);
  });

  testWidgets('cancel (debug flag) → cancelled, nothing written', (tester) async {
    await native.debugSetScanOverride('cancelled');
    expect(await native.scanDocument(maxPages: 50, destDir: dest.path), isA<NativeScanCancelled>());
    expect(dest.listSync(), isEmpty);
  });

  testWidgets('the real scanner path reports $scanExpect', (tester) async {
    final availability = await native.scanAvailability();
    final sw = Stopwatch()..start();
    final r = await native.scanDocument(maxPages: 50, destDir: dest.path);
    // Counts and codes only (CLAUDE.md rule 4).
    // ignore: avoid_print
    print('SCAN availability=${availability.name} result=${r.runtimeType} '
        'code=${r is NativeScanFailed ? r.code : '-'} ms=${sw.elapsedMilliseconds}');
    if (scanExpect == 'ready') {
      expect(availability, NativeScanAvailability.ready);
      return; // The scanner opened; the rest is manual (R37).
    }
    expect(availability, NativeScanAvailability.needsDownload);
    expect((r as NativeScanFailed).code, scanExpect);
    expect(dest.listSync(), isEmpty);
    if (scanExpect == 'offline') expect(await native.prepareScanner(), NativeScanPrepare.offline);
  });

  testWidgets('no restored scan without a process death', (tester) async {
    expect(await native.takeRestoredScan(), isNull);
  });
}
