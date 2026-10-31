/// A trip into the system's own UI that DocuKit starts and comes back from:
/// pickers, save dialogs, share, Open with, the scanner, permission and
/// unlock prompts, Settings, purchase and consent (RELEASE_V1_5 §4.8).
/// Leaving the app for one of these doesn't count as leaving for the app
/// lock: "Immediately" would otherwise lock after every file pick.
class SystemFlow {
  SystemFlow._();

  static int _active = 0;
  static DateTime? _endedAt;

  /// After a flow ends, the app's own resume may be reported a moment later.
  static const grace = Duration(seconds: 2);

  static bool get active => _active > 0;

  /// True while a flow runs or within [grace] after it ended (real time).
  static bool get busy => active || (_endedAt != null && DateTime.now().difference(_endedAt!) < grace);

  static Future<T> run<T>(Future<T> Function() flow) async {
    _active++;
    try {
      return await flow();
    } finally {
      _active--;
      _endedAt = DateTime.now();
    }
  }

  /// Tests only.
  static void reset() {
    _active = 0;
    _endedAt = null;
  }
}
