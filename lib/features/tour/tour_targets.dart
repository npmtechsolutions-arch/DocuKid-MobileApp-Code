import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/tool_catalog.dart';

/// GlobalKeys Home attaches to the tour's targets (TOUR.md §2, §4).
class TourTargets {
  final search = GlobalKey(debugLabel: 'tourSearch');
  final recent = GlobalKey(debugLabel: 'tourRecent');
  final appBarActions = GlobalKey(debugLabel: 'tourAppBarActions');
  final favourites = GlobalKey(debugLabel: 'tourFavourites');

  /// The "Secure & Sign" section header (1.4, FR-SEC-02).
  final secureSection = GlobalKey(debugLabel: 'tourSecureSection');
  final Map<ToolId, GlobalKey> _tools = {for (final t in ToolId.values) t: GlobalKey(debugLabel: 'tourTool.${t.name}')};

  GlobalKey toolKey(ToolId id) => _tools[id]!;
}

final tourTargetsProvider = Provider<TourTargets>((ref) => TourTargets());
