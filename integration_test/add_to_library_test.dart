// T12.3 on a device (RELEASE_V1_5 R60, R61): the data path behind "Save to My
// Documents" and "Import files" with the real native encoder, file system and
// SQLite. The dialogs themselves are covered by test/widgets/add_to_library_test.dart;
// the system picker (R61's "pick 5 PDFs") is a manual check on a phone.
//
//   flutter test integration_test/add_to_library_test.dart -d <android device>
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/file_gateway_impl.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/image/image_engine_impl.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/library/library_repository.dart';
import 'package:docukit/data/library/library_repository_impl.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/image_compress/application/compress_operation.dart';
import 'package:docukit/features/search/tool_catalog.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

Uint8List photo() {
  final r = img.Image(width: 1600, height: 1200);
  for (var y = 0; y < r.height; y++) {
    for (var x = 0; x < r.width; x++) {
      r.setPixelRgb(x, y, x * 255 ~/ r.width, y * 255 ~/ r.height, (x ^ y) & 0xff);
    }
  }
  return img.encodeJpg(r, quality: 95);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPaths paths;
  late Directory dir, support;
  late AppDatabase db;
  late LibraryRepositoryImpl repo;
  const images = NativeImageEngine();

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    paths = await AppPaths.resolve();
    dir = Directory(p.join(paths.cacheRoot.path, 'it_add_library'))..createSync(recursive: true);
    support = Directory(p.join(dir.path, 'support'))..createSync();
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(db, support);
  });

  tearDownAll(() async {
    await repo.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  testWidgets('R60: compress an image → Save to My Documents → new folder "IDs"; the result is unchanged', (_) async {
    final runner = JobRunner(
        paths: paths,
        history: HistoryRepository(AppDatabase(NativeDatabase.memory())),
        outputs: OutputsRepository(paths),
        device: NativeDeviceServices(DocukitNative()));
    final gateway = PluginFileGateway(paths: paths, images: images, pdfs: PdfrxPdfEngine(), native: DocukitNative());
    final src = File(p.join(dir.path, 'IMG_2001.jpg'))..writeAsBytesSync(photo());
    final input = (await gateway.reinspect([
      PickedFile(path: src.path, displayName: 'IMG_2001.jpg', type: SniffedType.unknown, sizeBytes: src.lengthSync()),
    ]))
        .single;
    final states = <JobState>[];
    await runner.run(
      jobId: 'it_lib_${DateTime.now().microsecondsSinceEpoch}',
      op: CompressImageOperation(images),
      inputs: [input],
      options: const CompressOptions(quality: 60),
      cancel: CancelToken(),
      emit: states.add,
    );
    final r = (states.last as JobCompleted).result;
    final resultSha = sha(r.outputPath);

    final ids = await repo.createFolder('IDs');
    final added = await repo.addFile(r.outputPath,
        displayName: r.outputName,
        folderId: ids.id,
        source: DocSource.result,
        sourceTool: r.tool,
        mime: r.mime,
        width: r.meta.width,
        height: r.meta.height) as Added;
    final saved = repo.absolutePath(added.doc);
    // ignore: avoid_print
    print('R60 result=${r.meta.bytes}B saved=${File(saved).lengthSync()}B in=${p.relative(saved, from: support.path)}');
    expect(sha(saved), resultSha, reason: 'a byte-identical copy');
    expect(p.isWithin(support.path, saved), isTrue);
    expect(sha(r.outputPath), resultSha, reason: 'the Recent result is unchanged');
    expect(File(r.outputPath).existsSync(), isTrue);
    expect((await repo.watchDocs(folderId: ids.id).first).map((d) => (d.name, d.sourceTool)), [(r.outputName, ToolId.imageCompress)]);
    expect((await repo.watchFolders().first).single.docCount, 1);
  });

  testWidgets('R61: import 5 PDFs incl. one duplicate → 1 Duplicate (then Add copy), counts right', (_) async {
    Future<String> pdf(String name, String text) async {
      final d = pw.Document()..addPage(pw.Page(build: (_) => pw.Center(child: pw.Text(text))));
      final f = File(p.join(dir.path, name));
      await f.writeAsBytes(await d.save());
      return f.path;
    }

    final bank = await repo.createFolder('Bank');
    final files = [
      await pdf('jan.pdf', 'January'),
      await pdf('feb.pdf', 'February'),
      await pdf('mar.pdf', 'March'),
      await pdf('apr.pdf', 'April'),
    ];
    // The 5th is the same bytes as jan.pdf under another name.
    files.add((File(files[0]).copySync(p.join(dir.path, 'jan (1).pdf'))).path);
    final before = {for (final f in files) f: sha(f)};
    final results = [
      for (final f in files)
        await repo.addFile(f, displayName: p.basename(f), folderId: bank.id, source: DocSource.import, mime: 'application/pdf'),
    ];
    expect(results.whereType<Added>(), hasLength(4));
    final dup = results.last as Duplicate;
    expect(dup.existing.name, 'jan.pdf');
    expect((await repo.watchFolders().first).firstWhere((f) => f.id == bank.id).docCount, 4);

    // "Add copy": the same bytes under a free name.
    final copy = await repo.addFile(files.last,
        displayName: 'jan (1).pdf', folderId: bank.id, source: DocSource.import, mime: 'application/pdf', allowDuplicate: true) as Added;
    expect(copy.doc.sha256, dup.existing.sha256);
    expect((await repo.watchFolders().first).firstWhere((f) => f.id == bank.id).docCount, 5);
    for (final f in files) {
      expect(sha(f), before[f], reason: 'imported files are copied, never changed');
    }
    // ignore: avoid_print
    print('R61 bank=${(await repo.watchDocs(folderId: bank.id).first).map((d) => d.name).join(', ')}');
  });
}
