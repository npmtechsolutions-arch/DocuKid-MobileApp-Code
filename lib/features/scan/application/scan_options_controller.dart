import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/scan/scan_options.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';

/// S29 options. They start from the last choices (`scan_default_format`,
/// `scan_page_size` — Letter by locale, FR-SCN-14 — `scan_quality`, and in
/// 1.3 `scan_make_searchable` with the shared `ocr_script`).
class ScanOptionsController extends Notifier<ScanOptions> {
  @override
  ScanOptions build() {
    final s = ref.read(settingsProvider);
    final defaults = ScanOptions(
      format: s.scanFormat,
      pageSize: s.scanPageSize,
      quality: s.scanQuality,
      makeSearchable: s.scanMakeSearchable,
      ocrScript: s.ocrScript,
    );
    final init = initialOptions(ref, ToolId.scanDocument);
    return init == null ? defaults : ScanOptions.fromJson(init, defaults);
  }

  void set(ScanOptions o) {
    state = o;
    writeOptionsDraft(ref, ToolId.scanDocument, o.toJson());
    unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(
          scanFormat: o.format,
          scanPageSize: o.pageSize,
          scanQuality: o.quality,
          scanMakeSearchable: o.makeSearchable,
          // The language is shared with Text Recognition (`ocr_script`).
          ocrScript: o.ocrScript,
        )));
  }
}

final scanOptionsProvider = NotifierProvider.autoDispose<ScanOptionsController, ScanOptions>(ScanOptionsController.new);
