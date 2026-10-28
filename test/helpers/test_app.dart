import 'dart:io';
import 'dart:ui' as ui;

import 'package:docukit/app/app.dart';
import 'package:docukit/core/ads/ads_service.dart';
import 'package:docukit/core/ads/remove_ads.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/file_gateway.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/page_edit.dart';
import 'package:docukit/core/pdf/pdf_engine.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/core/validation/input_validator.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fakes.dart';

class FakeGateway implements FileGateway {
  List<PickedFile> nextImages = const [];
  List<PickedFile> nextPdfs = const [];

  /// Simulates the picker plugin failing to copy the chosen file (e.g. ENOSPC).
  bool throwOnPick = false;

  @override
  Future<PickResult> pickImages({required String draftId, required int max}) async {
    if (throwOnPick) throw const FileSystemException('copy failed');
    return PickResult(nextImages);
  }

  @override
  Future<PickResult> pickPdfs({required String draftId, required bool multiple, int max = 20}) async {
    if (throwOnPick) throw const FileSystemException('copy failed');
    return PickResult(nextPdfs);
  }
  @override
  Future<List<PickedFile>> reinspect(List<PickedFile> files) async => files;
  @override
  Future<SaveOutcome> saveAs(String path, {required String suggestedName, required String mime}) async => const Saved();
  @override
  Future<SaveOutcome> saveToPhotos(String path) async => const Saved();
  /// What the next save-many returns; null → all saved.
  SaveManyOutcome? nextSaveMany;
  final savedMany = <List<SaveItem>>[];
  @override
  Future<SaveManyOutcome> saveManyToFolder(List<SaveItem> items) async {
    savedMany.add(items);
    return nextSaveMany ?? SavedMany(saved: items.length, failed: 0, folderName: 'DocuKit');
  }
  @override
  Future<ShareOutcome> share(List<String> paths, {required String mime, Rect? origin}) async =>
      paths.length > Limits.maxShareFiles ? ShareOutcome.tooMany : ShareOutcome.shared;
  @override
  Future<bool> openWith(String path, {required String mime, Rect? origin}) async => true;
  @override
  Future<bool> exists(String path) async => false;
  @override
  Future<void> discardDraft(String draftId) async {}
}

class FakeImageEngine implements ImageEngine {
  @override
  bool canEncode(ImageFormat format) => format != ImageFormat.heic;
  @override
  Future<ImageMeta> inspect(String path) async => const ImageMeta(format: SniffedType.jpeg, width: 10, height: 10);
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) =>
      throw const AppError(AppErrorCode.processingFailed);
}

class FakePdfEngine implements PdfEngine {
  @override
  Future<PdfAnalysis> analyse(String path, int fileBytes) async =>
      const PdfAnalysis(pageCount: 3, imageCount: 0, imageHeavy: false);
  @override
  Future<void> close(String path) async {}
  @override
  Future<void> combineFiles(List<String> inputs, String out) async {}
  @override
  Future<PdfMeta> inspect(String path) async => const PdfMeta(pageCount: 3);
  @override
  Future<void> merge(List<String> inputs, String out, JobContext ctx) async {}
  @override
  Future<void> organize(String input, List<PageEdit> edits, String out, JobContext ctx) async {}
  @override
  Future<void> reduce(String input, String out, ReduceLevel level, JobContext ctx) async {}
  @override
  Future<ui.Image?> renderPage(String path, int index, {required int targetWidthPx}) async => null;
}

class TestHarness {
  TestHarness._(this.db, this.paths, this.store, this.gateway);
  final device = FakeDevice();
  final AppDatabase db;
  final AppPaths paths;
  final MemoryStore store;
  final FakeGateway gateway;

  /// [tourDone] defaults to true so screens under test aren't covered by the
  /// auto-starting Home tour (tour tests pass false).
  static Future<TestHarness> create({bool onboarded = true, bool tourDone = true, Map<String, Object> store = const {}}) async =>
      TestHarness._(
        memoryDb(),
        await tempPaths(),
        MemoryStore({
          if (onboarded) SettingsRepository.kOnboarding: true,
          if (tourDone) SettingsRepository.kTourDone: true,
          ...store,
        }),
        FakeGateway(),
      );

  Widget app({List<Override> overrides = const [], AdsService ads = const NoAdsService()}) => ProviderScope(
        overrides: [
          ...overrides,
          appPathsProvider.overrideWithValue(paths),
          databaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(store)),
          fileGatewayProvider.overrideWithValue(gateway),
          imageEngineProvider.overrideWithValue(FakeImageEngine()),
          pdfEngineProvider.overrideWithValue(FakePdfEngine()),
          deviceServicesProvider.overrideWithValue(device),
          adsServiceProvider.overrideWithValue(ads),
          purchaseServiceProvider.overrideWithValue(const NoPurchaseService()),
        ],
        child: const DocuKitApp(),
      );
}

PickedFile fakeImage(String name, {bool alpha = false, SniffedType type = SniffedType.jpeg}) => PickedFile(
      path: '/nonexistent/$name',
      displayName: name,
      type: type,
      sizeBytes: 300 * 1024,
      image: ImageMeta(format: type, width: 4000, height: 3000, hasAlpha: alpha),
      status: alpha ? const ValidationStatus.warning({WarningCode.hasAlpha}) : const ValidationStatus.ok(),
    );

PickedFile fakePdf(String name, {bool encrypted = false, int pages = 3}) => PickedFile(
      path: '/nonexistent/$name',
      displayName: name,
      type: SniffedType.pdf,
      sizeBytes: 1024 * 1024,
      pdf: encrypted ? null : PdfMeta(pageCount: pages),
      status: encrypted ? const ValidationStatus.invalid(AppErrorCode.encryptedDocument) : const ValidationStatus.ok(),
    );
