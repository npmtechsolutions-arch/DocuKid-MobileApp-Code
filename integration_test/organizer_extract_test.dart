// T8.10 on a device (RELEASE_V1_1 R34, FR-EXT-01/03): Organizer Extract with
// the real PDFium engine. Page i is (200 + i) × 400 pt, so the output shows
// which source pages it holds, in which order, and whether they're rotated.
//
//   flutter test integration_test/organizer_extract_test.dart -d <android device>
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docukit/core/files/mime_sniffer.dart';
import 'package:docukit/core/files/paths.dart';
import 'package:docukit/core/files/picked_file.dart';
import 'package:docukit/core/operation/job_runner.dart';
import 'package:docukit/core/operation/job_state.dart';
import 'package:docukit/core/operation/tool_operation.dart';
import 'package:docukit/core/pdf/page_edit.dart';
import 'package:docukit/core/pdf/pdfrx_pdf_engine.dart';
import 'package:docukit/core/platform/device_services.dart';
import 'package:docukit/data/db/app_database.dart';
import 'package:docukit/data/repositories/history_repository.dart';
import 'package:docukit/data/repositories/outputs_repository.dart';
import 'package:docukit/features/pdf_organize/application/organize_controller.dart';
import 'package:docukit_native/docukit_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R34: select 3 pages (one rotated, one moved) → Extract → exactly those pages', (_) async {
    await pdfrxFlutterInitialize();
    final pdfs = PdfrxPdfEngine();
    final paths = await AppPaths.resolve();
    final history = HistoryRepository(AppDatabase(NativeDatabase.memory()));
    final runner = JobRunner(paths: paths, history: history, outputs: OutputsRepository(paths), device: NativeDeviceServices(DocukitNative()));
    final dir = paths.jobIn('it_extract')..createSync(recursive: true);

    final doc = pw.Document();
    for (var i = 0; i < 10; i++) {
      doc.addPage(pw.Page(pageFormat: PdfPageFormat(200.0 + i, 400), build: (_) => pw.Center(child: pw.Text('Page ${i + 1}'))));
    }
    final path = p.join(dir.path, 'contract.pdf');
    File(path).writeAsBytesSync(await doc.save());
    final before = sha256.convert(File(path).readAsBytesSync()).toString();
    final meta = await pdfs.inspect(path);
    final input = PickedFile(path: path, displayName: 'contract.pdf', type: SniffedType.pdf, sizeBytes: File(path).lengthSync(), pdf: meta);

    // UI order after the user moved page 9 before page 3 and rotated page 3:
    // selected (in UI order) = page 9, page 3 (rotated right), page 6.
    const selected = [PageEdit(8), PageEdit(2, 1), PageEdit(5)];
    final states = <JobState>[];
    await runner.run(
      jobId: 'it_extract_${DateTime.now().microsecondsSinceEpoch}',
      op: OrganizePdfOperation(pdfs),
      inputs: [input],
      options: const OrganizeOptions(selected, extract: true),
      cancel: CancelToken(),
      emit: states.add,
    );
    final last = states.last;
    if (last is JobFailed) fail('job failed: ${last.error.code.name}');
    final r = (last as JobCompleted).result;
    expect(r.outputName, 'contract_extract.pdf');
    expect(r.meta.pages, 3);
    final out = await pdfs.inspect(r.outputPath);
    final sizes = [for (final (w, h) in out.pageSizes) (w.round(), h.round())];
    // ignore: avoid_print
    print('R34 sizes=$sizes');
    expect(sizes, [(208, 400), (400, 202), (205, 400)], reason: 'page 9, page 3 rotated (w/h swapped), page 6');
    expect(sha256.convert(File(path).readAsBytesSync()).toString(), before, reason: 'original untouched (rule 1)');
    final rec = (await history.get(r.jobId))!;
    expect((rec.tool?.name, rec.options['mode']), ('pdfOrganize', 'extract'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
