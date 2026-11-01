import '../search/tool_catalog.dart';

/// FR-SHR-06: received files kept per kind; the rest is dropped with the
/// truncation message.
const incomingLimits = (images: 50, pdfs: 20);

enum IncomingKind { images, pdfs }

class IncomingOption {
  const IncomingOption(this.tool, {this.needsMore = false});
  final ToolId tool;

  /// Merge with a single PDF: "Needs one more PDF. You can add it next."
  final bool needsMore;
}

class IncomingSection {
  const IncomingSection(this.kind, this.count, this.options);
  final IncomingKind kind;
  final int count;
  final List<IncomingOption> options;
}

/// RELEASE_V1_1 §4.8: which tools can take the received files, one section
/// per kind (images first). Empty when nothing usable arrived.
List<IncomingSection> matchIncoming({required int images, required int pdfs}) => [
      if (images > 0)
        IncomingSection(IncomingKind.images, images, const [
          IncomingOption(ToolId.imageCompress),
          IncomingOption(ToolId.imageResize),
          IncomingOption(ToolId.imageConvert),
          IncomingOption(ToolId.imageToPdf),
          IncomingOption(ToolId.print), // 1.6 (RELEASE_PRINT §3.4)
        ]),
      if (pdfs == 1)
        const IncomingSection(IncomingKind.pdfs, 1, [
          IncomingOption(ToolId.pdfOrganize),
          IncomingOption(ToolId.pdfSplit),
          IncomingOption(ToolId.pdfToImages),
          IncomingOption(ToolId.pdfCompress),
          IncomingOption(ToolId.pdfMerge, needsMore: true),
          IncomingOption(ToolId.print),
        ])
      else if (pdfs > 1)
        IncomingSection(IncomingKind.pdfs, pdfs, const [IncomingOption(ToolId.pdfMerge)]),
    ];
