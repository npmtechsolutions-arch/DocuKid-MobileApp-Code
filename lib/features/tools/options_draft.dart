import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../search/tool_catalog.dart';

/// Tool options survive process death with the inputs draft (FR-LIFE-03).
String optionsDraftKey(ToolId tool) => '${tool.name}_opts';

Map<String, dynamic>? readOptionsDraft(Ref ref, ToolId tool) {
  final raw = ref.read(settingsRepositoryProvider).readDraft(optionsDraftKey(tool));
  if (raw == null) return null;
  try {
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
}

void writeOptionsDraft(Ref ref, ToolId tool, Map<String, Object?> json) {
  unawaited(ref.read(settingsRepositoryProvider).writeDraft(optionsDraftKey(tool), jsonEncode(json)));
}

/// Pending "Run again" / quick-action options, consumed once by the tool's
/// options controller on build. A plain holder, not a Notifier: nothing
/// watches it, and `ToolEntry` fills it while the route is being built.
class RunAgainOptions {
  final _pending = <ToolId, Map<String, dynamic>>{};

  void set(ToolId tool, Map<String, dynamic> options) => _pending[tool] = options;

  Map<String, dynamic>? take(ToolId tool) => _pending.remove(tool);
}

final runAgainProvider = Provider<RunAgainOptions>((ref) => RunAgainOptions());

/// Run-again options win over a draft, which wins over Settings defaults.
Map<String, dynamic>? initialOptions(Ref ref, ToolId tool) =>
    ref.read(runAgainProvider).take(tool) ?? readOptionsDraft(ref, tool);
