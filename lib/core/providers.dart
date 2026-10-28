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
import 'image/image_engine.dart';
import 'image/image_engine_impl.dart';
import 'image/page_image_encoder.dart';
import 'operation/job_runner.dart';
import 'pdf/pdf_engine.dart';
import 'pdf/pdfrx_pdf_engine.dart';
import 'platform/device_services.dart';

/// Overridden in main.dart (and in tests) — they need async setup.
final appPathsProvider = Provider<AppPaths>((ref) => throw UnimplementedError('override appPathsProvider'));
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override databaseProvider'));
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => throw UnimplementedError('override settingsRepositoryProvider'));

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final nativeProvider = Provider<DocukitNative>((ref) => DocukitNative());
final deviceServicesProvider = Provider<DeviceServices>((ref) => NativeDeviceServices(ref.watch(nativeProvider)));

final imageEngineProvider = Provider<ImageEngine>((ref) => const NativeImageEngine());
final pdfEngineProvider = Provider<PdfEngine>((ref) => PdfrxPdfEngine());
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
