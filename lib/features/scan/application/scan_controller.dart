import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/files/mime_sniffer.dart';
import '../../../core/files/picked_file.dart';
import '../../../core/logging/log.dart';
import '../../../core/providers.dart';
import '../../../core/scan/document_scanner.dart';

/// Where the scan flow is (S27): checking → preparing (module download) →
/// scanning (system UI) → adding (inspecting the returned pages).
enum ScanPhase { idle, checking, preparing, scanning, adding }

/// The S27/S29 banner for a scanner problem (RELEASE_V1_2 §2.1, §7).
enum ScanBanner {
  /// scn_err_module_offline + Retry (FR-SCN-07).
  moduleOffline,

  /// scn_err_unavailable_android + Choose photos instead (FR-SCN-06).
  noPlayServices,

  /// scn_err_unavailable_ios + Choose photos instead (FR-SCN-09).
  unsupported,

  /// scn_err_camera_denied + Open Settings + Choose photos instead (FR-SCN-08).
  cameraDenied,

  /// The existing low-storage message.
  storage,

  /// scn_err_unknown + Retry.
  unknown,
}

/// One-shot information after a scan (FR-SCN-02).
enum ScanNotice { truncated, limitReached }

class ScanFlowState {
  const ScanFlowState({this.phase = ScanPhase.idle, this.banner, this.notice});
  final ScanPhase phase;
  final ScanBanner? banner;
  final ScanNotice? notice;

  bool get busy => phase != ScanPhase.idle;

  @override
  bool operator ==(Object other) =>
      other is ScanFlowState && other.phase == phase && other.banner == banner && other.notice == notice;

  @override
  int get hashCode => Object.hash(phase, banner, notice);
}

/// How long "Getting the scanner ready…" may show (FR-SCN-07).
final scanPrepareTimeoutProvider = Provider<Duration>((ref) => const Duration(seconds: 60));

/// Runs the system scanner for a scan draft (RELEASE_V1_2 §4.4). The pages
/// themselves live in the shared page model (ToolInputs, as on Images to PDF);
/// this returns the new ones for the caller to append. Never writes history.
class ScanController extends Notifier<ScanFlowState> {
  static const maxPages = 50;

  /// Bumped by [cancelPreparing], so a download that finishes later is ignored.
  int _run = 0;

  @override
  ScanFlowState build() => const ScanFlowState();

  /// Cancel on "Getting the scanner ready…": back to the entry. The download
  /// itself carries on in Play services.
  void cancelPreparing() {
    if (state.phase != ScanPhase.preparing) return;
    _run++;
    state = const ScanFlowState();
  }

  /// Opens the scanner for up to `50 − existing` pages ([limit] 1 for
  /// "Rescan this page"). Returns the new pages, or nothing on cancel or error.
  Future<List<PickedFile>> scan({required String draftId, required int existing, int? limit}) async {
    if (state.busy) return const [];
    final room = maxPages - existing;
    if (room <= 0) {
      state = const ScanFlowState(notice: ScanNotice.limitReached);
      return const [];
    }
    final scanner = ref.read(documentScannerProvider);
    state = const ScanFlowState(phase: ScanPhase.checking);

    switch (await scanner.availability()) {
      case ScannerAvailability.ready:
        break;
      case ScannerAvailability.needsDownload:
        if (!ref.mounted) return const [];
        state = const ScanFlowState(phase: ScanPhase.preparing);
        final run = _run;
        final ready = await scanner
            .prepare()
            .timeout(ref.read(scanPrepareTimeoutProvider), onTimeout: () => ScanPrepareResult.failed);
        if (!ref.mounted || run != _run) return const [];
        if (ready != ScanPrepareResult.ready) return _fail(ScanBanner.moduleOffline, 'scan_module_${ready.name}');
      case ScannerAvailability.noPlayServices:
        return _fail(ScanBanner.noPlayServices, 'scan_no_play_services');
      case ScannerAvailability.unsupported:
        return _fail(ScanBanner.unsupported, 'scan_unsupported');
      case ScannerAvailability.cameraDenied:
        return _fail(ScanBanner.cameraDenied, 'scan_camera_denied');
    }

    if (!ref.mounted) return const [];
    state = const ScanFlowState(phase: ScanPhase.scanning);
    // The native side creates the folder when it copies the pages.
    final inDir = ref.read(appPathsProvider).jobIn(draftId);
    final outcome = await scanner.scan(maxPages: math.min(room, limit ?? room), destDir: inDir.path);
    if (!ref.mounted) return const [];

    switch (outcome) {
      case ScanCancelled():
        state = const ScanFlowState();
        return const [];
      case ScanFailed(:final code):
        return _fail(_bannerFor(code), code.name);
      case ScanCompleted(:final pagePaths, :final truncated):
        state = const ScanFlowState(phase: ScanPhase.adding);
        final pages = await _inspect(pagePaths);
        if (!ref.mounted) return pages;
        state = ScanFlowState(notice: truncated ? ScanNotice.truncated : null);
        return pages;
    }
  }

  /// Pages from a scan that finished after Android killed the app, if they
  /// belong to this draft (FR-SCN-20).
  Future<List<PickedFile>?> takeRestored(String draftId) async {
    final r = await ref.read(documentScannerProvider).takeRestored();
    if (r == null || !ref.mounted) return null;
    if (!p.equals(r.destDir, ref.read(appPathsProvider).jobIn(draftId).path)) return null;
    final outcome = r.outcome;
    if (outcome is! ScanCompleted || outcome.pagePaths.isEmpty) return null;
    return _inspect(outcome.pagePaths);
  }

  void dismissBanner() => state = ScanFlowState(phase: state.phase, notice: state.notice);
  void dismissNotice() => state = ScanFlowState(phase: state.phase, banner: state.banner);

  Future<List<PickedFile>> _inspect(List<String> paths) => ref.read(fileGatewayProvider).reinspect([
        for (final path in paths)
          PickedFile(path: path, displayName: p.basename(path), type: SniffedType.jpeg, sizeBytes: 0),
      ]);

  List<PickedFile> _fail(ScanBanner banner, String code) {
    Log.event('scan_failed', code);
    if (ref.mounted) state = ScanFlowState(banner: banner);
    return const [];
  }

  static ScanBanner _bannerFor(ScanErrorCode code) => switch (code) {
        ScanErrorCode.offline || ScanErrorCode.moduleUnavailable => ScanBanner.moduleOffline,
        ScanErrorCode.noPlayServices => ScanBanner.noPlayServices,
        ScanErrorCode.unsupported => ScanBanner.unsupported,
        ScanErrorCode.cameraDenied => ScanBanner.cameraDenied,
        ScanErrorCode.storage => ScanBanner.storage,
        ScanErrorCode.unknown => ScanBanner.unknown,
      };
}

/// Lives while S27/S29 are on screen; a stale banner never outlives them.
final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanFlowState>(ScanController.new);
