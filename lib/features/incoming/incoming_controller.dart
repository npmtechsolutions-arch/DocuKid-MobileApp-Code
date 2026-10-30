import 'dart:async';
import 'dart:io';

import 'package:docukit_native/docukit_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/files/mime_sniffer.dart';
import '../../core/files/paths.dart';
import '../../core/files/picked_file.dart';
import '../../core/providers.dart';
import '../search/tool_catalog.dart';
import 'incoming_matching.dart';

/// Files received from a share / "Open with", copied into their own draft
/// (`jobs/<draftId>/in/`) and inspected, waiting for the user to pick a tool
/// on S19.
class IncomingSession {
  const IncomingSession({
    required this.draftId,
    this.images = const [],
    this.pdfs = const [],
    this.unsupported = 0,
    this.imagesTruncated = false,
    this.pdfsTruncated = false,
  });

  final String draftId;
  final List<PickedFile> images, pdfs;

  /// Files that are neither an image DocuKit reads nor a PDF.
  final int unsupported;
  final bool imagesTruncated, pdfsTruncated;

  int get count => images.length + pdfs.length + unsupported;
  List<IncomingSection> get sections => matchIncoming(images: images.length, pdfs: pdfs.length);
}

/// FR-SHR-03/04/06: receives batches (cold start via [start], warm via the
/// stream), merges them into one session, and hands files to a tool.
class IncomingController extends Notifier<IncomingSession?> {
  StreamSubscription<IncomingBatch>? _sub;
  bool _started = false;

  @override
  IncomingSession? build() {
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  /// Called once after the first frame.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final native = ref.read(nativeProvider);
    _sub = native.incomingFiles.listen((b) => unawaited(receive(b)), onError: (_) {});
    for (final b in await native.getIncomingFiles()) {
      await receive(b);
    }
  }

  Future<void> receive(IncomingBatch batch) async {
    if (batch.files.isEmpty && batch.failed == 0) {
      if (batch.dir.isNotEmpty) unawaited(deleteQuietly(Directory(batch.dir)));
      return;
    }
    // Nothing could be read: S19 still opens, with the "can't work with" card,
    // so a share never silently does nothing (found on the emulator, R36).
    final current = state;
    final draftId = current?.draftId ?? 'incoming_${const Uuid().v7()}';
    final files = await ref.read(fileGatewayProvider).adoptIncoming(batch.files, draftId: draftId, sourceDir: batch.dir);
    final images = [...?current?.images];
    final pdfs = [...?current?.pdfs];
    var unsupported = current?.unsupported ?? 0;
    var imagesCut = current?.imagesTruncated ?? false, pdfsCut = current?.pdfsTruncated ?? false;
    for (final f in files) {
      if (f.type == SniffedType.pdf) {
        if (pdfs.length < incomingLimits.pdfs) {
          pdfs.add(f);
        } else {
          pdfsCut = true;
          unawaited(deleteQuietly(File(f.path))); // best effort; the temp sweep is the backstop
        }
      } else if (f.type.isSupportedImage) {
        if (images.length < incomingLimits.images) {
          images.add(f);
        } else {
          imagesCut = true;
          unawaited(deleteQuietly(File(f.path))); // best effort; the temp sweep is the backstop
        }
      } else {
        unsupported++;
        unawaited(deleteQuietly(File(f.path)));
      }
    }
    // The native side keeps at most 70 per share; anything beyond was dropped there.
    if (batch.truncated) {
      imagesCut = imagesCut || images.length >= incomingLimits.images;
      pdfsCut = pdfsCut || pdfs.length >= incomingLimits.pdfs;
    }
    unsupported += batch.failed;
    state = IncomingSession(
      draftId: draftId,
      images: images,
      pdfs: pdfs,
      unsupported: unsupported,
      imagesTruncated: imagesCut,
      pdfsTruncated: pdfsCut,
    );
  }

  /// S19 → a tool: the group's files go to that tool's screen (moved into its
  /// own draft when it opens); the incoming draft is then removed.
  void handTo(ToolId tool, IncomingKind kind) {
    final s = state;
    if (s == null) return;
    ref.read(incomingHandoffProvider.notifier).put(tool, kind == IncomingKind.images ? s.images : s.pdfs, s.draftId);
    state = null;
  }

  /// Cancel on S19: the temp copies are deleted (R36).
  Future<void> cancel() async {
    final s = state;
    state = null;
    if (s != null) await ref.read(fileGatewayProvider).discardDraft(s.draftId);
  }
}

final incomingProvider = NotifierProvider<IncomingController, IncomingSession?>(IncomingController.new);

/// Files waiting for a tool screen to open (its inputs provider is created
/// with the screen, so they can't be written into it beforehand).
class IncomingHandoff {
  const IncomingHandoff(this.tool, this.files, this.fromDraftId, {this.copy = false});
  final ToolId tool;
  final List<PickedFile> files;
  final String fromDraftId;

  /// Copy instead of move, and keep the source draft: "Unlock it first"
  /// (FR-UNL-08) leaves the file in the tool it came from.
  final bool copy;
}

class IncomingHandoffController extends Notifier<IncomingHandoff?> {
  @override
  IncomingHandoff? build() => null;

  void put(ToolId tool, List<PickedFile> files, String fromDraftId, {bool copy = false}) =>
      state = IncomingHandoff(tool, files, fromDraftId, copy: copy);

  /// The files for [tool], once.
  IncomingHandoff? take(ToolId tool) {
    final h = state;
    if (h == null || h.tool != tool) return null;
    state = null;
    return h;
  }
}

final incomingHandoffProvider = NotifierProvider<IncomingHandoffController, IncomingHandoff?>(IncomingHandoffController.new);
