import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/tool_scaffold.dart';
import '../search/tool_catalog.dart';

/// Stand-in for a 1.1 tool whose screen isn't built yet (T8.1). Uses the
/// shared frame, so the route, category strip and Tools banner already behave
/// like the real screen. Replaced by T8.8 (Split) and T8.9 (PDF to Images);
/// delete this file with the last of them.
class PlaceholderToolScreen extends StatelessWidget {
  const PlaceholderToolScreen({super.key, required this.tool});
  final ToolId tool;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = toolById(tool);
    return ToolScaffold(
      title: t.title(l),
      primary: [Text(t.subtitle(l), style: context.text.bodyLarge)],
      action: PrimaryActionBar(label: t.title(l), onPressed: null),
    );
  }
}
