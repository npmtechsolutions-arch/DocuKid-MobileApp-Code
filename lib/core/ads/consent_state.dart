import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the first-run consent flow (ADS.md §5) has finished. The Home tour
/// waits for it, so the consent form never stacks on the tour. Settled by
/// default; the ads consent gate calls [beginFlow] before it shows anything.
class ConsentState extends Notifier<bool> {
  Completer<void> _done = Completer<void>()..complete();

  @override
  bool build() => true;

  Future<void> get settled => _done.future;

  void beginFlow() {
    if (_done.isCompleted) _done = Completer<void>();
    state = false;
  }

  void markSettled() {
    if (!_done.isCompleted) _done.complete();
    state = true;
  }
}

final consentStateProvider = NotifierProvider<ConsentState, bool>(ConsentState.new);
