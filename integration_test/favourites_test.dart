// T8.11 on a device (RELEASE_V1_1 R35, FR-FAV-02/04): pin 6, try a 7th,
// reorder, then "restart": settings are rebuilt from the real on-device
// preferences, as on a fresh launch.
//
//   flutter test integration_test/favourites_test.dart -d <android device>
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/favourites/favourites_controller.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R35: pin 6, a 7th is refused, reorder, the order survives a restart', (_) async {
    Future<ProviderContainer> launch() async =>
        ProviderContainer(overrides: [settingsRepositoryProvider.overrideWithValue(SettingsRepository(await PrefsStore.open()))]);

    final first = await launch();
    final fav = first.read(favouritesProvider.notifier);
    for (final t in [...fav.state]) {
      fav.unpin(t); // start clean on a reused emulator
    }
    final six = [ToolId.pdfMerge, ToolId.imageCompress, ToolId.pdfSplit, ToolId.imageConvert, ToolId.pdfToImages, ToolId.imageResize];
    for (final t in six) {
      expect(fav.pin(t), PinResult.pinned);
    }
    expect(fav.pin(ToolId.pdfCompress), PinResult.limit);
    fav.reorder(5, 0); // Resize to the front
    fav.move(ToolId.pdfMerge, 1);
    final expected = [ToolId.imageResize, ToolId.imageCompress, ToolId.pdfMerge, ToolId.pdfSplit, ToolId.imageConvert, ToolId.pdfToImages];
    expect(first.read(favouritesProvider), expected);
    // Writes go over one platform channel in order: awaiting one more save
    // means every earlier one has landed.
    await first.read(settingsProvider.notifier).update((s) => s);
    first.dispose();

    final second = await launch();
    // ignore: avoid_print
    print('R35 after restart: ${second.read(favouritesProvider).map((t) => t.name).join(', ')}');
    expect(second.read(favouritesProvider), expected);
    final c = second.read(favouritesProvider.notifier);
    for (final t in expected) {
      c.unpin(t);
    }
    await second.read(settingsProvider.notifier).update((s) => s);
    second.dispose();
  });
}
