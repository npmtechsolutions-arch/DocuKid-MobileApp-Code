import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/ads/bottom_banner.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/illustrations.dart';

/// S39 · first visit to My Documents (RELEASE_V1_5 §3, FR-LIB-02): where the
/// files live, that backups don't include them, and that uninstalling deletes
/// them. "Get started" sets `lib_intro_seen`.
class LibraryIntroScreen extends StatelessWidget {
  const LibraryIntroScreen({super.key, required this.onStart});
  final VoidCallback onStart;

  void _backupNote(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        // The full backup section is S46 (T12.8); this is its note.
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.x5, 0, Space.x5, Space.x5),
            child: Text(ctx.l10n.setLibBackupNote, style: ctx.text.bodyLarge),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget bullet(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: context.colors.primary),
            const SizedBox(width: Space.x3),
            Expanded(child: Text(text, style: context.text.bodyLarge)),
          ]),
        );
    return AppBottomBanner(
      unit: AdUnit.bannerMain,
      child: Scaffold(
        appBar: AppBar(title: Text(l.libTitle)),
        body: SafeArea(
          child: ContentWidth(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: Space.x6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: Illustration(kind: IllustrationKind.onboarding, size: 140)),
                const SizedBox(height: Space.x5),
                Semantics(header: true, child: Text(l.libIntroTitle, style: context.text.headlineSmall, textAlign: TextAlign.center)),
                const SizedBox(height: Space.x4),
                bullet(Icons.phone_android_rounded, l.libIntroB1),
                bullet(Icons.cloud_off_rounded, l.libIntroB2),
                bullet(Icons.delete_forever_outlined, l.libIntroB3),
                const SizedBox(height: Space.x6),
                FilledButton(
                  key: const ValueKey('lib-intro-start'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: onStart,
                  child: Text(l.libIntroCta),
                ),
                const SizedBox(height: Space.x2),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _backupNote(context),
                  child: Text('${l.libIntroBackupLink} ›'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
