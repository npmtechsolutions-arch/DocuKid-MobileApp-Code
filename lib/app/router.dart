import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ads/ads_config.dart';
import '../core/ads/bottom_banner.dart';
import '../core/widgets/common.dart';
import '../features/history/details_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/image_compress/presentation/compress_screen.dart';
import '../features/image_convert/presentation/convert_screen.dart';
import '../features/image_resize/presentation/resize_screen.dart';
import '../features/image_to_pdf/presentation/image_to_pdf_screen.dart';
import '../features/incoming/incoming_screen.dart';
import '../features/job/job_screen.dart';
import '../features/library/application/app_lock.dart';
import '../features/library/presentation/doc_viewer_screen.dart';
import '../features/library/presentation/document_screen.dart';
import '../features/library/presentation/library_home_screen.dart';
import '../features/library/presentation/library_settings_screen.dart';
import '../features/library/presentation/lock_screen.dart';
import '../features/ocr/presentation/ocr_review_screen.dart';
import '../features/ocr/presentation/ocr_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/pdf_compress/presentation/reduce_screen.dart';
import '../features/pdf_merge/presentation/merge_screen.dart';
import '../features/pdf_organize/presentation/organize_screen.dart';
import '../features/pdf_organize/presentation/page_preview_screen.dart';
import '../features/pdf_protect/presentation/protect_screen.dart';
import '../features/pdf_sign/presentation/placement_screen.dart';
import '../features/pdf_sign/presentation/sign_screen.dart';
import '../features/pdf_sign/presentation/signature_creator_screen.dart';
import '../features/pdf_split/presentation/split_screen.dart';
import '../features/pdf_to_images/presentation/pdf_to_images_screen.dart';
import '../features/pdf_unlock/presentation/unlock_screen.dart';
import '../features/pdf_watermark/presentation/watermark_screen.dart';
import '../features/print/presentation/print_preview_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/scan/presentation/scan_screen.dart';
import '../features/search/search_screen.dart';
import '../features/search/tool_catalog.dart';
import '../features/settings/ad_diagnostics_screen.dart';
import '../features/settings/saved_signatures_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tools/manage_files_screen.dart';
import '../features/tools/tool_entry.dart';
import 'theme/tokens.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

Widget toolScreenFor(ToolId id, {Map<String, String> query = const {}}) => switch (id) {
      ToolId.imageCompress => const CompressScreen(),
      ToolId.imageResize => const ResizeScreen(),
      ToolId.imageToPdf => const ImageToPdfScreen(),
      ToolId.pdfMerge => const MergeScreen(),
      ToolId.pdfOrganize => const OrganizeScreen(),
      ToolId.pdfCompress => const ReduceScreen(),
      ToolId.imageConvert => const ConvertScreen(),
      ToolId.pdfSplit => const SplitScreen(),
      ToolId.pdfToImages => const PdfToImagesScreen(),
      // Quick action / launcher shortcut open the scanner at once (FR-SCN-24).
      ToolId.scanDocument => ScanScreen(autostart: query['autostart'] == '1'),
      ToolId.ocr => const OcrScreen(),
      // 1.4: each tool's own screen replaces the shell in its task (T11.3–T11.8).
      ToolId.pdfProtect => const ProtectScreen(),
      ToolId.pdfUnlock => const UnlockScreen(),
      ToolId.pdfSign => const SignScreen(),
      ToolId.pdfWatermark => const WatermarkScreen(),
    };

/// Route table (SCREENS §0). [guard] (1.5 app lock, §4.8) returns where to
/// go instead of a location, or null.
GoRouter buildRouter({required bool onboarded, String? Function(String location)? guard}) {
  // Bottom banners collapse while a dialog/sheet is open on either navigator.
  overlayRoutes.reset();
  return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: onboarded ? '/' : '/onboarding',
      observers: [overlayRoutes.observer()],
      redirect: guard == null ? null : (_, state) => guard(state.uri.toString()),
      routes: [
        ShellRoute(
          observers: [overlayRoutes.observer()],
          builder: (context, state, child) => AdaptiveShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
            GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          ],
        ),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
        // 1.5 S45 (FR-LCK-06); `next` is checked (no open redirect). No banner.
        GoRoute(
            path: '/lock',
            builder: (_, state) =>
                LockScreen(next: safeNext(state.uri.queryParameters['next']), cover: state.uri.queryParameters['cover'] == '1')),
        // S19: received files → compatible tools (FR-SHR-05). No banner.
        GoRoute(path: '/incoming', builder: (_, _) => const IncomingScreen()),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? ''),
            transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: Motion.of(context, const Duration(milliseconds: 250)),
          ),
        ),
        GoRoute(
          path: '/tool/:slug',
          redirect: (_, state) => toolBySlug(state.pathParameters['slug']!) == null ? '/?missing=1' : null,
          builder: (_, state) {
            final id = toolBySlug(state.pathParameters['slug']!)!.id;
            final q = state.uri.queryParameters;
            return ToolEntry(tool: id, query: q, child: toolScreenFor(id, query: q));
          },
          routes: [
            GoRoute(
              path: 'review',
              builder: (_, state) => ManageFilesScreen(tool: toolBySlug(state.pathParameters['slug']!)!.id),
            ),
            // S34 (RELEASE_V1_4): full screen, no ads; Sign PDF only.
            GoRoute(
              path: 'create',
              redirect: (_, state) => state.pathParameters['slug'] == 'pdf-sign' ? null : '/?missing=1',
              builder: (_, state) =>
                  SignatureCreatorScreen(mode: SignatureCreatorScreen.modeOf(state.uri.queryParameters['mode'])),
            ),
            // S35 (RELEASE_V1_4): full screen, no ads; Sign PDF only.
            GoRoute(
              path: 'place',
              redirect: (_, state) => state.pathParameters['slug'] == 'pdf-sign' ? null : '/?missing=1',
              builder: (_, _) => const PlacementScreen(),
            ),
            GoRoute(
              path: 'preview/:page',
              builder: (_, state) => PagePreviewScreen(initial: int.tryParse(state.pathParameters['page']!) ?? 0),
            ),
          ],
        ),
        // 1.6 S48 Print preview (RELEASE_PRINT §3): the file comes from
        // printRequestProvider, set by the entry point. Banner with the gap.
        GoRoute(path: '/print/preview', builder: (_, _) => const PrintPreviewScreen()),
        GoRoute(path: '/job/:jobId', builder: (_, state) => JobScreen(jobId: state.pathParameters['jobId']!)),
        // S31 Review text: no banner (RELEASE_V1_3 §3.3).
        GoRoute(path: '/job/:jobId/text', builder: (_, state) => OcrReviewScreen(jobId: state.pathParameters['jobId']!)),
        GoRoute(path: '/history/:opId', builder: (_, state) => DetailsScreen(opId: state.pathParameters['opId']!)),
        GoRoute(path: '/settings/privacy', builder: (_, _) => const PrivacyScreen()),
        GoRoute(path: '/settings/policy', builder: (_, _) => const PolicyScreen()),
        GoRoute(path: '/settings/signatures', builder: (_, _) => const SavedSignaturesScreen()),
        // 1.5 S46; the lock guard comes in T12.7.
        GoRoute(path: '/settings/library', builder: (_, _) => const LibrarySettingsScreen()),
        // 1.5 My Documents (RELEASE_V1_5 §4.10); the lock guard comes in T12.7.
        GoRoute(
          path: '/library',
          builder: (_, _) => const LibraryScreen(),
          routes: [
            GoRoute(path: 'folder/:id', builder: (_, state) => LibraryScreen(folderId: state.pathParameters['id'])),
            GoRoute(
              path: 'doc/:id',
              builder: (_, state) => DocumentScreen(docId: state.pathParameters['id']!),
              routes: [GoRoute(path: 'view', builder: (_, state) => DocViewerScreen(docId: state.pathParameters['id']!))],
            ),
          ],
        ),
        // Hidden: Settings → tap the version 7 times (ADR-035). No banner.
        GoRoute(path: '/settings/ads-diagnostics', builder: (_, _) => const AdDiagnosticsScreen()),
        GoRoute(
          path: '/settings/licenses',
          builder: (context, _) => AppBottomBanner(
            unit: AdUnit.bannerInfo,
            child: LicensePage(
              applicationName: context.l10n.appName,
              applicationIcon: const Padding(padding: EdgeInsets.all(Space.x2), child: Icon(Icons.description_rounded, size: 40)),
            ),
          ),
        ),
      ],
      // Deep-link safety: unknown routes → Home + "That item is no longer available."
      errorBuilder: (_, _) => const _UnknownRoute(),
    );
}

class _UnknownRoute extends StatefulWidget {
  const _UnknownRoute();

  @override
  State<_UnknownRoute> createState() => _UnknownRouteState();
}

class _UnknownRouteState extends State<_UnknownRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final msg = context.l10n.itemUnavailable;
      GoRouter.of(context).go('/');
      rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// Tablets/landscape ≥ 840 dp: NavigationRail (Home, My Documents, History,
/// Settings) replaces the app-bar icons (SCREENS S01, RELEASE_V1_5 FR-LIB-01).
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final missing = GoRouterState.of(context).uri.queryParameters['missing'] == '1';
    if (missing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(context.l10n.itemUnavailable)));
        if (context.mounted) GoRouter.of(context).go('/');
      });
    }
    if (MediaQuery.sizeOf(context).width < Breakpoints.expanded) return child;
    final l = context.l10n;
    final index = location.startsWith('/history') ? 2 : (location.startsWith('/settings') ? 3 : 0);
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: index,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x4),
            child: Icon(Icons.description_rounded, color: context.colors.primary, size: 32),
          ),
          // My Documents opens above the shell, as the phone's 📁 does.
          onDestinationSelected: (i) => i == 1 ? context.push('/library') : context.go(const ['/', '', '/history', '/settings'][i]),
          destinations: [
            NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: Text(l.homeNavHome)),
            NavigationRailDestination(icon: const Icon(Icons.folder_outlined), selectedIcon: const Icon(Icons.folder_rounded), label: Text(l.libTitle)),
            NavigationRailDestination(icon: const Icon(Icons.history_rounded), label: Text(l.homeHistoryTooltip)),
            NavigationRailDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings_rounded), label: Text(l.homeSettingsTooltip)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ]),
    );
  }
}
