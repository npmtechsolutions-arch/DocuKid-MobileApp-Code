// T8.11 — Favourites (RELEASE_V1_1 FR-FAV-01…04, §4.9, §8.1: cap 6,
// reorder, unknown ids dropped), written before the implementation.
import 'package:docukit/core/providers.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/favourites/favourites_controller.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer c;

  ProviderContainer container() => ProviderContainer(overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(store)),
      ]);

  setUp(() {
    store = MemoryStore();
    c = container();
  });
  tearDown(() => c.dispose());

  FavouritesController fav() => c.read(favouritesProvider.notifier);
  List<ToolId> favs() => c.read(favouritesProvider);

  test('empty by default', () => expect(favs(), isEmpty));

  test('pin keeps the order pinned; pinning twice is a no-op', () {
    expect(fav().pin(ToolId.pdfMerge), PinResult.pinned);
    expect(fav().pin(ToolId.imageCompress), PinResult.pinned);
    expect(fav().pin(ToolId.pdfMerge), PinResult.pinned);
    expect(favs(), [ToolId.pdfMerge, ToolId.imageCompress]);
    expect(fav().isPinned(ToolId.pdfMerge), isTrue);
  });

  test('at most 6: a 7th is refused (FR-FAV-02)', () {
    final tools = ToolId.values.take(7).toList();
    for (final t in tools.take(6)) {
      expect(fav().pin(t), PinResult.pinned);
    }
    expect(fav().pin(tools[6]), PinResult.limit);
    expect(favs(), tools.take(6));
    expect(FavouritesController.max, 6);
  });

  test('unpin and toggle', () {
    fav()
      ..pin(ToolId.pdfMerge)
      ..pin(ToolId.pdfSplit)
      ..unpin(ToolId.pdfMerge);
    expect(favs(), [ToolId.pdfSplit]);
    expect(fav().toggle(ToolId.pdfSplit), PinResult.unpinned);
    expect(favs(), isEmpty);
  });

  test('reorder and move up / down (FR-FAV-03)', () {
    for (final t in [ToolId.imageCompress, ToolId.imageResize, ToolId.pdfMerge]) {
      fav().pin(t);
    }
    fav().reorder(2, 0);
    expect(favs(), [ToolId.pdfMerge, ToolId.imageCompress, ToolId.imageResize]);
    fav().move(ToolId.imageResize, -1);
    expect(favs(), [ToolId.pdfMerge, ToolId.imageResize, ToolId.imageCompress]);
    fav().move(ToolId.pdfMerge, -1); // already first: no-op
    expect(favs().first, ToolId.pdfMerge);
  });

  test('persisted as a JSON list of names; survives a restart (FR-FAV-04)', () async {
    fav()
      ..pin(ToolId.pdfToImages)
      ..pin(ToolId.imageConvert);
    await pumpEventQueue();
    expect(store.get(SettingsRepository.kFavouriteTools), '["pdfToImages","imageConvert"]');
    final again = container();
    addTearDown(again.dispose);
    expect(again.read(favouritesProvider), [ToolId.pdfToImages, ToolId.imageConvert]);
  });

  test('unknown ids (other versions), duplicates and junk are dropped silently; still capped at 6', () {
    store = MemoryStore({
      SettingsRepository.kFavouriteTools:
          '["pdfMerge","scanDocument","pdfMerge",3,"imageCompress","imageResize","pdfSplit","pdfOrganize","pdfCompress","imageToPdf"]',
    });
    final x = container();
    addTearDown(x.dispose);
    expect(x.read(favouritesProvider),
        [ToolId.pdfMerge, ToolId.imageCompress, ToolId.imageResize, ToolId.pdfSplit, ToolId.pdfOrganize, ToolId.pdfCompress]);
    store = MemoryStore({SettingsRepository.kFavouriteTools: 'not json'});
    final y = container();
    addTearDown(y.dispose);
    expect(y.read(favouritesProvider), isEmpty);
  });
}
