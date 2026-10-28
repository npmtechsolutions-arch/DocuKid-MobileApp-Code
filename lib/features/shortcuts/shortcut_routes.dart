import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Routes a launcher shortcut may open (FR-SCN-22). Anything else is ignored.
const shortcutRoutes = {'/tool/scan?autostart=1'};

/// The Android launcher shortcut's route, waiting to be opened (ADR-065).
/// Cold start: taken once from the plugin; warm start: the plugin's stream.
class ShortcutRouteController extends Notifier<String?> {
  StreamSubscription<String>? _sub;

  @override
  String? build() {
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  Future<void> start() async {
    final native = ref.read(nativeProvider);
    _sub ??= native.shortcutRoutes.listen(receive, onError: (_) {});
    final cold = await native.takePendingRoute();
    if (cold != null && ref.mounted) receive(cold);
  }

  void receive(String route) {
    if (shortcutRoutes.contains(route)) state = route;
  }

  /// The route was opened (or dropped): forget it.
  String? take() {
    final r = state;
    state = null;
    return r;
  }
}

final shortcutRouteProvider = NotifierProvider<ShortcutRouteController, String?>(ShortcutRouteController.new);
