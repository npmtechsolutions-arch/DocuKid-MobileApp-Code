import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/files/png_size.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../secure/unlock_first.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/sign_session.dart';
import '../application/signature_models.dart';
import '../application/signature_providers.dart';

/// S33 · Sign PDF (RELEASE_V1_4 §3; FR-SIG-01, 10, 11): the file, the
/// signature to place (saved tiles + Draw / Type / Photo), the honest
/// "not a certified signature" note, then S35.
class SignScreen extends ConsumerWidget {
  const SignScreen({super.key});
  static const tool = ToolId.pdfSign;

  Future<void> _create(BuildContext context, WidgetRef ref, SignatureKind mode) async {
    final r = await context.push<CreatedSignature>('${toolById(tool).route}/create?mode=${mode.name}');
    if (r != null) ref.read(signSessionProvider.notifier).created(r);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final session = ref.watch(signSessionProvider);
    final saved = ref.watch(savedSignaturesProvider);
    final repo = ref.watch(signatureRepositoryProvider);
    final file = inputs.single;
    final locked = file != null && isLockedPdf(file);
    final valid = file?.status.isValid == true;
    final chosen = session.chosen;
    // The new signature, unless it's already one of the saved tiles.
    final created = session.created?.savedId == null ? session.created : null;

    Widget tile({required String path, required String label, required bool selected, VoidCallback? onLongPress, required VoidCallback onTap}) =>
        Semantics(
          selected: selected,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              width: 112,
              height: 64,
              padding: const EdgeInsets.all(Space.x1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: selected ? context.colors.primary : context.colors.outlineVariant, width: selected ? 3 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Checkerboard(child: Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true)),
              ),
            ),
          ),
        );

    return ToolScaffold(
      title: l.toolPdfSignTitle,
      info: l.sigNotCertified,
      hasWork: file != null,
      banner: const RestoredBanner(tool: tool),
      action: PrimaryActionBar(
        label: l.sigPlaceCta,
        icon: Icons.draw_rounded,
        helper: file == null ? l.pickPdf : null,
        onPressed: valid && chosen != null && !inputs.picking ? () => context.push('${toolById(tool).route}/place') : null,
      ),
      primary: [
        SectionHeader(l.inputsFileHeader),
        if (file == null)
          PickerDropCard(
            label: l.pickPdf,
            formats: l.pickFormatsPdf,
            icon: Icons.draw_rounded,
            accent: context.docu.secureAccent,
            loading: inputs.picking,
            onTap: () => pick.pick(),
          )
        else
          SingleFileCard(file: file, onChange: () => pick.pick(replace: true)),
        if (locked) UnlockFirstBanner(tool: tool, file: file),
      ],
      secondary: [
        SectionHeader(l.sigYourSignature),
        Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
          for (final (i, s) in saved.indexed)
            tile(
              path: repo.pathOf(s),
              label: l.sigSavedTile(i + 1),
              selected: chosen?.savedId == s.id,
              onTap: () {
                final size = pngSize(repo.pathOf(s));
                ref.read(signSessionProvider.notifier).choose(
                    SignatureChoice(pngPath: repo.pathOf(s), aspect: size == null ? 3 : size.$1 / size.$2, savedId: s.id));
              },
              onLongPress: () async {
                final ok = await askAdaptive(context, title: l.sigDeleteTitle, no: l.actionCancel, yes: l.sigDelete);
                if (!ok) return;
                await ref.read(savedSignaturesProvider.notifier).delete(s.id);
                ref.read(signSessionProvider.notifier).forgetSaved(s.id);
              },
            ),
          if (created != null)
            tile(
              path: created.pngPath,
              label: l.sigNewTile,
              selected: chosen?.pngPath == created.pngPath,
              onTap: () => ref.read(signSessionProvider.notifier).created(created),
            ),
        ]),
        const SizedBox(height: Space.x3),
        Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
          for (final (mode, label, icon) in [
            (SignatureKind.draw, l.sigDraw, Icons.gesture_rounded),
            (SignatureKind.type, l.sigType, Icons.keyboard_rounded),
            (SignatureKind.photo, l.sigPhoto, Icons.photo_camera_outlined),
          ])
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => _create(context, ref, mode),
              icon: Icon(icon),
              label: Text(label),
            ),
        ]),
        const SizedBox(height: Space.x4),
        // FR-SIG-11: always visible.
        InlineBanner(kind: BannerKind.info, text: l.sigNotCertified),
      ],
    );
  }
}
