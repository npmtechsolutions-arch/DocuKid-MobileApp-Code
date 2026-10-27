/// Build-time configuration. Set with `--dart-define`, e.g.
/// `flutter build appbundle --dart-define=DOCUKIT_FEEDBACK_EMAIL=support@yourdomain.com`.
/// The "Send feedback" row is hidden when this is empty, so no placeholder
/// address can ship by accident.
const feedbackEmail = String.fromEnvironment('DOCUKIT_FEEDBACK_EMAIL');
