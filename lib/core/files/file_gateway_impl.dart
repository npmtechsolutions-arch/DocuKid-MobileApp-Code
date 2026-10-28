import 'dart:io';
import 'dart:ui' show Rect;

import 'package:docukit_native/docukit_native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../errors/app_error.dart';
import '../image/image_engine.dart';
import '../pdf/pdf_engine.dart';
import '../validation/input_validator.dart';
import 'file_gateway.dart';
import 'file_naming.dart';
import 'mime_sniffer.dart';
import 'paths.dart';
import 'picked_file.dart';

/// Plugin-backed gateway.
///
/// Pickers (spike T1.2 decision, DECISIONS ADR-021):
/// - Android images: `image_picker` → Android Photo Picker (no permission);
///   with no resize/quality options it copies the original bytes.
/// - iOS images: `file_picker` `FileType.image` → PHPicker with
///   `DarwinAssetRepresentationMode.current` so HEIC isn't transcoded.
/// - PDFs (both): `file_picker` custom `pdf` → SAF OPEN_DOCUMENT /
///   UIDocumentPickerViewController; the plugin copies into the app cache.
class PluginFileGateway implements FileGateway {
  PluginFileGateway({
    required this.paths,
    required this.images,
    required this.pdfs,
    required this.native,
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker ?? ImagePicker();

  final AppPaths paths;
  final ImageEngine images;
  final PdfEngine pdfs;
  final DocukitNative native;
  final ImagePicker _imagePicker;

  int _seq = 0;

  @override
  Future<PickResult> pickImages({required String draftId, required int max}) async {
    final picked = <(String path, String name)>[];
    if (Platform.isIOS) {
      const opts = DarwinOptions(assetRepresentationMode: DarwinAssetRepresentationMode.current);
      if (max == 1) {
        final f = await FilePicker.pickFile(type: FileType.image, darwinOptions: opts);
        if (f?.path != null) picked.add((f!.path!, f.name));
      } else {
        final fs = await FilePicker.pickFiles(type: FileType.image, darwinOptions: opts);
        for (final f in fs) {
          if (f.path != null) picked.add((f.path!, f.name));
        }
      }
    } else {
      if (max == 1) {
        final x = await _imagePicker.pickImage(source: ImageSource.gallery, requestFullMetadata: false);
        if (x != null) picked.add((x.path, x.name));
      } else {
        final xs = await _imagePicker.pickMultiImage(limit: max, requestFullMetadata: false);
        for (final x in xs) {
          picked.add((x.path, x.name));
        }
      }
    }
    return _intake(draftId, picked, max: max, pdf: false);
  }

  @override
  Future<PickResult> pickPdfs({required String draftId, required bool multiple, int max = 20}) async {
    final picked = <(String, String)>[];
    if (multiple) {
      final fs = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
      for (final f in fs) {
        if (f.path != null) picked.add((f.path!, f.name));
      }
    } else {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
      if (f?.path != null) picked.add((f!.path!, f.name));
    }
    return _intake(draftId, picked, max: multiple ? max : 1, pdf: true);
  }

  Future<PickResult> _intake(String draftId, List<(String, String)> picked, {required int max, required bool pdf}) async {
    if (picked.isEmpty) return const PickResult.cancelled();
    final truncated = picked.length > max;
    final keep = truncated ? picked.sublist(0, max) : picked;
    final inDir = paths.jobIn(draftId);
    await inDir.create(recursive: true);
    final out = <PickedFile>[];
    var tooLarge = 0;
    for (final (src, name) in keep) {
      final display = name.isEmpty ? p.basename(src) : name;
      int size;
      try {
        size = await File(src).length();
      } on FileSystemException {
        out.add(PickedFile(
          path: src,
          displayName: display,
          type: SniffedType.unknown,
          sizeBytes: 0,
          status: const ValidationStatus.invalid(AppErrorCode.permissionLost),
        ));
        continue;
      }
      if (sizeGate(pdf: pdf, sizeBytes: size) != null) {
        tooLarge++;
        await _dropPluginCopy(src);
        continue;
      }
      final dest = p.join(inDir.path, '${_seq++}_${safeBaseName(display, removeExtension: false)}');
      try {
        await _adopt(src, dest);
      } on FileSystemException {
        out.add(PickedFile(
          path: src,
          displayName: display,
          type: SniffedType.unknown,
          sizeBytes: size,
          status: const ValidationStatus.invalid(AppErrorCode.permissionLost),
        ));
        continue;
      }
      out.add(await _inspect(dest, display, size, pdf: pdf));
    }
    return PickResult(out, truncated: truncated, rejectedTooLarge: tooLarge);
  }

  /// Plugins hand back a copy in our own cache; move it (fast, no extra
  /// space). Anything outside the app's directories is only ever copied, so a
  /// user's file can never be moved or modified (rule 1).
  Future<void> _adopt(String src, String dest) async {
    if (_isAppOwned(src)) {
      try {
        await File(src).rename(dest);
        return;
      } on FileSystemException {
        // Cross-device: fall through to copy.
      }
    }
    await File(src).copy(dest);
    if (_isAppOwned(src)) await _dropPluginCopy(src);
  }

  bool _isAppOwned(String path) {
    final abs = p.normalize(File(path).absolute.path);
    return p.isWithin(paths.cacheRoot.path, abs) || p.isWithin(paths.supportRoot.path, abs);
  }

  Future<void> _dropPluginCopy(String src) async {
    if (!_isAppOwned(src)) return;
    try {
      await File(src).delete();
    } on FileSystemException {
      // Plugin cache; the launch sweep handles leftovers.
    }
  }

  Future<PickedFile> _inspect(String path, String display, int size, {required bool pdf}) async {
    final type = await sniffFile(path);
    if (pdf || type == SniffedType.pdf) {
      PdfMeta? meta;
      AppErrorCode? err;
      if (type == SniffedType.pdf) {
        try {
          meta = await pdfs.inspect(path);
        } on AppError catch (e) {
          err = e.code;
        }
      }
      return PickedFile(
        path: path,
        displayName: display,
        type: type,
        sizeBytes: size,
        pdf: meta,
        status: validatePdfFile(type: type, sizeBytes: size, meta: meta, inspectError: err),
      );
    }
    ImageMeta? meta;
    AppErrorCode? err;
    if (type.isSupportedImage) {
      try {
        meta = await images.inspect(path);
      } on AppError catch (e) {
        err = e.code;
      }
    }
    return PickedFile(
      path: path,
      displayName: display,
      type: type,
      sizeBytes: size,
      image: meta,
      status: validateImageFile(type: type, sizeBytes: size, meta: meta, inspectError: err),
    );
  }

  @override
  Future<List<PickedFile>> reinspect(List<PickedFile> files) async {
    final out = <PickedFile>[];
    for (final f in files) {
      if (!await File(f.path).exists()) continue;
      out.add(await _inspect(f.path, f.displayName, await File(f.path).length(), pdf: f.isPdf));
    }
    return out;
  }

  @override
  Future<SaveOutcome> saveAs(String path, {required String suggestedName, required String mime}) async {
    final r = await native.saveAs(path, suggestedName: suggestedName, mime: mime);
    return switch (r) {
      NativeSaved(:final displayName) => Saved(displayName),
      NativeSaveCancelled() => const SaveCancelled(),
      NativeSaveFailed() => const SaveFailed(),
    };
  }

  @override
  Future<SaveOutcome> saveToPhotos(String path) async {
    try {
      // iOS: no album → add-only permission (NSPhotoLibraryAddUsageDescription).
      // Android: Pictures/DocuKit via MediaStore.
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return const PhotosAccessDenied();
      }
      await Gal.putImage(path, album: Platform.isAndroid ? 'DocuKit' : null);
      return const Saved();
    } on GalException catch (e) {
      return e.type == GalExceptionType.accessDenied ? const PhotosAccessDenied() : const SaveFailed();
    } catch (_) {
      return const SaveFailed();
    }
  }

  @override
  Future<SaveManyOutcome> saveManyToFolder(List<SaveItem> items) async {
    if (items.isEmpty) return const SaveManyFailed();
    final names = uniqueNames([for (final i in items) i.name]);
    final r = await native.saveManyToFolder([
      for (var i = 0; i < items.length; i++) (path: items[i].path, name: names[i], mime: items[i].mime),
    ]);
    return switch (r) {
      NativeSavedMany(:final saved, :final failed, :final failedIndexes, :final folderName) =>
        SavedMany(saved: saved, failed: failed, failedIndexes: failedIndexes, folderName: folderName),
      NativeSaveManyCancelled() => const SaveManyCancelled(),
      NativeSaveManyFailed() => const SaveManyFailed(),
    };
  }

  @override
  Future<ShareOutcome> share(List<String> paths, {required String mime, Rect? origin}) async {
    if (paths.length > Limits.maxShareFiles) return ShareOutcome.tooMany;
    try {
      final r = await SharePlus.instance.share(ShareParams(
        files: [for (final x in paths) XFile(x, mimeType: mime)],
        sharePositionOrigin: origin,
      ));
      return switch (r.status) {
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        _ => ShareOutcome.shared,
      };
    } catch (_) {
      return ShareOutcome.failed;
    }
  }

  @override
  Future<bool> openWith(String path, {required String mime, Rect? origin}) =>
      native.openWith(path, mime: mime, origin: origin);

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> discardDraft(String draftId) => deleteQuietly(paths.jobDir(draftId));
}
