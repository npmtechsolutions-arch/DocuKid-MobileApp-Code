import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pdf/pdf_options.dart';
import '../../../core/providers.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import 'split_operation.dart';

class SplitController extends Notifier<SplitOptions> {
  @override
  SplitOptions build() {
    final s = ref.read(settingsProvider);
    final defaults = SplitOptions(mode: enumByName(SplitMode.values, s.splitMode, SplitMode.ranges), everyN: s.splitEveryN);
    final init = initialOptions(ref, ToolId.pdfSplit);
    return init == null ? defaults : SplitOptions.fromJson(init, defaults);
  }

  void set(SplitOptions o) {
    final remember = o.mode != state.mode || o.everyN != state.everyN;
    state = o;
    writeOptionsDraft(ref, ToolId.pdfSplit, o.toJson());
    // split_mode / split_every_n remember the last choice (§5.2).
    if (remember) {
      unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(splitMode: o.mode.name, splitEveryN: o.everyN)));
    }
  }
}

final splitOptionsProvider = NotifierProvider.autoDispose<SplitController, SplitOptions>(SplitController.new);

/// [endWords]: "end" plus the localised alias (§4.6).
final splitOperationProvider = Provider.family<SplitPdfOperation, String>(
  (ref, endWord) => SplitPdfOperation(ref.watch(pdfEngineProvider), endWords: {'end', endWord}),
);
