import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/image/image_options.dart';
import '../../core/ocr/text_recognizer.dart';
import '../../core/pdf/pdf_options.dart';
import '../../core/scan/scan_options.dart';
import '../../features/search/tool_catalog.dart';

enum Retention {
  h24(Duration(hours: 24)),
  d7(Duration(days: 7)),
  d30(Duration(days: 30)),
  forever(null);

  const Retention(this.duration);
  final Duration? duration;
}

class CustomPreset {
  const CustomPreset(this.name, this.width, this.height);
  final String name;
  final int width, height;
  Map<String, Object> toJson() => {'n': name, 'w': width, 'h': height};
  static CustomPreset fromJson(Map<String, dynamic> j) => CustomPreset(j['n'] as String, j['w'] as int, j['h'] as int);
}

/// 1.5 FR-LCK-03 (ADR-057): what the app lock covers.
enum LockScope { library, app }

/// 1.5 FR-LCK-04: lock again after being away this long.
enum LockTimeout {
  immediate(Duration.zero),
  m1(Duration(minutes: 1)),
  m5(Duration(minutes: 5));

  const LockTimeout(this.duration);
  final Duration duration;
}

/// Every preference (ARCHITECTURE §8.1).
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.imgQuality = 80,
    this.imgFormat = OutputFormatChoice.same,
    this.imgStripMetadata = true,
    this.resizeLockRatio = true,
    this.resizeCustomPresets = const [],
    this.pdfPageSize = PdfPageSize.a4,
    this.pdfFit = PdfFit.fit,
    this.pdfMargin = PdfMargin.small,
    this.pdfImageQuality = PdfImageQuality.high,
    this.reduceLevel = ReduceLevel.balanced,
    this.outputRetention = Retention.d7,
    this.confirmDestructive = true,
    this.onboardingDone = false,
    this.lastTool,
    this.tourDone = false,
    this.tourVersion = 0,
    this.statsTotalSavedBytes = 0,
    this.convertFormat = ImageFormat.jpeg,
    this.convertQuality = 90,
    this.splitMode = 'ranges',
    this.splitEveryN = 2,
    this.p2iFormat = ImageFormat.jpeg,
    this.p2iDpi = 150,
    this.favouriteTools = const [],
    this.scanFormat = ScanOutputFormat.pdf,
    this.scanPageSize = ScanPageSize.a4,
    this.scanQuality = ScanQuality.high,
    this.ocrScript = OcrScript.latin,
    this.ocrOutputPdf = true,
    this.ocrOutputReview = true,
    this.ocrOutputTxt = false,
    this.ocrRotateRetry = true,
    this.scanMakeSearchable = false,
    this.libIndexScans = true,
    this.libIndexOther = false,
    this.libIndexPaused = false,
    this.remMinuteOfDay = 540,
    this.remShowNames = false,
    this.lockEnabled = false,
    this.lockScope = LockScope.library,
    this.lockTimeout = LockTimeout.m1,
    this.lockHideRecents = true,
  });

  final ThemeMode themeMode;
  final int imgQuality;
  final OutputFormatChoice imgFormat;
  final bool imgStripMetadata;
  final bool resizeLockRatio;
  final List<CustomPreset> resizeCustomPresets;
  final PdfPageSize pdfPageSize;
  final PdfFit pdfFit;
  final PdfMargin pdfMargin;
  final PdfImageQuality pdfImageQuality;
  final ReduceLevel reduceLevel;
  final Retention outputRetention;
  final bool confirmDestructive;
  final bool onboardingDone;
  final ToolId? lastTool;

  /// v2.1 (TOUR.md §4, UI_REFRESH §2.2).
  final bool tourDone;
  final int tourVersion;
  final int statsTotalSavedBytes;

  /// Convert Image's last choices (RELEASE_V1_1 §5.2).
  final ImageFormat convertFormat;
  final int convertQuality;

  /// Split PDF's last choices (§5.2): `ranges|everyN|each`, pages per file
  /// (the spec's default 1 is shown as the smallest useful value, 2).
  final String splitMode;
  final int splitEveryN;

  /// PDF to Images' last choices (§5.2): jpg/png, 72/150/300.
  final ImageFormat p2iFormat;
  final int p2iDpi;

  /// Pinned tools in row order, max 6 (FR-FAV-02/04).
  final List<ToolId> favouriteTools;

  /// Scan Document's last choices (RELEASE_V1_2 §5).
  final ScanOutputFormat scanFormat;
  final ScanPageSize scanPageSize;
  final ScanQuality scanQuality;

  /// Text Recognition (RELEASE_V1_3 §5): `ocr_script` (Devanagari by default
  /// for hi/mr), `ocr_outputs` {pdf, review, txt}, `ocr_rotate_retry`.
  final OcrScript ocrScript;
  final bool ocrOutputPdf, ocrOutputReview, ocrOutputTxt;
  final bool ocrRotateRetry;

  /// S29 "Make searchable" (`scan_make_searchable`, FR-OCR-13).
  final bool scanMakeSearchable;

  /// 1.5 S46 "Make documents searchable" (FR-LIB-15/16, ADR-055):
  /// `lib_index_scans` (OCR for scans), `lib_index_other` (OCR for other
  /// PDFs and images), `lib_index_paused` (the user's Pause).
  final bool libIndexScans, libIndexOther, libIndexPaused;

  /// 1.5 reminders (FR-REM-02/05): `rem_minute_of_day` (08:00–21:00, default
  /// 09:00) and `rem_show_names` (generic text by default).
  final int remMinuteOfDay;
  final bool remShowNames;

  /// 1.5 app lock (FR-LCK-01–05): `lock_enabled`, `lock_scope`,
  /// `lock_timeout`, `lock_hide_recents`. No credential is ever stored (ADR-056).
  final bool lockEnabled;
  final LockScope lockScope;
  final LockTimeout lockTimeout;
  final bool lockHideRecents;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? imgQuality,
    OutputFormatChoice? imgFormat,
    bool? imgStripMetadata,
    bool? resizeLockRatio,
    List<CustomPreset>? resizeCustomPresets,
    PdfPageSize? pdfPageSize,
    PdfFit? pdfFit,
    PdfMargin? pdfMargin,
    PdfImageQuality? pdfImageQuality,
    ReduceLevel? reduceLevel,
    Retention? outputRetention,
    bool? confirmDestructive,
    bool? onboardingDone,
    ToolId? lastTool,
    bool? tourDone,
    int? tourVersion,
    int? statsTotalSavedBytes,
    ImageFormat? convertFormat,
    int? convertQuality,
    String? splitMode,
    int? splitEveryN,
    ImageFormat? p2iFormat,
    int? p2iDpi,
    List<ToolId>? favouriteTools,
    ScanOutputFormat? scanFormat,
    ScanPageSize? scanPageSize,
    ScanQuality? scanQuality,
    OcrScript? ocrScript,
    bool? ocrOutputPdf,
    bool? ocrOutputReview,
    bool? ocrOutputTxt,
    bool? ocrRotateRetry,
    bool? scanMakeSearchable,
    bool? libIndexScans,
    bool? libIndexOther,
    bool? libIndexPaused,
    int? remMinuteOfDay,
    bool? remShowNames,
    bool? lockEnabled,
    LockScope? lockScope,
    LockTimeout? lockTimeout,
    bool? lockHideRecents,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        imgQuality: imgQuality ?? this.imgQuality,
        imgFormat: imgFormat ?? this.imgFormat,
        imgStripMetadata: imgStripMetadata ?? this.imgStripMetadata,
        resizeLockRatio: resizeLockRatio ?? this.resizeLockRatio,
        resizeCustomPresets: resizeCustomPresets ?? this.resizeCustomPresets,
        pdfPageSize: pdfPageSize ?? this.pdfPageSize,
        pdfFit: pdfFit ?? this.pdfFit,
        pdfMargin: pdfMargin ?? this.pdfMargin,
        pdfImageQuality: pdfImageQuality ?? this.pdfImageQuality,
        reduceLevel: reduceLevel ?? this.reduceLevel,
        outputRetention: outputRetention ?? this.outputRetention,
        confirmDestructive: confirmDestructive ?? this.confirmDestructive,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        lastTool: lastTool ?? this.lastTool,
        tourDone: tourDone ?? this.tourDone,
        tourVersion: tourVersion ?? this.tourVersion,
        statsTotalSavedBytes: statsTotalSavedBytes ?? this.statsTotalSavedBytes,
        convertFormat: convertFormat ?? this.convertFormat,
        convertQuality: convertQuality ?? this.convertQuality,
        splitMode: splitMode ?? this.splitMode,
        splitEveryN: splitEveryN ?? this.splitEveryN,
        p2iFormat: p2iFormat ?? this.p2iFormat,
        p2iDpi: p2iDpi ?? this.p2iDpi,
        favouriteTools: favouriteTools ?? this.favouriteTools,
        scanFormat: scanFormat ?? this.scanFormat,
        scanPageSize: scanPageSize ?? this.scanPageSize,
        scanQuality: scanQuality ?? this.scanQuality,
        ocrScript: ocrScript ?? this.ocrScript,
        ocrOutputPdf: ocrOutputPdf ?? this.ocrOutputPdf,
        ocrOutputReview: ocrOutputReview ?? this.ocrOutputReview,
        ocrOutputTxt: ocrOutputTxt ?? this.ocrOutputTxt,
        ocrRotateRetry: ocrRotateRetry ?? this.ocrRotateRetry,
        scanMakeSearchable: scanMakeSearchable ?? this.scanMakeSearchable,
        libIndexScans: libIndexScans ?? this.libIndexScans,
        libIndexOther: libIndexOther ?? this.libIndexOther,
        libIndexPaused: libIndexPaused ?? this.libIndexPaused,
        remMinuteOfDay: remMinuteOfDay ?? this.remMinuteOfDay,
        remShowNames: remShowNames ?? this.remShowNames,
        lockEnabled: lockEnabled ?? this.lockEnabled,
        lockScope: lockScope ?? this.lockScope,
        lockTimeout: lockTimeout ?? this.lockTimeout,
        lockHideRecents: lockHideRecents ?? this.lockHideRecents,
      );
}

/// Letter for US/CA/MX/PH (ARCHITECTURE §8.1), A4 elsewhere.
PdfPageSize defaultPageSizeFor(String? countryCode) =>
    const {'US', 'CA', 'MX', 'PH'}.contains(countryCode?.toUpperCase()) ? PdfPageSize.letter : PdfPageSize.a4;

String encodePresets(List<CustomPreset> p) => jsonEncode([for (final x in p) x.toJson()]);

List<CustomPreset> decodePresets(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    return [
      for (final e in jsonDecode(raw) as List) CustomPreset.fromJson((e as Map).cast<String, dynamic>()),
    ];
  } on FormatException {
    return const [];
  }
}
