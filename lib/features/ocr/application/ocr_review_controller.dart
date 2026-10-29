import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/files/file_naming.dart';
import '../../../core/ocr/ocr_text_file.dart';
import '../../../core/providers.dart';
import 'ocr_review_files.dart';

/// S31 state (RELEASE_V1_3 §3.3). Edits live here only: they change what is
/// copied, shared or saved as `.txt`, never the PDF or the recognised text.
class OcrReviewState {
  const OcrReviewState({this.files, this.edits = const {}, this.loading = true, this.unavailable = false, this.tooLong = false});

  final OcrReviewFiles? files;
  final Map<int, String> edits;
  final bool loading;

  /// The review folder is gone (Result was left, or the app restarted).
  final bool unavailable;

  /// More than [OcrReviewController.maxEditableBytes] of text: editing off.
  final bool tooLong;

  bool get edited => edits.isNotEmpty;
  bool isEdited(int page) => edits.containsKey(page);

  OcrReviewState copyWith({OcrReviewFiles? files, Map<int, String>? edits, bool? loading, bool? unavailable, bool? tooLong}) =>
      OcrReviewState(
        files: files ?? this.files,
        edits: edits ?? this.edits,
        loading: loading ?? this.loading,
        unavailable: unavailable ?? this.unavailable,
        tooLong: tooLong ?? this.tooLong,
      );
}

/// What Share sends: the text, or a `.txt` file when the text is long.
typedef ShareableText = ({String? text, String? filePath});

class OcrReviewController extends Notifier<OcrReviewState> {
  OcrReviewController(this.jobId);
  final String jobId;

  static const maxShareChars = 100000;
  static const maxEditableBytes = 2 * 1024 * 1024;

  late String _dir;
  final _original = <int, String>{};

  @override
  OcrReviewState build() {
    _dir = ref.read(appPathsProvider).reviewDir(jobId).path;
    unawaited(_load());
    return const OcrReviewState();
  }

  Future<void> _load() async {
    try {
      final files = await OcrReviewFiles.read(_dir);
      var bytes = 0;
      for (var i = 0; i < files.pages.length; i++) {
        final f = File(OcrReviewFiles.textPath(_dir, i));
        if (await f.exists()) bytes += await f.length();
      }
      if (!ref.mounted) return;
      state = state.copyWith(files: files, loading: false, tooLong: bytes > maxEditableBytes);
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, unavailable: true);
    }
  }

  /// The page as shown: the edit, or the recognised text (read once).
  Future<String> textOf(int i) async => state.edits[i] ?? await _originalOf(i);

  Future<String> _originalOf(int i) async => _original[i] ??= await state.files!.text(i);

  void edit(int i, String text) => state = state.copyWith(edits: {...state.edits, i: text});

  /// Like [edit], but an edit back to the recognised text isn't an edit.
  Future<void> editChecked(int i, String text) async {
    if (text == await _originalOf(i)) {
      state = state.copyWith(edits: {...state.edits}..remove(i));
    } else {
      edit(i, text);
    }
  }

  Future<List<String>> _all() async => [for (var i = 0; i < (state.files?.pages.length ?? 0); i++) await textOf(i)];

  /// Copy all: pages joined by a blank line, no markers.
  Future<String> allText() async => joinForCopy(await _all());

  Future<ShareableText> shareable() async {
    final text = await allText();
    if (text.length <= maxShareChars) return (text: text, filePath: null);
    final path = p.join(_dir, ocrTxtName(state.files!.baseName));
    await File(path).writeAsString(text, flush: true);
    return (text: null, filePath: path);
  }

  /// Save .txt (S12): the edited text with page markers (FR-OCR-09), inside
  /// the review folder so it goes when the folder goes.
  Future<String> writeTxt() async {
    final path = p.join(_dir, ocrTxtName(state.files!.baseName));
    await File(path).writeAsString(formatOcrTxt(await _all()), flush: true);
    return path;
  }
}

final ocrReviewProvider =
    NotifierProvider.autoDispose.family<OcrReviewController, OcrReviewState, String>(OcrReviewController.new);

/// Copy text on Result (FR-OCR-16): the review folder's pages, or the `.txt`
/// output's pages when only that was chosen.
Future<String> ocrTextForCopy({String? reviewDir, String? txtPath}) async {
  if (reviewDir != null && await Directory(reviewDir).exists()) {
    final files = await OcrReviewFiles.read(reviewDir);
    return joinForCopy([for (var i = 0; i < files.pages.length; i++) await files.text(i)]);
  }
  if (txtPath != null && await File(txtPath).exists()) return joinForCopy(pagesFromTxt(await File(txtPath).readAsString()));
  return '';
}

/// S32's text card for a job without a PDF: the first 6 lines (§3.4).
final ocrTextPreviewProvider = FutureProvider.autoDispose.family<String, ({String? reviewDir, String? txtPath})>(
  (ref, src) async {
    final text = await ocrTextForCopy(reviewDir: src.reviewDir, txtPath: src.txtPath);
    return text.split('\n').where((line) => line.trim().isNotEmpty).take(6).join('\n');
  },
);
