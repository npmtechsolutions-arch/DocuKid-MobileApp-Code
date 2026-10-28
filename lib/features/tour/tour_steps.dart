import '../../l10n/gen/app_localizations.dart';
import '../search/tool_catalog.dart';
import 'tour_controller.dart';
import 'tour_step.dart';
import 'tour_targets.dart';

/// TOUR.md §2: #0 intro, #1 search, one step per catalogue tool, recent,
/// history/settings, done. Tool steps come from [catalog], so a new tool
/// automatically gets a step.
List<TourStep> buildHomeTourSteps({
  required AppLocalizations l,
  required TourTargets targets,
  required String period,
  List<ToolDescriptor> catalog = toolCatalog,
}) => [
  TourStep(title: l.tourIntroTitle, body: l.tourIntroBody),
  TourStep(target: targets.search, title: l.tourSearchTitle, body: l.tourSearchBody),
  for (final t in catalog)
    TourStep(
      target: targets.toolKey(t.id),
      title: t.tourTitle(l),
      body: t.tourBody(l),
      example: t.tourExample(l),
      tryTool: t.id,
    ),
  TourStep(target: targets.recent, title: l.tourRecentTitle, body: l.tourRecentBody(period)),
  TourStep(target: targets.appBarActions, title: l.tourNavTitle, body: l.tourNavBody),
  TourStep(title: l.tourDoneTitle, body: l.tourDoneBody),
];

/// The `tour_version` that introduced each tool's step; tools not listed have
/// been in the tour since version 1 (TOUR.md §2.1).
const toolTourVersion = <ToolId, int>{
  ToolId.imageConvert: 2,
  ToolId.pdfSplit: 2,
  ToolId.pdfToImages: 2,
  ToolId.scanDocument: 3, // 1.2 (FR-SCN-26)
};

/// FR-TOUR-10/11: "New in DocuKit" for a user whose stored `tour_version` is
/// [since] — an intro, the steps added after it (catalogue order), the
/// Favourites row step (1.1, shown only here — FR-FAV-05) and the done card.
/// Empty when there's nothing new.
List<TourStep> buildWhatsNewSteps({
  required AppLocalizations l,
  required TourTargets targets,
  required int since,
  bool favouritesVisible = false,
  List<ToolDescriptor> catalog = toolCatalog,
}) {
  if (since >= currentTourVersion) return const [];
  return [
    TourStep(title: l.tourWhatsNew, body: ''),
    for (final t in catalog)
      if ((toolTourVersion[t.id] ?? 1) > since)
        TourStep(
          target: targets.toolKey(t.id),
          title: t.tourTitle(l),
          body: t.tourBody(l),
          example: t.tourExample(l),
          tryTool: t.id,
        ),
    if (since < 2)
      TourStep(
        // Points at the row only when something is pinned (it's hidden otherwise).
        target: favouritesVisible ? targets.favourites : null,
        title: l.tourFavouritesTitle,
        body: l.tourFavouritesBody,
      ),
    TourStep(title: l.tourDoneTitle, body: l.tourDoneBody),
  ];
}

