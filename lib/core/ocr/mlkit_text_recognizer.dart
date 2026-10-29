import 'dart:io';
import 'dart:math' show Point;

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;

import '../errors/app_error.dart';
import '../image/image_header.dart';
import 'text_recognizer.dart';

/// Scripts whose models ship inside the app (ADR-045, owner decision
/// 2026-10-29): Android bundles Latin (the plugin's dependency) and
/// Devanagari (`android/app/build.gradle.kts`). iOS has Latin until the Xcode
/// round measures the Devanagari pod against the 60 MB rule.
Set<OcrScript> bundledScripts({required bool android}) =>
    android ? const {OcrScript.latin, OcrScript.devanagari} : const {OcrScript.latin};

mlkit.TextRecognitionScript mlkitScript(OcrScript s) => switch (s) {
      OcrScript.latin => mlkit.TextRecognitionScript.latin,
      // The plugin spells it this way (0.17.1).
      OcrScript.devanagari => mlkit.TextRecognitionScript.devanagiri,
      OcrScript.chinese => mlkit.TextRecognitionScript.chinese,
      OcrScript.japanese => mlkit.TextRecognitionScript.japanese,
      OcrScript.korean => mlkit.TextRecognitionScript.korean,
    };

/// ML Kit's blocks → lines (in ML Kit's order; §4.5 sorts them later) and
/// elements → words. Blank elements and lines are dropped.
OcrPage ocrPageFrom(mlkit.RecognizedText r, {required int imageWidth, required int imageHeight}) {
  List<Offset> corners(List<Point<int>> points) => [for (final p in points) Offset(p.x.toDouble(), p.y.toDouble())];
  final lines = <OcrLine>[];
  for (final b in r.blocks) {
    for (final l in b.lines) {
      final words = [
        for (final e in l.elements)
          if (e.text.trim().isNotEmpty)
            OcrWord(text: e.text.trim(), box: e.boundingBox, corners: corners(e.cornerPoints), confidence: e.confidence),
      ];
      if (words.isEmpty) continue;
      lines.add(OcrLine(text: l.text.trim(), box: l.boundingBox, corners: corners(l.cornerPoints), words: words));
    }
  }
  return OcrPage(imageWidth: imageWidth, imageHeight: imageHeight, lines: lines);
}

/// `google_mlkit_text_recognition` (ADR-046 lists the verified API). One
/// recogniser per script, kept for the job and closed in [dispose].
class MlKitTextRecognizer implements TextRecognizer {
  MlKitTextRecognizer({Set<OcrScript>? scripts}) : _scripts = scripts ?? bundledScripts(android: Platform.isAndroid);

  final Set<OcrScript> _scripts;
  final _open = <OcrScript, mlkit.TextRecognizer>{};

  @override
  Future<Set<OcrScript>> availableScripts() async => _scripts;

  @override
  Future<void> ensureModel(OcrScript script) async {
    // Bundled models need no download; a script that isn't shipped can't run.
    if (!_scripts.contains(script)) throw AppError(AppErrorCode.ocrModelUnavailable, script: script.name);
  }

  @override
  Future<OcrPage> recognize(String imagePath, OcrScript script) async {
    await ensureModel(script);
    final ImageHeader header;
    try {
      header = await readImageHeader(imagePath);
    } on ImageHeaderException {
      throw const AppError(AppErrorCode.corruptFile);
    } on FileSystemException {
      // The pipeline's own page file went missing.
      throw const AppError(AppErrorCode.processingFailed);
    }
    final recognizer = _open.putIfAbsent(script, () => mlkit.TextRecognizer(script: mlkitScript(script)));
    try {
      final r = await recognizer.processImage(mlkit.InputImage.fromFilePath(imagePath));
      return ocrPageFrom(r, imageWidth: header.displayWidth, imageHeight: header.displayHeight);
    } on PlatformException {
      throw const AppError(AppErrorCode.processingFailed);
    }
  }

  @override
  Future<void> dispose() async {
    final open = _open.values.toList();
    _open.clear();
    for (final r in open) {
      await r.close();
    }
  }
}
