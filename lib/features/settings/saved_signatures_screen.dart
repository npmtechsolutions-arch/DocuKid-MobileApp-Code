import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ads/ads_config.dart';
import '../../core/ads/bottom_banner.dart';
import '../../core/formatting/date_format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../pdf_sign/application/signature_models.dart';
import '../pdf_sign/application/signature_providers.dart';

/// Settings → Saved signatures (RELEASE_V1_4 FR-SIG-10, §5.2): each can be
/// deleted, or all at once; deleting removes the file immediately.
class SavedSignaturesScreen extends ConsumerWidget {
  const SavedSignaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final saved = ref.watch(savedSignaturesProvider);
    final repo = ref.watch(signatureRepositoryProvider);
    final ctrl = ref.read(savedSignaturesProvider.notifier);
    String kindLabel(SignatureKind k) => switch (k) {
          SignatureKind.draw => l.sigDraw,
          SignatureKind.type => l.sigType,
          SignatureKind.photo => l.sigPhoto,
        };

    // ADR-072: a Settings sub-page, so the Settings banner (like S46).
    return AppBottomBanner(unit: AdUnit.bannerSettings, child: Scaffold(
      appBar: AppBar(title: Text(l.setSavedSignatures)),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(padding: const EdgeInsets.symmetric(vertical: Space.x3), children: [
            if (saved.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: Text(l.setSavedNone, style: context.text.bodyLarge),
              ),
            for (final s in saved)
              ListTile(
                key: ValueKey('saved-${s.id}'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: SizedBox(
                    width: 72,
                    height: 40,
                    child: Checkerboard(child: Image.file(File(repo.pathOf(s)), fit: BoxFit.contain)),
                  ),
                ),
                title: Text(kindLabel(s.kind)),
                subtitle: Text(formatDate(s.createdAt)),
                trailing: IconButton(
                  tooltip: l.sigDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    final ok = await askAdaptive(context, title: l.sigDeleteTitle, no: l.actionCancel, yes: l.sigDelete);
                    if (ok) await ctrl.delete(s.id);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(l.setDeleteAllSignatures),
                onPressed: saved.isEmpty
                    ? null
                    : () async {
                        final ok = await askAdaptive(context,
                            title: l.setDeleteAllSignaturesTitle, no: l.actionCancel, yes: l.sigDelete);
                        if (ok) await ctrl.deleteAll();
                      },
              ),
            ),
          ]),
        ),
      ),
    ));
  }
}
