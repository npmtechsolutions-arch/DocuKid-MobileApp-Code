import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/files/file_gateway.dart';
import '../../core/files/picked_file.dart';
import '../../core/providers.dart';
import '../../core/validation/input_validator.dart';
import '../search/tool_catalog.dart';
import 'options_draft.dart';

/// Inputs for one tool screen, always copies in `jobs/<draftId>/in`.
class ToolInputs {
  const ToolInputs({
    required this.draftId,
    this.files = const [],
    this.rotations = const [],
    this.picking = false,
    this.restored = false,
    this.lastPick,
  });

  final String draftId;
  final List<PickedFile> files;

  /// Per-file extra quarter turns (Images → PDF).
  final List<int> rotations;
  final bool picking;

  /// Draft restored after process death (S-global "Restored your last session.").
  final bool restored;

  /// The latest pick result, for one-shot messages (truncated, too large).
  final PickResult? lastPick;

  bool get isEmpty => files.isEmpty;
  List<PickedFile> get valid => files.where((f) => f.status.isValid).toList();
  int get invalidCount => files.length - valid.length;
  int get totalBytes => files.fold(0, (s, f) => s + f.sizeBytes);
  int get totalPages => files.fold(0, (s, f) => s + (f.pdf?.pageCount ?? 0));
  PickedFile? get single => files.isEmpty ? null : files.first;

  ToolInputs copyWith({
    List<PickedFile>? files,
    List<int>? rotations,
    bool? picking,
    bool? restored,
    PickResult? lastPick,
    bool clearLastPick = false,
  }) =>
      ToolInputs(
        draftId: draftId,
        files: files ?? this.files,
        rotations: rotations ?? this.rotations,
        picking: picking ?? this.picking,
        restored: restored ?? this.restored,
        lastPick: clearLastPick ? null : (lastPick ?? this.lastPick),
      );
}

const _draftTtl = Duration(hours: 24);

class ToolInputsController extends Notifier<ToolInputs> {
  ToolInputsController(this.tool);
  final ToolId tool;
  late String _draftId;

  ToolDescriptor get descriptor => toolById(tool);

  @override
  ToolInputs build() {
    final restored = _readDraft();
    final draftId = restored?.draftId ?? const Uuid().v7();
    _draftId = draftId;
    // `ref` can't be used inside onDispose (Riverpod 3), so capture now.
    final repo = ref.read(settingsRepositoryProvider);
    final gateway = ref.read(fileGatewayProvider);
    ref.onDispose(() {
      // Leaving the screen (D4, Done, back) discards the copies and the draft.
      // Process death never runs this, so the draft survives for FR-LIFE-03.
      unawaited(repo.clearDraft(tool.name));
      unawaited(repo.clearDraft(optionsDraftKey(tool)));
      unawaited(gateway.discardDraft(_draftId));
    });
    if (restored != null) {
      // Re-check the files still exist and are valid.
      Future.microtask(() async {
        final files = await ref.read(fileGatewayProvider).reinspect(restored.files);
        if (!ref.mounted) return;
        if (files.isEmpty) {
          state = ToolInputs(draftId: draftId);
        } else {
          state = state.copyWith(files: files, rotations: _fit(restored.rotations, files.length), restored: true);
        }
      });
    }
    return ToolInputs(draftId: draftId);
  }

  ToolInputs? _readDraft() {
    final raw = ref.read(settingsRepositoryProvider).readDraft(tool.name);
    if (raw == null) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
      if (ref.read(clockProvider)().difference(at) > _draftTtl) return null;
      final files = [for (final f in j['files'] as List) PickedFile.fromJson((f as Map).cast<String, dynamic>())];
      if (files.isEmpty) return null;
      return ToolInputs(
        draftId: j['id'] as String,
        files: files,
        rotations: [for (final r in (j['rot'] as List? ?? const [])) r as int],
      );
    } catch (_) {
      return null;
    }
  }

  List<int> _fit(List<int> r, int n) => [for (var i = 0; i < n; i++) i < r.length ? r[i] : 0];

  Future<void> _persist() async {
    if (state.files.isEmpty) {
      await ref.read(settingsRepositoryProvider).clearDraft(tool.name);
      return;
    }
    await ref.read(settingsRepositoryProvider).writeDraft(
          tool.name,
          jsonEncode({
            'id': state.draftId,
            'at': ref.read(clockProvider)().millisecondsSinceEpoch,
            'files': [for (final f in state.files) f.toJson()],
            'rot': state.rotations,
          }),
        );
  }

  int get _remaining => descriptor.maxInputs - state.files.length;

  /// Opens the system picker. [replace] swaps the single input (Change).
  Future<void> pick({bool replace = false}) async {
    if (state.picking) return;
    final single = descriptor.maxInputs == 1;
    final max = single || replace ? 1 : _remaining;
    if (max <= 0) {
      state = state.copyWith(lastPick: const PickResult([], truncated: true));
      return;
    }
    state = state.copyWith(picking: true, clearLastPick: true);
    final gateway = ref.read(fileGatewayProvider);
    PickResult r;
    try {
      r = switch (descriptor.inputKind) {
        InputKind.images || InputKind.singleImage => await gateway.pickImages(draftId: state.draftId, max: max),
        InputKind.pdfs => await gateway.pickPdfs(draftId: state.draftId, multiple: true, max: max),
        InputKind.singlePdf => await gateway.pickPdfs(draftId: state.draftId, multiple: false),
      };
    } catch (_) {
      r = const PickResult.cancelled();
    }
    if (!ref.mounted) return;
    if (r.isEmpty && r.rejectedTooLarge == 0) {
      // Picker cancelled: nothing happens (global state matrix).
      state = state.copyWith(picking: false);
      return;
    }
    final files = single || replace ? r.files : [...state.files, ...r.files];
    final rotations = single || replace ? List.filled(files.length, 0) : [...state.rotations, ...List.filled(r.files.length, 0)];
    state = state.copyWith(files: files, rotations: rotations, picking: false, lastPick: r, restored: false);
    await _persist();
  }

  void remove(int index) {
    if (index < 0 || index >= state.files.length) return;
    final files = [...state.files]..removeAt(index);
    final rot = [...state.rotations]..removeAt(index);
    state = state.copyWith(files: files, rotations: rot);
    unawaited(_persist());
  }

  void move(int from, int to) {
    if (from == to || from < 0 || from >= state.files.length) return;
    final files = [...state.files];
    final rot = [...state.rotations];
    final f = files.removeAt(from);
    final r = rot.removeAt(from);
    final at = to.clamp(0, files.length);
    files.insert(at, f);
    rot.insert(at, r);
    state = state.copyWith(files: files, rotations: rot);
    unawaited(_persist());
  }

  void rotate(int index) {
    final rot = [...state.rotations];
    rot[index] = (rot[index] + 1) % 4;
    state = state.copyWith(rotations: rot);
    unawaited(_persist());
  }

  void removeInvalid() {
    final keep = <int>[];
    for (var i = 0; i < state.files.length; i++) {
      if (state.files[i].status.isValid) keep.add(i);
    }
    state = state.copyWith(
      files: [for (final i in keep) state.files[i]],
      rotations: [for (final i in keep) state.rotations[i]],
    );
    unawaited(_persist());
  }

  /// "Start over" after a restore.
  Future<void> clear() async {
    final old = state.draftId;
    _draftId = const Uuid().v7();
    state = ToolInputs(draftId: _draftId);
    await ref.read(settingsRepositoryProvider).clearDraft(tool.name);
    await ref.read(fileGatewayProvider).discardDraft(old);
  }

  void acknowledgeRestore() => state = state.copyWith(restored: false);
  void acknowledgePick() => state = state.copyWith(clearLastPick: true);
}

final toolInputsProvider =
    NotifierProvider.autoDispose.family<ToolInputsController, ToolInputs, ToolId>(ToolInputsController.new);

bool isLarge(ToolInputs i) => i.totalBytes > Limits.largeFileBytes;
