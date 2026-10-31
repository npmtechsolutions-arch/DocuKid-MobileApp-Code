import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'DocuKit'**
  String get appName;

  /// No description provided for @privacyPromise.
  ///
  /// In en, this message translates to:
  /// **'Files never leave your phone'**
  String get privacyPromise;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get actionReplace;

  /// No description provided for @actionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get actionDetails;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open with…'**
  String get actionOpenWith;

  /// No description provided for @actionLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get actionLeave;

  /// No description provided for @actionStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get actionStay;

  /// No description provided for @actionDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// No description provided for @actionKeepAnyway.
  ///
  /// In en, this message translates to:
  /// **'Keep anyway'**
  String get actionKeepAnyway;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionInfo.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get actionInfo;

  /// No description provided for @originalUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Your original file was not changed.'**
  String get originalUnchanged;

  /// No description provided for @chooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get chooseAnother;

  /// No description provided for @backToTool.
  ///
  /// In en, this message translates to:
  /// **'Back to tool'**
  String get backToTool;

  /// No description provided for @itemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That item is no longer available.'**
  String get itemUnavailable;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do today?'**
  String get homeGreeting;

  /// No description provided for @homeSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search tools — \"make photo smaller\"'**
  String get homeSearchPlaceholder;

  /// No description provided for @homeSearchExample1.
  ///
  /// In en, this message translates to:
  /// **'Search tools, like \"join PDFs\"'**
  String get homeSearchExample1;

  /// No description provided for @homeSearchExample2.
  ///
  /// In en, this message translates to:
  /// **'Search tools, like \"make photo smaller\"'**
  String get homeSearchExample2;

  /// No description provided for @homeSearchExample3.
  ///
  /// In en, this message translates to:
  /// **'Search tools, like \"passport photo\"'**
  String get homeSearchExample3;

  /// No description provided for @homeSectionImage.
  ///
  /// In en, this message translates to:
  /// **'Image tools'**
  String get homeSectionImage;

  /// No description provided for @homeSectionPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF tools'**
  String get homeSectionPdf;

  /// No description provided for @homeSectionRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeSectionRecent;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue: {toolName}'**
  String homeContinue(Object toolName);

  /// No description provided for @homeRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your finished files will show up here.'**
  String get homeRecentEmpty;

  /// No description provided for @homeJobRunning.
  ///
  /// In en, this message translates to:
  /// **'Processing… Tap to view'**
  String get homeJobRunning;

  /// No description provided for @homeHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get homeHistoryTooltip;

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettingsTooltip;

  /// No description provided for @homeNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavHome;

  /// No description provided for @homeOfflineBadge.
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get homeOfflineBadge;

  /// No description provided for @searchFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search tools'**
  String get searchFieldHint;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @searchHintEmpty.
  ///
  /// In en, this message translates to:
  /// **'Try: compress, combine PDF, passport photo, rotate page'**
  String get searchHintEmpty;

  /// No description provided for @searchChipCompress.
  ///
  /// In en, this message translates to:
  /// **'compress'**
  String get searchChipCompress;

  /// No description provided for @searchChipCombine.
  ///
  /// In en, this message translates to:
  /// **'combine PDF'**
  String get searchChipCombine;

  /// No description provided for @searchChipPassport.
  ///
  /// In en, this message translates to:
  /// **'passport photo'**
  String get searchChipPassport;

  /// No description provided for @searchChipRotate.
  ///
  /// In en, this message translates to:
  /// **'rotate page'**
  String get searchChipRotate;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No tool matches \"{query}\".'**
  String searchNoResults(Object query);

  /// No description provided for @searchMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches \"{phrase}\"'**
  String searchMatches(Object phrase);

  /// No description provided for @searchAllTools.
  ///
  /// In en, this message translates to:
  /// **'All tools'**
  String get searchAllTools;

  /// No description provided for @onbTitle.
  ///
  /// In en, this message translates to:
  /// **'Document tools that stay on your phone'**
  String get onbTitle;

  /// No description provided for @onbB1.
  ///
  /// In en, this message translates to:
  /// **'Compress and resize photos'**
  String get onbB1;

  /// No description provided for @onbB2.
  ///
  /// In en, this message translates to:
  /// **'Make and edit PDFs'**
  String get onbB2;

  /// No description provided for @onbB3.
  ///
  /// In en, this message translates to:
  /// **'No account. No uploads.'**
  String get onbB3;

  /// No description provided for @onbCta.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbCta;

  /// No description provided for @toolImageCompressTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Compressor'**
  String get toolImageCompressTitle;

  /// No description provided for @toolImageCompressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make photos smaller'**
  String get toolImageCompressSubtitle;

  /// No description provided for @toolImageResizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Resizer'**
  String get toolImageResizeTitle;

  /// No description provided for @toolImageResizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set an exact size'**
  String get toolImageResizeSubtitle;

  /// No description provided for @toolImageToPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Images to PDF'**
  String get toolImageToPdfTitle;

  /// No description provided for @toolImageToPdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn photos into one PDF'**
  String get toolImageToPdfSubtitle;

  /// No description provided for @toolPdfMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge PDFs'**
  String get toolPdfMergeTitle;

  /// No description provided for @toolPdfMergeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Combine files into one'**
  String get toolPdfMergeSubtitle;

  /// No description provided for @toolPdfOrganizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize Pages'**
  String get toolPdfOrganizeTitle;

  /// No description provided for @toolPdfOrganizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder, rotate or delete'**
  String get toolPdfOrganizeSubtitle;

  /// No description provided for @toolPdfCompressTitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce PDF Size'**
  String get toolPdfCompressTitle;

  /// No description provided for @toolPdfCompressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make a PDF smaller'**
  String get toolPdfCompressSubtitle;

  /// No description provided for @toolImageConvertTitle.
  ///
  /// In en, this message translates to:
  /// **'Convert Image'**
  String get toolImageConvertTitle;

  /// No description provided for @toolImageConvertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change the file format'**
  String get toolImageConvertSubtitle;

  /// No description provided for @toolPdfSplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Split PDF'**
  String get toolPdfSplitTitle;

  /// No description provided for @toolPdfSplitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Break a PDF into parts'**
  String get toolPdfSplitSubtitle;

  /// No description provided for @toolPdfToImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF to Images'**
  String get toolPdfToImagesTitle;

  /// No description provided for @toolPdfToImagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save pages as pictures'**
  String get toolPdfToImagesSubtitle;

  /// No description provided for @infoImageCompress.
  ///
  /// In en, this message translates to:
  /// **'DocuKit makes a smaller copy of your photo on this device. Lower quality means a smaller file. Target size tries several qualities until the copy fits. Your original is never changed.'**
  String get infoImageCompress;

  /// No description provided for @infoImageResize.
  ///
  /// In en, this message translates to:
  /// **'Set the exact width and height in pixels, scale by a percentage, or pick a preset such as a passport photo. If the shape changes, choose how the image should fit. Your original is never changed.'**
  String get infoImageResize;

  /// No description provided for @infoImageToPdf.
  ///
  /// In en, this message translates to:
  /// **'Each image becomes one page, in the order shown. Images are oriented upright and sized to the page you choose. Everything happens on this device.'**
  String get infoImageToPdf;

  /// No description provided for @infoPdfMerge.
  ///
  /// In en, this message translates to:
  /// **'Pages are copied exactly. Bookmarks and form fields may not be kept.'**
  String get infoPdfMerge;

  /// No description provided for @infoPdfOrganize.
  ///
  /// In en, this message translates to:
  /// **'Reorder, rotate or delete pages, then save the result as a new PDF. Your original PDF is not changed.'**
  String get infoPdfOrganize;

  /// No description provided for @infoPdfCompress.
  ///
  /// In en, this message translates to:
  /// **'Basic cleans up the file without any quality loss. Balanced shrinks photos inside the PDF. Strong turns every page into an image. How much a PDF shrinks depends on what\'s inside it.'**
  String get infoPdfCompress;

  /// No description provided for @pickImages.
  ///
  /// In en, this message translates to:
  /// **'Choose images'**
  String get pickImages;

  /// No description provided for @pickImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get pickImage;

  /// No description provided for @pickPdfs.
  ///
  /// In en, this message translates to:
  /// **'Choose PDFs'**
  String get pickPdfs;

  /// No description provided for @pickPdf.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF'**
  String get pickPdf;

  /// No description provided for @pickFormatsImages.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG, WebP or HEIC · up to 100 MB'**
  String get pickFormatsImages;

  /// No description provided for @pickFormatsPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF · up to 500 MB'**
  String get pickFormatsPdf;

  /// No description provided for @pickLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading files…'**
  String get pickLoading;

  /// No description provided for @inputsHeader.
  ///
  /// In en, this message translates to:
  /// **'Files ({count})'**
  String inputsHeader(int count);

  /// No description provided for @inputsFileHeader.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get inputsFileHeader;

  /// No description provided for @inputsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get inputsAdd;

  /// No description provided for @inputsManageAll.
  ///
  /// In en, this message translates to:
  /// **'Manage all files'**
  String get inputsManageAll;

  /// No description provided for @inputsTruncated.
  ///
  /// In en, this message translates to:
  /// **'Only the first {max} files were added.'**
  String inputsTruncated(int max);

  /// No description provided for @inputsAllInvalid.
  ///
  /// In en, this message translates to:
  /// **'None of these files can be used. Choose different files.'**
  String get inputsAllInvalid;

  /// No description provided for @largeFileHint.
  ///
  /// In en, this message translates to:
  /// **'Large file — this may take a while.'**
  String get largeFileHint;

  /// No description provided for @inputsOptionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get inputsOptionsHeader;

  /// No description provided for @badgeHasAlpha.
  ///
  /// In en, this message translates to:
  /// **'Has transparency'**
  String get badgeHasAlpha;

  /// No description provided for @badgeLocked.
  ///
  /// In en, this message translates to:
  /// **'Password-protected'**
  String get badgeLocked;

  /// No description provided for @badgeDamaged.
  ///
  /// In en, this message translates to:
  /// **'Looks damaged'**
  String get badgeDamaged;

  /// No description provided for @badgeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported'**
  String get badgeUnsupported;

  /// No description provided for @badgeTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too large'**
  String get badgeTooLarge;

  /// No description provided for @badgeUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be read'**
  String get badgeUnreadable;

  /// No description provided for @metaPages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String metaPages(int count);

  /// No description provided for @metaDims.
  ///
  /// In en, this message translates to:
  /// **'{w} × {h}'**
  String metaDims(int w, int h);

  /// No description provided for @cmpSectionHow.
  ///
  /// In en, this message translates to:
  /// **'How small?'**
  String get cmpSectionHow;

  /// No description provided for @cmpModeQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get cmpModeQuality;

  /// No description provided for @cmpModeTarget.
  ///
  /// In en, this message translates to:
  /// **'Target size'**
  String get cmpModeTarget;

  /// No description provided for @cmpQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Smaller file'**
  String get cmpQualityLow;

  /// No description provided for @cmpQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'Sharper'**
  String get cmpQualityHigh;

  /// No description provided for @cmpQualityA11y.
  ///
  /// In en, this message translates to:
  /// **'Quality {value} percent'**
  String cmpQualityA11y(int value);

  /// No description provided for @cmpTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep under'**
  String get cmpTargetLabel;

  /// No description provided for @cmpTargetAlreadySmaller.
  ///
  /// In en, this message translates to:
  /// **'This image is already under {size}.'**
  String cmpTargetAlreadySmaller(Object size);

  /// No description provided for @cmpTargetMin.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 5 KB.'**
  String get cmpTargetMin;

  /// No description provided for @cmpUnitKb.
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get cmpUnitKb;

  /// No description provided for @cmpUnitMb.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get cmpUnitMb;

  /// No description provided for @cmpMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get cmpMoreOptions;

  /// No description provided for @cmpFormat.
  ///
  /// In en, this message translates to:
  /// **'Output format'**
  String get cmpFormat;

  /// No description provided for @cmpFormatSame.
  ///
  /// In en, this message translates to:
  /// **'Same as original'**
  String get cmpFormatSame;

  /// No description provided for @cmpMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Max size'**
  String get cmpMaxSize;

  /// No description provided for @cmpMaxOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get cmpMaxOriginal;

  /// No description provided for @cmpMaxPx.
  ///
  /// In en, this message translates to:
  /// **'{px} px'**
  String cmpMaxPx(int px);

  /// No description provided for @cmpStripMeta.
  ///
  /// In en, this message translates to:
  /// **'Remove location and camera info'**
  String get cmpStripMeta;

  /// No description provided for @cmpPngWarning.
  ///
  /// In en, this message translates to:
  /// **'PNG doesn\'t use quality. Choose JPEG or WebP for smaller files.'**
  String get cmpPngWarning;

  /// No description provided for @cmpSwitchJpeg.
  ///
  /// In en, this message translates to:
  /// **'Switch to JPEG'**
  String get cmpSwitchJpeg;

  /// No description provided for @warnAlphaLost.
  ///
  /// In en, this message translates to:
  /// **'Transparent areas will become white.'**
  String get warnAlphaLost;

  /// No description provided for @cmpTargetUsesJpeg.
  ///
  /// In en, this message translates to:
  /// **'Target size uses JPEG.'**
  String get cmpTargetUsesJpeg;

  /// No description provided for @cmpRun.
  ///
  /// In en, this message translates to:
  /// **'Compress image'**
  String get cmpRun;

  /// No description provided for @cmpRunAnyway.
  ///
  /// In en, this message translates to:
  /// **'Compress anyway'**
  String get cmpRunAnyway;

  /// No description provided for @fmtJpeg.
  ///
  /// In en, this message translates to:
  /// **'JPEG'**
  String get fmtJpeg;

  /// No description provided for @fmtPng.
  ///
  /// In en, this message translates to:
  /// **'PNG'**
  String get fmtPng;

  /// No description provided for @fmtWebp.
  ///
  /// In en, this message translates to:
  /// **'WebP'**
  String get fmtWebp;

  /// No description provided for @fmtHeic.
  ///
  /// In en, this message translates to:
  /// **'HEIC'**
  String get fmtHeic;

  /// No description provided for @fmtPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get fmtPdf;

  /// No description provided for @resSectionSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get resSectionSize;

  /// No description provided for @resModePixels.
  ///
  /// In en, this message translates to:
  /// **'Pixels'**
  String get resModePixels;

  /// No description provided for @resModePercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get resModePercent;

  /// No description provided for @resModePreset.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get resModePreset;

  /// No description provided for @resWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get resWidth;

  /// No description provided for @resHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get resHeight;

  /// No description provided for @resUnitPx.
  ///
  /// In en, this message translates to:
  /// **'px'**
  String get resUnitPx;

  /// No description provided for @resLockOn.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio locked'**
  String get resLockOn;

  /// No description provided for @resLockOff.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio unlocked'**
  String get resLockOff;

  /// No description provided for @resOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original {w} × {h}'**
  String resOriginal(int w, int h);

  /// No description provided for @resResultLine.
  ///
  /// In en, this message translates to:
  /// **'Result: {w} × {h} px'**
  String resResultLine(int w, int h);

  /// No description provided for @resScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get resScale;

  /// No description provided for @resPercentValue.
  ///
  /// In en, this message translates to:
  /// **'{p}%'**
  String resPercentValue(int p);

  /// No description provided for @resShapeHeader.
  ///
  /// In en, this message translates to:
  /// **'When the shape changes'**
  String get resShapeHeader;

  /// No description provided for @resFitStretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get resFitStretch;

  /// No description provided for @resFitContain.
  ///
  /// In en, this message translates to:
  /// **'Fit with border'**
  String get resFitContain;

  /// No description provided for @resFitCover.
  ///
  /// In en, this message translates to:
  /// **'Crop to fill'**
  String get resFitCover;

  /// No description provided for @resPadColor.
  ///
  /// In en, this message translates to:
  /// **'Border colour'**
  String get resPadColor;

  /// No description provided for @resPadWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get resPadWhite;

  /// No description provided for @resPadBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get resPadBlack;

  /// No description provided for @resPadTransparent.
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get resPadTransparent;

  /// No description provided for @resUpscaleWarning.
  ///
  /// In en, this message translates to:
  /// **'Enlarging can make the image blurry.'**
  String get resUpscaleWarning;

  /// No description provided for @resErrRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 12000.'**
  String get resErrRange;

  /// No description provided for @resErrMegapixels.
  ///
  /// In en, this message translates to:
  /// **'That would be over 100 megapixels. Choose a smaller size.'**
  String get resErrMegapixels;

  /// No description provided for @resSavePreset.
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get resSavePreset;

  /// No description provided for @resMyPresets.
  ///
  /// In en, this message translates to:
  /// **'My presets'**
  String get resMyPresets;

  /// No description provided for @resPresetNameHint.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get resPresetNameHint;

  /// No description provided for @resPresetLimit.
  ///
  /// In en, this message translates to:
  /// **'You can save up to 10 presets.'**
  String get resPresetLimit;

  /// No description provided for @resDeletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get resDeletePreset;

  /// No description provided for @resPresetPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport photo (35×45 mm)'**
  String get resPresetPassport;

  /// No description provided for @resPresetSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get resPresetSignature;

  /// No description provided for @resPresetSquare.
  ///
  /// In en, this message translates to:
  /// **'Square post'**
  String get resPresetSquare;

  /// No description provided for @resPresetStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get resPresetStory;

  /// No description provided for @resPresetHd.
  ///
  /// In en, this message translates to:
  /// **'HD'**
  String get resPresetHd;

  /// No description provided for @resPresetFullhd.
  ///
  /// In en, this message translates to:
  /// **'Full HD'**
  String get resPresetFullhd;

  /// No description provided for @resQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get resQuality;

  /// No description provided for @resRun.
  ///
  /// In en, this message translates to:
  /// **'Resize image'**
  String get resRun;

  /// No description provided for @i2pHeader.
  ///
  /// In en, this message translates to:
  /// **'Images ({count})'**
  String i2pHeader(int count);

  /// No description provided for @i2pEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 100 images. Pages follow this order.'**
  String get i2pEmptyHint;

  /// No description provided for @i2pSectionPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get i2pSectionPage;

  /// No description provided for @i2pSectionQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get i2pSectionQuality;

  /// No description provided for @i2pPageSize.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get i2pPageSize;

  /// No description provided for @i2pOrientation.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get i2pOrientation;

  /// No description provided for @i2pFit.
  ///
  /// In en, this message translates to:
  /// **'Image fit'**
  String get i2pFit;

  /// No description provided for @i2pMargins.
  ///
  /// In en, this message translates to:
  /// **'Margins'**
  String get i2pMargins;

  /// No description provided for @i2pQuality.
  ///
  /// In en, this message translates to:
  /// **'Image quality'**
  String get i2pQuality;

  /// No description provided for @i2pSizeA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get i2pSizeA4;

  /// No description provided for @i2pSizeLetter.
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get i2pSizeLetter;

  /// No description provided for @i2pSizeLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get i2pSizeLegal;

  /// No description provided for @i2pSizeImage.
  ///
  /// In en, this message translates to:
  /// **'Same as image'**
  String get i2pSizeImage;

  /// No description provided for @i2pOrientAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get i2pOrientAuto;

  /// No description provided for @i2pOrientPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get i2pOrientPortrait;

  /// No description provided for @i2pOrientLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get i2pOrientLandscape;

  /// No description provided for @i2pFitFit.
  ///
  /// In en, this message translates to:
  /// **'Fit whole image'**
  String get i2pFitFit;

  /// No description provided for @i2pFitFill.
  ///
  /// In en, this message translates to:
  /// **'Fill page'**
  String get i2pFitFill;

  /// No description provided for @i2pMarginNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get i2pMarginNone;

  /// No description provided for @i2pMarginSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get i2pMarginSmall;

  /// No description provided for @i2pMarginLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get i2pMarginLarge;

  /// No description provided for @i2pQOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get i2pQOriginal;

  /// No description provided for @i2pQHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get i2pQHigh;

  /// No description provided for @i2pQCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get i2pQCompact;

  /// No description provided for @i2pPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get i2pPreview;

  /// No description provided for @i2pOutputName.
  ///
  /// In en, this message translates to:
  /// **'Output name'**
  String get i2pOutputName;

  /// No description provided for @i2pRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get i2pRotate;

  /// No description provided for @i2pRemoveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Remove and continue'**
  String get i2pRemoveAndContinue;

  /// No description provided for @i2pImageA11y.
  ///
  /// In en, this message translates to:
  /// **'Image {n} of {total}'**
  String i2pImageA11y(int n, int total);

  /// No description provided for @i2pRun.
  ///
  /// In en, this message translates to:
  /// **'Create PDF ({count, plural, =1{1 page} other{{count} pages}})'**
  String i2pRun(int count);

  /// No description provided for @i2pRunEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create PDF'**
  String get i2pRunEmpty;

  /// No description provided for @mrgHeader.
  ///
  /// In en, this message translates to:
  /// **'PDFs ({count})'**
  String mrgHeader(int count);

  /// No description provided for @mrgTotal.
  ///
  /// In en, this message translates to:
  /// **'{files} PDFs · {pages} pages total'**
  String mrgTotal(int files, int pages);

  /// No description provided for @mrgDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to change the order. Files are merged top to bottom.'**
  String get mrgDragHint;

  /// No description provided for @mrgNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Add at least 2 PDFs'**
  String get mrgNeedTwo;

  /// No description provided for @mrgRemoveInvalid.
  ///
  /// In en, this message translates to:
  /// **'Remove {count, plural, =1{1 file} other{{count} files}} that can\'t be merged'**
  String mrgRemoveInvalid(int count);

  /// No description provided for @mrgTooManyPages.
  ///
  /// In en, this message translates to:
  /// **'Merged PDFs can have up to 2000 pages.'**
  String get mrgTooManyPages;

  /// No description provided for @mrgSectionOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get mrgSectionOutput;

  /// No description provided for @mrgName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mrgName;

  /// No description provided for @mrgRun.
  ///
  /// In en, this message translates to:
  /// **'Merge {count} PDFs'**
  String mrgRun(int count);

  /// No description provided for @mrgInfoSheet.
  ///
  /// In en, this message translates to:
  /// **'Pages are copied exactly. Bookmarks and form fields may not be kept.'**
  String get mrgInfoSheet;

  /// No description provided for @orgStatus.
  ///
  /// In en, this message translates to:
  /// **'{pages, plural, =1{1 page} other{{pages} pages}} · {selected} selected'**
  String orgStatus(int pages, int selected);

  /// No description provided for @orgHint.
  ///
  /// In en, this message translates to:
  /// **'Tap pages to select them. Long-press and drag to reorder. Double-tap to preview.'**
  String get orgHint;

  /// No description provided for @orgRotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get orgRotateLeft;

  /// No description provided for @orgRotateRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get orgRotateRight;

  /// No description provided for @orgDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get orgDelete;

  /// No description provided for @orgMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get orgMove;

  /// No description provided for @orgMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move selected pages to'**
  String get orgMoveTo;

  /// No description provided for @orgMoveStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get orgMoveStart;

  /// No description provided for @orgMoveEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get orgMoveEnd;

  /// No description provided for @orgMoveAfter.
  ///
  /// In en, this message translates to:
  /// **'After page'**
  String get orgMoveAfter;

  /// No description provided for @orgMinOnePage.
  ///
  /// In en, this message translates to:
  /// **'A PDF needs at least one page.'**
  String get orgMinOnePage;

  /// No description provided for @orgDeletedUndo.
  ///
  /// In en, this message translates to:
  /// **'Page deleted'**
  String get orgDeletedUndo;

  /// No description provided for @orgPageMovedFrom.
  ///
  /// In en, this message translates to:
  /// **'Page {pos}, originally page {orig}'**
  String orgPageMovedFrom(int pos, int orig);

  /// No description provided for @orgA11yPage.
  ///
  /// In en, this message translates to:
  /// **'Page {pos} of {total}'**
  String orgA11yPage(int pos, int total);

  /// No description provided for @orgA11yRotated.
  ///
  /// In en, this message translates to:
  /// **'rotated {deg} degrees'**
  String orgA11yRotated(int deg);

  /// No description provided for @orgA11ySelected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get orgA11ySelected;

  /// No description provided for @orgOrigPage.
  ///
  /// In en, this message translates to:
  /// **'p.{n}'**
  String orgOrigPage(int n);

  /// No description provided for @orgCantPreview.
  ///
  /// In en, this message translates to:
  /// **'Can\'t preview'**
  String get orgCantPreview;

  /// No description provided for @orgUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get orgUndo;

  /// No description provided for @orgRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get orgRedo;

  /// No description provided for @orgMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get orgMore;

  /// No description provided for @orgSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get orgSelectAll;

  /// No description provided for @orgSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get orgSelectNone;

  /// No description provided for @orgInvert.
  ///
  /// In en, this message translates to:
  /// **'Invert selection'**
  String get orgInvert;

  /// No description provided for @orgReset.
  ///
  /// In en, this message translates to:
  /// **'Reset changes'**
  String get orgReset;

  /// No description provided for @orgDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} pages?'**
  String orgDeleteConfirmTitle(int count);

  /// No description provided for @orgDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You can undo this before saving.'**
  String get orgDeleteConfirmBody;

  /// No description provided for @orgRun.
  ///
  /// In en, this message translates to:
  /// **'Save as new PDF'**
  String get orgRun;

  /// No description provided for @orgPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Page {pos} of {total}'**
  String orgPreviewTitle(int pos, int total);

  /// No description provided for @redSectionLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get redSectionLevel;

  /// No description provided for @redAnalysis.
  ///
  /// In en, this message translates to:
  /// **'{pages} pages · {images} images · {kind}'**
  String redAnalysis(int pages, int images, String kind);

  /// No description provided for @redAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing…'**
  String get redAnalysing;

  /// No description provided for @redKindImage.
  ///
  /// In en, this message translates to:
  /// **'Image-heavy'**
  String get redKindImage;

  /// No description provided for @redKindText.
  ///
  /// In en, this message translates to:
  /// **'Mostly text'**
  String get redKindText;

  /// No description provided for @redBasicT.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get redBasicT;

  /// No description provided for @redBasicD.
  ///
  /// In en, this message translates to:
  /// **'Clean up the file. No quality loss. Usually a small reduction.'**
  String get redBasicD;

  /// No description provided for @redBalancedT.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get redBalancedT;

  /// No description provided for @redBalancedD.
  ///
  /// In en, this message translates to:
  /// **'Shrinks photos inside the PDF. Text stays sharp and selectable.'**
  String get redBalancedD;

  /// No description provided for @redStrongT.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get redStrongT;

  /// No description provided for @redStrongD.
  ///
  /// In en, this message translates to:
  /// **'Turns every page into an image. Smallest file. Text can\'t be selected or searched.'**
  String get redStrongD;

  /// No description provided for @redRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get redRecommended;

  /// No description provided for @redNote.
  ///
  /// In en, this message translates to:
  /// **'How much a PDF shrinks depends on what\'s inside it. Text-only PDFs may not get smaller.'**
  String get redNote;

  /// No description provided for @redBalancedWarning.
  ///
  /// In en, this message translates to:
  /// **'Photos inside the PDF may look slightly softer.'**
  String get redBalancedWarning;

  /// No description provided for @strongConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Strong reduction?'**
  String get strongConfirmTitle;

  /// No description provided for @strongConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Text will no longer be selectable or searchable, and links will stop working. Your original stays as it is.'**
  String get strongConfirmBody;

  /// No description provided for @strongConfirmOk.
  ///
  /// In en, this message translates to:
  /// **'Use Strong'**
  String get strongConfirmOk;

  /// No description provided for @redRun.
  ///
  /// In en, this message translates to:
  /// **'Reduce size'**
  String get redRun;

  /// No description provided for @stepPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get stepPreparing;

  /// No description provided for @stepReading.
  ///
  /// In en, this message translates to:
  /// **'Reading files…'**
  String get stepReading;

  /// No description provided for @stepCompressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing image…'**
  String get stepCompressing;

  /// No description provided for @stepResizing.
  ///
  /// In en, this message translates to:
  /// **'Resizing image…'**
  String get stepResizing;

  /// No description provided for @stepBuildingPdf.
  ///
  /// In en, this message translates to:
  /// **'Building PDF…'**
  String get stepBuildingPdf;

  /// No description provided for @stepMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging PDFs…'**
  String get stepMerging;

  /// No description provided for @stepSavingPages.
  ///
  /// In en, this message translates to:
  /// **'Saving pages…'**
  String get stepSavingPages;

  /// No description provided for @stepOptimizing.
  ///
  /// In en, this message translates to:
  /// **'Reducing size…'**
  String get stepOptimizing;

  /// No description provided for @stepChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the result…'**
  String get stepChecking;

  /// No description provided for @progressPages.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} pages'**
  String progressPages(int done, int total);

  /// No description provided for @progressImages.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} images'**
  String progressImages(int done, int total);

  /// No description provided for @progressFiles.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} files'**
  String progressFiles(int done, int total);

  /// No description provided for @keepOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep DocuKit open until this finishes.'**
  String get keepOpen;

  /// No description provided for @cancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this job?'**
  String get cancelConfirmTitle;

  /// No description provided for @cancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing will be saved.'**
  String get cancelConfirmBody;

  /// No description provided for @cancelConfirmKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get cancelConfirmKeep;

  /// No description provided for @cancelConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get cancelConfirmYes;

  /// No description provided for @cancelledSnack.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing was saved.'**
  String get cancelledSnack;

  /// No description provided for @busySnack.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel the current job first.'**
  String get busySnack;

  /// No description provided for @jobCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get jobCancelTooltip;

  /// No description provided for @jobOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Processing on this device'**
  String get jobOnDevice;

  /// No description provided for @resultDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get resultDone;

  /// No description provided for @resultBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get resultBefore;

  /// No description provided for @resultAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get resultAfter;

  /// No description provided for @resultChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get resultChange;

  /// No description provided for @resultSmaller.
  ///
  /// In en, this message translates to:
  /// **'{percent}% smaller'**
  String resultSmaller(int percent);

  /// No description provided for @resultLarger.
  ///
  /// In en, this message translates to:
  /// **'{percent}% larger'**
  String resultLarger(int percent);

  /// No description provided for @resultNoChange.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get resultNoChange;

  /// No description provided for @resultNotSmallerImg.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make this image smaller. Try a lower quality or a smaller max size.'**
  String get resultNotSmallerImg;

  /// No description provided for @resultNotSmallerPdf.
  ///
  /// In en, this message translates to:
  /// **'This PDF is already well optimised. The result is not smaller.'**
  String get resultNotSmallerPdf;

  /// No description provided for @resultTargetMissed.
  ///
  /// In en, this message translates to:
  /// **'Closest we could get: {actual} (target {target}). Try a smaller max size.'**
  String resultTargetMissed(String actual, String target);

  /// No description provided for @resultRetention.
  ///
  /// In en, this message translates to:
  /// **'Kept in Recent for {period}'**
  String resultRetention(Object period);

  /// No description provided for @resultRetentionForever.
  ///
  /// In en, this message translates to:
  /// **'Kept in Recent until you delete it'**
  String get resultRetentionForever;

  /// No description provided for @resultEditOptions.
  ///
  /// In en, this message translates to:
  /// **'Edit options'**
  String get resultEditOptions;

  /// No description provided for @resultKeepOriginal.
  ///
  /// In en, this message translates to:
  /// **'Keep original'**
  String get resultKeepOriginal;

  /// No description provided for @resultTryLower.
  ///
  /// In en, this message translates to:
  /// **'Try lower quality'**
  String get resultTryLower;

  /// No description provided for @resultCompareHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to compare before and after'**
  String get resultCompareHint;

  /// No description provided for @resultCompareA11y.
  ///
  /// In en, this message translates to:
  /// **'Before and after comparison'**
  String get resultCompareA11y;

  /// No description provided for @resultOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get resultOpen;

  /// No description provided for @resultA11ySummary.
  ///
  /// In en, this message translates to:
  /// **'Done. {before} to {after}.'**
  String resultA11ySummary(String before, String after);

  /// No description provided for @resultPreviewA11y.
  ///
  /// In en, this message translates to:
  /// **'Preview of the result'**
  String get resultPreviewA11y;

  /// No description provided for @saveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get saveToPhotos;

  /// No description provided for @saveToFiles.
  ///
  /// In en, this message translates to:
  /// **'Save to Files…'**
  String get saveToFiles;

  /// No description provided for @saveSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Save to'**
  String get saveSheetTitle;

  /// No description provided for @savedSnack.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedSnack;

  /// No description provided for @savedSnackNamed.
  ///
  /// In en, this message translates to:
  /// **'Saved as {name}'**
  String savedSnackNamed(Object name);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file. Try another location.'**
  String get saveFailed;

  /// No description provided for @photosDenied.
  ///
  /// In en, this message translates to:
  /// **'DocuKit can\'t add to Photos. Allow it in Settings.'**
  String get photosDenied;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @saveFilesInstead.
  ///
  /// In en, this message translates to:
  /// **'Save to Files instead'**
  String get saveFilesInstead;

  /// No description provided for @openWithNone.
  ///
  /// In en, this message translates to:
  /// **'No app on this device can open this file.'**
  String get openWithNone;

  /// No description provided for @discardedSnack.
  ///
  /// In en, this message translates to:
  /// **'Result discarded.'**
  String get discardedSnack;

  /// No description provided for @errUnsupportedFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported'**
  String get errUnsupportedFormatTitle;

  /// No description provided for @errUnsupportedFormatBody.
  ///
  /// In en, this message translates to:
  /// **'DocuKit works with JPG, PNG, WebP and HEIC images, and PDF files.'**
  String get errUnsupportedFormatBody;

  /// No description provided for @errInvalidInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your settings'**
  String get errInvalidInputTitle;

  /// No description provided for @errInvalidInputBody.
  ///
  /// In en, this message translates to:
  /// **'Some options aren\'t valid. Go back and check them.'**
  String get errInvalidInputBody;

  /// No description provided for @errEncryptedDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'This PDF is password-protected'**
  String get errEncryptedDocumentTitle;

  /// No description provided for @errEncryptedDocumentBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock it first, then try again.'**
  String get errEncryptedDocumentBody;

  /// No description provided for @errCorruptFileTitle.
  ///
  /// In en, this message translates to:
  /// **'This file looks damaged'**
  String get errCorruptFileTitle;

  /// No description provided for @errCorruptFileBody.
  ///
  /// In en, this message translates to:
  /// **'It couldn\'t be read. Try opening it in another app, or choose a different copy.'**
  String get errCorruptFileBody;

  /// No description provided for @errFileTooLargeTitle.
  ///
  /// In en, this message translates to:
  /// **'This file is too large'**
  String get errFileTooLargeTitle;

  /// No description provided for @errFileTooLargeBody.
  ///
  /// In en, this message translates to:
  /// **'The limit is {limit}. Try a smaller file.'**
  String errFileTooLargeBody(Object limit);

  /// No description provided for @errTooManyFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Too many files'**
  String get errTooManyFilesTitle;

  /// No description provided for @errTooManyFilesBody.
  ///
  /// In en, this message translates to:
  /// **'You can add up to {max} at a time.'**
  String errTooManyFilesBody(int max);

  /// No description provided for @errNotEnoughFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Add more files'**
  String get errNotEnoughFilesTitle;

  /// No description provided for @errNotEnoughFilesBody.
  ///
  /// In en, this message translates to:
  /// **'This tool needs at least {min}.'**
  String errNotEnoughFilesBody(int min);

  /// No description provided for @errInsufficientStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space'**
  String get errInsufficientStorageTitle;

  /// No description provided for @errInsufficientStorageBody.
  ///
  /// In en, this message translates to:
  /// **'About {needed} is needed. Free up some space on your phone and try again.'**
  String errInsufficientStorageBody(Object needed);

  /// No description provided for @errPermissionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t read this file anymore'**
  String get errPermissionLostTitle;

  /// No description provided for @errPermissionLostBody.
  ///
  /// In en, this message translates to:
  /// **'Please choose the file again.'**
  String get errPermissionLostBody;

  /// No description provided for @errProcessingFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errProcessingFailedTitle;

  /// No description provided for @errProcessingFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The job didn\'t finish. Your files are safe.'**
  String get errProcessingFailedBody;

  /// No description provided for @errOutOfMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'This file is too big for your phone to process'**
  String get errOutOfMemoryTitle;

  /// No description provided for @errOutOfMemoryBody.
  ///
  /// In en, this message translates to:
  /// **'Try a smaller file, or a lower max size.'**
  String get errOutOfMemoryBody;

  /// No description provided for @errCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get errCancelledTitle;

  /// No description provided for @errCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved.'**
  String get errCancelledBody;

  /// No description provided for @errOutputValidationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The result didn\'t pass our checks'**
  String get errOutputValidationFailedTitle;

  /// No description provided for @errOutputValidationFailedBody.
  ///
  /// In en, this message translates to:
  /// **'We didn\'t keep it, to avoid giving you a broken file. Please try again.'**
  String get errOutputValidationFailedBody;

  /// No description provided for @errSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file'**
  String get errSaveFailedTitle;

  /// No description provided for @errSaveFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Try another location.'**
  String get errSaveFailedBody;

  /// No description provided for @errInterruptedTitle.
  ///
  /// In en, this message translates to:
  /// **'This job was interrupted'**
  String get errInterruptedTitle;

  /// No description provided for @errInterruptedBody.
  ///
  /// In en, this message translates to:
  /// **'DocuKit was closed before it finished.'**
  String get errInterruptedBody;

  /// No description provided for @errFileLabel.
  ///
  /// In en, this message translates to:
  /// **'File: {name}'**
  String errFileLabel(Object name);

  /// No description provided for @histTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get histTitle;

  /// No description provided for @histFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get histFilterAll;

  /// No description provided for @histFilterImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get histFilterImages;

  /// No description provided for @histFilterPdfs.
  ///
  /// In en, this message translates to:
  /// **'PDFs'**
  String get histFilterPdfs;

  /// No description provided for @histFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get histFilterFailed;

  /// No description provided for @histToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get histToday;

  /// No description provided for @histYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get histYesterday;

  /// No description provided for @histUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File no longer available'**
  String get histUnavailable;

  /// No description provided for @histEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Files you create appear here for {period}.'**
  String histEmpty(Object period);

  /// No description provided for @histEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get histEmptyTitle;

  /// No description provided for @histRemovedUndo.
  ///
  /// In en, this message translates to:
  /// **'Removed from history'**
  String get histRemovedUndo;

  /// No description provided for @histClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get histClearTitle;

  /// No description provided for @histClearBody.
  ///
  /// In en, this message translates to:
  /// **'This clears the list. Files you saved elsewhere are not affected.'**
  String get histClearBody;

  /// No description provided for @histClearAlsoFiles.
  ///
  /// In en, this message translates to:
  /// **'Also delete app copies of results'**
  String get histClearAlsoFiles;

  /// No description provided for @histClearOk.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get histClearOk;

  /// No description provided for @histSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort and filter'**
  String get histSortTooltip;

  /// No description provided for @histClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get histClearTooltip;

  /// No description provided for @histSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort and filter'**
  String get histSortTitle;

  /// No description provided for @histSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get histSortLabel;

  /// No description provided for @histSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get histSortNewest;

  /// No description provided for @histSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get histSortOldest;

  /// No description provided for @histSortSaving.
  ///
  /// In en, this message translates to:
  /// **'Biggest saving'**
  String get histSortSaving;

  /// No description provided for @histStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get histStatusLabel;

  /// No description provided for @histStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get histStatusAll;

  /// No description provided for @histStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get histStatusCompleted;

  /// No description provided for @histStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get histStatusFailed;

  /// No description provided for @histFailedLine.
  ///
  /// In en, this message translates to:
  /// **'Failed — {reason}'**
  String histFailedLine(Object reason);

  /// No description provided for @histCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get histCancelled;

  /// No description provided for @histInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get histInterrupted;

  /// No description provided for @histRunning.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get histRunning;

  /// No description provided for @histSizes.
  ///
  /// In en, this message translates to:
  /// **'{before} → {after}'**
  String histSizes(String before, String after);

  /// No description provided for @histFilesPages.
  ///
  /// In en, this message translates to:
  /// **'{files, plural, =1{1 file} other{{files} files}} · {pages} pages · {size}'**
  String histFilesPages(int files, int pages, String size);

  /// No description provided for @histLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get histLoadMore;

  /// No description provided for @detTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detTitle;

  /// No description provided for @detStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get detStatus;

  /// No description provided for @detTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get detTool;

  /// No description provided for @detInputs.
  ///
  /// In en, this message translates to:
  /// **'Inputs'**
  String get detInputs;

  /// No description provided for @detOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get detOutput;

  /// No description provided for @detSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get detSettings;

  /// No description provided for @detSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get detSaved;

  /// No description provided for @detKeptUntil.
  ///
  /// In en, this message translates to:
  /// **'Kept until'**
  String get detKeptUntil;

  /// No description provided for @detNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved to your device yet'**
  String get detNotSaved;

  /// No description provided for @detSavedYes.
  ///
  /// In en, this message translates to:
  /// **'Saved to device'**
  String get detSavedYes;

  /// No description provided for @detDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get detDeleted;

  /// No description provided for @detForever.
  ///
  /// In en, this message translates to:
  /// **'Until you delete it'**
  String get detForever;

  /// No description provided for @detTook.
  ///
  /// In en, this message translates to:
  /// **'took {duration}'**
  String detTook(Object duration);

  /// No description provided for @detStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get detStatusCompleted;

  /// No description provided for @detStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get detStatusFailed;

  /// No description provided for @detStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get detStatusCancelled;

  /// No description provided for @detStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get detStatusInterrupted;

  /// No description provided for @detStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get detStatusRunning;

  /// No description provided for @detRunAgain.
  ///
  /// In en, this message translates to:
  /// **'Run again with these settings'**
  String get detRunAgain;

  /// No description provided for @detDeleteCopy.
  ///
  /// In en, this message translates to:
  /// **'Delete app copy'**
  String get detDeleteCopy;

  /// No description provided for @detRemoveEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get detRemoveEntry;

  /// No description provided for @detDeleteCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the app copy?'**
  String get detDeleteCopyTitle;

  /// No description provided for @detDeleteCopyBody.
  ///
  /// In en, this message translates to:
  /// **'Files you saved elsewhere are not affected.'**
  String get detDeleteCopyBody;

  /// No description provided for @detRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from history?'**
  String get detRemoveTitle;

  /// No description provided for @detRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The app copy of the result will also be deleted. Files you saved elsewhere are not affected.'**
  String get detRemoveBody;

  /// No description provided for @detRepickHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to choose the files again.'**
  String get detRepickHint;

  /// No description provided for @setTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setTitle;

  /// No description provided for @setSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setSectionAppearance;

  /// No description provided for @setSectionImage.
  ///
  /// In en, this message translates to:
  /// **'Image defaults'**
  String get setSectionImage;

  /// No description provided for @setSectionPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF defaults'**
  String get setSectionPdf;

  /// No description provided for @setSectionFiles.
  ///
  /// In en, this message translates to:
  /// **'Files and history'**
  String get setSectionFiles;

  /// No description provided for @setSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get setSectionAbout;

  /// No description provided for @setTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get setTheme;

  /// No description provided for @setSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get setSystem;

  /// No description provided for @setLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setLight;

  /// No description provided for @setDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get setDark;

  /// No description provided for @setDefaultQuality.
  ///
  /// In en, this message translates to:
  /// **'Default quality'**
  String get setDefaultQuality;

  /// No description provided for @setDefaultFormat.
  ///
  /// In en, this message translates to:
  /// **'Default output format'**
  String get setDefaultFormat;

  /// No description provided for @setLockRatio.
  ///
  /// In en, this message translates to:
  /// **'Keep aspect ratio when resizing'**
  String get setLockRatio;

  /// No description provided for @setPageSize.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get setPageSize;

  /// No description provided for @setImageFit.
  ///
  /// In en, this message translates to:
  /// **'Image fit'**
  String get setImageFit;

  /// No description provided for @setMargins.
  ///
  /// In en, this message translates to:
  /// **'Margins'**
  String get setMargins;

  /// No description provided for @setPdfImageQuality.
  ///
  /// In en, this message translates to:
  /// **'Image quality in PDFs'**
  String get setPdfImageQuality;

  /// No description provided for @setReduceLevel.
  ///
  /// In en, this message translates to:
  /// **'Size reducer level'**
  String get setReduceLevel;

  /// No description provided for @setKeepResults.
  ///
  /// In en, this message translates to:
  /// **'Keep results for'**
  String get setKeepResults;

  /// No description provided for @setH24.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get setH24;

  /// No description provided for @setD7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get setD7;

  /// No description provided for @setD30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get setD30;

  /// No description provided for @setForever.
  ///
  /// In en, this message translates to:
  /// **'Until I delete'**
  String get setForever;

  /// No description provided for @setStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'Storage used'**
  String get setStorageUsed;

  /// No description provided for @setStorageClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get setStorageClear;

  /// No description provided for @setStorageClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete app copies of results?'**
  String get setStorageClearTitle;

  /// No description provided for @setStorageClearBody.
  ///
  /// In en, this message translates to:
  /// **'History stays. Files you saved elsewhere are not affected.'**
  String get setStorageClearBody;

  /// No description provided for @setStorageCleared.
  ///
  /// In en, this message translates to:
  /// **'App copies deleted'**
  String get setStorageCleared;

  /// No description provided for @setConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm before deleting'**
  String get setConfirmDelete;

  /// No description provided for @setClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get setClearHistory;

  /// No description provided for @setHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get setHistoryCleared;

  /// No description provided for @setPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & about'**
  String get setPrivacy;

  /// No description provided for @setFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get setFeedback;

  /// No description provided for @setVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String setVersion(String version, String build);

  /// No description provided for @feedbackSubject.
  ///
  /// In en, this message translates to:
  /// **'DocuKit feedback'**
  String get feedbackSubject;

  /// No description provided for @feedbackBody.
  ///
  /// In en, this message translates to:
  /// **'App version: {version}\nDevice OS: {os}\n\n'**
  String feedbackBody(String version, String os);

  /// No description provided for @feedbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No email app is set up on this device.'**
  String get feedbackUnavailable;

  /// No description provided for @periodH24.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get periodH24;

  /// No description provided for @periodD7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get periodD7;

  /// No description provided for @periodD30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get periodD30;

  /// No description provided for @periodForever.
  ///
  /// In en, this message translates to:
  /// **'until you delete them'**
  String get periodForever;

  /// No description provided for @privTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & about'**
  String get privTitle;

  /// No description provided for @privLocalH.
  ///
  /// In en, this message translates to:
  /// **'Your files stay on your phone'**
  String get privLocalH;

  /// No description provided for @privLocalP.
  ///
  /// In en, this message translates to:
  /// **'Everything DocuKit does to your files happens on this device. Your files are never uploaded.'**
  String get privLocalP;

  /// No description provided for @privAccountH.
  ///
  /// In en, this message translates to:
  /// **'No account'**
  String get privAccountH;

  /// No description provided for @privAccountP.
  ///
  /// In en, this message translates to:
  /// **'You don\'t need to sign up, and DocuKit doesn\'t know who you are.'**
  String get privAccountP;

  /// No description provided for @privAccessH.
  ///
  /// In en, this message translates to:
  /// **'What DocuKit can access'**
  String get privAccessH;

  /// No description provided for @privAccessPhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get privAccessPhotosLabel;

  /// No description provided for @privAccessPhotos.
  ///
  /// In en, this message translates to:
  /// **'Only the photos you pick'**
  String get privAccessPhotos;

  /// No description provided for @privAccessFilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get privAccessFilesLabel;

  /// No description provided for @privAccessFiles.
  ///
  /// In en, this message translates to:
  /// **'Only the files you pick'**
  String get privAccessFiles;

  /// No description provided for @privAccessPhotosAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos (add only)'**
  String get privAccessPhotosAddLabel;

  /// No description provided for @privAccessPhotosAdd.
  ///
  /// In en, this message translates to:
  /// **'Adding to Photos, only when you tap Save to Photos'**
  String get privAccessPhotosAdd;

  /// No description provided for @privAccessCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get privAccessCameraLabel;

  /// No description provided for @privStoredH.
  ///
  /// In en, this message translates to:
  /// **'What\'s stored'**
  String get privStoredH;

  /// No description provided for @privStoredP.
  ///
  /// In en, this message translates to:
  /// **'A list of recent jobs, and copies of results for {period}. Both stay on this device and you can clear them in Settings.'**
  String privStoredP(Object period);

  /// No description provided for @privProtectedH.
  ///
  /// In en, this message translates to:
  /// **'Password-protected files'**
  String get privProtectedH;

  /// No description provided for @privProtectedP.
  ///
  /// In en, this message translates to:
  /// **'DocuKit opens or unlocks a protected PDF only with the password you type. It never tries to guess or remove a password without it.'**
  String get privProtectedP;

  /// No description provided for @privLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get privLicenses;

  /// No description provided for @privPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privPolicy;

  /// No description provided for @privPolicyBody1.
  ///
  /// In en, this message translates to:
  /// **'DocuKit has no account system and never uploads your files. Your files, file names and results stay on your device and are never sent to us or to anyone else.'**
  String get privPolicyBody1;

  /// No description provided for @privPolicyBody2.
  ///
  /// In en, this message translates to:
  /// **'Files you choose are processed only on your device. The app keeps a list of recent jobs and copies of results on your device for the period you choose in Settings (7 days by default). You can delete them at any time in Settings. Uninstalling the app deletes them. Saved signatures are stored only on your device and are not included in backups. Passwords you enter are used once and never saved.'**
  String get privPolicyBody2;

  /// No description provided for @privPolicyBody3.
  ///
  /// In en, this message translates to:
  /// **'The app accesses only the photos and files you select in the system picker. On iOS it asks for permission to add images to your photo library only when you choose Save to Photos. Files you share into DocuKit from other apps are copied into the app and processed only on your device. When you scan, the camera images are processed on your phone. On Android, the scanner is provided by Google Play services, which may send Google basic diagnostics about it, such as the device model, app version and error codes, but never your images. Text recognition also runs on your phone: DocuKit doesn\'t upload your files or the text found in them. It uses Google\'s ML Kit, which may send Google basic diagnostics about it, such as the device model, app version and error codes, but never your images or text.'**
  String get privPolicyBody3;

  /// No description provided for @privPolicyBody4.
  ///
  /// In en, this message translates to:
  /// **'Ads: DocuKit shows ads from Google AdMob to stay free. To show and measure ads and to prevent fraud, Google\'s ads SDK collects device information such as the advertising ID, approximate location from the IP address, and how you interact with ads. It never receives your files, file names or results. Where the law requires it, DocuKit asks for your consent first, and you can change your choice in Settings → Privacy & ad choices. You can remove ads with a one-time purchase. Google\'s privacy policy: policies.google.com/privacy'**
  String get privPolicyBody4;

  /// No description provided for @privPolicyBody5.
  ///
  /// In en, this message translates to:
  /// **'Purchases are handled by Google Play or the App Store; we never receive your payment details. Google Play and Apple may provide anonymous crash statistics if you\'ve allowed this in your device settings. The app isn\'t directed at children under 13.'**
  String get privPolicyBody5;

  /// No description provided for @unsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without finishing?'**
  String get unsavedTitle;

  /// No description provided for @unsavedBody.
  ///
  /// In en, this message translates to:
  /// **'Your files and settings for this tool will be cleared.'**
  String get unsavedBody;

  /// No description provided for @unsavedOrganizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard your page changes?'**
  String get unsavedOrganizerTitle;

  /// No description provided for @unsavedOrganizerBody.
  ///
  /// In en, this message translates to:
  /// **'Your page edits haven\'t been saved.'**
  String get unsavedOrganizerBody;

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameTitle;

  /// No description provided for @renameHint.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get renameHint;

  /// No description provided for @renameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get renameEmpty;

  /// No description provided for @renamePreview.
  ///
  /// In en, this message translates to:
  /// **'Will be saved as {name}'**
  String renamePreview(Object name);

  /// No description provided for @fdTitle.
  ///
  /// In en, this message translates to:
  /// **'File details'**
  String get fdTitle;

  /// No description provided for @fdName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fdName;

  /// No description provided for @fdType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fdType;

  /// No description provided for @fdSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fdSize;

  /// No description provided for @fdDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get fdDimensions;

  /// No description provided for @fdPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get fdPages;

  /// No description provided for @fdAlpha.
  ///
  /// In en, this message translates to:
  /// **'Transparency'**
  String get fdAlpha;

  /// No description provided for @fdLocation.
  ///
  /// In en, this message translates to:
  /// **'Location data'**
  String get fdLocation;

  /// No description provided for @fdProtected.
  ///
  /// In en, this message translates to:
  /// **'Password-protected'**
  String get fdProtected;

  /// No description provided for @fdYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get fdYes;

  /// No description provided for @fdNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get fdNo;

  /// No description provided for @moveToTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveToTitle;

  /// No description provided for @moveTop.
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get moveTop;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @moveBottom.
  ///
  /// In en, this message translates to:
  /// **'Move to bottom'**
  String get moveBottom;

  /// No description provided for @dragHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragHandle;

  /// No description provided for @draftRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored your last session.'**
  String get draftRestored;

  /// No description provided for @draftStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get draftStartOver;

  /// No description provided for @durUnderSecond.
  ///
  /// In en, this message translates to:
  /// **'under a second'**
  String get durUnderSecond;

  /// No description provided for @durSeconds.
  ///
  /// In en, this message translates to:
  /// **'{s} s'**
  String durSeconds(Object s);

  /// No description provided for @durMinutes.
  ///
  /// In en, this message translates to:
  /// **'{m} min {s} s'**
  String durMinutes(int m, int s);

  /// No description provided for @a11ySizeWords.
  ///
  /// In en, this message translates to:
  /// **'{value} {unit, select, B{bytes} KB{kilobytes} MB{megabytes} GB{gigabytes} other{}}'**
  String a11ySizeWords(String value, String unit);

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeSavedSoFar.
  ///
  /// In en, this message translates to:
  /// **'You\'ve saved {size} so far'**
  String homeSavedSoFar(String size);

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// No description provided for @homeHelpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Take the tour'**
  String get homeHelpTooltip;

  /// No description provided for @qaPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport photo'**
  String get qaPassport;

  /// No description provided for @qaUnder100kb.
  ///
  /// In en, this message translates to:
  /// **'Under 100 KB'**
  String get qaUnder100kb;

  /// No description provided for @qaSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get qaSignature;

  /// No description provided for @qaPhotosToPdf.
  ///
  /// In en, this message translates to:
  /// **'Photos to PDF'**
  String get qaPhotosToPdf;

  /// No description provided for @qaMergePdfs.
  ///
  /// In en, this message translates to:
  /// **'Merge PDFs'**
  String get qaMergePdfs;

  /// No description provided for @qaEmailPdf.
  ///
  /// In en, this message translates to:
  /// **'Email-size PDF'**
  String get qaEmailPdf;

  /// No description provided for @tourIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick tour'**
  String get tourIntroTitle;

  /// No description provided for @tourIntroBody.
  ///
  /// In en, this message translates to:
  /// **'See what DocuKit can do in about 30 seconds.'**
  String get tourIntroBody;

  /// No description provided for @tourStart.
  ///
  /// In en, this message translates to:
  /// **'Start tour'**
  String get tourStart;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tourSkip;

  /// No description provided for @tourNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tourNext;

  /// No description provided for @tourBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tourBack;

  /// No description provided for @tourDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tourDone;

  /// No description provided for @tourTry.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get tourTry;

  /// No description provided for @tourSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search in plain words'**
  String get tourSearchTitle;

  /// No description provided for @tourSearchBody.
  ///
  /// In en, this message translates to:
  /// **'Type what you need, like \"make photo smaller\" or \"join PDFs\".'**
  String get tourSearchBody;

  /// No description provided for @tourImageCompressTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Compressor'**
  String get tourImageCompressTitle;

  /// No description provided for @tourImageCompressBody.
  ///
  /// In en, this message translates to:
  /// **'Make photos smaller. Pick a quality, or set a limit like \"under 100 KB\".'**
  String get tourImageCompressBody;

  /// No description provided for @tourImageCompressExample.
  ///
  /// In en, this message translates to:
  /// **'Great for job and exam portals with upload limits.'**
  String get tourImageCompressExample;

  /// No description provided for @tourImageResizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Resizer'**
  String get tourImageResizeTitle;

  /// No description provided for @tourImageResizeBody.
  ///
  /// In en, this message translates to:
  /// **'Set an exact size in pixels or percent, or use a preset.'**
  String get tourImageResizeBody;

  /// No description provided for @tourImageResizeExample.
  ///
  /// In en, this message translates to:
  /// **'Passport photo 413×531 or a signature at 140×60.'**
  String get tourImageResizeExample;

  /// No description provided for @tourImageToPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Images to PDF'**
  String get tourImageToPdfTitle;

  /// No description provided for @tourImageToPdfBody.
  ///
  /// In en, this message translates to:
  /// **'Turn several photos into one PDF, in the order you choose.'**
  String get tourImageToPdfBody;

  /// No description provided for @tourImageToPdfExample.
  ///
  /// In en, this message translates to:
  /// **'Notes, receipts or certificates in one file.'**
  String get tourImageToPdfExample;

  /// No description provided for @tourPdfMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge PDFs'**
  String get tourPdfMergeTitle;

  /// No description provided for @tourPdfMergeBody.
  ///
  /// In en, this message translates to:
  /// **'Combine several PDFs into one. Drag to set the order.'**
  String get tourPdfMergeBody;

  /// No description provided for @tourPdfMergeExample.
  ///
  /// In en, this message translates to:
  /// **'Put a cover letter and CV together.'**
  String get tourPdfMergeExample;

  /// No description provided for @tourPdfOrganizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize Pages'**
  String get tourPdfOrganizeTitle;

  /// No description provided for @tourPdfOrganizeBody.
  ///
  /// In en, this message translates to:
  /// **'Reorder, rotate or delete pages, then save a new copy.'**
  String get tourPdfOrganizeBody;

  /// No description provided for @tourPdfOrganizeExample.
  ///
  /// In en, this message translates to:
  /// **'Fix a sideways scan or remove a blank page.'**
  String get tourPdfOrganizeExample;

  /// No description provided for @tourPdfCompressTitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce PDF Size'**
  String get tourPdfCompressTitle;

  /// No description provided for @tourPdfCompressBody.
  ///
  /// In en, this message translates to:
  /// **'Make a PDF smaller for email, with clear choices about quality.'**
  String get tourPdfCompressBody;

  /// No description provided for @tourPdfCompressExample.
  ///
  /// In en, this message translates to:
  /// **'Get under a 10 MB email limit.'**
  String get tourPdfCompressExample;

  /// No description provided for @tourImageConvertTitle.
  ///
  /// In en, this message translates to:
  /// **'Convert Image'**
  String get tourImageConvertTitle;

  /// No description provided for @tourImageConvertBody.
  ///
  /// In en, this message translates to:
  /// **'Change photos between JPG, PNG, WebP and HEIC.'**
  String get tourImageConvertBody;

  /// No description provided for @tourImageConvertExample.
  ///
  /// In en, this message translates to:
  /// **'Turn iPhone HEIC photos into JPG for upload forms.'**
  String get tourImageConvertExample;

  /// No description provided for @tourPdfSplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Split PDF'**
  String get tourPdfSplitTitle;

  /// No description provided for @tourPdfSplitBody.
  ///
  /// In en, this message translates to:
  /// **'Break one PDF into several smaller ones.'**
  String get tourPdfSplitBody;

  /// No description provided for @tourPdfSplitExample.
  ///
  /// In en, this message translates to:
  /// **'Send only pages 3–5 of a long report.'**
  String get tourPdfSplitExample;

  /// No description provided for @tourPdfToImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF to Images'**
  String get tourPdfToImagesTitle;

  /// No description provided for @tourPdfToImagesBody.
  ///
  /// In en, this message translates to:
  /// **'Save each page as a picture.'**
  String get tourPdfToImagesBody;

  /// No description provided for @tourPdfToImagesExample.
  ///
  /// In en, this message translates to:
  /// **'Post a page of a PDF as a photo.'**
  String get tourPdfToImagesExample;

  /// No description provided for @multiHeaderAll.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get multiHeaderAll;

  /// No description provided for @multiHeaderSome.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String multiHeaderSome(int done, int total);

  /// No description provided for @multiTotals.
  ///
  /// In en, this message translates to:
  /// **'Before {before} → After {after}'**
  String multiTotals(String before, String after);

  /// No description provided for @multiCountPdfs.
  ///
  /// In en, this message translates to:
  /// **'{count} PDFs · {size}'**
  String multiCountPdfs(int count, String size);

  /// No description provided for @multiCountImages.
  ///
  /// In en, this message translates to:
  /// **'{count} images · {size}'**
  String multiCountImages(int count, String size);

  /// No description provided for @multiSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save all…'**
  String get multiSaveAll;

  /// No description provided for @multiSaveZip.
  ///
  /// In en, this message translates to:
  /// **'Save as ZIP'**
  String get multiSaveZip;

  /// No description provided for @multiShareAll.
  ///
  /// In en, this message translates to:
  /// **'Share all'**
  String get multiShareAll;

  /// No description provided for @multiSavedFolder.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} files to {folder}'**
  String multiSavedFolder(int count, String folder);

  /// No description provided for @multiSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} files'**
  String multiSaved(int count);

  /// No description provided for @multiSavedPartial.
  ///
  /// In en, this message translates to:
  /// **'Saved {saved} of {total}. {failed} couldn\'t be written.'**
  String multiSavedPartial(int saved, int total, int failed);

  /// No description provided for @multiShareTooMany.
  ///
  /// In en, this message translates to:
  /// **'That\'s more than 50 files. Share them as one ZIP instead?'**
  String get multiShareTooMany;

  /// No description provided for @multiItemClosest.
  ///
  /// In en, this message translates to:
  /// **'Closest to {target}'**
  String multiItemClosest(String target);

  /// No description provided for @multiItemFailed.
  ///
  /// In en, this message translates to:
  /// **'{error}. Original not changed.'**
  String multiItemFailed(String error);

  /// No description provided for @multiAllFailed.
  ///
  /// In en, this message translates to:
  /// **'None of the files could be processed. Your originals were not changed.'**
  String get multiAllFailed;

  /// No description provided for @multiZipping.
  ///
  /// In en, this message translates to:
  /// **'Zipping {done} of {total}'**
  String multiZipping(int done, int total);

  /// No description provided for @multiFilesHeader.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get multiFilesHeader;

  /// No description provided for @batchHeader.
  ///
  /// In en, this message translates to:
  /// **'Images ({count})'**
  String batchHeader(int count);

  /// No description provided for @batchTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {size}'**
  String batchTotal(String size);

  /// No description provided for @batchInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 can\'t be used} other{{count} can\'t be used}}'**
  String batchInvalid(int count);

  /// No description provided for @batchRemoveInvalid.
  ///
  /// In en, this message translates to:
  /// **'Remove them'**
  String get batchRemoveInvalid;

  /// No description provided for @batchNoneValid.
  ///
  /// In en, this message translates to:
  /// **'Add images that DocuKit can open'**
  String get batchNoneValid;

  /// No description provided for @batchRunCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress {count} images'**
  String batchRunCompress(int count);

  /// No description provided for @batchShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String batchShowAll(int count);

  /// No description provided for @batchClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get batchClearAll;

  /// No description provided for @batchRunResize.
  ///
  /// In en, this message translates to:
  /// **'Resize {count} images'**
  String batchRunResize(int count);

  /// No description provided for @resFitInside.
  ///
  /// In en, this message translates to:
  /// **'Fit inside'**
  String get resFitInside;

  /// No description provided for @batchRunConvert.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Convert 1 image} other{Convert {count} images}}'**
  String batchRunConvert(int count);

  /// No description provided for @cnvTo.
  ///
  /// In en, this message translates to:
  /// **'Convert to'**
  String get cnvTo;

  /// No description provided for @cnvSameFormat.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 image is} other{{count} images are}} already {format}. They\'ll be re-saved.'**
  String cnvSameFormat(int count, String format);

  /// No description provided for @cnvHeicIosOnly.
  ///
  /// In en, this message translates to:
  /// **'HEIC is available on iPhone only.'**
  String get cnvHeicIosOnly;

  /// No description provided for @stepConverting.
  ///
  /// In en, this message translates to:
  /// **'Converting images…'**
  String get stepConverting;

  /// No description provided for @splModeRanges.
  ///
  /// In en, this message translates to:
  /// **'Custom ranges'**
  String get splModeRanges;

  /// No description provided for @splModeEvery.
  ///
  /// In en, this message translates to:
  /// **'Every N pages'**
  String get splModeEvery;

  /// No description provided for @splModeEach.
  ///
  /// In en, this message translates to:
  /// **'Each page'**
  String get splModeEach;

  /// No description provided for @splHow.
  ///
  /// In en, this message translates to:
  /// **'How to split'**
  String get splHow;

  /// No description provided for @splRangesHint.
  ///
  /// In en, this message translates to:
  /// **'Use commas and dashes, e.g. 1-3, 5, 8-end'**
  String get splRangesHint;

  /// No description provided for @splPreviewFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}: {parts}'**
  String splPreviewFiles(int count, String parts);

  /// No description provided for @splPartPage.
  ///
  /// In en, this message translates to:
  /// **'page {page}'**
  String splPartPage(int page);

  /// No description provided for @splPartPages.
  ///
  /// In en, this message translates to:
  /// **'pages {first}–{last}'**
  String splPartPages(int first, int last);

  /// No description provided for @splEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Pages per file'**
  String get splEveryLabel;

  /// No description provided for @splEveryLess.
  ///
  /// In en, this message translates to:
  /// **'Fewer pages per file'**
  String get splEveryLess;

  /// No description provided for @splEveryMore.
  ///
  /// In en, this message translates to:
  /// **'More pages per file'**
  String get splEveryMore;

  /// No description provided for @splEveryPreview.
  ///
  /// In en, this message translates to:
  /// **'{count} files (the last has {lastPages, plural, =1{1 page} other{{lastPages} pages}})'**
  String splEveryPreview(int count, int lastPages);

  /// No description provided for @splEachPreview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String splEachPreview(int count);

  /// No description provided for @splOnePage.
  ///
  /// In en, this message translates to:
  /// **'This PDF has only one page.'**
  String get splOnePage;

  /// No description provided for @splEachCap.
  ///
  /// In en, this message translates to:
  /// **'That would make more than 500 files. Use Every N pages instead.'**
  String get splEachCap;

  /// No description provided for @splRun.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Split} =1{Split into 1 PDF} other{Split into {count} PDFs}}'**
  String splRun(int count);

  /// No description provided for @rangeErrPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} doesn\'t exist. This PDF has {total} pages.'**
  String rangeErrPage(int page, int total);

  /// No description provided for @rangeErrReversed.
  ///
  /// In en, this message translates to:
  /// **'Write ranges from low to high, e.g. 3-5.'**
  String get rangeErrReversed;

  /// No description provided for @rangeErrZero.
  ///
  /// In en, this message translates to:
  /// **'Pages start at 1.'**
  String get rangeErrZero;

  /// No description provided for @rangeErrChars.
  ///
  /// In en, this message translates to:
  /// **'Use only numbers, commas, dashes and \"end\".'**
  String get rangeErrChars;

  /// No description provided for @rangeErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one page.'**
  String get rangeErrEmpty;

  /// No description provided for @rangeEndWord.
  ///
  /// In en, this message translates to:
  /// **'end'**
  String get rangeEndWord;

  /// No description provided for @orgExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get orgExtract;

  /// No description provided for @incTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Received 1 file} other{Received {count} files}}'**
  String incTitle(int count);

  /// No description provided for @incImagesSection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 image} other{{count} images}}'**
  String incImagesSection(int count);

  /// No description provided for @incPdfsSection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 PDF} other{{count} PDFs}}'**
  String incPdfsSection(int count);

  /// No description provided for @incMergeNeedsMore.
  ///
  /// In en, this message translates to:
  /// **'Needs one more PDF. You can add it next.'**
  String get incMergeNeedsMore;

  /// No description provided for @incUnsupported.
  ///
  /// In en, this message translates to:
  /// **'DocuKit can\'t work with this file type.'**
  String get incUnsupported;

  /// No description provided for @incWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file received} other{{count} files received}}. Open when this job finishes.'**
  String incWaiting(int count);

  /// No description provided for @tourFavouritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get tourFavouritesTitle;

  /// No description provided for @tourFavouritesBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press any tool to pin it here.'**
  String get tourFavouritesBody;

  /// No description provided for @favHeader.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favHeader;

  /// No description provided for @favEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get favEdit;

  /// No description provided for @favAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get favAdd;

  /// No description provided for @favRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get favRemove;

  /// No description provided for @favLimit.
  ///
  /// In en, this message translates to:
  /// **'You can pin up to 6 tools. Remove one first.'**
  String get favLimit;

  /// No description provided for @favMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get favMoveUp;

  /// No description provided for @favMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get favMoveDown;

  /// No description provided for @p2iPagesAll.
  ///
  /// In en, this message translates to:
  /// **'All pages'**
  String get p2iPagesAll;

  /// No description provided for @p2iPagesChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose pages'**
  String get p2iPagesChoose;

  /// No description provided for @p2iResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get p2iResolution;

  /// No description provided for @p2iRes72.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get p2iRes72;

  /// No description provided for @p2iRes150.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get p2iRes150;

  /// No description provided for @p2iRes300.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get p2iRes300;

  /// No description provided for @p2iPxEstimate.
  ///
  /// In en, this message translates to:
  /// **'≈ {w} × {h} px per page'**
  String p2iPxEstimate(int w, int h);

  /// No description provided for @p2iPageCapped.
  ///
  /// In en, this message translates to:
  /// **'Page {page} was limited to {px} px to save memory.'**
  String p2iPageCapped(int page, int px);

  /// No description provided for @p2iKeepTransparent.
  ///
  /// In en, this message translates to:
  /// **'Keep transparent background'**
  String get p2iKeepTransparent;

  /// No description provided for @p2iRun.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Create images} =1{Create 1 image} other{Create {count} images}}'**
  String p2iRun(int count);

  /// No description provided for @resFitInsideHint.
  ///
  /// In en, this message translates to:
  /// **'Each photo keeps its shape and fits inside {w} × {h} px. Smaller photos keep their size.'**
  String resFitInsideHint(int w, int h);

  /// No description provided for @tourRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recent files'**
  String get tourRecentTitle;

  /// No description provided for @tourNavTitle.
  ///
  /// In en, this message translates to:
  /// **'History and settings'**
  String get tourNavTitle;

  /// No description provided for @tourNavBody.
  ///
  /// In en, this message translates to:
  /// **'See everything you\'ve made, and set your favourite defaults.'**
  String get tourNavBody;

  /// No description provided for @tourDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set'**
  String get tourDoneTitle;

  /// No description provided for @tourDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your files never leave your phone, and originals are never changed. Tap any tool to start.'**
  String get tourDoneBody;

  /// No description provided for @tourWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'New in DocuKit'**
  String get tourWhatsNew;

  /// No description provided for @setTakeTour.
  ///
  /// In en, this message translates to:
  /// **'Take the tour'**
  String get setTakeTour;

  /// No description provided for @setTakeTourSub.
  ///
  /// In en, this message translates to:
  /// **'A 30-second look at every tool'**
  String get setTakeTourSub;

  /// No description provided for @tourRecentBody.
  ///
  /// In en, this message translates to:
  /// **'Finished files appear here for {period}, so you can save or share them again.'**
  String tourRecentBody(String period);

  /// No description provided for @tourProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}'**
  String tourProgress(int n, int total);

  /// No description provided for @a11yTourStep.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}. {title}. {body}'**
  String a11yTourStep(int n, int total, String title, String body);

  /// No description provided for @adBadge.
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get adBadge;

  /// No description provided for @adSponsored.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get adSponsored;

  /// No description provided for @setRemoveAds.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get setRemoveAds;

  /// No description provided for @setRemoveAdsSub.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase'**
  String get setRemoveAdsSub;

  /// No description provided for @setAdChoices.
  ///
  /// In en, this message translates to:
  /// **'Privacy & ad choices'**
  String get setAdChoices;

  /// No description provided for @setAdChoicesSub.
  ///
  /// In en, this message translates to:
  /// **'Change your consent at any time'**
  String get setAdChoicesSub;

  /// No description provided for @setSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get setSectionHelp;

  /// No description provided for @setSectionAds.
  ///
  /// In en, this message translates to:
  /// **'Ads and privacy'**
  String get setSectionAds;

  /// No description provided for @remTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get remTitle;

  /// No description provided for @remBody.
  ///
  /// In en, this message translates to:
  /// **'Enjoying DocuKit? Remove ads once and support development.'**
  String get remBody;

  /// No description provided for @remPoint1.
  ///
  /// In en, this message translates to:
  /// **'No ads, ever'**
  String get remPoint1;

  /// No description provided for @remPoint2.
  ///
  /// In en, this message translates to:
  /// **'Works on this device and future installs with the same store account'**
  String get remPoint2;

  /// No description provided for @remPoint3.
  ///
  /// In en, this message translates to:
  /// **'Your files stay on your phone, as always'**
  String get remPoint3;

  /// No description provided for @remRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get remRestore;

  /// No description provided for @remThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your support. Ads are gone.'**
  String get remThanks;

  /// No description provided for @remFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. You haven\'t been charged.'**
  String get remFailed;

  /// No description provided for @remUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store isn\'t available right now. Try again later.'**
  String get remUnavailable;

  /// No description provided for @remOwned.
  ///
  /// In en, this message translates to:
  /// **'Ads removed. Thank you.'**
  String get remOwned;

  /// No description provided for @privAdsH.
  ///
  /// In en, this message translates to:
  /// **'About ads'**
  String get privAdsH;

  /// No description provided for @privAdsP.
  ///
  /// In en, this message translates to:
  /// **'DocuKit shows ads from Google AdMob to stay free. Ads never see your files, file names or results. Google may use device information to show and measure ads. You can change your ad choices in Settings, or remove ads with a one-time purchase.'**
  String get privAdsP;

  /// No description provided for @rewOffer.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad: no ads for 24 hours'**
  String get rewOffer;

  /// No description provided for @rewOfferShort.
  ///
  /// In en, this message translates to:
  /// **'No ads for 24 hours? Watch a short ad'**
  String get rewOfferShort;

  /// No description provided for @rewNotEarned.
  ///
  /// In en, this message translates to:
  /// **'The ad was closed early, so ads are still on.'**
  String get rewNotEarned;

  /// No description provided for @rewLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used today\'s ad-free passes. Try again tomorrow.'**
  String get rewLimit;

  /// No description provided for @remBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price}'**
  String remBuy(String price);

  /// No description provided for @rewGranted.
  ///
  /// In en, this message translates to:
  /// **'Done. No ads until {time} tomorrow.'**
  String rewGranted(String time);

  /// No description provided for @adsFreeUntil.
  ///
  /// In en, this message translates to:
  /// **'Ad-free until {time}'**
  String adsFreeUntil(String time);

  /// No description provided for @tip1.
  ///
  /// In en, this message translates to:
  /// **'Tip: Use Target size to hit upload limits exactly.'**
  String get tip1;

  /// No description provided for @tip2.
  ///
  /// In en, this message translates to:
  /// **'Tip: The Passport photo preset gives you exactly 413 × 531 pixels.'**
  String get tip2;

  /// No description provided for @tip3.
  ///
  /// In en, this message translates to:
  /// **'Tip: Turn on \"Remove location and camera info\" before sharing photos.'**
  String get tip3;

  /// No description provided for @tip4.
  ///
  /// In en, this message translates to:
  /// **'Tip: Balanced shrinks photos inside a PDF and keeps the text sharp.'**
  String get tip4;

  /// No description provided for @tip5.
  ///
  /// In en, this message translates to:
  /// **'Tip: In Organize Pages, double-tap a page to see it full screen.'**
  String get tip5;

  /// No description provided for @tip6.
  ///
  /// In en, this message translates to:
  /// **'Tip: Your original file is never changed. DocuKit always makes a copy.'**
  String get tip6;

  /// No description provided for @tip7.
  ///
  /// In en, this message translates to:
  /// **'Tip: Finished files stay in Recent, so you can save or share them again.'**
  String get tip7;

  /// No description provided for @tip8.
  ///
  /// In en, this message translates to:
  /// **'Tip: Search understands plain words, like \"join PDFs\".'**
  String get tip8;

  /// No description provided for @resultDoneImage.
  ///
  /// In en, this message translates to:
  /// **'Image ready'**
  String get resultDoneImage;

  /// No description provided for @resultDonePdf.
  ///
  /// In en, this message translates to:
  /// **'PDF ready'**
  String get resultDonePdf;

  /// No description provided for @resultChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked and ready to save'**
  String get resultChecked;

  /// No description provided for @resultSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get resultSize;

  /// No description provided for @resultSmallerShort.
  ///
  /// In en, this message translates to:
  /// **'smaller'**
  String get resultSmallerShort;

  /// No description provided for @resultLargerShort.
  ///
  /// In en, this message translates to:
  /// **'larger'**
  String get resultLargerShort;

  /// No description provided for @diagTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad diagnostics'**
  String get diagTitle;

  /// No description provided for @diagSectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get diagSectionStatus;

  /// No description provided for @diagSectionSlots.
  ///
  /// In en, this message translates to:
  /// **'Ad slots'**
  String get diagSectionSlots;

  /// No description provided for @diagYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get diagYes;

  /// No description provided for @diagNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get diagNo;

  /// No description provided for @diagConsent.
  ///
  /// In en, this message translates to:
  /// **'Consent allows ads: {answer}'**
  String diagConsent(String answer);

  /// No description provided for @diagAdsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Remove ads bought: {answer}'**
  String diagAdsRemoved(String answer);

  /// No description provided for @diagAdFreeUntil.
  ///
  /// In en, this message translates to:
  /// **'Ad-free pass until {time}'**
  String diagAdFreeUntil(String time);

  /// No description provided for @diagAdFreeNone.
  ///
  /// In en, this message translates to:
  /// **'No ad-free pass active'**
  String get diagAdFreeNone;

  /// No description provided for @diagBuildIds.
  ///
  /// In en, this message translates to:
  /// **'This build uses: {kind}'**
  String diagBuildIds(String kind);

  /// No description provided for @diagIdsTest.
  ///
  /// In en, this message translates to:
  /// **'Test IDs (debug build)'**
  String get diagIdsTest;

  /// No description provided for @diagIdsReal.
  ///
  /// In en, this message translates to:
  /// **'Real IDs (release build)'**
  String get diagIdsReal;

  /// No description provided for @diagUnitTest.
  ///
  /// In en, this message translates to:
  /// **'Test ID'**
  String get diagUnitTest;

  /// No description provided for @diagUnitReal.
  ///
  /// In en, this message translates to:
  /// **'Real ID'**
  String get diagUnitReal;

  /// No description provided for @diagUnitOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get diagUnitOff;

  /// No description provided for @diagUnitMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get diagUnitMissing;

  /// No description provided for @diagLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded at {time}'**
  String diagLoaded(String time);

  /// No description provided for @diagNoFill.
  ///
  /// In en, this message translates to:
  /// **'No fill at {time} (code {code})'**
  String diagNoFill(String time, int code);

  /// No description provided for @diagError.
  ///
  /// In en, this message translates to:
  /// **'Error at {time}: code {code}, {message}'**
  String diagError(String time, int code, String message);

  /// No description provided for @diagErrorNoCode.
  ///
  /// In en, this message translates to:
  /// **'Error at {time}: {message}'**
  String diagErrorNoCode(String time, String message);

  /// No description provided for @diagNotRequested.
  ///
  /// In en, this message translates to:
  /// **'Not requested yet'**
  String get diagNotRequested;

  /// No description provided for @diagPlaceNativeHome.
  ///
  /// In en, this message translates to:
  /// **'Native card on Home (AD-1)'**
  String get diagPlaceNativeHome;

  /// No description provided for @diagPlaceNativeResult.
  ///
  /// In en, this message translates to:
  /// **'Native card on Result (AD-2)'**
  String get diagPlaceNativeResult;

  /// No description provided for @diagPlaceNativeHistory.
  ///
  /// In en, this message translates to:
  /// **'Native card in Recent activity (AD-4)'**
  String get diagPlaceNativeHistory;

  /// No description provided for @diagPlaceNativeDetails.
  ///
  /// In en, this message translates to:
  /// **'Native card on Operation details (AD-6)'**
  String get diagPlaceNativeDetails;

  /// No description provided for @diagPlaceBannerSettings.
  ///
  /// In en, this message translates to:
  /// **'Bottom banner on Settings (AD-5)'**
  String get diagPlaceBannerSettings;

  /// No description provided for @diagPlaceBannerMain.
  ///
  /// In en, this message translates to:
  /// **'Bottom banner: Home, Search, Result, Recent activity, Operation details'**
  String get diagPlaceBannerMain;

  /// No description provided for @diagPlaceBannerTools.
  ///
  /// In en, this message translates to:
  /// **'Bottom banner: tool screens and Manage files'**
  String get diagPlaceBannerTools;

  /// No description provided for @diagPlaceBannerInfo.
  ///
  /// In en, this message translates to:
  /// **'Bottom banner: Privacy & About, Licences'**
  String get diagPlaceBannerInfo;

  /// No description provided for @diagPlaceInterstitial.
  ///
  /// In en, this message translates to:
  /// **'Full-screen ad after Done (AD-3)'**
  String get diagPlaceInterstitial;

  /// No description provided for @diagPlaceRewarded.
  ///
  /// In en, this message translates to:
  /// **'Rewarded ad-free pass (AD-8)'**
  String get diagPlaceRewarded;

  /// No description provided for @toolScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Document'**
  String get toolScanTitle;

  /// No description provided for @toolScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn paper into a PDF'**
  String get toolScanSubtitle;

  /// No description provided for @homeSectionScan.
  ///
  /// In en, this message translates to:
  /// **'Scan & text'**
  String get homeSectionScan;

  /// No description provided for @qaScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get qaScan;

  /// No description provided for @scnEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan pages with your camera'**
  String get scnEntryTitle;

  /// No description provided for @scnEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Edges are found and straightened for you.'**
  String get scnEntryBody;

  /// No description provided for @scnStart.
  ///
  /// In en, this message translates to:
  /// **'Start scanning'**
  String get scnStart;

  /// No description provided for @scnHavePhotos.
  ///
  /// In en, this message translates to:
  /// **'Have photos already?'**
  String get scnHavePhotos;

  /// No description provided for @scnChoosePhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose photos instead'**
  String get scnChoosePhotos;

  /// No description provided for @scnPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting the scanner ready…'**
  String get scnPreparing;

  /// No description provided for @scnErrModuleOffline.
  ///
  /// In en, this message translates to:
  /// **'The scanner needs a one-time download. Connect to the internet and try again.'**
  String get scnErrModuleOffline;

  /// No description provided for @scnErrUnavailableAndroid.
  ///
  /// In en, this message translates to:
  /// **'Scanning needs Google Play services, which isn\'t on this phone.'**
  String get scnErrUnavailableAndroid;

  /// No description provided for @scnErrUnavailableIos.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t scan documents.'**
  String get scnErrUnavailableIos;

  /// No description provided for @scnErrCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'DocuKit can\'t use the camera. Allow it in Settings.'**
  String get scnErrCameraDenied;

  /// No description provided for @scnErrUnknown.
  ///
  /// In en, this message translates to:
  /// **'The scanner closed unexpectedly. Try again.'**
  String get scnErrUnknown;

  /// No description provided for @scnPages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String scnPages(int count);

  /// No description provided for @scnAddPages.
  ///
  /// In en, this message translates to:
  /// **'Add pages'**
  String get scnAddPages;

  /// No description provided for @scnRescanPage.
  ///
  /// In en, this message translates to:
  /// **'Rescan this page'**
  String get scnRescanPage;

  /// No description provided for @scnTruncated.
  ///
  /// In en, this message translates to:
  /// **'Only the first {max} pages were kept.'**
  String scnTruncated(int max);

  /// No description provided for @scnLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached {max} pages. Save this scan to start a new one.'**
  String scnLimitReached(int max);

  /// No description provided for @scnSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get scnSaveAs;

  /// No description provided for @scnFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get scnFormatPdf;

  /// No description provided for @scnFormatJpg.
  ///
  /// In en, this message translates to:
  /// **'JPG images'**
  String get scnFormatJpg;

  /// No description provided for @scnPageFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to scan'**
  String get scnPageFit;

  /// No description provided for @scnQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get scnQualityHigh;

  /// No description provided for @scnQualityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get scnQualityCompact;

  /// No description provided for @scnRunPdf.
  ///
  /// In en, this message translates to:
  /// **'Save scan ({count, plural, =1{1 page} other{{count} pages}})'**
  String scnRunPdf(int count);

  /// No description provided for @scnRunJpg.
  ///
  /// In en, this message translates to:
  /// **'Save {count, plural, =1{1 image} other{{count} images}}'**
  String scnRunJpg(int count);

  /// No description provided for @scnDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this scan?'**
  String get scnDiscardTitle;

  /// No description provided for @scnDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The scanned pages will be deleted.'**
  String get scnDiscardBody;

  /// No description provided for @scnDeleteLastTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this scan?'**
  String get scnDeleteLastTitle;

  /// No description provided for @stepSavingScan.
  ///
  /// In en, this message translates to:
  /// **'Saving your scan…'**
  String get stepSavingScan;

  /// No description provided for @tourScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Document'**
  String get tourScanTitle;

  /// No description provided for @tourScanBody.
  ///
  /// In en, this message translates to:
  /// **'Scan paper with your camera. Edges are found and straightened automatically.'**
  String get tourScanBody;

  /// No description provided for @tourScanExample.
  ///
  /// In en, this message translates to:
  /// **'Notes, receipts or a signed form in one PDF.'**
  String get tourScanExample;

  /// No description provided for @privAccessCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera, only while you\'re scanning'**
  String get privAccessCamera;

  /// No description provided for @scnRotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get scnRotateLeft;

  /// No description provided for @scnRotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get scnRotateRight;

  /// No description provided for @scnPageMenu.
  ///
  /// In en, this message translates to:
  /// **'Page options'**
  String get scnPageMenu;

  /// No description provided for @ocrLangLatin.
  ///
  /// In en, this message translates to:
  /// **'Latin (English, Spanish, French…)'**
  String get ocrLangLatin;

  /// No description provided for @ocrLangDevanagari.
  ///
  /// In en, this message translates to:
  /// **'Devanagari (Hindi, Marathi…)'**
  String get ocrLangDevanagari;

  /// No description provided for @ocrLangChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get ocrLangChinese;

  /// No description provided for @ocrLangJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get ocrLangJapanese;

  /// No description provided for @ocrLangKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get ocrLangKorean;

  /// No description provided for @errOcrModelUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Text recognition isn\'t ready'**
  String get errOcrModelUnavailableTitle;

  /// No description provided for @errOcrModelUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The {language} model couldn\'t be downloaded. Connect to the internet once and try again, or choose Latin.'**
  String errOcrModelUnavailableBody(String language);

  /// No description provided for @ocrCheckingText.
  ///
  /// In en, this message translates to:
  /// **'Checking for text…'**
  String get ocrCheckingText;

  /// No description provided for @ocrBadgeNoText.
  ///
  /// In en, this message translates to:
  /// **'No text yet'**
  String get ocrBadgeNoText;

  /// No description provided for @ocrBadgeHasText.
  ///
  /// In en, this message translates to:
  /// **'Already has text'**
  String get ocrBadgeHasText;

  /// No description provided for @toolOcrTitle.
  ///
  /// In en, this message translates to:
  /// **'Text Recognition'**
  String get toolOcrTitle;

  /// No description provided for @toolOcrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find text in photos and scans'**
  String get toolOcrSubtitle;

  /// No description provided for @tourOcrTitle.
  ///
  /// In en, this message translates to:
  /// **'Text Recognition'**
  String get tourOcrTitle;

  /// No description provided for @tourOcrBody.
  ///
  /// In en, this message translates to:
  /// **'Find the text in photos and scans. Copy it, or make a PDF you can search.'**
  String get tourOcrBody;

  /// No description provided for @tourOcrExample.
  ///
  /// In en, this message translates to:
  /// **'Turn a photo of notes into text you can paste.'**
  String get tourOcrExample;

  /// No description provided for @ocrBadgePartial.
  ///
  /// In en, this message translates to:
  /// **'Text on {n} of {total} pages'**
  String ocrBadgePartial(int n, int total);

  /// No description provided for @ocrPickImages.
  ///
  /// In en, this message translates to:
  /// **'Choose images'**
  String get ocrPickImages;

  /// No description provided for @ocrPickPdf.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF'**
  String get ocrPickPdf;

  /// No description provided for @ocrPickHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 50 images or one PDF'**
  String get ocrPickHint;

  /// No description provided for @ocrMixRefused.
  ///
  /// In en, this message translates to:
  /// **'Choose images or one PDF, not both.'**
  String get ocrMixRefused;

  /// No description provided for @ocrPdfHasText.
  ///
  /// In en, this message translates to:
  /// **'This PDF already has text you can search and copy.'**
  String get ocrPdfHasText;

  /// No description provided for @ocrPdfPartial.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total} pages already have text. Only the other pages will be recognised.'**
  String ocrPdfPartial(int n, int total);

  /// No description provided for @ocrPdfRebuildNote.
  ///
  /// In en, this message translates to:
  /// **'Recognised pages are rebuilt from images. Links and form fields on those pages won\'t work.'**
  String get ocrPdfRebuildNote;

  /// No description provided for @ocrResultsHeader.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get ocrResultsHeader;

  /// No description provided for @ocrOutPdf.
  ///
  /// In en, this message translates to:
  /// **'Searchable PDF'**
  String get ocrOutPdf;

  /// No description provided for @ocrOutReview.
  ///
  /// In en, this message translates to:
  /// **'Review and copy text'**
  String get ocrOutReview;

  /// No description provided for @ocrOutTxt.
  ///
  /// In en, this message translates to:
  /// **'Save as .txt'**
  String get ocrOutTxt;

  /// No description provided for @ocrOutPdfDisabled.
  ///
  /// In en, this message translates to:
  /// **'Already searchable'**
  String get ocrOutPdfDisabled;

  /// No description provided for @ocrNeedOutput.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one result'**
  String get ocrNeedOutput;

  /// No description provided for @ocrLanguage.
  ///
  /// In en, this message translates to:
  /// **'Text language'**
  String get ocrLanguage;

  /// No description provided for @ocrLongJob.
  ///
  /// In en, this message translates to:
  /// **'This may take a few minutes. Keep DocuKit open.'**
  String get ocrLongJob;

  /// No description provided for @ocrRun.
  ///
  /// In en, this message translates to:
  /// **'Recognise text ({count, plural, =1{1 page} other{{count} pages}})'**
  String ocrRun(int count);

  /// No description provided for @ocrRunGetText.
  ///
  /// In en, this message translates to:
  /// **'Get text'**
  String get ocrRunGetText;

  /// No description provided for @stepOcrPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting text recognition ready…'**
  String get stepOcrPreparing;

  /// No description provided for @stepOcrPage.
  ///
  /// In en, this message translates to:
  /// **'Recognising page {n} of {total}'**
  String stepOcrPage(int n, int total);

  /// No description provided for @stepOcrBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building searchable PDF…'**
  String get stepOcrBuilding;

  /// No description provided for @ocrResultStats.
  ///
  /// In en, this message translates to:
  /// **'{pages, plural, =1{1 page} other{{pages} pages}} · {words, plural, =1{1 word} other{{words} words}} found'**
  String ocrResultStats(int pages, int words);

  /// No description provided for @ocrResultLowPages.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 page with little text} other{{n} pages with little text}}'**
  String ocrResultLowPages(int n);

  /// No description provided for @ocrLowTextPage.
  ///
  /// In en, this message translates to:
  /// **'Little or no text found on page {n}.'**
  String ocrLowTextPage(int n);

  /// No description provided for @ocrLowTextAll.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find much text. Try a sharper photo, or check the language.'**
  String get ocrLowTextAll;

  /// No description provided for @ocrReview.
  ///
  /// In en, this message translates to:
  /// **'Review text'**
  String get ocrReview;

  /// No description provided for @ocrCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get ocrCopyText;

  /// No description provided for @ocrCopyPage.
  ///
  /// In en, this message translates to:
  /// **'Copy page'**
  String get ocrCopyPage;

  /// No description provided for @ocrCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get ocrCopyAll;

  /// No description provided for @ocrCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get ocrCopied;

  /// No description provided for @ocrShareText.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get ocrShareText;

  /// No description provided for @ocrSaveTxt.
  ///
  /// In en, this message translates to:
  /// **'Save .txt'**
  String get ocrSaveTxt;

  /// No description provided for @ocrSharedAsFile.
  ///
  /// In en, this message translates to:
  /// **'Shared as a text file because it\'s long.'**
  String get ocrSharedAsFile;

  /// No description provided for @ocrEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get ocrEdited;

  /// No description provided for @ocrTooLongToEdit.
  ///
  /// In en, this message translates to:
  /// **'Text is too long to edit here. You can still copy or save it.'**
  String get ocrTooLongToEdit;

  /// No description provided for @ocrDiscardEdits.
  ///
  /// In en, this message translates to:
  /// **'Discard your text changes?'**
  String get ocrDiscardEdits;

  /// No description provided for @ocrDiscardEditsBody.
  ///
  /// In en, this message translates to:
  /// **'The edits you made here will be lost. Your files aren\'t changed.'**
  String get ocrDiscardEditsBody;

  /// No description provided for @ocrTextOnlyHistory.
  ///
  /// In en, this message translates to:
  /// **'Text only, not saved'**
  String get ocrTextOnlyHistory;

  /// No description provided for @ocrPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get ocrPrevPage;

  /// No description provided for @ocrNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get ocrNextPage;

  /// No description provided for @ocrViewPage.
  ///
  /// In en, this message translates to:
  /// **'View page {n}'**
  String ocrViewPage(int n);

  /// No description provided for @scanMakeSearchable.
  ///
  /// In en, this message translates to:
  /// **'Make searchable (recognise text)'**
  String get scanMakeSearchable;

  /// No description provided for @setOcrLanguage.
  ///
  /// In en, this message translates to:
  /// **'Text recognition language'**
  String get setOcrLanguage;

  /// No description provided for @privOcrH.
  ///
  /// In en, this message translates to:
  /// **'Text recognition stays on your phone'**
  String get privOcrH;

  /// No description provided for @privOcrP.
  ///
  /// In en, this message translates to:
  /// **'Text recognition runs on your phone. DocuKit doesn\'t upload your files or the text found in them.'**
  String get privOcrP;

  /// No description provided for @toolPdfSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign PDF'**
  String get toolPdfSignTitle;

  /// No description provided for @toolPdfSignSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your signature to pages'**
  String get toolPdfSignSubtitle;

  /// No description provided for @toolPdfWatermarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark PDF'**
  String get toolPdfWatermarkTitle;

  /// No description provided for @toolPdfWatermarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stamp text or a logo on pages'**
  String get toolPdfWatermarkSubtitle;

  /// No description provided for @toolPdfProtectTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect PDF'**
  String get toolPdfProtectTitle;

  /// No description provided for @toolPdfProtectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a password'**
  String get toolPdfProtectSubtitle;

  /// No description provided for @toolPdfUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock PDF'**
  String get toolPdfUnlockTitle;

  /// No description provided for @toolPdfUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove a password you know'**
  String get toolPdfUnlockSubtitle;

  /// No description provided for @homeSectionSecure.
  ///
  /// In en, this message translates to:
  /// **'Secure & Sign'**
  String get homeSectionSecure;

  /// No description provided for @tourSecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure & Sign'**
  String get tourSecureTitle;

  /// No description provided for @tourSecureBody.
  ///
  /// In en, this message translates to:
  /// **'Sign, watermark, or add and remove passwords — all on your phone.'**
  String get tourSecureBody;

  /// No description provided for @tourPdfSignExample.
  ///
  /// In en, this message translates to:
  /// **'Sign a rental agreement without printing it.'**
  String get tourPdfSignExample;

  /// No description provided for @tourPdfWatermarkExample.
  ///
  /// In en, this message translates to:
  /// **'Mark a document \"Draft\" or \"Confidential\".'**
  String get tourPdfWatermarkExample;

  /// No description provided for @tourPdfProtectExample.
  ///
  /// In en, this message translates to:
  /// **'Lock a bank statement before emailing it.'**
  String get tourPdfProtectExample;

  /// No description provided for @tourPdfUnlockExample.
  ///
  /// In en, this message translates to:
  /// **'Remove a password you know from a statement.'**
  String get tourPdfUnlockExample;

  /// No description provided for @sigPlaceCta.
  ///
  /// In en, this message translates to:
  /// **'Place signature on pages'**
  String get sigPlaceCta;

  /// No description provided for @wmkRun.
  ///
  /// In en, this message translates to:
  /// **'Add watermark'**
  String get wmkRun;

  /// No description provided for @prtRun.
  ///
  /// In en, this message translates to:
  /// **'Protect PDF'**
  String get prtRun;

  /// No description provided for @unlRun.
  ///
  /// In en, this message translates to:
  /// **'Unlock PDF'**
  String get unlRun;

  /// No description provided for @prtPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get prtPassword;

  /// No description provided for @prtConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get prtConfirm;

  /// No description provided for @prtShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get prtShow;

  /// No description provided for @prtHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get prtHide;

  /// No description provided for @prtStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get prtStrength;

  /// No description provided for @prtStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get prtStrengthWeak;

  /// No description provided for @prtStrengthOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get prtStrengthOk;

  /// No description provided for @prtStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get prtStrengthStrong;

  /// No description provided for @prtErrShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters'**
  String get prtErrShort;

  /// No description provided for @prtErrLong.
  ///
  /// In en, this message translates to:
  /// **'Use 64 characters or fewer'**
  String get prtErrLong;

  /// No description provided for @prtErrBytes.
  ///
  /// In en, this message translates to:
  /// **'This password is too long. Use fewer characters.'**
  String get prtErrBytes;

  /// No description provided for @prtErrMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get prtErrMismatch;

  /// No description provided for @prtNoRecover.
  ///
  /// In en, this message translates to:
  /// **'If you forget this password, nobody can open the file — DocuKit can\'t recover it.'**
  String get prtNoRecover;

  /// No description provided for @prtWeakTitle.
  ///
  /// In en, this message translates to:
  /// **'This password is easy to guess'**
  String get prtWeakTitle;

  /// No description provided for @prtWeakBody.
  ///
  /// In en, this message translates to:
  /// **'Use it anyway?'**
  String get prtWeakBody;

  /// No description provided for @prtWeakChange.
  ///
  /// In en, this message translates to:
  /// **'Change it'**
  String get prtWeakChange;

  /// No description provided for @prtWeakUse.
  ///
  /// In en, this message translates to:
  /// **'Use anyway'**
  String get prtWeakUse;

  /// No description provided for @prtAlready.
  ///
  /// In en, this message translates to:
  /// **'This PDF already has a password.'**
  String get prtAlready;

  /// No description provided for @encUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock PDF'**
  String get encUnlockAction;

  /// No description provided for @stepEncrypting.
  ///
  /// In en, this message translates to:
  /// **'Adding password…'**
  String get stepEncrypting;

  /// No description provided for @resultProtectedNote.
  ///
  /// In en, this message translates to:
  /// **'Keep the password somewhere safe.'**
  String get resultProtectedNote;

  /// No description provided for @resultLockedPreviewA11y.
  ///
  /// In en, this message translates to:
  /// **'Password-protected PDF. The preview needs the password.'**
  String get resultLockedPreviewA11y;

  /// No description provided for @unlPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get unlPassword;

  /// No description provided for @unlWrong.
  ///
  /// In en, this message translates to:
  /// **'That password didn\'t work. Check it and try again.'**
  String get unlWrong;

  /// No description provided for @unlNeedPw.
  ///
  /// In en, this message translates to:
  /// **'You need the file\'s password. DocuKit can\'t unlock files without it.'**
  String get unlNeedPw;

  /// No description provided for @unlNotEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This PDF doesn\'t have a password.'**
  String get unlNotEncrypted;

  /// No description provided for @unlOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'This PDF opens without a password. It has restrictions set by its creator, which DocuKit keeps.'**
  String get unlOwnerOnly;

  /// No description provided for @encUnlockFirst.
  ///
  /// In en, this message translates to:
  /// **'This PDF is password-protected. Unlock it first.'**
  String get encUnlockFirst;

  /// No description provided for @stepCheckingPassword.
  ///
  /// In en, this message translates to:
  /// **'Checking password…'**
  String get stepCheckingPassword;

  /// No description provided for @stepUnlocking.
  ///
  /// In en, this message translates to:
  /// **'Removing password…'**
  String get stepUnlocking;

  /// No description provided for @sigYourSignature.
  ///
  /// In en, this message translates to:
  /// **'Your signature'**
  String get sigYourSignature;

  /// No description provided for @sigDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get sigDraw;

  /// No description provided for @sigType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sigType;

  /// No description provided for @sigPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get sigPhoto;

  /// No description provided for @sigNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get sigNew;

  /// No description provided for @sigNotCertified.
  ///
  /// In en, this message translates to:
  /// **'This adds an image of your signature. It isn\'t a certified digital signature.'**
  String get sigNotCertified;

  /// No description provided for @sigPadTitleDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw signature'**
  String get sigPadTitleDraw;

  /// No description provided for @sigPadTitleType.
  ///
  /// In en, this message translates to:
  /// **'Type signature'**
  String get sigPadTitleType;

  /// No description provided for @sigPadTitlePhoto.
  ///
  /// In en, this message translates to:
  /// **'Signature from photo'**
  String get sigPadTitlePhoto;

  /// No description provided for @sigPadHint.
  ///
  /// In en, this message translates to:
  /// **'Sign with your finger'**
  String get sigPadHint;

  /// No description provided for @sigPadLandscape.
  ///
  /// In en, this message translates to:
  /// **'Turn your phone for more room'**
  String get sigPadLandscape;

  /// No description provided for @sigPadA11y.
  ///
  /// In en, this message translates to:
  /// **'Signature pad. Draw with one finger. You can also type your signature instead.'**
  String get sigPadA11y;

  /// No description provided for @sigUndoStroke.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sigUndoStroke;

  /// No description provided for @sigClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get sigClear;

  /// No description provided for @sigColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get sigColour;

  /// No description provided for @sigThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get sigThickness;

  /// No description provided for @sigBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get sigBlack;

  /// No description provided for @sigBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get sigBlue;

  /// No description provided for @sigThin.
  ///
  /// In en, this message translates to:
  /// **'Thin'**
  String get sigThin;

  /// No description provided for @sigMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sigMedium;

  /// No description provided for @sigThick.
  ///
  /// In en, this message translates to:
  /// **'Thick'**
  String get sigThick;

  /// No description provided for @sigYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get sigYourName;

  /// No description provided for @sigStyle.
  ///
  /// In en, this message translates to:
  /// **'Style {n}'**
  String sigStyle(int n);

  /// No description provided for @sigBgCleanup.
  ///
  /// In en, this message translates to:
  /// **'Background cleanup'**
  String get sigBgCleanup;

  /// No description provided for @sigPhotoNone.
  ///
  /// In en, this message translates to:
  /// **'No ink found. Try moving Background cleanup.'**
  String get sigPhotoNone;

  /// No description provided for @sigSaveAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Save this signature for next time?'**
  String get sigSaveAskTitle;

  /// No description provided for @sigSaveAskBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s kept only on this phone and isn\'t included in backups.'**
  String get sigSaveAskBody;

  /// No description provided for @sigSaveYes.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sigSaveYes;

  /// No description provided for @sigSaveNo.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get sigSaveNo;

  /// No description provided for @sigSavedLimit.
  ///
  /// In en, this message translates to:
  /// **'You can keep up to 3 signatures. Delete one to save this.'**
  String get sigSavedLimit;

  /// No description provided for @sigDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this saved signature?'**
  String get sigDeleteTitle;

  /// No description provided for @sigDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this signature?'**
  String get sigDiscardTitle;

  /// No description provided for @setSavedSignatures.
  ///
  /// In en, this message translates to:
  /// **'Saved signatures'**
  String get setSavedSignatures;

  /// No description provided for @setSavedNone.
  ///
  /// In en, this message translates to:
  /// **'No saved signatures.'**
  String get setSavedNone;

  /// No description provided for @setDeleteAllSignatures.
  ///
  /// In en, this message translates to:
  /// **'Delete all saved signatures'**
  String get setDeleteAllSignatures;

  /// No description provided for @setDeleteAllSignaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all saved signatures?'**
  String get setDeleteAllSignaturesTitle;

  /// No description provided for @sigDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sigDelete;

  /// No description provided for @sigPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Place signature'**
  String get sigPlaceTitle;

  /// No description provided for @sigAddSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get sigAddSignature;

  /// No description provided for @sigAddDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get sigAddDate;

  /// No description provided for @sigAddText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get sigAddText;

  /// No description provided for @sigAddInitials.
  ///
  /// In en, this message translates to:
  /// **'Initials'**
  String get sigAddInitials;

  /// No description provided for @sigPagesSheet.
  ///
  /// In en, this message translates to:
  /// **'Add this to'**
  String get sigPagesSheet;

  /// No description provided for @sigPagesAll.
  ///
  /// In en, this message translates to:
  /// **'All pages'**
  String get sigPagesAll;

  /// No description provided for @sigPagesRange.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get sigPagesRange;

  /// No description provided for @sigPagesThis.
  ///
  /// In en, this message translates to:
  /// **'Only this page'**
  String get sigPagesThis;

  /// No description provided for @sigPagesButton.
  ///
  /// In en, this message translates to:
  /// **'Pages…'**
  String get sigPagesButton;

  /// No description provided for @sigNeedOne.
  ///
  /// In en, this message translates to:
  /// **'Add your signature to at least one page.'**
  String get sigNeedOne;

  /// No description provided for @sigMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get sigMoveTo;

  /// No description provided for @sigBigger.
  ///
  /// In en, this message translates to:
  /// **'Bigger'**
  String get sigBigger;

  /// No description provided for @sigSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get sigSmaller;

  /// No description provided for @sigRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90°'**
  String get sigRotate;

  /// No description provided for @sigRun.
  ///
  /// In en, this message translates to:
  /// **'Save signed PDF'**
  String get sigRun;

  /// No description provided for @sigPageN.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String sigPageN(int n);

  /// No description provided for @sigResizeHandle.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get sigResizeHandle;

  /// No description provided for @sigRotateHandle.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get sigRotateHandle;

  /// No description provided for @sigMore.
  ///
  /// In en, this message translates to:
  /// **'More options for this item'**
  String get sigMore;

  /// No description provided for @sigSavedTile.
  ///
  /// In en, this message translates to:
  /// **'Saved signature {n}'**
  String sigSavedTile(int n);

  /// No description provided for @sigNewTile.
  ///
  /// In en, this message translates to:
  /// **'New signature'**
  String get sigNewTile;

  /// No description provided for @wmkPosCentre.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get wmkPosCentre;

  /// No description provided for @wmkPosTl.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get wmkPosTl;

  /// No description provided for @wmkPosTr.
  ///
  /// In en, this message translates to:
  /// **'Top right'**
  String get wmkPosTr;

  /// No description provided for @wmkPosBl.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get wmkPosBl;

  /// No description provided for @wmkPosBr.
  ///
  /// In en, this message translates to:
  /// **'Bottom right'**
  String get wmkPosBr;

  /// No description provided for @wmkRangeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1-3, 5'**
  String get wmkRangeHint;

  /// No description provided for @wmkText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get wmkText;

  /// No description provided for @wmkImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get wmkImage;

  /// No description provided for @wmkTextHint.
  ///
  /// In en, this message translates to:
  /// **'Watermark text'**
  String get wmkTextHint;

  /// No description provided for @wmkNeedText.
  ///
  /// In en, this message translates to:
  /// **'Enter watermark text'**
  String get wmkNeedText;

  /// No description provided for @wmkPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get wmkPosition;

  /// No description provided for @wmkPosDiagonal.
  ///
  /// In en, this message translates to:
  /// **'Centre diagonal'**
  String get wmkPosDiagonal;

  /// No description provided for @wmkPosTile.
  ///
  /// In en, this message translates to:
  /// **'Tile'**
  String get wmkPosTile;

  /// No description provided for @wmkSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get wmkSize;

  /// No description provided for @wmkOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get wmkOpacity;

  /// No description provided for @wmkRotation.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get wmkRotation;

  /// No description provided for @wmkPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get wmkPages;

  /// No description provided for @wmkPagesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get wmkPagesAll;

  /// No description provided for @wmkPagesRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get wmkPagesRange;

  /// No description provided for @wmkPagesOdd.
  ///
  /// In en, this message translates to:
  /// **'Odd'**
  String get wmkPagesOdd;

  /// No description provided for @wmkPagesEven.
  ///
  /// In en, this message translates to:
  /// **'Even'**
  String get wmkPagesEven;

  /// No description provided for @wmkRangeError.
  ///
  /// In en, this message translates to:
  /// **'Use page numbers like 1-3, 5'**
  String get wmkRangeError;

  /// No description provided for @wmkOnTop.
  ///
  /// In en, this message translates to:
  /// **'The watermark is added on top of the page.'**
  String get wmkOnTop;

  /// No description provided for @wmkNotSearchable.
  ///
  /// In en, this message translates to:
  /// **'Text watermarks are added as an image, so they can\'t be selected or searched.'**
  String get wmkNotSearchable;

  /// No description provided for @wmkBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get wmkBold;

  /// No description provided for @wmkCustomColour.
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get wmkCustomColour;

  /// No description provided for @wmkChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get wmkChooseImage;

  /// No description provided for @wmkColourRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get wmkColourRed;

  /// No description provided for @wmkColourBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get wmkColourBlack;

  /// No description provided for @wmkColourGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get wmkColourGrey;

  /// No description provided for @wmkColourBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get wmkColourBlue;

  /// No description provided for @wmkColourGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get wmkColourGreen;

  /// No description provided for @wmkColourOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get wmkColourOrange;

  /// No description provided for @wmkPreviewA11y.
  ///
  /// In en, this message translates to:
  /// **'Preview of page {n}'**
  String wmkPreviewA11y(int n);

  /// No description provided for @privPwSigH.
  ///
  /// In en, this message translates to:
  /// **'Passwords and signatures'**
  String get privPwSigH;

  /// No description provided for @privPwSigP.
  ///
  /// In en, this message translates to:
  /// **'Passwords you enter are used once and never saved. Saved signatures stay only on this phone and aren\'t included in backups.'**
  String get privPwSigP;

  /// No description provided for @libTitle.
  ///
  /// In en, this message translates to:
  /// **'My Documents'**
  String get libTitle;

  /// No description provided for @libIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep important documents here'**
  String get libIntroTitle;

  /// No description provided for @libIntroB1.
  ///
  /// In en, this message translates to:
  /// **'Stored only on this phone'**
  String get libIntroB1;

  /// No description provided for @libIntroB2.
  ///
  /// In en, this message translates to:
  /// **'Not included in cloud backups. You can export a backup anytime.'**
  String get libIntroB2;

  /// No description provided for @libIntroB3.
  ///
  /// In en, this message translates to:
  /// **'Deleted if you uninstall DocuKit'**
  String get libIntroB3;

  /// No description provided for @libIntroCta.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get libIntroCta;

  /// No description provided for @libIntroBackupLink.
  ///
  /// In en, this message translates to:
  /// **'Learn about backups'**
  String get libIntroBackupLink;

  /// No description provided for @libEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get libEmptyTitle;

  /// No description provided for @libEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tip: tap \"Save to My Documents\" on any result.'**
  String get libEmptyBody;

  /// No description provided for @libNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get libNewFolder;

  /// No description provided for @libFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libFilterAll;

  /// No description provided for @libFilterStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get libFilterStarred;

  /// No description provided for @libSectionFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libSectionFolders;

  /// No description provided for @libSectionDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get libSectionDocuments;

  /// No description provided for @libMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move {count, plural, =1{1 item} other{{count} items}} to…'**
  String libMoveTitle(int count);

  /// No description provided for @libMoveHere.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get libMoveHere;

  /// No description provided for @libSaveHere.
  ///
  /// In en, this message translates to:
  /// **'Save here'**
  String get libSaveHere;

  /// No description provided for @libRoot.
  ///
  /// In en, this message translates to:
  /// **'My Documents'**
  String get libRoot;

  /// No description provided for @libFolderDepth.
  ///
  /// In en, this message translates to:
  /// **'Folders can be 3 levels deep'**
  String get libFolderDepth;

  /// No description provided for @libFolderNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A folder with this name already exists here'**
  String get libFolderNameTaken;

  /// No description provided for @libFolderNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 1 to 60 characters'**
  String get libFolderNameInvalid;

  /// No description provided for @libNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A document with this name is already in this folder'**
  String get libNameTaken;

  /// No description provided for @libFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get libFolderName;

  /// No description provided for @libDeleteDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String libDeleteDocTitle(String name);

  /// No description provided for @libDeleteDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count, plural, =1{1 document} other{{count} documents}}?'**
  String libDeleteDocsTitle(int count);

  /// No description provided for @libDeleteDocBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get libDeleteDocBody;

  /// No description provided for @libDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete folder \"{name}\"?'**
  String libDeleteFolderTitle(String name);

  /// No description provided for @libDeleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'It contains {docs, plural, =1{1 document} other{{docs} documents}} and {folders, plural, =1{1 folder} other{{folders} folders}}.'**
  String libDeleteFolderBody(int docs, int folders);

  /// No description provided for @libDeleteFolderMove.
  ///
  /// In en, this message translates to:
  /// **'Move contents up'**
  String get libDeleteFolderMove;

  /// No description provided for @libDeleteFolderAll.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get libDeleteFolderAll;

  /// No description provided for @libGone.
  ///
  /// In en, this message translates to:
  /// **'That document is no longer in My Documents.'**
  String get libGone;

  /// No description provided for @libDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String libDeletedSnack(String name);

  /// No description provided for @libSortName.
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get libSortName;

  /// No description provided for @libSortAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added (newest)'**
  String get libSortAdded;

  /// No description provided for @libSortSize.
  ///
  /// In en, this message translates to:
  /// **'Size (largest)'**
  String get libSortSize;

  /// No description provided for @libSortExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry (soonest)'**
  String get libSortExpiry;

  /// No description provided for @libSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get libSort;

  /// No description provided for @libViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get libViewGrid;

  /// No description provided for @libViewList.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get libViewList;

  /// No description provided for @libSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get libSelect;

  /// No description provided for @libSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String libSelected(int count);

  /// No description provided for @libStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get libStar;

  /// No description provided for @libUnstar.
  ///
  /// In en, this message translates to:
  /// **'Remove star'**
  String get libUnstar;

  /// No description provided for @libMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get libMove;

  /// No description provided for @libDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get libDelete;

  /// No description provided for @libMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get libMore;

  /// No description provided for @libFolderDocs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 document} other{{count} documents}}'**
  String libFolderDocs(int count);

  /// No description provided for @libCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get libCreate;

  /// No description provided for @setLibBackupNote.
  ///
  /// In en, this message translates to:
  /// **'My Documents isn\'t included in iCloud or Google backups. Export a backup before changing or resetting your phone. Uninstalling DocuKit deletes these documents.'**
  String get setLibBackupNote;

  /// No description provided for @libFindFolder.
  ///
  /// In en, this message translates to:
  /// **'Find folder'**
  String get libFindFolder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
