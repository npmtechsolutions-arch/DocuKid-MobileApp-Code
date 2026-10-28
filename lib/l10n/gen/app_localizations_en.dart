// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'DocuKit';

  @override
  String get privacyPromise => 'Files never leave your phone';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDone => 'Done';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionReplace => 'Replace';

  @override
  String get actionDetails => 'Details';

  @override
  String get actionRename => 'Rename';

  @override
  String get actionSave => 'Save';

  @override
  String get actionShare => 'Share';

  @override
  String get actionOpenWith => 'Open with…';

  @override
  String get actionLeave => 'Leave';

  @override
  String get actionStay => 'Stay';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get actionKeepAnyway => 'Keep anyway';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionClose => 'Close';

  @override
  String get actionChange => 'Change';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionBack => 'Back';

  @override
  String get actionInfo => 'How it works';

  @override
  String get originalUnchanged => 'Your original file was not changed.';

  @override
  String get chooseAnother => 'Choose another file';

  @override
  String get backToTool => 'Back to tool';

  @override
  String get itemUnavailable => 'That item is no longer available.';

  @override
  String get homeGreeting => 'What do you want to do today?';

  @override
  String get homeSearchPlaceholder => 'Search tools — \"make photo smaller\"';

  @override
  String get homeSearchExample1 => 'Search tools, like \"join PDFs\"';

  @override
  String get homeSearchExample2 => 'Search tools, like \"make photo smaller\"';

  @override
  String get homeSearchExample3 => 'Search tools, like \"passport photo\"';

  @override
  String get homeSectionImage => 'Image tools';

  @override
  String get homeSectionPdf => 'PDF tools';

  @override
  String get homeSectionRecent => 'Recent';

  @override
  String get homeSeeAll => 'See all';

  @override
  String homeContinue(Object toolName) {
    return 'Continue: $toolName';
  }

  @override
  String get homeRecentEmpty => 'Your finished files will show up here.';

  @override
  String get homeJobRunning => 'Processing… Tap to view';

  @override
  String get homeHistoryTooltip => 'Recent activity';

  @override
  String get homeSettingsTooltip => 'Settings';

  @override
  String get homeNavHome => 'Home';

  @override
  String get homeOfflineBadge => 'Works offline';

  @override
  String get searchFieldHint => 'Search tools';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchHintEmpty =>
      'Try: compress, combine PDF, passport photo, rotate page';

  @override
  String get searchChipCompress => 'compress';

  @override
  String get searchChipCombine => 'combine PDF';

  @override
  String get searchChipPassport => 'passport photo';

  @override
  String get searchChipRotate => 'rotate page';

  @override
  String searchNoResults(Object query) {
    return 'No tool matches \"$query\".';
  }

  @override
  String searchMatches(Object phrase) {
    return 'Matches \"$phrase\"';
  }

  @override
  String get searchAllTools => 'All tools';

  @override
  String get onbTitle => 'Document tools that stay on your phone';

  @override
  String get onbB1 => 'Compress and resize photos';

  @override
  String get onbB2 => 'Make and edit PDFs';

  @override
  String get onbB3 => 'No account. No uploads.';

  @override
  String get onbCta => 'Get started';

  @override
  String get toolImageCompressTitle => 'Image Compressor';

  @override
  String get toolImageCompressSubtitle => 'Make photos smaller';

  @override
  String get toolImageResizeTitle => 'Image Resizer';

  @override
  String get toolImageResizeSubtitle => 'Set an exact size';

  @override
  String get toolImageToPdfTitle => 'Images to PDF';

  @override
  String get toolImageToPdfSubtitle => 'Turn photos into one PDF';

  @override
  String get toolPdfMergeTitle => 'Merge PDFs';

  @override
  String get toolPdfMergeSubtitle => 'Combine files into one';

  @override
  String get toolPdfOrganizeTitle => 'Organize Pages';

  @override
  String get toolPdfOrganizeSubtitle => 'Reorder, rotate or delete';

  @override
  String get toolPdfCompressTitle => 'Reduce PDF Size';

  @override
  String get toolPdfCompressSubtitle => 'Make a PDF smaller';

  @override
  String get toolImageConvertTitle => 'Convert Image';

  @override
  String get toolImageConvertSubtitle => 'Change the file format';

  @override
  String get toolPdfSplitTitle => 'Split PDF';

  @override
  String get toolPdfSplitSubtitle => 'Break a PDF into parts';

  @override
  String get toolPdfToImagesTitle => 'PDF to Images';

  @override
  String get toolPdfToImagesSubtitle => 'Save pages as pictures';

  @override
  String get infoImageCompress =>
      'DocuKit makes a smaller copy of your photo on this device. Lower quality means a smaller file. Target size tries several qualities until the copy fits. Your original is never changed.';

  @override
  String get infoImageResize =>
      'Set the exact width and height in pixels, scale by a percentage, or pick a preset such as a passport photo. If the shape changes, choose how the image should fit. Your original is never changed.';

  @override
  String get infoImageToPdf =>
      'Each image becomes one page, in the order shown. Images are oriented upright and sized to the page you choose. Everything happens on this device.';

  @override
  String get infoPdfMerge =>
      'Pages are copied exactly. Bookmarks and form fields may not be kept.';

  @override
  String get infoPdfOrganize =>
      'Reorder, rotate or delete pages, then save the result as a new PDF. Your original PDF is not changed.';

  @override
  String get infoPdfCompress =>
      'Basic cleans up the file without any quality loss. Balanced shrinks photos inside the PDF. Strong turns every page into an image. How much a PDF shrinks depends on what\'s inside it.';

  @override
  String get pickImages => 'Choose images';

  @override
  String get pickImage => 'Choose image';

  @override
  String get pickPdfs => 'Choose PDFs';

  @override
  String get pickPdf => 'Choose PDF';

  @override
  String get pickFormatsImages => 'JPG, PNG, WebP or HEIC · up to 100 MB';

  @override
  String get pickFormatsPdf => 'PDF · up to 500 MB';

  @override
  String get pickLoading => 'Reading files…';

  @override
  String inputsHeader(int count) {
    return 'Files ($count)';
  }

  @override
  String get inputsFileHeader => 'File';

  @override
  String get inputsAdd => 'Add';

  @override
  String get inputsManageAll => 'Manage all files';

  @override
  String inputsTruncated(int max) {
    return 'Only the first $max files were added.';
  }

  @override
  String get inputsAllInvalid =>
      'None of these files can be used. Choose different files.';

  @override
  String get largeFileHint => 'Large file — this may take a while.';

  @override
  String get inputsOptionsHeader => 'Options';

  @override
  String get badgeHasAlpha => 'Has transparency';

  @override
  String get badgeLocked => 'Password-protected';

  @override
  String get badgeDamaged => 'Looks damaged';

  @override
  String get badgeUnsupported => 'Not supported';

  @override
  String get badgeTooLarge => 'Too large';

  @override
  String get badgeUnreadable => 'Can\'t be read';

  @override
  String metaPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String metaDims(int w, int h) {
    return '$w × $h';
  }

  @override
  String get cmpSectionHow => 'How small?';

  @override
  String get cmpModeQuality => 'Quality';

  @override
  String get cmpModeTarget => 'Target size';

  @override
  String get cmpQualityLow => 'Smaller file';

  @override
  String get cmpQualityHigh => 'Sharper';

  @override
  String cmpQualityA11y(int value) {
    return 'Quality $value percent';
  }

  @override
  String get cmpTargetLabel => 'Keep under';

  @override
  String cmpTargetAlreadySmaller(Object size) {
    return 'This image is already under $size.';
  }

  @override
  String get cmpTargetMin => 'Enter at least 5 KB.';

  @override
  String get cmpUnitKb => 'KB';

  @override
  String get cmpUnitMb => 'MB';

  @override
  String get cmpMoreOptions => 'More options';

  @override
  String get cmpFormat => 'Output format';

  @override
  String get cmpFormatSame => 'Same as original';

  @override
  String get cmpMaxSize => 'Max size';

  @override
  String get cmpMaxOriginal => 'Original';

  @override
  String cmpMaxPx(int px) {
    return '$px px';
  }

  @override
  String get cmpStripMeta => 'Remove location and camera info';

  @override
  String get cmpPngWarning =>
      'PNG doesn\'t use quality. Choose JPEG or WebP for smaller files.';

  @override
  String get cmpSwitchJpeg => 'Switch to JPEG';

  @override
  String get warnAlphaLost => 'Transparent areas will become white.';

  @override
  String get cmpTargetUsesJpeg => 'Target size uses JPEG.';

  @override
  String get cmpRun => 'Compress image';

  @override
  String get cmpRunAnyway => 'Compress anyway';

  @override
  String get fmtJpeg => 'JPEG';

  @override
  String get fmtPng => 'PNG';

  @override
  String get fmtWebp => 'WebP';

  @override
  String get fmtHeic => 'HEIC';

  @override
  String get fmtPdf => 'PDF';

  @override
  String get resSectionSize => 'Size';

  @override
  String get resModePixels => 'Pixels';

  @override
  String get resModePercent => 'Percent';

  @override
  String get resModePreset => 'Preset';

  @override
  String get resWidth => 'Width';

  @override
  String get resHeight => 'Height';

  @override
  String get resUnitPx => 'px';

  @override
  String get resLockOn => 'Aspect ratio locked';

  @override
  String get resLockOff => 'Aspect ratio unlocked';

  @override
  String resOriginal(int w, int h) {
    return 'Original $w × $h';
  }

  @override
  String resResultLine(int w, int h) {
    return 'Result: $w × $h px';
  }

  @override
  String get resScale => 'Scale';

  @override
  String resPercentValue(int p) {
    return '$p%';
  }

  @override
  String get resShapeHeader => 'When the shape changes';

  @override
  String get resFitStretch => 'Stretch';

  @override
  String get resFitContain => 'Fit with border';

  @override
  String get resFitCover => 'Crop to fill';

  @override
  String get resPadColor => 'Border colour';

  @override
  String get resPadWhite => 'White';

  @override
  String get resPadBlack => 'Black';

  @override
  String get resPadTransparent => 'Transparent';

  @override
  String get resUpscaleWarning => 'Enlarging can make the image blurry.';

  @override
  String get resErrRange => 'Enter a number from 1 to 12000.';

  @override
  String get resErrMegapixels =>
      'That would be over 100 megapixels. Choose a smaller size.';

  @override
  String get resSavePreset => 'Save as preset';

  @override
  String get resMyPresets => 'My presets';

  @override
  String get resPresetNameHint => 'Preset name';

  @override
  String get resPresetLimit => 'You can save up to 10 presets.';

  @override
  String get resDeletePreset => 'Delete preset';

  @override
  String get resPresetPassport => 'Passport photo (35×45 mm)';

  @override
  String get resPresetSignature => 'Signature';

  @override
  String get resPresetSquare => 'Square post';

  @override
  String get resPresetStory => 'Story';

  @override
  String get resPresetHd => 'HD';

  @override
  String get resPresetFullhd => 'Full HD';

  @override
  String get resQuality => 'Quality';

  @override
  String get resRun => 'Resize image';

  @override
  String i2pHeader(int count) {
    return 'Images ($count)';
  }

  @override
  String get i2pEmptyHint => 'Up to 100 images. Pages follow this order.';

  @override
  String get i2pSectionPage => 'Page';

  @override
  String get i2pSectionQuality => 'Quality';

  @override
  String get i2pPageSize => 'Page size';

  @override
  String get i2pOrientation => 'Orientation';

  @override
  String get i2pFit => 'Image fit';

  @override
  String get i2pMargins => 'Margins';

  @override
  String get i2pQuality => 'Image quality';

  @override
  String get i2pSizeA4 => 'A4';

  @override
  String get i2pSizeLetter => 'Letter';

  @override
  String get i2pSizeLegal => 'Legal';

  @override
  String get i2pSizeImage => 'Same as image';

  @override
  String get i2pOrientAuto => 'Auto';

  @override
  String get i2pOrientPortrait => 'Portrait';

  @override
  String get i2pOrientLandscape => 'Landscape';

  @override
  String get i2pFitFit => 'Fit whole image';

  @override
  String get i2pFitFill => 'Fill page';

  @override
  String get i2pMarginNone => 'None';

  @override
  String get i2pMarginSmall => 'Small';

  @override
  String get i2pMarginLarge => 'Large';

  @override
  String get i2pQOriginal => 'Original';

  @override
  String get i2pQHigh => 'High';

  @override
  String get i2pQCompact => 'Compact';

  @override
  String get i2pPreview => 'Preview';

  @override
  String get i2pOutputName => 'Output name';

  @override
  String get i2pRotate => 'Rotate';

  @override
  String get i2pRemoveAndContinue => 'Remove and continue';

  @override
  String i2pImageA11y(int n, int total) {
    return 'Image $n of $total';
  }

  @override
  String i2pRun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return 'Create PDF ($_temp0)';
  }

  @override
  String get i2pRunEmpty => 'Create PDF';

  @override
  String mrgHeader(int count) {
    return 'PDFs ($count)';
  }

  @override
  String mrgTotal(int files, int pages) {
    return '$files PDFs · $pages pages total';
  }

  @override
  String get mrgDragHint =>
      'Drag to change the order. Files are merged top to bottom.';

  @override
  String get mrgNeedTwo => 'Add at least 2 PDFs';

  @override
  String mrgRemoveInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Remove $_temp0 that can\'t be merged';
  }

  @override
  String get mrgTooManyPages => 'Merged PDFs can have up to 2000 pages.';

  @override
  String get mrgSectionOutput => 'Output';

  @override
  String get mrgName => 'Name';

  @override
  String mrgRun(int count) {
    return 'Merge $count PDFs';
  }

  @override
  String get mrgInfoSheet =>
      'Pages are copied exactly. Bookmarks and form fields may not be kept.';

  @override
  String orgStatus(int pages, int selected) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pages',
      one: '1 page',
    );
    return '$_temp0 · $selected selected';
  }

  @override
  String get orgHint =>
      'Tap pages to select them. Long-press and drag to reorder. Double-tap to preview.';

  @override
  String get orgRotateLeft => 'Left';

  @override
  String get orgRotateRight => 'Right';

  @override
  String get orgDelete => 'Delete';

  @override
  String get orgMove => 'Move';

  @override
  String get orgMoveTo => 'Move selected pages to';

  @override
  String get orgMoveStart => 'Start';

  @override
  String get orgMoveEnd => 'End';

  @override
  String get orgMoveAfter => 'After page';

  @override
  String get orgMinOnePage => 'A PDF needs at least one page.';

  @override
  String get orgDeletedUndo => 'Page deleted';

  @override
  String orgPageMovedFrom(int pos, int orig) {
    return 'Page $pos, originally page $orig';
  }

  @override
  String orgA11yPage(int pos, int total) {
    return 'Page $pos of $total';
  }

  @override
  String orgA11yRotated(int deg) {
    return 'rotated $deg degrees';
  }

  @override
  String get orgA11ySelected => 'selected';

  @override
  String orgOrigPage(int n) {
    return 'p.$n';
  }

  @override
  String get orgCantPreview => 'Can\'t preview';

  @override
  String get orgUndo => 'Undo';

  @override
  String get orgRedo => 'Redo';

  @override
  String get orgMore => 'More';

  @override
  String get orgSelectAll => 'Select all';

  @override
  String get orgSelectNone => 'Select none';

  @override
  String get orgInvert => 'Invert selection';

  @override
  String get orgReset => 'Reset changes';

  @override
  String orgDeleteConfirmTitle(int count) {
    return 'Delete $count pages?';
  }

  @override
  String get orgDeleteConfirmBody => 'You can undo this before saving.';

  @override
  String get orgRun => 'Save as new PDF';

  @override
  String orgPreviewTitle(int pos, int total) {
    return 'Page $pos of $total';
  }

  @override
  String get redSectionLevel => 'Level';

  @override
  String redAnalysis(int pages, int images, String kind) {
    return '$pages pages · $images images · $kind';
  }

  @override
  String get redAnalysing => 'Analysing…';

  @override
  String get redKindImage => 'Image-heavy';

  @override
  String get redKindText => 'Mostly text';

  @override
  String get redBasicT => 'Basic';

  @override
  String get redBasicD =>
      'Clean up the file. No quality loss. Usually a small reduction.';

  @override
  String get redBalancedT => 'Balanced';

  @override
  String get redBalancedD =>
      'Shrinks photos inside the PDF. Text stays sharp and selectable.';

  @override
  String get redStrongT => 'Strong';

  @override
  String get redStrongD =>
      'Turns every page into an image. Smallest file. Text can\'t be selected or searched.';

  @override
  String get redRecommended => 'Recommended';

  @override
  String get redNote =>
      'How much a PDF shrinks depends on what\'s inside it. Text-only PDFs may not get smaller.';

  @override
  String get redBalancedWarning =>
      'Photos inside the PDF may look slightly softer.';

  @override
  String get strongConfirmTitle => 'Use Strong reduction?';

  @override
  String get strongConfirmBody =>
      'Text will no longer be selectable or searchable, and links will stop working. Your original stays as it is.';

  @override
  String get strongConfirmOk => 'Use Strong';

  @override
  String get redRun => 'Reduce size';

  @override
  String get stepPreparing => 'Getting ready…';

  @override
  String get stepReading => 'Reading files…';

  @override
  String get stepCompressing => 'Compressing image…';

  @override
  String get stepResizing => 'Resizing image…';

  @override
  String get stepBuildingPdf => 'Building PDF…';

  @override
  String get stepMerging => 'Merging PDFs…';

  @override
  String get stepSavingPages => 'Saving pages…';

  @override
  String get stepOptimizing => 'Reducing size…';

  @override
  String get stepChecking => 'Checking the result…';

  @override
  String progressPages(int done, int total) {
    return '$done of $total pages';
  }

  @override
  String progressImages(int done, int total) {
    return '$done of $total images';
  }

  @override
  String progressFiles(int done, int total) {
    return '$done of $total files';
  }

  @override
  String get keepOpen => 'Keep DocuKit open until this finishes.';

  @override
  String get cancelConfirmTitle => 'Cancel this job?';

  @override
  String get cancelConfirmBody => 'Nothing will be saved.';

  @override
  String get cancelConfirmKeep => 'Keep going';

  @override
  String get cancelConfirmYes => 'Cancel job';

  @override
  String get cancelledSnack => 'Cancelled. Nothing was saved.';

  @override
  String get busySnack => 'Finish or cancel the current job first.';

  @override
  String get jobCancelTooltip => 'Cancel job';

  @override
  String get jobOnDevice => 'Processing on this device';

  @override
  String get resultDone => 'Done';

  @override
  String get resultBefore => 'Before';

  @override
  String get resultAfter => 'After';

  @override
  String get resultChange => 'Change';

  @override
  String resultSmaller(int percent) {
    return '$percent% smaller';
  }

  @override
  String resultLarger(int percent) {
    return '$percent% larger';
  }

  @override
  String get resultNoChange => 'No change';

  @override
  String get resultNotSmallerImg =>
      'Couldn\'t make this image smaller. Try a lower quality or a smaller max size.';

  @override
  String get resultNotSmallerPdf =>
      'This PDF is already well optimised. The result is not smaller.';

  @override
  String resultTargetMissed(String actual, String target) {
    return 'Closest we could get: $actual (target $target). Try a smaller max size.';
  }

  @override
  String resultRetention(Object period) {
    return 'Kept in Recent for $period';
  }

  @override
  String get resultRetentionForever => 'Kept in Recent until you delete it';

  @override
  String get resultEditOptions => 'Edit options';

  @override
  String get resultKeepOriginal => 'Keep original';

  @override
  String get resultTryLower => 'Try lower quality';

  @override
  String get resultCompareHint => 'Drag to compare before and after';

  @override
  String get resultCompareA11y => 'Before and after comparison';

  @override
  String get resultOpen => 'Open';

  @override
  String resultA11ySummary(String before, String after) {
    return 'Done. $before to $after.';
  }

  @override
  String get resultPreviewA11y => 'Preview of the result';

  @override
  String get saveToPhotos => 'Save to Photos';

  @override
  String get saveToFiles => 'Save to Files…';

  @override
  String get saveSheetTitle => 'Save to';

  @override
  String get savedSnack => 'Saved';

  @override
  String savedSnackNamed(Object name) {
    return 'Saved as $name';
  }

  @override
  String get saveFailed => 'Couldn\'t save the file. Try another location.';

  @override
  String get photosDenied =>
      'DocuKit can\'t add to Photos. Allow it in Settings.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get saveFilesInstead => 'Save to Files instead';

  @override
  String get openWithNone => 'No app on this device can open this file.';

  @override
  String get discardedSnack => 'Result discarded.';

  @override
  String get errUnsupportedFormatTitle => 'This file type isn\'t supported';

  @override
  String get errUnsupportedFormatBody =>
      'DocuKit works with JPG, PNG, WebP and HEIC images, and PDF files.';

  @override
  String get errInvalidInputTitle => 'Check your settings';

  @override
  String get errInvalidInputBody =>
      'Some options aren\'t valid. Go back and check them.';

  @override
  String get errEncryptedDocumentTitle => 'This PDF is password-protected';

  @override
  String get errEncryptedDocumentBody =>
      'DocuKit can\'t open protected files yet. Remove the password in the app that created it, then try again.';

  @override
  String get errCorruptFileTitle => 'This file looks damaged';

  @override
  String get errCorruptFileBody =>
      'It couldn\'t be read. Try opening it in another app, or choose a different copy.';

  @override
  String get errFileTooLargeTitle => 'This file is too large';

  @override
  String errFileTooLargeBody(Object limit) {
    return 'The limit is $limit. Try a smaller file.';
  }

  @override
  String get errTooManyFilesTitle => 'Too many files';

  @override
  String errTooManyFilesBody(int max) {
    return 'You can add up to $max at a time.';
  }

  @override
  String get errNotEnoughFilesTitle => 'Add more files';

  @override
  String errNotEnoughFilesBody(int min) {
    return 'This tool needs at least $min.';
  }

  @override
  String get errInsufficientStorageTitle => 'Not enough free space';

  @override
  String errInsufficientStorageBody(Object needed) {
    return 'About $needed is needed. Free up some space on your phone and try again.';
  }

  @override
  String get errPermissionLostTitle => 'Can\'t read this file anymore';

  @override
  String get errPermissionLostBody => 'Please choose the file again.';

  @override
  String get errProcessingFailedTitle => 'Something went wrong';

  @override
  String get errProcessingFailedBody =>
      'The job didn\'t finish. Your files are safe.';

  @override
  String get errOutOfMemoryTitle =>
      'This file is too big for your phone to process';

  @override
  String get errOutOfMemoryBody => 'Try a smaller file, or a lower max size.';

  @override
  String get errCancelledTitle => 'Cancelled';

  @override
  String get errCancelledBody => 'Nothing was saved.';

  @override
  String get errOutputValidationFailedTitle =>
      'The result didn\'t pass our checks';

  @override
  String get errOutputValidationFailedBody =>
      'We didn\'t keep it, to avoid giving you a broken file. Please try again.';

  @override
  String get errSaveFailedTitle => 'Couldn\'t save the file';

  @override
  String get errSaveFailedBody => 'Try another location.';

  @override
  String get errInterruptedTitle => 'This job was interrupted';

  @override
  String get errInterruptedBody => 'DocuKit was closed before it finished.';

  @override
  String errFileLabel(Object name) {
    return 'File: $name';
  }

  @override
  String get histTitle => 'Recent activity';

  @override
  String get histFilterAll => 'All';

  @override
  String get histFilterImages => 'Images';

  @override
  String get histFilterPdfs => 'PDFs';

  @override
  String get histFilterFailed => 'Failed';

  @override
  String get histToday => 'Today';

  @override
  String get histYesterday => 'Yesterday';

  @override
  String get histUnavailable => 'File no longer available';

  @override
  String histEmpty(Object period) {
    return 'Nothing here yet. Files you create appear here for $period.';
  }

  @override
  String get histEmptyTitle => 'No activity yet';

  @override
  String get histRemovedUndo => 'Removed from history';

  @override
  String get histClearTitle => 'Clear history?';

  @override
  String get histClearBody =>
      'This clears the list. Files you saved elsewhere are not affected.';

  @override
  String get histClearAlsoFiles => 'Also delete app copies of results';

  @override
  String get histClearOk => 'Clear';

  @override
  String get histSortTooltip => 'Sort and filter';

  @override
  String get histClearTooltip => 'Clear history';

  @override
  String get histSortTitle => 'Sort and filter';

  @override
  String get histSortLabel => 'Sort';

  @override
  String get histSortNewest => 'Newest';

  @override
  String get histSortOldest => 'Oldest';

  @override
  String get histSortSaving => 'Biggest saving';

  @override
  String get histStatusLabel => 'Status';

  @override
  String get histStatusAll => 'All';

  @override
  String get histStatusCompleted => 'Completed';

  @override
  String get histStatusFailed => 'Failed';

  @override
  String histFailedLine(Object reason) {
    return 'Failed — $reason';
  }

  @override
  String get histCancelled => 'Cancelled';

  @override
  String get histInterrupted => 'Interrupted';

  @override
  String get histRunning => 'In progress';

  @override
  String histSizes(String before, String after) {
    return '$before → $after';
  }

  @override
  String histFilesPages(int files, int pages, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files',
      one: '1 file',
    );
    return '$_temp0 · $pages pages · $size';
  }

  @override
  String get histLoadMore => 'Show more';

  @override
  String get detTitle => 'Details';

  @override
  String get detStatus => 'Status';

  @override
  String get detTool => 'Tool';

  @override
  String get detInputs => 'Inputs';

  @override
  String get detOutput => 'Output';

  @override
  String get detSettings => 'Settings';

  @override
  String get detSaved => 'Saved';

  @override
  String get detKeptUntil => 'Kept until';

  @override
  String get detNotSaved => 'Not saved to your device yet';

  @override
  String get detSavedYes => 'Saved to device';

  @override
  String get detDeleted => 'Deleted';

  @override
  String get detForever => 'Until you delete it';

  @override
  String detTook(Object duration) {
    return 'took $duration';
  }

  @override
  String get detStatusCompleted => 'Completed';

  @override
  String get detStatusFailed => 'Failed';

  @override
  String get detStatusCancelled => 'Cancelled';

  @override
  String get detStatusInterrupted => 'Interrupted';

  @override
  String get detStatusRunning => 'In progress';

  @override
  String get detRunAgain => 'Run again with these settings';

  @override
  String get detDeleteCopy => 'Delete app copy';

  @override
  String get detRemoveEntry => 'Remove from history';

  @override
  String get detDeleteCopyTitle => 'Delete the app copy?';

  @override
  String get detDeleteCopyBody => 'Files you saved elsewhere are not affected.';

  @override
  String get detRemoveTitle => 'Remove from history?';

  @override
  String get detRemoveBody =>
      'The app copy of the result will also be deleted. Files you saved elsewhere are not affected.';

  @override
  String get detRepickHint => 'You\'ll need to choose the files again.';

  @override
  String get setTitle => 'Settings';

  @override
  String get setSectionAppearance => 'Appearance';

  @override
  String get setSectionImage => 'Image defaults';

  @override
  String get setSectionPdf => 'PDF defaults';

  @override
  String get setSectionFiles => 'Files and history';

  @override
  String get setSectionAbout => 'About';

  @override
  String get setTheme => 'Theme';

  @override
  String get setSystem => 'System';

  @override
  String get setLight => 'Light';

  @override
  String get setDark => 'Dark';

  @override
  String get setDefaultQuality => 'Default quality';

  @override
  String get setDefaultFormat => 'Default output format';

  @override
  String get setLockRatio => 'Keep aspect ratio when resizing';

  @override
  String get setPageSize => 'Page size';

  @override
  String get setImageFit => 'Image fit';

  @override
  String get setMargins => 'Margins';

  @override
  String get setPdfImageQuality => 'Image quality in PDFs';

  @override
  String get setReduceLevel => 'Size reducer level';

  @override
  String get setKeepResults => 'Keep results for';

  @override
  String get setH24 => '24 hours';

  @override
  String get setD7 => '7 days';

  @override
  String get setD30 => '30 days';

  @override
  String get setForever => 'Until I delete';

  @override
  String get setStorageUsed => 'Storage used';

  @override
  String get setStorageClear => 'Clear';

  @override
  String get setStorageClearTitle => 'Delete app copies of results?';

  @override
  String get setStorageClearBody =>
      'History stays. Files you saved elsewhere are not affected.';

  @override
  String get setStorageCleared => 'App copies deleted';

  @override
  String get setConfirmDelete => 'Confirm before deleting';

  @override
  String get setClearHistory => 'Clear history';

  @override
  String get setHistoryCleared => 'History cleared';

  @override
  String get setPrivacy => 'Privacy & about';

  @override
  String get setFeedback => 'Send feedback';

  @override
  String setVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get feedbackSubject => 'DocuKit feedback';

  @override
  String feedbackBody(String version, String os) {
    return 'App version: $version\nDevice OS: $os\n\n';
  }

  @override
  String get feedbackUnavailable => 'No email app is set up on this device.';

  @override
  String get periodH24 => '24 hours';

  @override
  String get periodD7 => '7 days';

  @override
  String get periodD30 => '30 days';

  @override
  String get periodForever => 'until you delete them';

  @override
  String get privTitle => 'Privacy & about';

  @override
  String get privLocalH => 'Your files stay on your phone';

  @override
  String get privLocalP =>
      'Everything DocuKit does to your files happens on this device. Your files are never uploaded.';

  @override
  String get privAccountH => 'No account';

  @override
  String get privAccountP =>
      'You don\'t need to sign up, and DocuKit doesn\'t know who you are.';

  @override
  String get privAccessH => 'What DocuKit can access';

  @override
  String get privAccessPhotosLabel => 'Photos';

  @override
  String get privAccessPhotos => 'Only the photos you pick';

  @override
  String get privAccessFilesLabel => 'Files';

  @override
  String get privAccessFiles => 'Only the files you pick';

  @override
  String get privAccessPhotosAddLabel => 'Photos (add only)';

  @override
  String get privAccessPhotosAdd =>
      'Adding to Photos, only when you tap Save to Photos';

  @override
  String get privStoredH => 'What\'s stored';

  @override
  String privStoredP(Object period) {
    return 'A list of recent jobs, and copies of results for $period. Both stay on this device and you can clear them in Settings.';
  }

  @override
  String get privProtectedH => 'Password-protected files';

  @override
  String get privProtectedP =>
      'DocuKit doesn\'t open or unlock protected PDFs.';

  @override
  String get privLicenses => 'Open-source licences';

  @override
  String get privPolicy => 'Privacy policy';

  @override
  String get privPolicyBody1 =>
      'DocuKit has no account system and never uploads your files. Your files, file names and results stay on your device and are never sent to us or to anyone else.';

  @override
  String get privPolicyBody2 =>
      'Files you choose are processed only on your device. The app keeps a list of recent jobs and copies of results on your device for the period you choose in Settings (7 days by default). You can delete them at any time in Settings. Uninstalling the app deletes them.';

  @override
  String get privPolicyBody3 =>
      'The app accesses only the photos and files you select in the system picker. On iOS it asks for permission to add images to your photo library only when you choose Save to Photos.';

  @override
  String get privPolicyBody4 =>
      'Ads: DocuKit shows ads from Google AdMob to stay free. To show and measure ads and to prevent fraud, Google\'s ads SDK collects device information such as the advertising ID, approximate location from the IP address, and how you interact with ads. It never receives your files, file names or results. Where the law requires it, DocuKit asks for your consent first, and you can change your choice in Settings → Privacy & ad choices. You can remove ads with a one-time purchase. Google\'s privacy policy: policies.google.com/privacy';

  @override
  String get privPolicyBody5 =>
      'Purchases are handled by Google Play or the App Store; we never receive your payment details. Google Play and Apple may provide anonymous crash statistics if you\'ve allowed this in your device settings. The app isn\'t directed at children under 13.';

  @override
  String get unsavedTitle => 'Leave without finishing?';

  @override
  String get unsavedBody =>
      'Your files and settings for this tool will be cleared.';

  @override
  String get unsavedOrganizerTitle => 'Discard your page changes?';

  @override
  String get unsavedOrganizerBody => 'Your page edits haven\'t been saved.';

  @override
  String get renameTitle => 'Rename';

  @override
  String get renameHint => 'File name';

  @override
  String get renameEmpty => 'Enter a name.';

  @override
  String renamePreview(Object name) {
    return 'Will be saved as $name';
  }

  @override
  String get fdTitle => 'File details';

  @override
  String get fdName => 'Name';

  @override
  String get fdType => 'Type';

  @override
  String get fdSize => 'Size';

  @override
  String get fdDimensions => 'Dimensions';

  @override
  String get fdPages => 'Pages';

  @override
  String get fdAlpha => 'Transparency';

  @override
  String get fdLocation => 'Location data';

  @override
  String get fdProtected => 'Password-protected';

  @override
  String get fdYes => 'Yes';

  @override
  String get fdNo => 'No';

  @override
  String get moveToTitle => 'Move to…';

  @override
  String get moveTop => 'Move to top';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get moveBottom => 'Move to bottom';

  @override
  String get dragHandle => 'Drag to reorder';

  @override
  String get draftRestored => 'Restored your last session.';

  @override
  String get draftStartOver => 'Start over';

  @override
  String get durUnderSecond => 'under a second';

  @override
  String durSeconds(Object s) {
    return '$s s';
  }

  @override
  String durMinutes(int m, int s) {
    return '$m min $s s';
  }

  @override
  String a11ySizeWords(String value, String unit) {
    String _temp0 = intl.Intl.selectLogic(unit, {
      'B': 'bytes',
      'KB': 'kilobytes',
      'MB': 'megabytes',
      'GB': 'gigabytes',
      'other': '',
    });
    return '$value $_temp0';
  }

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String homeSavedSoFar(String size) {
    return 'You\'ve saved $size so far';
  }

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homeHelpTooltip => 'Take the tour';

  @override
  String get qaPassport => 'Passport photo';

  @override
  String get qaUnder100kb => 'Under 100 KB';

  @override
  String get qaSignature => 'Signature';

  @override
  String get qaPhotosToPdf => 'Photos to PDF';

  @override
  String get qaMergePdfs => 'Merge PDFs';

  @override
  String get qaEmailPdf => 'Email-size PDF';

  @override
  String get tourIntroTitle => 'Quick tour';

  @override
  String get tourIntroBody => 'See what DocuKit can do in about 30 seconds.';

  @override
  String get tourStart => 'Start tour';

  @override
  String get tourSkip => 'Skip';

  @override
  String get tourNext => 'Next';

  @override
  String get tourBack => 'Back';

  @override
  String get tourDone => 'Done';

  @override
  String get tourTry => 'Try it';

  @override
  String get tourSearchTitle => 'Search in plain words';

  @override
  String get tourSearchBody =>
      'Type what you need, like \"make photo smaller\" or \"join PDFs\".';

  @override
  String get tourImageCompressTitle => 'Image Compressor';

  @override
  String get tourImageCompressBody =>
      'Make photos smaller. Pick a quality, or set a limit like \"under 100 KB\".';

  @override
  String get tourImageCompressExample =>
      'Great for job and exam portals with upload limits.';

  @override
  String get tourImageResizeTitle => 'Image Resizer';

  @override
  String get tourImageResizeBody =>
      'Set an exact size in pixels or percent, or use a preset.';

  @override
  String get tourImageResizeExample =>
      'Passport photo 413×531 or a signature at 140×60.';

  @override
  String get tourImageToPdfTitle => 'Images to PDF';

  @override
  String get tourImageToPdfBody =>
      'Turn several photos into one PDF, in the order you choose.';

  @override
  String get tourImageToPdfExample =>
      'Notes, receipts or certificates in one file.';

  @override
  String get tourPdfMergeTitle => 'Merge PDFs';

  @override
  String get tourPdfMergeBody =>
      'Combine several PDFs into one. Drag to set the order.';

  @override
  String get tourPdfMergeExample => 'Put a cover letter and CV together.';

  @override
  String get tourPdfOrganizeTitle => 'Organize Pages';

  @override
  String get tourPdfOrganizeBody =>
      'Reorder, rotate or delete pages, then save a new copy.';

  @override
  String get tourPdfOrganizeExample =>
      'Fix a sideways scan or remove a blank page.';

  @override
  String get tourPdfCompressTitle => 'Reduce PDF Size';

  @override
  String get tourPdfCompressBody =>
      'Make a PDF smaller for email, with clear choices about quality.';

  @override
  String get tourPdfCompressExample => 'Get under a 10 MB email limit.';

  @override
  String get tourImageConvertTitle => 'Convert Image';

  @override
  String get tourImageConvertBody =>
      'Change photos between JPG, PNG, WebP and HEIC.';

  @override
  String get tourImageConvertExample =>
      'Turn iPhone HEIC photos into JPG for upload forms.';

  @override
  String get tourPdfSplitTitle => 'Split PDF';

  @override
  String get tourPdfSplitBody => 'Break one PDF into several smaller ones.';

  @override
  String get tourPdfSplitExample => 'Send only pages 3–5 of a long report.';

  @override
  String get tourPdfToImagesTitle => 'PDF to Images';

  @override
  String get tourPdfToImagesBody => 'Save each page as a picture.';

  @override
  String get tourPdfToImagesExample => 'Post a page of a PDF as a photo.';

  @override
  String get multiHeaderAll => 'All done';

  @override
  String multiHeaderSome(int done, int total) {
    return '$done of $total done';
  }

  @override
  String multiTotals(String before, String after) {
    return 'Before $before → After $after';
  }

  @override
  String multiCountPdfs(int count, String size) {
    return '$count PDFs · $size';
  }

  @override
  String multiCountImages(int count, String size) {
    return '$count images · $size';
  }

  @override
  String get multiSaveAll => 'Save all…';

  @override
  String get multiSaveZip => 'Save as ZIP';

  @override
  String get multiShareAll => 'Share all';

  @override
  String multiSavedFolder(int count, String folder) {
    return 'Saved $count files to $folder';
  }

  @override
  String multiSaved(int count) {
    return 'Saved $count files';
  }

  @override
  String multiSavedPartial(int saved, int total, int failed) {
    return 'Saved $saved of $total. $failed couldn\'t be written.';
  }

  @override
  String get multiShareTooMany =>
      'That\'s more than 50 files. Share them as one ZIP instead?';

  @override
  String multiItemClosest(String target) {
    return 'Closest to $target';
  }

  @override
  String multiItemFailed(String error) {
    return '$error. Original not changed.';
  }

  @override
  String get multiAllFailed =>
      'None of the files could be processed. Your originals were not changed.';

  @override
  String multiZipping(int done, int total) {
    return 'Zipping $done of $total';
  }

  @override
  String get multiFilesHeader => 'Files';

  @override
  String batchHeader(int count) {
    return 'Images ($count)';
  }

  @override
  String batchTotal(String size) {
    return 'Total $size';
  }

  @override
  String batchInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count can\'t be used',
      one: '1 can\'t be used',
    );
    return '$_temp0';
  }

  @override
  String get batchRemoveInvalid => 'Remove them';

  @override
  String get batchNoneValid => 'Add images that DocuKit can open';

  @override
  String batchRunCompress(int count) {
    return 'Compress $count images';
  }

  @override
  String batchShowAll(int count) {
    return 'Show all $count';
  }

  @override
  String get batchClearAll => 'Clear all';

  @override
  String batchRunResize(int count) {
    return 'Resize $count images';
  }

  @override
  String get resFitInside => 'Fit inside';

  @override
  String batchRunConvert(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Convert $count images',
      one: 'Convert 1 image',
    );
    return '$_temp0';
  }

  @override
  String get cnvTo => 'Convert to';

  @override
  String cnvSameFormat(int count, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images are',
      one: '1 image is',
    );
    return '$_temp0 already $format. They\'ll be re-saved.';
  }

  @override
  String get cnvHeicIosOnly => 'HEIC is available on iPhone only.';

  @override
  String get stepConverting => 'Converting images…';

  @override
  String get splModeRanges => 'Custom ranges';

  @override
  String get splModeEvery => 'Every N pages';

  @override
  String get splModeEach => 'Each page';

  @override
  String get splHow => 'How to split';

  @override
  String get splRangesHint => 'Use commas and dashes, e.g. 1-3, 5, 8-end';

  @override
  String splPreviewFiles(int count, String parts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0: $parts';
  }

  @override
  String splPartPage(int page) {
    return 'page $page';
  }

  @override
  String splPartPages(int first, int last) {
    return 'pages $first–$last';
  }

  @override
  String get splEveryLabel => 'Pages per file';

  @override
  String get splEveryLess => 'Fewer pages per file';

  @override
  String get splEveryMore => 'More pages per file';

  @override
  String splEveryPreview(int count, int lastPages) {
    String _temp0 = intl.Intl.pluralLogic(
      lastPages,
      locale: localeName,
      other: '$lastPages pages',
      one: '1 page',
    );
    return '$count files (the last has $_temp0)';
  }

  @override
  String splEachPreview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get splOnePage => 'This PDF has only one page.';

  @override
  String get splEachCap =>
      'That would make more than 500 files. Use Every N pages instead.';

  @override
  String splRun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Split into $count PDFs',
      one: 'Split into 1 PDF',
      zero: 'Split',
    );
    return '$_temp0';
  }

  @override
  String rangeErrPage(int page, int total) {
    return 'Page $page doesn\'t exist. This PDF has $total pages.';
  }

  @override
  String get rangeErrReversed => 'Write ranges from low to high, e.g. 3-5.';

  @override
  String get rangeErrZero => 'Pages start at 1.';

  @override
  String get rangeErrChars => 'Use only numbers, commas, dashes and \"end\".';

  @override
  String get rangeErrEmpty => 'Enter at least one page.';

  @override
  String get rangeEndWord => 'end';

  @override
  String get orgExtract => 'Extract';

  @override
  String incTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Received $count files',
      one: 'Received 1 file',
    );
    return '$_temp0';
  }

  @override
  String incImagesSection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return '$_temp0';
  }

  @override
  String incPdfsSection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs',
      one: '1 PDF',
    );
    return '$_temp0';
  }

  @override
  String get incMergeNeedsMore => 'Needs one more PDF. You can add it next.';

  @override
  String get incUnsupported => 'DocuKit can\'t work with this file type.';

  @override
  String incWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files received',
      one: '1 file received',
    );
    return '$_temp0. Open when this job finishes.';
  }

  @override
  String get favHeader => 'Favourites';

  @override
  String get favEdit => 'Edit';

  @override
  String get favAdd => 'Add to favourites';

  @override
  String get favRemove => 'Remove from favourites';

  @override
  String get favLimit => 'You can pin up to 6 tools. Remove one first.';

  @override
  String get favMoveUp => 'Move up';

  @override
  String get favMoveDown => 'Move down';

  @override
  String get p2iPagesAll => 'All pages';

  @override
  String get p2iPagesChoose => 'Choose pages';

  @override
  String get p2iResolution => 'Resolution';

  @override
  String get p2iRes72 => 'Screen';

  @override
  String get p2iRes150 => 'Standard';

  @override
  String get p2iRes300 => 'Print';

  @override
  String p2iPxEstimate(int w, int h) {
    return '≈ $w × $h px per page';
  }

  @override
  String p2iPageCapped(int page, int px) {
    return 'Page $page was limited to $px px to save memory.';
  }

  @override
  String get p2iKeepTransparent => 'Keep transparent background';

  @override
  String p2iRun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create $count images',
      one: 'Create 1 image',
      zero: 'Create images',
    );
    return '$_temp0';
  }

  @override
  String resFitInsideHint(int w, int h) {
    return 'Each photo keeps its shape and fits inside $w × $h px. Smaller photos keep their size.';
  }

  @override
  String get tourRecentTitle => 'Your recent files';

  @override
  String get tourNavTitle => 'History and settings';

  @override
  String get tourNavBody =>
      'See everything you\'ve made, and set your favourite defaults.';

  @override
  String get tourDoneTitle => 'You\'re all set';

  @override
  String get tourDoneBody =>
      'Your files never leave your phone, and originals are never changed. Tap any tool to start.';

  @override
  String get tourWhatsNew => 'New in DocuKit';

  @override
  String get setTakeTour => 'Take the tour';

  @override
  String get setTakeTourSub => 'A 30-second look at every tool';

  @override
  String tourRecentBody(String period) {
    return 'Finished files appear here for $period, so you can save or share them again.';
  }

  @override
  String tourProgress(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String a11yTourStep(int n, int total, String title, String body) {
    return 'Step $n of $total. $title. $body';
  }

  @override
  String get adBadge => 'Ad';

  @override
  String get adSponsored => 'Sponsored';

  @override
  String get setRemoveAds => 'Remove ads';

  @override
  String get setRemoveAdsSub => 'One-time purchase';

  @override
  String get setAdChoices => 'Privacy & ad choices';

  @override
  String get setAdChoicesSub => 'Change your consent at any time';

  @override
  String get setSectionHelp => 'Help';

  @override
  String get setSectionAds => 'Ads and privacy';

  @override
  String get remTitle => 'Remove ads';

  @override
  String get remBody =>
      'Enjoying DocuKit? Remove ads once and support development.';

  @override
  String get remPoint1 => 'No ads, ever';

  @override
  String get remPoint2 =>
      'Works on this device and future installs with the same store account';

  @override
  String get remPoint3 => 'Your files stay on your phone, as always';

  @override
  String get remRestore => 'Restore purchase';

  @override
  String get remThanks => 'Thanks for your support. Ads are gone.';

  @override
  String get remFailed =>
      'The purchase didn\'t go through. You haven\'t been charged.';

  @override
  String get remUnavailable =>
      'The store isn\'t available right now. Try again later.';

  @override
  String get remOwned => 'Ads removed. Thank you.';

  @override
  String get privAdsH => 'About ads';

  @override
  String get privAdsP =>
      'DocuKit shows ads from Google AdMob to stay free. Ads never see your files, file names or results. Google may use device information to show and measure ads. You can change your ad choices in Settings, or remove ads with a one-time purchase.';

  @override
  String get rewOffer => 'Watch a short ad: no ads for 24 hours';

  @override
  String get rewOfferShort => 'No ads for 24 hours? Watch a short ad';

  @override
  String get rewNotEarned => 'The ad was closed early, so ads are still on.';

  @override
  String get rewLimit =>
      'You\'ve used today\'s ad-free passes. Try again tomorrow.';

  @override
  String remBuy(String price) {
    return 'Buy for $price';
  }

  @override
  String rewGranted(String time) {
    return 'Done. No ads until $time tomorrow.';
  }

  @override
  String adsFreeUntil(String time) {
    return 'Ad-free until $time';
  }

  @override
  String get tip1 => 'Tip: Use Target size to hit upload limits exactly.';

  @override
  String get tip2 =>
      'Tip: The Passport photo preset gives you exactly 413 × 531 pixels.';

  @override
  String get tip3 =>
      'Tip: Turn on \"Remove location and camera info\" before sharing photos.';

  @override
  String get tip4 =>
      'Tip: Balanced shrinks photos inside a PDF and keeps the text sharp.';

  @override
  String get tip5 =>
      'Tip: In Organize Pages, double-tap a page to see it full screen.';

  @override
  String get tip6 =>
      'Tip: Your original file is never changed. DocuKit always makes a copy.';

  @override
  String get tip7 =>
      'Tip: Finished files stay in Recent, so you can save or share them again.';

  @override
  String get tip8 => 'Tip: Search understands plain words, like \"join PDFs\".';

  @override
  String get resultDoneImage => 'Image ready';

  @override
  String get resultDonePdf => 'PDF ready';

  @override
  String get resultChecked => 'Checked and ready to save';

  @override
  String get resultSize => 'Size';

  @override
  String get resultSmallerShort => 'smaller';

  @override
  String get resultLargerShort => 'larger';

  @override
  String get diagTitle => 'Ad diagnostics';

  @override
  String get diagSectionStatus => 'Status';

  @override
  String get diagSectionSlots => 'Ad slots';

  @override
  String get diagYes => 'Yes';

  @override
  String get diagNo => 'No';

  @override
  String diagConsent(String answer) {
    return 'Consent allows ads: $answer';
  }

  @override
  String diagAdsRemoved(String answer) {
    return 'Remove ads bought: $answer';
  }

  @override
  String diagAdFreeUntil(String time) {
    return 'Ad-free pass until $time';
  }

  @override
  String get diagAdFreeNone => 'No ad-free pass active';

  @override
  String diagBuildIds(String kind) {
    return 'This build uses: $kind';
  }

  @override
  String get diagIdsTest => 'Test IDs (debug build)';

  @override
  String get diagIdsReal => 'Real IDs (release build)';

  @override
  String get diagUnitTest => 'Test ID';

  @override
  String get diagUnitReal => 'Real ID';

  @override
  String get diagUnitOff => 'Off';

  @override
  String get diagUnitMissing => 'Missing';

  @override
  String diagLoaded(String time) {
    return 'Loaded at $time';
  }

  @override
  String diagNoFill(String time, int code) {
    return 'No fill at $time (code $code)';
  }

  @override
  String diagError(String time, int code, String message) {
    return 'Error at $time: code $code, $message';
  }

  @override
  String diagErrorNoCode(String time, String message) {
    return 'Error at $time: $message';
  }

  @override
  String get diagNotRequested => 'Not requested yet';

  @override
  String get diagPlaceNativeHome => 'Native card on Home (AD-1)';

  @override
  String get diagPlaceNativeResult => 'Native card on Result (AD-2)';

  @override
  String get diagPlaceNativeHistory => 'Native card in Recent activity (AD-4)';

  @override
  String get diagPlaceNativeDetails =>
      'Native card on Operation details (AD-6)';

  @override
  String get diagPlaceBannerSettings => 'Bottom banner on Settings (AD-5)';

  @override
  String get diagPlaceBannerMain =>
      'Bottom banner: Home, Search, Result, Recent activity, Operation details';

  @override
  String get diagPlaceBannerTools =>
      'Bottom banner: tool screens and Manage files';

  @override
  String get diagPlaceBannerInfo => 'Bottom banner: Privacy & About, Licences';

  @override
  String get diagPlaceInterstitial => 'Full-screen ad after Done (AD-3)';

  @override
  String get diagPlaceRewarded => 'Rewarded ad-free pass (AD-8)';
}
