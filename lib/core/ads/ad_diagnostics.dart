import 'package:flutter/foundation.dart';

import 'ads_config.dart';

enum AdOutcome { loaded, noFill, error }

/// The last load result of one ad unit. Holds only the SDK's result code and
/// message: no user, file or app data (shown on the hidden diagnostics screen).
@immutable
class AdLoadResult {
  const AdLoadResult._(this.outcome, this.at, {this.code, this.message});

  factory AdLoadResult.loaded() => AdLoadResult._(AdOutcome.loaded, DateTime.now());

  /// From a LoadAdError. "No fill" is code 3 on Android (AdRequest.ERROR_CODE_NO_FILL)
  /// and 1 on iOS (GADErrorNoFill).
  factory AdLoadResult.fromError(int code, String message, {required bool android}) => AdLoadResult._(
        code == (android ? 3 : 1) ? AdOutcome.noFill : AdOutcome.error,
        DateTime.now(),
        code: code,
        message: message,
      );

  /// A failure without an SDK code (e.g. the load timed out).
  factory AdLoadResult.error({required String message}) => AdLoadResult._(AdOutcome.error, DateTime.now(), message: message);

  final AdOutcome outcome;
  final DateTime at;
  final int? code;
  final String? message;
}

/// In-memory record of each unit's last load result (not persisted).
class AdDiagnostics {
  AdDiagnostics._();
  static final instance = AdDiagnostics._();

  final results = ValueNotifier<Map<AdUnit, AdLoadResult>>(const {});

  void record(AdUnit unit, AdLoadResult r) => results.value = {...results.value, unit: r};

  @visibleForTesting
  void clear() => results.value = const {};
}
