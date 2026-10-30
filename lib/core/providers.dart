import 'dart:io';
import 'dart:ui' show Size;

import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/outputs_repository.dart';
import '../data/settings/app_settings.dart';
import '../data/settings/settings_repository.dart';
import 'files/file_gateway.dart';
import 'files/file_gateway_impl.dart';
import 'files/paths.dart';
import 'files/picked_file.dart';
import 'image/image_engine.dart';
import 'image/image_engine_impl.dart';
import 'image/page_image_encoder.dart';
import 'ocr/mlkit_text_recognizer.dart';
import 'ocr/pdf_text_reader.dart';
import 'ocr/pdfrx_text_reader.dart';
import 'ocr/text_recognizer.dart';
import 'operation/job_runner.dart';
import 'pdf/pdf_engine.dart';
import 'pdf/pdf_security.dart';
import 'pdf/pdf_stamper.dart';
import 'pdf/pdfium_security_ops.dart';
import 'pdf/pdfrx_pdf_engine.dart';
import 'platform/device_services.dart';
import 'scan/document_scanner.dart';

/// Overridden in main.dart (and in tests) — they need async setup.
final appPathsProvider = Provider<AppPaths>((ref) => throw UnimplementedError('override appPathsProvider'));
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override databaseProvider'));
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => throw UnimplementedError('override settingsRepositoryProvider'));

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final nativeProvider = Provider<DocukitNative>((ref) => DocukitNative());
final deviceServicesProvider = Provider<DeviceServices>((ref) => NativeDeviceServices(ref.watch(nativeProvider)));

final documentScannerProvider = Provider<DocumentScanner>((ref) => NativeDocumentScanner(ref.watch(nativeProvider)));

/// A new recogniser per OCR job; the job disposes it (RELEASE_V1_3 §4.2).
final textRecognizerFactoryProvider = Provider<TextRecognizer Function()>((ref) => MlKitTextRecognizer.new);
final pdfTextReaderProvider = Provider<PdfTextReader>((ref) => const PdfrxTextReader());

final imageEngineProvider = Provider<ImageEngine>((ref) => const NativeImageEngine());
final pdfEngineProvider = Provider<PdfEngine>((ref) => PdfrxPdfEngine());
/// Protect/Unlock (ADR-049): Unlock's native fallback is Android-only for now.
final pdfSecurityProvider = Provider<PdfSecurity>(
    (ref) => NativePdfSecurity(ref.watch(nativeProvider), const PdfrxSecurityOps(), nativeUnlock: Platform.isAndroid));
/// Sign / Watermark (ADR-048).
final pdfStamperProvider = Provider<PdfStamper>((ref) => const PdfiumStamper());

/// A PDF's visual page sizes (points) when the pick didn't carry them (a
/// restored draft).
final pdfPageSizesProvider = FutureProvider.autoDispose.family<List<Size>, String>((ref, path) async {
  final meta = await ref.watch(pdfEngineProvider).inspect(path);
  return [for (final (w, h) in meta.pageSizes) Size(w, h)];
});

/// [file]'s page sizes now, or null while they're being read (S35, S36).
List<Size>? visualPageSizes(WidgetRef ref, PickedFile file) {
  final m = file.pdf;
  if (m != null && m.pageSizes.length == m.pageCount && m.pageCount > 0) {
    return [for (final (w, h) in m.pageSizes) Size(w, h)];
  }
  return ref.watch(pdfPageSizesProvider(file.path)).value;
}

/// What a picked PDF's security allows, keyed by its path (S37/S38).
final pdfProtectionProvider = FutureProvider.autoDispose.family<PdfProtection, String>(
  (ref, path) => ref.watch(pdfSecurityProvider).inspect(path),
);
final pageImageEncoderProvider = Provider<PageImageEncoder>((ref) => const NativePageImageEncoder());

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository(ref.watch(databaseProvider)));
final outputsRepositoryProvider = Provider<OutputsRepository>((ref) {
  final device = ref.watch(deviceServicesProvider);
  return OutputsRepository(ref.watch(appPathsProvider), protect: device.protectOutput);
});

final fileGatewayProvider = Provider<FileGateway>((ref) => PluginFileGateway(
      paths: ref.watch(appPathsProvider),
      images: ref.watch(imageEngineProvider),
      pdfs: ref.watch(pdfEngineProvider),
      native: ref.watch(nativeProvider),
    ));

final jobRunnerProvider = Provider<JobRunner>((ref) => JobRunner(
      paths: ref.watch(appPathsProvider),
      history: ref.watch(historyRepositoryProvider),
      outputs: ref.watch(outputsRepositoryProvider),
      device: ref.watch(deviceServicesProvider),
      clock: ref.watch(clockProvider),
    ));

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  /// Saves immediately (S16: no Save button).
  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
