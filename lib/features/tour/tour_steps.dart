import '../../l10n/gen/app_localizations.dart';
import '../search/tool_catalog.dart';
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
