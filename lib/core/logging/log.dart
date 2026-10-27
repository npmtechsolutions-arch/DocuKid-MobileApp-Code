import 'package:flutter/foundation.dart';

/// The only logger in the app (CLAUDE.md rule 4, ARCHITECTURE §9).
///
/// Format: `[job <id8>] <event> <code>`. Never pass file names, paths or
/// contents. Release builds log nothing.
abstract final class Log {
  static void job(String jobId, String event, [String? code]) {
    if (!kDebugMode) return;
    final id = jobId.length > 8 ? jobId.substring(jobId.length - 8) : jobId;
    debugPrint('[job $id] $event${code == null ? '' : ' $code'}');
  }

  static void event(String event, [String? code]) {
    if (!kDebugMode) return;
    debugPrint('[app] $event${code == null ? '' : ' $code'}');
  }
}
