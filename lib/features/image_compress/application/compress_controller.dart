import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import 'compress_operation.dart';

class CompressController extends Notifier<CompressOptions> {
  @override
  CompressOptions build() {
    final s = ref.read(settingsProvider);
    final defaults = CompressOptions(quality: s.imgQuality, format: s.imgFormat, stripMetadata: s.imgStripMetadata);
    final init = initialOptions(ref, ToolId.imageCompress);
    return init == null ? defaults : CompressOptions.fromJson(init, defaults);
  }

  void set(CompressOptions o) {
    state = o;
    writeOptionsDraft(ref, ToolId.imageCompress, o.toJson());
  }
}

final compressOptionsProvider =
    NotifierProvider.autoDispose<CompressController, CompressOptions>(CompressController.new);

final compressOperationProvider = Provider<CompressImageOperation>(
  (ref) => CompressImageOperation(ref.watch(imageEngineProvider), clock: ref.watch(clockProvider)),
);

final batchCompressOperationProvider = Provider<BatchCompressOperation>(
  (ref) => BatchCompressOperation(ref.watch(imageEngineProvider), clock: ref.watch(clockProvider)),
);
