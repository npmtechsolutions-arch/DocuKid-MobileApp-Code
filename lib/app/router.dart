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
import '../features/job/job_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/pdf_compress/presentation/reduce_screen.dart';
import '../features/pdf_merge/presentation/merge_screen.dart';
import '../features/pdf_organize/presentation/organize_screen.dart';
import '../features/pdf_organize/presentation/page_preview_screen.dart';
import '../features/pdf_split/presentation/split_screen.dart';
import '../features/pdf_to_images/presentation/pdf_to_images_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/search/search_screen.dart';
import '../features/search/tool_catalog.dart';
import '../features/settings/ad_diagnostics_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tools/manage_files_screen.dart';
import '../features/tools/tool_entry.dart';
import 'theme/tokens.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

Widget toolScreenFor(ToolId id) => switch (id) {
      ToolId.imageCompress => const CompressScreen(),
      ToolId.imageResize => const ResizeScreen(),
      ToolId.imageToPdf => const ImageToPdfScreen(),
      ToolId.pdfMerge => const MergeScreen(),
      ToolId.pdfOrganize => const OrganizeScreen(),
      ToolId.pdfCompress => const ReduceScreen(),
      ToolId.imageConvert => const ConvertScreen(),
      ToolId.pdfSplit => const SplitScreen(),
      ToolId.pdfToImages => const PdfToImagesScreen(),
    };

/// Route table (SCREENS §0).
GoRouter buildRouter({required bool onboarded}) {
  // Bottom banners collapse while a dialog/sheet is open on either navigator.
  overlayRoutes.reset();
  return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: onboarded ? '/' : '/onboarding',
      observers: [overlayRoutes.observer()],
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
            return ToolEntry(tool: id, query: state.uri.queryParameters, child: toolScreenFor(id));
          },
          routes: [
            GoRoute(
              path: 'review',
              builder: (_, state) => ManageFilesScreen(tool: toolBySlug(state.pathParameters['slug']!)!.id),
            ),
            GoRoute(
              path: 'preview/:page',
              builder: (_, state) => PagePreviewScreen(initial: int.tryParse(state.pathParameters['page']!) ?? 0),
            ),
          ],
        ),
        GoRoute(path: '/job/:jobId', builder: (_, state) => JobScreen(jobId: state.pathParameters['jobId']!)),
        GoRoute(path: '/history/:opId', builder: (_, state) => DetailsScreen(opId: state.pathParameters['opId']!)),
        GoRoute(path: '/settings/privacy', builder: (_, _) => const PrivacyScreen()),
        GoRoute(path: '/settings/policy', builder: (_, _) => const PolicyScreen()),
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

/// Tablets/landscape ≥ 840 dp: NavigationRail (Home, History, Settings)
/// replaces the app-bar icons (SCREENS S01).
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
    final index = location.startsWith('/history') ? 1 : (location.startsWith('/settings') ? 2 : 0);
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: index,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x4),
            child: Icon(Icons.description_rounded, color: context.colors.primary, size: 32),
          ),
          onDestinationSelected: (i) => context.go(const ['/', '/history', '/settings'][i]),
          destinations: [
            NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: Text(l.homeNavHome)),
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
