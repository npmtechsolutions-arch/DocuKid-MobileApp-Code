import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/providers.dart';
import 'signature_models.dart';
import 'signature_repository.dart';

final signatureRepositoryProvider = Provider<SignatureRepository>((ref) => SignatureRepository(
      ref.watch(settingsRepositoryProvider),
      Directory(p.join(ref.watch(appPathsProvider).supportRoot.path, 'signatures')),
      protect: ref.watch(deviceServicesProvider).protectOutput,
      clock: ref.watch(clockProvider),
    ));

/// The saved signatures, for S33's tiles and Settings → Saved signatures.
class SavedSignaturesController extends Notifier<List<SavedSignature>> {
  SignatureRepository get _repo => ref.read(signatureRepositoryProvider);

  @override
  List<SavedSignature> build() => ref.watch(signatureRepositoryProvider).list();

  Future<SavedSignature> save(String pngPath, SignatureKind kind) async {
    final s = await _repo.save(pngPath, kind);
    state = _repo.list();
    return s;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = _repo.list();
  }

  Future<void> deleteAll() async {
    await _repo.deleteAll();
    state = const [];
  }
}

final savedSignaturesProvider =
    NotifierProvider<SavedSignaturesController, List<SavedSignature>>(SavedSignaturesController.new);
