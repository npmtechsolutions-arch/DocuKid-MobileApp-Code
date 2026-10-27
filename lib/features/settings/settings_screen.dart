import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/bootstrap/sweeps.dart';
import '../../app/config.dart';
import '../../app/theme/tokens.dart';
import '../../core/ads/ad_slots.dart';
import '../../core/ads/ads_controller.dart';
import '../../core/formatting/bytes_format.dart';
import '../../core/image/image_options.dart';
import '../../core/pdf/pdf_options.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/options.dart';
import '../../data/settings/app_settings.dart';
import '../tour/tour_controller.dart';
import 'remove_ads_sheet.dart';

final storageUsedProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(outputsRepositoryProvider).totalBytes());
final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

Future<T?> pickOne<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String)> options,
}) {
  return showAppSheet<T>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x2),
          child: Text(title, style: ctx.text.titleLarge),
        ),
        for (final (v, label) in options)
          ListTile(
            leading: Icon(
              v == current ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: v == current ? ctx.colors.primary : null,
            ),
            title: Text(label),
            onTap: () => Navigator.pop(ctx, v),
          ),
        const SizedBox(height: Space.x4),
      ],
    ),
  );
}

/// S16 · Settings. Every change saves immediately.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final storage = ref.watch(storageUsedProvider);
    final info = ref.watch(packageInfoProvider);
    final ads = ref.watch(adsControllerProvider);

    final themes = [(ThemeMode.system, l.setSystem), (ThemeMode.light, l.setLight), (ThemeMode.dark, l.setDark)];
    final formats = [
      (OutputFormatChoice.same, l.cmpFormatSame),
      (OutputFormatChoice.jpeg, l.fmtJpeg),
      (OutputFormatChoice.png, l.fmtPng),
      (OutputFormatChoice.webp, l.fmtWebp),
    ];
    final sizes = [
      (PdfPageSize.a4, l.i2pSizeA4),
      (PdfPageSize.letter, l.i2pSizeLetter),
      (PdfPageSize.legal, l.i2pSizeLegal),
      (PdfPageSize.image, l.i2pSizeImage),
    ];
    final fits = [(PdfFit.fit, l.i2pFitFit), (PdfFit.fill, l.i2pFitFill)];
    final margins = [
      (PdfMargin.none, l.i2pMarginNone),
      (PdfMargin.small, l.i2pMarginSmall),
      (PdfMargin.large, l.i2pMarginLarge),
    ];
    final qualities = [
      (PdfImageQuality.original, l.i2pQOriginal),
      (PdfImageQuality.high, l.i2pQHigh),
      (PdfImageQuality.compact, l.i2pQCompact),
    ];
    final levels = [(ReduceLevel.basic, l.redBasicT), (ReduceLevel.balanced, l.redBalancedT)];
    final retentions = [
      (Retention.h24, l.setH24),
      (Retention.d7, l.setD7),
      (Retention.d30, l.setD30),
      (Retention.forever, l.setForever),
    ];
    String label<T>(List<(T, String)> o, T v) => o.firstWhere((e) => e.$1 == v, orElse: () => o.first).$2;

    Widget choice<T>(IconData icon, String title, List<(T, String)> options, T value, void Function(T) onPick) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(label(options, value)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final v = await pickOne<T>(context, title: title, current: value, options: options);
            if (v != null) onPick(v);
          },
        );

    Widget group(String header, List<Widget> tiles) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x1),
          child: SectionHeader(header),
        ),
        Card(child: Column(children: tiles)),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.setTitle)),
      // AD-5: reserved space below the list; never overlaps settings.
      bottomNavigationBar: const BannerAdSlot(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.x8),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              group(l.setSectionAppearance, [
                choice(
                  Icons.dark_mode_outlined,
                  l.setTheme,
                  themes,
                  s.themeMode,
                  (v) => c.update((x) => x.copyWith(themeMode: v)),
                ),
              ]),
              group(l.setSectionImage, [
                ListTile(leading: const Icon(Icons.high_quality_outlined), title: Text(l.setDefaultQuality)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.x2, 0, Space.x2, Space.x2),
                  child: QualitySlider(
                    value: s.imgQuality,
                    onChanged: (v) => c.update((x) => x.copyWith(imgQuality: v)),
                  ),
                ),
                choice(
                  Icons.image_outlined,
                  l.setDefaultFormat,
                  formats,
                  s.imgFormat,
                  (v) => c.update((x) => x.copyWith(imgFormat: v)),
                ),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.location_off_outlined),
                  title: Text(l.cmpStripMeta),
                  value: s.imgStripMetadata,
                  onChanged: (v) => c.update((x) => x.copyWith(imgStripMetadata: v)),
                ),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.link_rounded),
                  title: Text(l.setLockRatio),
                  value: s.resizeLockRatio,
                  onChanged: (v) => c.update((x) => x.copyWith(resizeLockRatio: v)),
                ),
              ]),
              group(l.setSectionPdf, [
                choice(
                  Icons.crop_portrait_rounded,
                  l.setPageSize,
                  sizes,
                  s.pdfPageSize,
                  (v) => c.update((x) => x.copyWith(pdfPageSize: v)),
                ),
                choice(
                  Icons.fit_screen_outlined,
                  l.setImageFit,
                  fits,
                  s.pdfFit,
                  (v) => c.update((x) => x.copyWith(pdfFit: v)),
                ),
                choice(
                  Icons.border_outer_rounded,
                  l.setMargins,
                  margins,
                  s.pdfMargin,
                  (v) => c.update((x) => x.copyWith(pdfMargin: v)),
                ),
                choice(
                  Icons.photo_outlined,
                  l.setPdfImageQuality,
                  qualities,
                  s.pdfImageQuality,
                  (v) => c.update((x) => x.copyWith(pdfImageQuality: v)),
                ),
                // Strong is never offered as a default (FR-CMP-02).
                choice(
                  Icons.compress_rounded,
                  l.setReduceLevel,
                  levels,
                  s.reduceLevel,
                  (v) => c.update((x) => x.copyWith(reduceLevel: v)),
                ),
              ]),
              group(l.setSectionFiles, [
                choice(Icons.schedule_rounded, l.setKeepResults, retentions, s.outputRetention, (v) async {
                  await c.update((x) => x.copyWith(outputRetention: v));
                  await runRetentionSweep(
                    ref.read(historyRepositoryProvider),
                    ref.read(outputsRepositoryProvider),
                    v,
                    ref.read(clockProvider)(),
                  );
                  ref.invalidate(storageUsedProvider);
                }),
                ListTile(
                  leading: const Icon(Icons.storage_rounded),
                  title: Text(l.setStorageUsed),
                  subtitle: Text(storage.value == null ? '…' : formatBytes(storage.value!)),
                  trailing: TextButton(
                    onPressed: (storage.value ?? 0) == 0
                        ? null
                        : () async {
                            final (ok, _) = await confirmDestructive(
                              context,
                              title: l.setStorageClearTitle,
                              body: l.setStorageClearBody,
                              confirmLabel: l.setStorageClear,
                            );
                            if (!ok) return;
                            final jobs = ref.read(outputsRepositoryProvider);
                            await jobs.deleteAll();
                            await jobs.clearTemp(keep: activeDraftIds(ref.read(settingsRepositoryProvider)));
                            await ref.read(historyRepositoryProvider).markAllOutputsDeleted(ref.read(clockProvider)());
                            ref.invalidate(storageUsedProvider);
                            if (context.mounted) showAppSnack(context, l.setStorageCleared);
                          },
                    child: Text(l.setStorageClear),
                  ),
                ),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.verified_user_outlined),
                  title: Text(l.setConfirmDelete),
                  value: s.confirmDestructive,
                  onChanged: (v) => c.update((x) => x.copyWith(confirmDestructive: v)),
                ),
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined, color: context.colors.error),
                  title: Text(l.setClearHistory, style: TextStyle(color: context.colors.error)),
                  onTap: () async {
                    final (ok, alsoFiles) = await confirmDestructive(
                      context,
                      title: l.histClearTitle,
                      body: l.histClearBody,
                      confirmLabel: l.histClearOk,
                      checkboxLabel: l.histClearAlsoFiles,
                    );
                    if (!ok) return;
                    if (alsoFiles) await ref.read(outputsRepositoryProvider).deleteAll();
                    await ref.read(historyRepositoryProvider).clear();
                    ref.invalidate(storageUsedProvider);
                    if (context.mounted) showAppSnack(context, l.setHistoryCleared);
                  },
                ),
              ]),
              group(l.setSectionAds, [
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(l.setRemoveAds),
                subtitle: Text(ads.adsRemoved ? l.remOwned : l.setRemoveAdsSub),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showRemoveAdsSheet(context),
              ),
              // Only in regions where the consent message requires it (UMP).
              if (ads.privacyOptionsRequired)
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.setAdChoices),
                  subtitle: Text(l.setAdChoicesSub),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => ref.read(adsControllerProvider.notifier).showPrivacyOptions(),
                ),
            ]),
            group(l.setSectionHelp, [
                ListTile(
                  leading: const Icon(Icons.tour_outlined),
                  title: Text(l.setTakeTour),
                  subtitle: Text(l.setTakeTourSub),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ref.read(tourControllerProvider.notifier).requestReplay();
                    context.go('/');
                  },
                ),
              ]),
              group(l.setSectionAbout, [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(l.setPrivacy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/privacy'),
                ),
                if (feedbackEmail.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(l.setFeedback),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () async {
                      final v = info.value;
                      final uri = Uri(
                        scheme: 'mailto',
                        path: feedbackEmail,
                        query: _encode({
                          'subject': l.feedbackSubject,
                          'body': l.feedbackBody(
                            '${v?.version ?? ''} (${v?.buildNumber ?? ''})',
                            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
                          ),
                        }),
                      );
                      if (!await launchUrl(uri) && context.mounted) showAppSnack(context, l.feedbackUnavailable);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(
                    info.value == null ? l.appName : l.setVersion(info.value!.version, info.value!.buildNumber),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _encode(Map<String, String> q) =>
      q.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
}
