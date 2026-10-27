import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/illustrations.dart';

/// S20 · First-run welcome. No permissions are requested here.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    Widget bullet(IconData icon, String text, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: Space.x4),
            Expanded(child: Text(text, style: context.text.titleMedium?.copyWith(color: Colors.white))),
          ]),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightOverlay,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: context.docu.brandGradient,
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    padding: const EdgeInsets.all(Space.x6),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - Space.x12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: Space.x8),
                            ExcludeSemantics(
                              child: Container(
                                padding: const EdgeInsets.all(Space.x3),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(Radii.hero),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8))],
                                ),
                                child: const Illustration(kind: IllustrationKind.onboarding, size: 112),
                              ),
                            ),
                            const SizedBox(height: Space.x8),
                            Text(l.appName, style: context.text.titleMedium?.copyWith(color: Colors.white)),
                            const SizedBox(height: Space.x2),
                            Semantics(
                              header: true,
                              child: Text(
                                l.onbTitle,
                                style: context.text.headlineSmall?.copyWith(color: Colors.white, fontSize: 30, height: 1.2),
                              ),
                            ),
                            const SizedBox(height: Space.x8),
                            bullet(Icons.photo_size_select_large_rounded, l.onbB1, const Color(0xFF9FF0E4)),
                            bullet(Icons.picture_as_pdf_rounded, l.onbB2, const Color(0xFFFFC7AE)),
                            bullet(Icons.lock_rounded, l.onbB3, Colors.white),
                          ]),
                          const SizedBox(height: Space.x8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: context.docu.heroEnd,
                              minimumSize: const Size.fromHeight(56),
                            ),
                            onPressed: () async {
                              await ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingDone: true));
                              if (context.mounted) context.go('/');
                            },
                            child: Text(l.onbCta),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
