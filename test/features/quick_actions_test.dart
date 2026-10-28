import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/image/resize_math.dart';
import 'package:docukit/features/home/quick_actions.dart';
import 'package:docukit/features/image_compress/application/compress_operation.dart';
import 'package:docukit/features/image_resize/application/resize_operation.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick actions: the six UI_REFRESH §2.1 routes, then Scan (FR-SCN-24)', () {
    expect(quickActions.map((q) => q.location), [
      '/tool/image-resize?preset=passport',
      '/tool/image-compress?target=102400',
      '/tool/image-resize?preset=signature',
      '/tool/image-to-pdf',
      '/tool/pdf-merge',
      '/tool/pdf-compress?level=balanced',
      '/tool/scan?autostart=1',
    ]);
  });

  test('passport prefill → preset 413×531 with a white border', () {
    final o = ResizeOptions.fromJson(prefillFromQuery(ToolId.imageResize, {'preset': 'passport'})!, const ResizeOptions());
    expect(o.mode, ResizeMode.preset);
    expect((o.presetWidth, o.presetHeight), (413, 531));
    expect(o.fit, FitMode.contain);
    expect(o.pad, PadColor.white);
  });

  test('under 100 KB prefill → target-size mode', () {
    final o = CompressOptions.fromJson(prefillFromQuery(ToolId.imageCompress, {'target': '102400'})!, const CompressOptions());
    expect(o.mode, CompressMode.targetSize);
    expect(o.targetBytes, 102400);
  });

  test('Strong can never be prefilled (FR-CMP-02); junk is ignored', () {
    expect(prefillFromQuery(ToolId.pdfCompress, {'level': 'strong'}), isNull);
    expect(prefillFromQuery(ToolId.pdfCompress, {'level': 'balanced'}), {'level': 'balanced'});
    expect(prefillFromQuery(ToolId.imageCompress, {'target': 'abc'}), isNull);
    expect(prefillFromQuery(ToolId.imageResize, {'preset': 'nope'}), isNull);
    expect(prefillFromQuery(ToolId.pdfMerge, {'x': '1'}), isNull);
  });
}
