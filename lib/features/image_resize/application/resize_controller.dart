import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/image/image_options.dart';
import '../../../core/image/resize_math.dart';
import '../../../core/providers.dart';
import '../../../data/settings/app_settings.dart';
import '../../search/tool_catalog.dart';
import '../../tools/options_draft.dart';
import 'resize_operation.dart';

class ResizeController extends Notifier<ResizeOptions> {
  @override
  ResizeOptions build() {
    final s = ref.read(settingsProvider);
    final defaults = ResizeOptions(lockRatio: s.resizeLockRatio, format: s.imgFormat, stripMetadata: s.imgStripMetadata);
    final init = initialOptions(ref, ToolId.imageResize);
    return init == null ? defaults : ResizeOptions.fromJson(init, defaults);
  }

  void _set(ResizeOptions o) {
    state = o;
    writeOptionsDraft(ref, ToolId.imageResize, o.toJson());
  }

  void set(ResizeOptions o) => _set(o);

  /// Seeds pixel fields from a newly picked image.
  void seedFrom(int w, int h) {
    if (state.width == null || state.height == null) {
      _set(state.copyWith(width: () => w, height: () => h));
    }
  }

  /// FR-RES-02: editing one side recomputes the other when locked.
  void setWidth(int? w, int origW, int origH) {
    if (state.lockRatio && w != null && w > 0) {
      _set(state.copyWith(width: () => w, height: () => lockedHeightFor(w, origW, origH)));
    } else {
      _set(state.copyWith(width: () => w));
    }
  }

  void setHeight(int? h, int origW, int origH) {
    if (state.lockRatio && h != null && h > 0) {
      _set(state.copyWith(height: () => h, width: () => lockedWidthFor(h, origW, origH)));
    } else {
      _set(state.copyWith(height: () => h));
    }
  }

  void toggleLock(int origW, int origH) {
    final lock = !state.lockRatio;
    var next = state.copyWith(lockRatio: lock);
    if (lock && next.width != null) next = next.copyWith(height: () => lockedHeightFor(next.width!, origW, origH));
    _set(next);
  }

  /// Choosing a preset whose ratio differs → Fit with border (white).
  void choosePreset(String id, int w, int h, int origW, int origH) {
    _set(state.copyWith(
      preset: () => id,
      presetWidth: w,
      presetHeight: h,
      fit: ratioDiffers(w, h, origW, origH) ? FitMode.contain : state.fit,
      pad: ratioDiffers(w, h, origW, origH) ? PadColor.white : state.pad,
    ));
  }

  Future<bool> savePreset(String name, int w, int h) async {
    final s = ref.read(settingsProvider);
    if (s.resizeCustomPresets.length >= 10) return false;
    await ref.read(settingsProvider.notifier).update(
          (x) => x.copyWith(resizeCustomPresets: [...x.resizeCustomPresets, CustomPreset(name, w, h)]),
        );
    return true;
  }

  Future<void> deletePreset(CustomPreset p) => ref.read(settingsProvider.notifier).update(
        (x) => x.copyWith(resizeCustomPresets: [...x.resizeCustomPresets]..remove(p)),
      );
}

final resizeOptionsProvider = NotifierProvider.autoDispose<ResizeController, ResizeOptions>(ResizeController.new);

final resizeOperationProvider = Provider<ResizeImageOperation>(
  (ref) => ResizeImageOperation(ref.watch(imageEngineProvider), clock: ref.watch(clockProvider)),
);
