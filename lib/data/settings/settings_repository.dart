import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/image/image_options.dart';
import '../../core/ocr/text_recognizer.dart';
import '../../core/pdf/pdf_options.dart';
import '../../core/scan/scan_options.dart';
import '../../features/search/tool_catalog.dart';
import 'app_settings.dart';

/// Minimal key-value surface so tests can use an in-memory store.
abstract interface class KeyValueStore {
  Object? get(String key);
  Future<void> setString(String key, String value);
  Future<void> setInt(String key, int value);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

class PrefsStore implements KeyValueStore {
  PrefsStore(this._p);
  final SharedPreferencesWithCache _p;

  static Future<PrefsStore> open() async => PrefsStore(
        await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions()),
      );

  @override
  Object? get(String key) => _p.get(key);
  @override
  Future<void> setString(String key, String value) => _p.setString(key, value);
  @override
  Future<void> setInt(String key, int value) => _p.setInt(key, value);
  @override
  Future<void> setBool(String key, bool value) => _p.setBool(key, value);
  @override
  Future<void> remove(String key) => _p.remove(key);
}

class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, Object>? initial]) : _m = {...?initial};
  final Map<String, Object> _m;
  @override
  Object? get(String key) => _m[key];
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  Future<void> setInt(String key, int value) async => _m[key] = value;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Future<void> remove(String key) async => _m.remove(key);
}

/// Wraps the ARCHITECTURE §8.1 keys.
class SettingsRepository {
  SettingsRepository(this._store, {String? countryCode, String? languageCode})
      : _country = countryCode,
        _language = languageCode;
  final KeyValueStore _store;

  /// Raw store for feature-owned keys (ads counters, ADS.md §4).
  KeyValueStore get store => _store;
  final String? _country;
  final String? _language;

  static const kTheme = 'theme_mode';
  static const kImgQuality = 'img_quality';
  static const kImgFormat = 'img_format';
  static const kStrip = 'img_strip_metadata';
  static const kLock = 'resize_lock_ratio';
  static const kPresets = 'resize_custom_presets';
  static const kPageSize = 'pdf_page_size';
  static const kFit = 'pdf_fit';
  static const kMargin = 'pdf_margin';
  static const kPdfQuality = 'pdf_image_quality';
  static const kReduce = 'reduce_level';
  static const kRetention = 'output_retention';
  static const kConfirm = 'confirm_destructive';
  static const kOnboarding = 'onboarding_done';
  static const kLastTool = 'last_tool';
  static const kTourDone = 'tour_done';
  static const kTourVersion = 'tour_version';
  static const kSavedBytes = 'stats_total_saved_bytes';
  static const kConvertFormat = 'convert_format'; // jpg | png | webp | heic
  static const kConvertQuality = 'convert_quality';
  static const kSplitMode = 'split_mode';
  static const kSplitEveryN = 'split_every_n';
  static const kP2iFormat = 'p2i_format'; // jpg | png
  static const kP2iDpi = 'p2i_dpi';
  static const kFavouriteTools = 'favourite_tools'; // JSON list of ToolId.name
  static const kScanFormat = 'scan_default_format'; // pdf | jpg
  static const kScanPageSize = 'scan_page_size'; // a4 | letter | fit
  static const kScanQuality = 'scan_quality'; // high | compact
  static const kOcrScript = 'ocr_script'; // latin | devanagari | …
  static const kOcrOutputs = 'ocr_outputs'; // JSON {pdf, review, txt}
  static const kOcrRotateRetry = 'ocr_rotate_retry';
  static const kScanMakeSearchable = 'scan_make_searchable';
  // 1.4 (RELEASE_V1_4 §5.1).
  static const kSavedSignatures = 'saved_signatures'; // JSON [{id, file, createdAt, kind}], max 3
  static const kSigColour = 'sig_last_colour'; // black | blue
  static const kSigThickness = 'sig_last_thickness'; // thin | medium | thick
  static const kWmkTextStyle = 'wmk_last_text_style'; // JSON, text watermarks only (FR-WMK-10)
  // 1.5 My Documents (RELEASE_V1_5 §5).
  static const kLibIntroSeen = 'lib_intro_seen';
  static const kLibView = 'lib_view'; // grid | list
  static const kLibSort = 'lib_sort'; // name | added | size | expiry
  static String draftKey(String tool) => 'draft_$tool';

  AppSettings load() {
    T e<T extends Enum>(String key, List<T> values, T fallback) => enumByName(values, _store.get(key), fallback);
    final q = _store.get(kImgQuality);
    return AppSettings(
      themeMode: e(kTheme, ThemeMode.values, ThemeMode.system),
      imgQuality: q is int ? q.clamp(10, 100) : 80,
      imgFormat: e(kImgFormat, OutputFormatChoice.values, OutputFormatChoice.same),
      imgStripMetadata: _bool(kStrip, true),
      resizeLockRatio: _bool(kLock, true),
      resizeCustomPresets: decodePresets(_store.get(kPresets) as String?),
      pdfPageSize: e(kPageSize, PdfPageSize.values, defaultPageSizeFor(_country)),
      pdfFit: e(kFit, PdfFit.values, PdfFit.fit),
      pdfMargin: e(kMargin, PdfMargin.values, PdfMargin.small),
      pdfImageQuality: e(kPdfQuality, PdfImageQuality.values, PdfImageQuality.high),
      reduceLevel: e(kReduce, ReduceLevel.values, ReduceLevel.balanced),
      outputRetention: e(kRetention, Retention.values, Retention.d7),
      confirmDestructive: _bool(kConfirm, true),
      onboardingDone: _bool(kOnboarding, false),
      lastTool: toolIdByName(_store.get(kLastTool) as String?),
      tourDone: _bool(kTourDone, false),
      tourVersion: _int(kTourVersion, 0),
      statsTotalSavedBytes: _int(kSavedBytes, 0),
      convertFormat: ImageFormat.values.firstWhere((f) => f.ext == _store.get(kConvertFormat), orElse: () => ImageFormat.jpeg),
      convertQuality: _int(kConvertQuality, 90).clamp(10, 100),
      splitMode: (_store.get(kSplitMode) as String?) ?? 'ranges',
      splitEveryN: _int(kSplitEveryN, 2) < 2 ? 2 : _int(kSplitEveryN, 2),
      p2iFormat: _store.get(kP2iFormat) == 'png' ? ImageFormat.png : ImageFormat.jpeg,
      p2iDpi: const [72, 150, 300].contains(_store.get(kP2iDpi)) ? _store.get(kP2iDpi)! as int : 150,
      favouriteTools: decodeFavourites(_store.get(kFavouriteTools) as String?),
      scanFormat: e(kScanFormat, ScanOutputFormat.values, ScanOutputFormat.pdf),
      scanPageSize: switch (_store.get(kScanPageSize)) {
        'a4' => ScanPageSize.a4,
        'letter' => ScanPageSize.letter,
        'fit' => ScanPageSize.fitToScan,
        // Same locale rule as Images to PDF (FR-SCN-14).
        _ => defaultPageSizeFor(_country) == PdfPageSize.letter ? ScanPageSize.letter : ScanPageSize.a4,
      },
      scanQuality: e(kScanQuality, ScanQuality.values, ScanQuality.high),
      ocrScript: e(kOcrScript, OcrScript.values, defaultOcrScriptFor(_language)),
      ocrOutputPdf: _ocrOutput('pdf', true),
      ocrOutputReview: _ocrOutput('review', true),
      ocrOutputTxt: _ocrOutput('txt', false),
      ocrRotateRetry: _bool(kOcrRotateRetry, true),
      scanMakeSearchable: _bool(kScanMakeSearchable, false),
    );
  }

  bool _ocrOutput(String key, bool fallback) {
    try {
      final v = (jsonDecode(_store.get(kOcrOutputs) as String? ?? '{}') as Map)[key];
      return v is bool ? v : fallback;
    } catch (_) {
      return fallback;
    }
  }

  int _int(String k, int d) {
    final v = _store.get(k);
    return v is int ? v : d;
  }

  bool _bool(String k, bool d) {
    final v = _store.get(k);
    return v is bool ? v : d;
  }

  Future<void> save(AppSettings s) async {
    await _store.setString(kTheme, s.themeMode.name);
    await _store.setInt(kImgQuality, s.imgQuality);
    await _store.setString(kImgFormat, s.imgFormat.name);
    await _store.setBool(kStrip, s.imgStripMetadata);
    await _store.setBool(kLock, s.resizeLockRatio);
    await _store.setString(kPresets, encodePresets(s.resizeCustomPresets));
    await _store.setString(kPageSize, s.pdfPageSize.name);
    await _store.setString(kFit, s.pdfFit.name);
    await _store.setString(kMargin, s.pdfMargin.name);
    await _store.setString(kPdfQuality, s.pdfImageQuality.name);
    await _store.setString(kReduce, s.reduceLevel.name);
    await _store.setString(kRetention, s.outputRetention.name);
    await _store.setBool(kConfirm, s.confirmDestructive);
    await _store.setBool(kOnboarding, s.onboardingDone);
    if (s.lastTool != null) await _store.setString(kLastTool, s.lastTool!.name);
    await _store.setBool(kTourDone, s.tourDone);
    await _store.setInt(kTourVersion, s.tourVersion);
    await _store.setInt(kSavedBytes, s.statsTotalSavedBytes);
    await _store.setString(kConvertFormat, s.convertFormat.ext);
    await _store.setInt(kConvertQuality, s.convertQuality);
    await _store.setString(kSplitMode, s.splitMode);
    await _store.setInt(kSplitEveryN, s.splitEveryN);
    await _store.setString(kP2iFormat, s.p2iFormat.ext);
    await _store.setInt(kP2iDpi, s.p2iDpi);
    await _store.setString(kFavouriteTools, jsonEncode([for (final t in s.favouriteTools) t.name]));
    await _store.setString(kScanFormat, s.scanFormat.name);
    await _store.setString(kScanPageSize, s.scanPageSize == ScanPageSize.fitToScan ? 'fit' : s.scanPageSize.name);
    await _store.setString(kScanQuality, s.scanQuality.name);
    await _store.setString(kOcrScript, s.ocrScript.name);
    await _store.setString(kOcrOutputs, jsonEncode({'pdf': s.ocrOutputPdf, 'review': s.ocrOutputReview, 'txt': s.ocrOutputTxt}));
    await _store.setBool(kOcrRotateRetry, s.ocrRotateRetry);
    await _store.setBool(kScanMakeSearchable, s.scanMakeSearchable);
  }

  String? readDraft(String tool) => _store.get(draftKey(tool)) as String?;

  bool readLibIntroSeen() => _store.get(kLibIntroSeen) == true;
  Future<void> writeLibIntroSeen() => _store.setBool(kLibIntroSeen, true);
  (String?, String?) readLibView() => (_store.get(kLibView) as String?, _store.get(kLibSort) as String?);
  Future<void> writeLibView(String view, String sort) async {
    await _store.setString(kLibView, view);
    await _store.setString(kLibSort, sort);
  }

  String? readWatermarkStyle() => _store.get(kWmkTextStyle) as String?;
  Future<void> writeWatermarkStyle(String json) => _store.setString(kWmkTextStyle, json);

  String? readSavedSignatures() => _store.get(kSavedSignatures) as String?;
  Future<void> writeSavedSignatures(String json) => _store.setString(kSavedSignatures, json);

  /// The draw pad's last colour / thickness (`InkColour` / `InkThickness` names).
  (String?, String?) readInkStyle() => (_store.get(kSigColour) as String?, _store.get(kSigThickness) as String?);
  Future<void> writeInkStyle(String colour, String thickness) async {
    await _store.setString(kSigColour, colour);
    await _store.setString(kSigThickness, thickness);
  }
  Future<void> writeDraft(String tool, String json) => _store.setString(draftKey(tool), json);
  Future<void> clearDraft(String tool) => _store.remove(draftKey(tool));
}

/// FR-FAV-04: known tool names only, each once, at most 6; anything else
/// (tools from other versions, junk) is dropped silently.
List<ToolId> decodeFavourites(String? raw) {
  if (raw == null) return const [];
  try {
    final out = <ToolId>[];
    for (final v in jsonDecode(raw) as List) {
      final id = v is String ? toolIdByName(v) : null;
      if (id != null && !out.contains(id)) out.add(id);
      if (out.length == 6) break;
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// RELEASE_V1_3 §5: Hindi and Marathi devices start on Devanagari (shipped,
/// ADR-045); everyone else on Latin.
OcrScript defaultOcrScriptFor(String? languageCode) =>
    const {'hi', 'mr'}.contains(languageCode) ? OcrScript.devanagari : OcrScript.latin;
