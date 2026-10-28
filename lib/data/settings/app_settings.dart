import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/image/image_options.dart';
import '../../core/pdf/pdf_options.dart';
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
