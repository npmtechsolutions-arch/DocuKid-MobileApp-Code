import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/tool_scaffold.dart';
import '../../search/tool_catalog.dart';
import '../../secure/unlock_first.dart';
import '../../tools/batch_inputs.dart';
import '../../tools/tool_common.dart';
import '../../tools/tool_inputs.dart';
import '../application/print_preview_controller.dart';

/// S47 · Print (RELEASE_PRINT §3): one PDF or up to 100 images →
/// "Preview & print" (S48). Tools bottom banner with the 24 dp gap
/// (ToolScaffold). With [autoPreview] (Incoming, My Documents, Result,
/// Details: FR-PRN-02) S48 opens as soon as the handed-over files are in.
class PrintToolScreen extends ConsumerStatefulWidget {
  const PrintToolScreen({super.key, this.autoPreview = false});
  final bool autoPreview;

  @override
  ConsumerState<PrintToolScreen> createState() => _PrintToolScreenState();
}

class _PrintToolScreenState extends ConsumerState<PrintToolScreen> {
  static const tool = ToolId.print;
  late var _previewPending = widget.autoPreview;

  void _preview(ToolInputs inputs) {
    ref.read(printRequestProvider.notifier).set(PrintRequest(inputs.valid));
    context.push('/print/preview');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    listenPickResults(context, ref, tool);
    final inputs = ref.watch(toolInputsProvider(tool));
    final pick = ref.read(toolInputsProvider(tool).notifier);
    final files = inputs.files;
    final file = inputs.single;
    final mixed = files.length > 1 && files.any((f) => f.isPdf);
    final locked = files.length == 1 && file != null && isLockedPdf(file);
    final accent = accentFor(context, ToolCategory.pdf);
    final canPreview = !inputs.picking && !mixed && inputs.valid.isNotEmpty;

    if (_previewPending && canPreview) {
      _previewPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _preview(inputs);
      });
    } else if (_previewPending && (locked || mixed || (files.isNotEmpty && inputs.valid.isEmpty))) {
      // Nothing printable arrived: stay here, where the reason shows.
      _previewPending = false;
    }

    return ToolScaffold(
      title: l.toolPrintTitle,
      hasWork: !inputs.isEmpty,
      banner: const RestoredBanner(tool: tool),
      action: locked
          ? unlockFirstAction(context, ref, tool, file)
          : PrimaryActionBar(
              label: l.prnPreviewBtn,
              icon: Icons.print_rounded,
              helper: files.isEmpty
                  ? l.prnPickHint
                  : mixed
                      ? l.prnMixRefused
                      : inputs.valid.isEmpty
                          ? l.chooseAnother
                          : null,
              onPressed: canPreview ? () => _preview(inputs) : null,
            ),
      primary: [
        if (!mixed && files.length > 1)
          const BatchInputs(tool: tool)
        else ...[
          SectionHeader(l.inputsFileHeader),
          if (file == null) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: PickerDropCard(
                  label: l.prnChoosePdf,
                  formats: l.pickFormatsPdf,
                  icon: Icons.picture_as_pdf_rounded,
                  accent: accent,
                  loading: inputs.picking,
                  onTap: () => pick.pick(as: InputKind.singlePdf),
                ),
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: PickerDropCard(
                  label: l.prnChooseImages,
                  formats: l.pickFormatsImages,
                  icon: Icons.add_photo_alternate_rounded,
                  accent: accent,
                  loading: inputs.picking,
                  onTap: () => pick.pick(as: InputKind.images),
                ),
              ),
            ]),
            const SizedBox(height: Space.x2),
            Text(l.prnPickHint, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ] else if (mixed)
            InlineBanner(
              kind: BannerKind.warning,
              text: l.prnMixRefused,
              actions: [TextButton(onPressed: pick.clear, child: Text(l.draftStartOver))],
            )
          else
            SingleFileCard(
              file: file,
              onChange: () => pick.pick(replace: true, as: file.isPdf ? InputKind.singlePdf : InputKind.images),
              onAdd: file.isPdf || inputs.picking ? null : () => pick.pick(as: InputKind.images),
            ),
        ],
        LargeFileHint(bytes: inputs.totalBytes),
      ],
    );
  }
}
