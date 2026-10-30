import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../data/settings/settings_repository.dart';
import 'signature_models.dart';

class SignatureLimitReached implements Exception {
  const SignatureLimitReached();
}

/// Saved signatures (RELEASE_V1_4 FR-SIG-10, §5.1–5.2, ADR-050): only when
/// the user says Save; at most [max]; files in `appSupport/signatures/`,
/// excluded from backups ([protect] — iOS `isExcludedFromBackup`; Android
/// excludes all app data, ADR-023); deleting removes the file at once.
class SignatureRepository {
  SignatureRepository(this._settings, this.dir, {required Future<void> Function(String path) protect, DateTime Function()? clock})
      : _protect = protect,
        _now = clock ?? DateTime.now;
  final SettingsRepository _settings;
  final Directory dir;
  final Future<void> Function(String path) _protect;
  final DateTime Function() _now;

  static const max = 3;

  List<SavedSignature> _index() {
    final raw = _settings.readSavedSignatures();
    if (raw == null) return const [];
    try {
      return [for (final j in jsonDecode(raw) as List) SavedSignature.fromJson((j as Map).cast<String, dynamic>())];
    } catch (_) {
      return const [];
    }
  }

  /// Oldest first; only signatures whose file still exists.
  List<SavedSignature> list() => _index().where((s) => File(pathOf(s)).existsSync()).toList();

  bool get isFull => list().length >= max;

  String pathOf(SavedSignature s) => p.join(dir.path, s.file);

  /// Copies [pngPath] in. Throws [SignatureLimitReached] when [isFull].
  Future<SavedSignature> save(String pngPath, SignatureKind kind) async {
    final current = list();
    if (current.length >= max) throw const SignatureLimitReached();
    await dir.create(recursive: true);
    await _protect(dir.path);
    final id = const Uuid().v4();
    final s = SavedSignature(id: id, file: '$id.png', createdAt: _now(), kind: kind);
    await File(pngPath).copy(pathOf(s));
    await _protect(pathOf(s));
    await _write([...current, s]);
    return s;
  }

  Future<void> delete(String id) async {
    final all = _index();
    for (final s in all.where((s) => s.id == id)) {
      await _deleteFile(pathOf(s));
    }
    await _write(all.where((s) => s.id != id).toList());
  }

  /// Settings → Saved signatures → Delete all (D2). Clear history doesn't call this.
  Future<void> deleteAll() async {
    if (await dir.exists()) {
      for (final f in dir.listSync().whereType<File>()) {
        await _deleteFile(f.path);
      }
    }
    await _write(const []);
  }

  Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  Future<void> _write(List<SavedSignature> all) =>
      _settings.writeSavedSignatures(jsonEncode([for (final s in all) s.toJson()]));
}
