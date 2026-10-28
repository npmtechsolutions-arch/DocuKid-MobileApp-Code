// RELEASE_V1_1 §4.5 / §8.1 — ZipBuilder, written before the implementation
// (T8.3). Uses the API recorded in ADR-060 (archive 4.0.9, STORE entries via
// addArchiveFile, reopened with ZipDecoder.decodeStream).
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:docukit/core/errors/app_error.dart';
import 'package:docukit/core/files/zip_builder.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('zip_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  String file(String name, int size, [int fill = 1]) {
    final f = File(p.join(dir.path, name))..writeAsBytesSync(List.filled(size, fill));
    return f.path;
  }

  Archive reopen(String zip) {
    final input = InputFileStream(zip);
    addTearDown(input.closeSync);
    return ZipDecoder().decodeStream(input);
  }

  test('name: DocuKit_<tool>_<yyyyMMdd_HHmm>.zip (FR-BAT-03)', () {
    expect(zipFileName(ToolId.imageCompress, DateTime(2026, 10, 28, 9, 5)), 'DocuKit_imageCompress_20261028_0905.zip');
  });

  test('STORE for already-compressed formats, DEFLATE otherwise', () {
    for (final n in ['a.jpg', 'a.JPEG', 'a.png', 'a.webp', 'a.heic', 'a.pdf']) {
      expect(compressionFor(n), CompressionType.none, reason: n);
    }
    expect(compressionFor('notes.txt'), CompressionType.deflate);
  });

  test('builds a valid ZIP: every entry, de-duplicated names, exact contents, STORE', () async {
    final out = p.join(dir.path, 'out.zip');
    final progress = <(int, int)>[];
    final count = await buildZip(
      [
        ZipItem(file('one.jpg', 3000, 1), 'photo.jpg'),
        ZipItem(file('two.jpg', 2000, 2), 'photo.jpg'),
        ZipItem(file('three.pdf', 1000, 3), 'doc.pdf'),
      ],
      out,
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(count, 3);
    expect(progress.last, (3, 3));
    final archive = reopen(out);
    expect(archive.files.map((f) => f.name), ['photo.jpg', 'photo (1).jpg', 'doc.pdf']);
    expect(archive.files.map((f) => f.size), [3000, 2000, 1000]);
    expect(archive.files.every((f) => f.compression == CompressionType.none), isTrue);
    expect(archive.files[1].readBytes()!.every((b) => b == 2), isTrue);
  });

  test('cancelled before it starts: throws, leaves no file', () async {
    final out = p.join(dir.path, 'out.zip');
    final cancel = CancelToken()..cancel();
    await expectLater(
      buildZip([ZipItem(file('a.jpg', 100), 'a.jpg')], out, cancel: cancel),
      throwsA(isA<CancelledException>()),
    );
    expect(File(out).existsSync(), isFalse);
  });

  test('cancelled mid-way: stops, deletes the partial ZIP', () async {
    final out = p.join(dir.path, 'out.zip');
    final cancel = CancelToken();
    final items = [for (var i = 0; i < 20; i++) ZipItem(file('f$i.jpg', 200 * 1024, i), 'f$i.jpg')];
    var seen = 0;
    await expectLater(
      buildZip(items, out, cancel: cancel, onProgress: (done, _) {
        seen = done;
        if (done == 2) cancel.cancel();
      }),
      throwsA(isA<CancelledException>()),
    );
    expect(seen, lessThan(20));
    expect(File(out).existsSync(), isFalse);
  });

  test('a missing source file fails the build and leaves no file', () async {
    final out = p.join(dir.path, 'out.zip');
    await expectLater(
      buildZip([ZipItem(p.join(dir.path, 'gone.jpg'), 'gone.jpg')], out),
      throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.processingFailed)),
    );
    expect(File(out).existsSync(), isFalse);
  });
}
