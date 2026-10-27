import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../logging/log.dart';
import 'ads_controller.dart';

/// Non-consumable product on both stores (ADS.md §6).
const removeAdsProductId = 'remove_ads';

enum PurchaseOutcome { purchased, restored, failed, cancelled, pending }

/// Store access behind an interface (fakes in tests). in_app_purchase is
/// imported only here (CI check).
abstract interface class PurchaseService {
  /// Purchases and restores for [removeAdsProductId], as they arrive.
  Stream<PurchaseOutcome> get updates;

  /// Localised price, or null when the store or product is unavailable.
  Future<String?> price();
  Future<bool> buy();
  Future<void> restore();
}

class StorePurchaseService implements PurchaseService {
  StorePurchaseService() {
    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (_) {});
  }

  final _iap = InAppPurchase.instance;
  final _updates = StreamController<PurchaseOutcome>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  ProductDetails? _product;

  @override
  Stream<PurchaseOutcome> get updates => _updates.stream;

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != removeAdsProductId) continue;
      _updates.add(switch (p.status) {
        PurchaseStatus.purchased => PurchaseOutcome.purchased,
        PurchaseStatus.restored => PurchaseOutcome.restored,
        PurchaseStatus.pending => PurchaseOutcome.pending,
        PurchaseStatus.canceled => PurchaseOutcome.cancelled,
        PurchaseStatus.error => PurchaseOutcome.failed,
      });
      if (p.status == PurchaseStatus.error) Log.event('purchase_failed', p.error?.code);
      // Acknowledge, or Google Play refunds the purchase after 3 days.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  Future<ProductDetails?> _load() async {
    if (_product != null) return _product;
    try {
      if (!await _iap.isAvailable()) return null;
      final r = await _iap.queryProductDetails({removeAdsProductId});
      _product = r.productDetails.where((p) => p.id == removeAdsProductId).firstOrNull;
    } catch (_) {
      return null;
    }
    return _product;
  }

  @override
  Future<String?> price() async => (await _load())?.price;

  @override
  Future<bool> buy() async {
    final p = await _load();
    if (p == null) return false;
    try {
      return await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  void dispose() {
    unawaited(_sub.cancel());
    unawaited(_updates.close());
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final s = StorePurchaseService();
  ref.onDispose(s.dispose);
  return s;
});

/// Remove-ads purchase state for the sheet. Listens from app start, so a
/// restore or a purchase that completes later (pending) still removes ads.
class RemoveAdsState {
  const RemoveAdsState({this.price, this.loading = true, this.busy = false, this.last});
  final String? price;
  final bool loading, busy;
  final PurchaseOutcome? last;
}

class RemoveAdsController extends Notifier<RemoveAdsState> {
  @override
  RemoveAdsState build() {
    final sub = ref.watch(purchaseServiceProvider).updates.listen((o) async {
      if (o == PurchaseOutcome.purchased || o == PurchaseOutcome.restored) {
        await ref.read(adsControllerProvider.notifier).setAdsRemoved();
      }
      state = RemoveAdsState(price: state.price, loading: false, busy: o == PurchaseOutcome.pending, last: o);
    });
    ref.onDispose(sub.cancel);
    return const RemoveAdsState();
  }

  Future<void> loadPrice() async {
    final p = await ref.read(purchaseServiceProvider).price();
    state = RemoveAdsState(price: p, loading: false, busy: state.busy, last: state.last);
  }

  Future<void> buy() async {
    state = RemoveAdsState(price: state.price, loading: false, busy: true);
    final started = await ref.read(purchaseServiceProvider).buy();
    if (!started) state = RemoveAdsState(price: state.price, loading: false, last: PurchaseOutcome.failed);
  }

  Future<void> restore() async {
    state = RemoveAdsState(price: state.price, loading: false, busy: true);
    await ref.read(purchaseServiceProvider).restore();
    // Restores arrive on the stream; if nothing comes back, stop the spinner.
    await Future<void>.delayed(const Duration(seconds: 5));
    if (state.busy) state = RemoveAdsState(price: state.price, loading: false);
  }
}

final removeAdsProvider = NotifierProvider<RemoveAdsController, RemoveAdsState>(RemoveAdsController.new);

/// No store (tests, or a platform without billing): the sheet shows "unavailable".
class NoPurchaseService implements PurchaseService {
  const NoPurchaseService();
  @override
  Stream<PurchaseOutcome> get updates => const Stream.empty();
  @override
  Future<String?> price() async => null;
  @override
  Future<bool> buy() async => false;
  @override
  Future<void> restore() async {}
}
