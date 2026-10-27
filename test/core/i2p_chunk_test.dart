// Images → PDF always builds in chunks of 20 images and merges them, whatever
// the total size (written before the change; the old code only chunked above
// 120 MB). Page order across chunks is checked end to end on the device by
// integration_test/i2p_stress_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine.dart';
import 'package:docukit/core/image/image_options.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/image_to_pdf_builder.dart';
import 'package:docukit/core/pdf/pdf_engine.dart';
import 'package:docukit/core/pdf/pdf_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Copies a tiny JPEG to the output: enough for the PDF writer.
class _CopyEngine implements ImageEngine {
  _CopyEngine(this.jpeg);
  final List<int> jpeg;
  @override
  bool canEncode(ImageFormat format) => true;
  @override
  Future<ImageMeta> inspect(String path) async => const ImageMeta(format: SniffedType.jpeg, width: 40, height: 30);
  @override
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta}) async {
    File(outPath).writeAsBytesSync(jpeg);
    return EncodedImage(path: outPath, bytes: jpeg.length, width: 40, height: 30, format: ImageFormat.jpeg);
  }
}

/// Records combineFiles calls instead of merging.
class _RecordingPdf implements PdfEngine {
  final merges = <List<String>>[];
  @override
  Future<void> combineFiles(List<String> inputs, String out) async {
    merges.add(inputs);
    File(out).writeAsStringSync('%PDF-merged');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('i2p_chunk'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(String, _RecordingPdf)> build(int n) async {
    final jpeg = img.encodeJpg(img.Image(width: 40, height: 30));
    final pdf = _RecordingPdf();
    final work = Directory(p.join(tmp.path, 'work'))..createSync();
    final items = [
      for (var i = 0; i < n; i++)
        ImageToPdfItem(
          PickedFile(
            path: p.join(tmp.path, 'in_$i.jpg'),
            displayName: 'in_$i.jpg',
            type: SniffedType.jpeg,
            sizeBytes: jpeg.length,
            image: const ImageMeta(format: SniffedType.jpeg, width: 40, height: 30),
          ),
          0,
        ),
    ];
    final out = await ImageToPdfBuilder(_CopyEngine(jpeg), pdf).build(
      items,
      const ImageToPdfSettings(
        size: PdfPageSize.a4,
        orientation: PdfOrientation.auto,
        fit: PdfFit.fit,
        margin: PdfMargin.small,
        quality: PdfImageQuality.high,
      ),
      JobContext(jobId: 't', workDir: work, cancel: CancelToken(), report: (_) {}),
    );
    return (out, pdf);
  }

  int pagesIn(String path) => RegExp(r'/Type\s*/Page(?!s)').allMatches(File(path).readAsStringSync(encoding: latin1)).length;

  test('45 small images → chunks of 20, 20, 5, merged in order', () async {
    final (out, pdf) = await build(45);
    expect(pdf.merges, hasLength(1));
    final chunks = pdf.merges.single;
    expect(chunks.map(pagesIn).toList(), [20, 20, 5]);
    expect(chunks.map(p.basename).toList(), ['chunk_0.pdf', 'chunk_20.pdf', 'chunk_40.pdf']);
    expect(File(out).existsSync(), isTrue);
  });

  test('100 images → five chunks of 20', () async {
    final (_, pdf) = await build(100);
    expect(pdf.merges.single.map(pagesIn).toList(), [20, 20, 20, 20, 20]);
  });

  test('20 or fewer images → one chunk, written directly (nothing to merge)', () async {
    final (out, pdf) = await build(20);
    expect(pdf.merges, isEmpty);
    expect(pagesIn(out), 20);
  });
}
