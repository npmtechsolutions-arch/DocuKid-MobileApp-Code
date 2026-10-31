import 'dart:async';
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
import 'package:docukit/core/ocr/text_recognizer.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/page_edit.dart';
import 'package:docukit/core/pdf/pdf_engine.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:docukit/core/pdf/pdf_security.dart';
import 'package:docukit/core/providers.dart';
import 'package:docukit/core/validation/input_validator.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/settings/settings_repository.dart';
import 'package:docukit/features/library/application/app_lock.dart';
import 'package:docukit/features/library/application/index_queue.dart';
import 'package:docukit/features/tour/tour_controller.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path/path.dart' as p;

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
  Future<ShareOutcome> share(List<String> paths, {required String mime, Rect? origin}) async {
    if (paths.length > Limits.maxShareFiles) return ShareOutcome.tooMany;
    sharedFiles.add(paths);
    return ShareOutcome.shared;
  }
  final sharedTexts = <String>[];
  final sharedFiles = <List<String>>[];
  @override
  Future<ShareOutcome> shareText(String text, {Rect? origin}) async {
    sharedTexts.add(text);
    return ShareOutcome.shared;
  }

  @override
  Future<bool> openWith(String path, {required String mime, Rect? origin}) async => true;
  @override
  Future<bool> exists(String path) async => false;
  @override
  Future<void> discardDraft(String draftId) async => discarded.add(draftId);
  final discarded = <String>[];

  /// What the next adoptIncoming returns (the files, already "inspected").
  List<PickedFile> nextIncoming = const [];
  @override
  Future<List<PickedFile>> adoptIncoming(List<({String path, String name})> files,
          {required String draftId, String? sourceDir}) async =>
      nextIncoming;
}

class FakeImageEngine implements ImageEngine {
  /// Set by a test that needs a real conversion; otherwise transform fails.
  Future<EncodedImage> Function(String inPath, String outPath, ImageTransform t)? onTransform;

  @override
  bool canEncode(ImageFormat format) => format != ImageFormat.heic;
  @override
  Future<ImageMeta> inspect(String path) async => const ImageMeta(format: SniffedType.jpeg, width: 10, height: 10);
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) =>
      onTransform?.call(inPath, outPath, t) ?? (throw const AppError(AppErrorCode.processingFailed));
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
  Future<PdfPageExtractor> openExtractor(String input) => throw const AppError(AppErrorCode.processingFailed);
  @override
  Future<void> reduce(String input, String out, ReduceLevel level, JobContext ctx) async {}
  @override
  Future<ui.Image?> renderPage(String path, int index, {required int targetWidthPx}) async => null;
}

class TestHarness {
  TestHarness._(this.db, this.paths, this.store, this.gateway);
  final device = FakeDevice();
  final native = FakeNative();
  final scanner = FakeDocumentScanner();
  final recognizer = FakeTextRecognizer();
  final textReader = FakePdfTextReader();
  final security = FakePdfSecurity();
  final images = FakeImageEngine();
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
          // A user who finished the tour has seen this version's steps too.
          if (tourDone) SettingsRepository.kTourVersion: currentTourVersion,
          ...store,
        }),
        FakeGateway(),
      );

  /// 1.5 indexing without PDFium / ML Kit: no text unless a test sets some.
  final textSource = QuietTextSource();

  /// 1.5 reminders without the plugin.
  final notifications = FakeNotifications();

  /// 1.5 app lock without local_auth.
  final auth = FakeDeviceAuth();

  Widget app({List<Override> overrides = const [], AdsService ads = const NoAdsService()}) => ProviderScope(
        overrides: [
          ...overrides,
          appPathsProvider.overrideWithValue(paths),
          databaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(store)),
          fileGatewayProvider.overrideWithValue(gateway),
          imageEngineProvider.overrideWithValue(images),
          pdfEngineProvider.overrideWithValue(FakePdfEngine()),
          deviceServicesProvider.overrideWithValue(device),
          nativeProvider.overrideWithValue(native),
          documentScannerProvider.overrideWithValue(scanner),
          textRecognizerFactoryProvider.overrideWithValue(() => recognizer),
          pdfTextReaderProvider.overrideWithValue(textReader),
          pdfSecurityProvider.overrideWithValue(security),
          adsServiceProvider.overrideWithValue(ads),
          purchaseServiceProvider.overrideWithValue(const NoPurchaseService()),
          docTextSourceProvider.overrideWithValue(textSource),
          notificationServiceProvider.overrideWithValue(notifications),
          deviceAuthProvider.overrideWithValue(auth),
        ],
        child: const DocuKitApp(),
      );
}

/// Protect/Unlock without engines: [protection] per path (default none);
/// outputs it writes need a password and open with the one used. [passwords]
/// maps a locked input's file name (copies keep it) to its password.
class FakePdfSecurity implements PdfSecurity {
  final protection = <String, PdfProtection>{};
  final passwords = <String, String>{};
  final protectedWith = <String>[];
  final unlockedWith = <String>[];
  var pages = 3;
  var failProtect = false;

  @override
  Future<PdfProtection> inspect(String path) async =>
      protection[path] ?? (passwords.containsKey(p.basename(path)) ? PdfProtection.openPassword : PdfProtection.none);

  @override
  Future<int?> openPageCount(String path, String password) async =>
      protectedWith.contains(password) || passwords[p.basename(path)] == password ? pages : null;

  @override
  Future<void> protect(String inPath, String outPath, {required String userPassword, required JobContext ctx}) async {
    if (failProtect) throw const AppError(AppErrorCode.processingFailed);
    protectedWith.add(userPassword);
    File(outPath).writeAsStringSync('%PDF locked');
    protection[outPath] = PdfProtection.openPassword;
  }

  @override
  Future<UnlockResult> unlock(String inPath, String outPath, {required String password, required JobContext ctx}) async {
    if (passwords[p.basename(inPath)] != password) return const WrongPassword();
    unlockedWith.add(password);
    File(outPath).writeAsStringSync('%PDF open');
    return const Unlocked();
  }
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

/// No platform channels in widget tests: incoming files are delivered by the
/// test (cold start: [pending]; warm start: [send]).
class FakeNative extends DocukitNative {
  /// 1.5 FR-LCK-05: each `setSecure` call, in order.
  final secure = <bool>[];
  @override
  Future<void> setSecure(bool on) async => secure.add(on);
  @override
  Future<void> setPrivacyCover(bool on) async {}

  final _incoming = StreamController<IncomingBatch>.broadcast();
  List<IncomingBatch> pending = const [];
  void send(IncomingBatch b) => _incoming.add(b);
  @override
  Future<List<IncomingBatch>> getIncomingFiles() async {
    final out = pending;
    pending = const [];
    return out;
  }

  @override
  Stream<IncomingBatch> get incomingFiles => _incoming.stream;

  /// Launcher shortcut (FR-SCN-22): cold start [pendingRoute], warm [sendRoute].
  final _routes = StreamController<String>.broadcast();
  String? pendingRoute;
  void sendRoute(String r) => _routes.add(r);
  @override
  Future<String?> takePendingRoute() async {
    final r = pendingRoute;
    pendingRoute = null;
    return r;
  }

  @override
  Stream<String> get shortcutRoutes => _routes.stream;
}

/// The index queue's text in widget tests: [ocr] by file name (else none),
/// no text layers, one page each.
class QuietTextSource implements DocTextSource {
  final ocr = <String, String>{};

  @override
  Future<int> pageCount(String path) async => 1;
  @override
  Future<String> textLayer(String path) async => '';
  @override
  Future<String> recognize(String path, {required bool isPdf, required int index, required OcrScript script, required Directory work}) async =>
      ocr[p.basename(path)] ?? '';
  @override
  Future<void> release() async {}
}
