// Release CI gate: refuses a release whose AdMob App ID or Phase A unit IDs
// are missing, malformed, or Google's sample/test IDs.
//
//   dart run tool/check_release_ads.dart --platform android --defines admob_android.json
//   dart run tool/check_release_ads.dart --platform ios     --defines admob_ios.json
//
// The defines file is the same JSON passed to
// `flutter build … --dart-define-from-file=<file>`. For iOS the App ID is read
// from ios/Flutter/AdMob.xcconfig (ADMOB_APP_ID_IOS).
import 'dart:convert';
import 'dart:io';

import 'package:docukit/core/ads/release_check.dart';

void main(List<String> args) {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final platform = switch (arg('--platform')) {
    'android' => AdsPlatform.android,
    'ios' => AdsPlatform.ios,
    _ => null,
  };
  final file = arg('--defines');
  if (platform == null || file == null) {
    stderr.writeln('usage: dart run tool/check_release_ads.dart --platform android|ios --defines <file.json>');
    exit(64);
  }

  final defines = <String, String>{};
  final f = File(file);
  if (f.existsSync()) {
    (jsonDecode(f.readAsStringSync()) as Map).forEach((k, v) => defines['$k'] = '$v');
  }

  String? iosAppId;
  if (platform == AdsPlatform.ios) {
    final xc = File('ios/Flutter/AdMob.xcconfig');
    if (xc.existsSync()) {
      final m = RegExp(r'^\s*ADMOB_APP_ID_IOS\s*=\s*(\S*)', multiLine: true).firstMatch(xc.readAsStringSync());
      iosAppId = m?.group(1);
    }
  }

  final problems = releaseAdsProblems(defines, platform: platform, iosAppId: iosAppId);
  if (problems.isEmpty) {
    stdout.writeln('AdMob release IDs OK (${platform.name}).');
    return;
  }
  stderr.writeln('Release build refused: AdMob IDs are not ready (${platform.name}).');
  for (final p in problems) {
    stderr.writeln('  • $p');
  }
  stderr.writeln('Paste your real IDs from AdMob (see docs/DocuKit_Ad_Map.xlsx, sheet "Ad units").');
  exit(1);
}
