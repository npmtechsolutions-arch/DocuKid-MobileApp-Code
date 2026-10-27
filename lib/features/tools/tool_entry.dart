import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/tool_scaffold.dart';
import '../home/quick_actions.dart';
import '../search/tool_catalog.dart';
import 'options_draft.dart';

/// Applies `/tool/<slug>?…` prefill (quick actions, UI_REFRESH §2.1) before
/// the tool screen builds, using the same path as History's "Run again".
class ToolEntry extends ConsumerStatefulWidget {
  const ToolEntry({super.key, required this.tool, required this.query, required this.child});
  final ToolId tool;
  final Map<String, String> query;
  final Widget child;

  @override
  ConsumerState<ToolEntry> createState() => _ToolEntryState();
}

class _ToolEntryState extends ConsumerState<ToolEntry> {
  @override
  void initState() {
    super.initState();
    final prefill = prefillFromQuery(widget.tool, widget.query);
    // Runs before the child builds, so the options controller sees it.
    if (prefill != null) ref.read(runAgainProvider).set(widget.tool, prefill);
  }

  @override
  Widget build(BuildContext context) => CurrentTool(id: widget.tool, child: widget.child);
}
