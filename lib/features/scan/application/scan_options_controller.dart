import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pdf/pdf_options.dart';
import '../../../core/providers.dart';
import '../../../core/scan/scan_options.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';

/// S29 options. Page size starts like Images to PDF's (Letter in
/// US/CA/MX/PH, FR-SCN-14); the scan settings defaults arrive in T9.7.
class ScanOptionsController extends Notifier<ScanOptions> {
  @override
  ScanOptions build() {
    final size = ref.read(settingsProvider).pdfPageSize;
    final defaults = ScanOptions(pageSize: size == PdfPageSize.letter ? ScanPageSize.letter : ScanPageSize.a4);
    final init = initialOptions(ref, ToolId.scanDocument);
    return init == null ? defaults : ScanOptions.fromJson(init, defaults);
  }

  void set(ScanOptions o) {
    state = o;
    writeOptionsDraft(ref, ToolId.scanDocument, o.toJson());
  }
}

final scanOptionsProvider = NotifierProvider.autoDispose<ScanOptionsController, ScanOptions>(ScanOptionsController.new);
