import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../pdf/pdf_engine.dart';
import '../providers.dart';
import 'common.dart';

/// LRU of rendered pages, capped by bytes (ARCHITECTURE §10). Consumers get
/// `clone()` handles, so eviction never invalidates an image on screen.
class PdfThumbnailCache {
  PdfThumbnailCache(this._engine, {this.maxBytes = 64 * 1024 * 1024});
  final PdfEngine _engine;
  final int maxBytes;
  final _lru = <String, ui.Image>{}; // insertion-ordered → LRU
  final _inflight = <String, Future<ui.Image?>>{};
  var _bytes = 0;

  static String keyOf(String path, int index, int width) => '$path#$index@$width';

  Future<ui.Image?> get(String path, int index, int widthPx) {
    final key = keyOf(path, index, widthPx);
    final hit = _lru.remove(key);
    if (hit != null) {
      _lru[key] = hit;
      return Future.value(hit.clone());
    }
    final pending = _inflight[key] ??= _render(key, path, index, widthPx);
    return pending.then((img) => img?.clone());
  }

  Future<ui.Image?> _render(String key, String path, int index, int widthPx) async {
    try {
      final img = await _engine.renderPage(path, index, targetWidthPx: widthPx);
      if (img == null) return null;
      _lru[key] = img;
      _bytes += img.width * img.height * 4;
      _evict();
      return img;
    } catch (_) {
      return null;
    } finally {
      _inflight.remove(key)?.ignore();
    }
  }

  void _evict() {
    while (_bytes > maxBytes && _lru.isNotEmpty) {
      final k = _lru.keys.first;
      final img = _lru.remove(k)!;
      _bytes -= img.width * img.height * 4;
      img.dispose();
    }
  }

  /// Memory pressure / document closed.
  void clear([String? path]) {
    final keys = path == null ? _lru.keys.toList() : _lru.keys.where((k) => k.startsWith('$path#')).toList();
    for (final k in keys) {
      final img = _lru.remove(k)!;
      _bytes -= img.width * img.height * 4;
      img.dispose();
    }
  }
}

final thumbnailCacheProvider = Provider<PdfThumbnailCache>((ref) => PdfThumbnailCache(ref.watch(pdfEngineProvider)));

/// Lazily rendered page thumbnail at `width × dpr`.
class PdfThumbnail extends ConsumerStatefulWidget {
  const PdfThumbnail({
    super.key,
    required this.path,
    required this.pageIndex,
    required this.width,
    this.quarterTurns = 0,
    this.elevated = false,
    this.aspect,
  });
  final String path;
  final int pageIndex;
  final double width;
  final int quarterTurns;
  final bool elevated;

  /// Page width/height if known, so the placeholder has the right shape.
  final double? aspect;

  @override
  ConsumerState<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends ConsumerState<PdfThumbnail> {
  ui.Image? _image;
  bool _failed = false;
  int _gen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_image == null && !_failed) _load();
  }

  @override
  void didUpdateWidget(PdfThumbnail old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.pageIndex != widget.pageIndex || old.width != widget.width) {
      _image?.dispose();
      _image = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final gen = ++_gen;
    final px = (widget.width * MediaQuery.devicePixelRatioOf(context)).round().clamp(32, 1600);
    final img = await ref.read(thumbnailCacheProvider).get(widget.path, widget.pageIndex, px);
    if (!mounted || gen != _gen) {
      img?.dispose();
      return;
    }
    setState(() {
      _image = img;
      _failed = img == null;
    });
  }

  @override
  void dispose() {
    _gen++;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final aspect = img != null ? img.width / img.height : (widget.aspect ?? 1 / 1.414);
    Widget child;
    if (img != null) {
      child = RawImage(image: img, fit: BoxFit.contain);
    } else if (_failed) {
      child = Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x1),
          child: Text(
            context.l10n.orgCantPreview,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(color: Colors.black54),
          ),
        ),
      );
    } else {
      child = const SizedBox.expand();
    }
    final page = AspectRatio(
      aspectRatio: aspect,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        child: Container(
          key: ValueKey(img != null),
          decoration: BoxDecoration(
            color: img == null && !_failed ? const Color(0xFFF1F1F4) : Colors.white,
            borderRadius: BorderRadius.circular(Radii.xs),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: widget.elevated
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
    return SizedBox(
      width: widget.width,
      child: widget.quarterTurns % 4 == 0 ? page : RotatedBox(quarterTurns: widget.quarterTurns, child: page),
    );
  }
}

/// Stands in for [PdfThumbnail] when the PDF needs a password to render
/// (Protect PDF's output, RELEASE_V1_4 §3): a page shape with a lock.
class LockedPdfPreview extends StatelessWidget {
  const LockedPdfPreview({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.resultLockedPreviewA11y,
        excludeSemantics: true,
        child: Container(
          width: width,
          height: width * 1.414,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(Radii.sm),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Icon(Icons.lock_rounded, size: width * 0.3, color: context.docu.secureAccent),
        ),
      );
}
