import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../job/job_screen.dart' show retentionPeriod;
import '../settings/settings_screen.dart' show packageInfoProvider;

/// S17 · Privacy & About.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final retention = ref.watch(settingsProvider.select((s) => s.outputRetention));
    final info = ref.watch(packageInfoProvider).value;

    Widget point(IconData icon, String h, String p, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ToolIconTile(icon: icon, color: color),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text(h, style: context.text.titleMedium)),
                const SizedBox(height: Space.x1),
                Text(p, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ]),
            ),
          ]),
        );

    Widget access(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 136, child: Text(label, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value, style: context.text.bodyMedium)),
          ]),
        );

    final success = context.docu.success;
    return Scaffold(
      appBar: AppBar(title: Text(l.privTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.x8),
        child: ContentWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: Space.x2),
            Container(
              padding: const EdgeInsets.all(Space.x5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xl),
                gradient: LinearGradient(colors: [context.docu.heroStart, context.docu.heroEnd]),
              ),
              child: Row(children: [
                const Icon(Icons.shield_rounded, color: Colors.white, size: 40),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Text(l.privacyPromise, style: context.text.titleLarge?.copyWith(color: Colors.white)),
                ),
              ]),
            ),
            const SizedBox(height: Space.x2),
            point(Icons.phone_android_rounded, l.privLocalH, l.privLocalP, success),
            point(Icons.no_accounts_outlined, l.privAccountH, l.privAccountP, success),
            point(Icons.campaign_outlined, l.privAdsH, l.privAdsP, context.colors.primary),
            SectionHeader(l.privAccessH),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: Column(children: [
                  access(l.privAccessPhotosLabel, l.privAccessPhotos),
                  access(l.privAccessFilesLabel, l.privAccessFiles),
                  access(l.privAccessPhotosAddLabel, l.privAccessPhotosAdd),
                ]),
              ),
            ),
            point(Icons.inventory_2_outlined, l.privStoredH, l.privStoredP(retentionPeriod(l, retention)), context.colors.primary),
            point(Icons.lock_outline_rounded, l.privProtectedH, l.privProtectedP, context.colors.primary),
            const SizedBox(height: Space.x2),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.policy_outlined),
                  title: Text(l.privPolicy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/policy'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: Text(l.privLicenses),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/licenses'),
                ),
              ]),
            ),
            if (info != null) ...[
              const SizedBox(height: Space.x4),
              Text(l.setVersion(info.version, info.buildNumber),
                  textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Offline copy of the privacy policy (RELEASE §6), from ARB.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paras = [l.privPolicyBody1, l.privPolicyBody2, l.privPolicyBody3, l.privPolicyBody4, l.privPolicyBody5];
    return Scaffold(
      appBar: AppBar(title: Text(l.privPolicy)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.x8),
        child: ContentWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in paras)
              Padding(padding: const EdgeInsets.only(top: Space.x4), child: Text(p, style: context.text.bodyLarge)),
          ]),
        ),
      ),
    );
  }
}
