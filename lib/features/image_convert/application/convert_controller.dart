import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import 'convert_operation.dart';

class ConvertController extends Notifier<ConvertOptions> {
  @override
  ConvertOptions build() {
    final s = ref.read(settingsProvider);
    final engine = ref.read(imageEngineProvider);
    final defaults = ConvertOptions(
      // A remembered HEIC on a device that can't encode it falls back to JPG.
      format: engine.canEncode(s.convertFormat) ? s.convertFormat : const ConvertOptions().format,
      quality: s.convertQuality,
      stripMetadata: s.imgStripMetadata,
    );
    final init = initialOptions(ref, ToolId.imageConvert);
    final o = init == null ? defaults : ConvertOptions.fromJson(init, defaults);
    return engine.canEncode(o.format) ? o : o.copyWith(format: defaults.format);
  }

  void set(ConvertOptions o) {
    state = o;
    writeOptionsDraft(ref, ToolId.imageConvert, o.toJson());
    // convert_format / convert_quality remember the last choice (§5.2).
    unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(convertFormat: o.format, convertQuality: o.quality)));
  }
}

final convertOptionsProvider = NotifierProvider.autoDispose<ConvertController, ConvertOptions>(ConvertController.new);

final convertOperationProvider = Provider<ConvertImageOperation>((ref) => ConvertImageOperation(ref.watch(imageEngineProvider)));

final batchConvertOperationProvider =
    Provider<BatchConvertOperation>((ref) => BatchConvertOperation(ref.watch(imageEngineProvider)));
