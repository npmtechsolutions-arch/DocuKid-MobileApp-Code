import 'package:flutter/widgets.dart';

import '../search/tool_catalog.dart';

/// One tour step. [target] null = a centred card (intro / done).
class TourStep {
  const TourStep({this.target, required this.title, required this.body, this.example, this.tryTool});
  final GlobalKey? target;
  final String title, body;
  final String? example;

  /// Tool steps offer "Try it" (FR-TOUR-09).
  final ToolId? tryTool;
}
