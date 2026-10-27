import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../search/tool_catalog.dart';

/// Home shortcuts that open a tool with preset options (UI_REFRESH §2.1,
/// FR-HOME-06). Each is a plain deep link: `/tool/<slug>?<query>`.
class QuickAction {
  const QuickAction({required this.tool, required this.icon, required this.label, this.query = const {}});
  final ToolId tool;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final Map<String, String> query;

  String get location {
    final route = toolById(tool).route;
    return query.isEmpty ? route : Uri(path: route, queryParameters: query).toString();
  }
}

final quickActions = <QuickAction>[
  QuickAction(
    tool: ToolId.imageResize,
    icon: Icons.badge_outlined,
    label: (l) => l.qaPassport,
    query: const {'preset': 'passport'},
  ),
  QuickAction(
    tool: ToolId.imageCompress,
    icon: Icons.trending_down_rounded,
    label: (l) => l.qaUnder100kb,
    query: const {'target': '102400'},
  ),
  QuickAction(
    tool: ToolId.imageResize,
    icon: Icons.draw_outlined,
    label: (l) => l.qaSignature,
    query: const {'preset': 'signature'},
  ),
  QuickAction(tool: ToolId.imageToPdf, icon: Icons.picture_as_pdf_outlined, label: (l) => l.qaPhotosToPdf),
  QuickAction(tool: ToolId.pdfMerge, icon: Icons.call_merge_rounded, label: (l) => l.qaMergePdfs),
  QuickAction(
    tool: ToolId.pdfCompress,
    icon: Icons.mail_outline_rounded,
    label: (l) => l.qaEmailPdf,
    query: const {'level': 'balanced'},
  ),
];

/// Turns a tool route's query parameters into that tool's options JSON (the
/// same shape as "Run again" / draft options). Unknown values are ignored.
Map<String, dynamic>? prefillFromQuery(ToolId tool, Map<String, String> q) {
  switch (tool) {
    case ToolId.imageResize:
      final (w, h) = switch (q['preset']) {
        'passport' => (413, 531),
        'signature' => (140, 60),
        _ => (0, 0),
      };
      if (w == 0) return null;
      return {'mode': 'preset', 'preset': q['preset'], 'pw': w, 'ph': h, 'fit': 'contain', 'pad': 'white'};
    case ToolId.imageCompress:
      final t = int.tryParse(q['target'] ?? '');
      if (t == null || t <= 0) return null;
      return {'mode': 'targetSize', 'targetBytes': t};
    case ToolId.pdfCompress:
      final level = q['level'];
      return const {'basic', 'balanced'}.contains(level) ? {'level': level} : null;
    default:
      return null;
  }
}
