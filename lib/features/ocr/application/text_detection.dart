import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// FR-OCR-02 / §4.6: which pages of the picked PDF already have text, keyed by
/// the input copy's path. Runs in the background while S30 shows "Checking for
/// text…"; Run waits for it (T10.6).
final pdfTextPagesProvider = FutureProvider.autoDispose.family<List<bool>, String>(
  (ref, path) => ref.watch(pdfTextReaderProvider).textPages(path),
);
