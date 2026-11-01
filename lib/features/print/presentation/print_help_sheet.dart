import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';

/// FR-PRN-16 · "Can't find your printer?" (RELEASE_PRINT §3.3): this
/// platform's steps, the Save as PDF tip on Android, and the receipt-printer
/// line for both. No ad (§3.5).
Future<void> showPrintHelp(BuildContext context, {bool? ios}) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => PrintHelpSheet(ios: ios ?? Platform.isIOS),
  );
}

class PrintHelpSheet extends StatelessWidget {
  const PrintHelpSheet({super.key, required this.ios});
  final bool ios;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = ios
        ? [l.prnHelpIos1, l.prnHelpIos2, l.prnHelpIos3]
        : [l.prnHelpAndroid1, l.prnHelpAndroid2, l.prnHelpAndroid3, l.prnHelpAndroid4];
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.print_rounded, color: context.colors.primary),
            const SizedBox(width: Space.x3),
            Expanded(child: Semantics(header: true, child: Text(l.prnHelpTitle, style: context.text.titleLarge))),
          ]),
          const SizedBox(height: Space.x4),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: context.colors.primaryContainer,
                  child: Text('${i + 1}', style: context.text.labelMedium?.copyWith(color: context.colors.onPrimaryContainer)),
                ),
                const SizedBox(width: Space.x3),
                Expanded(child: Text(step, style: context.text.bodyLarge)),
              ]),
            ),
          if (!ios) ...[
            const SizedBox(height: Space.x2),
            Text(l.prnHelpTip, style: muted),
          ],
          const SizedBox(height: Space.x3),
          Text(l.prnHelpReceipt, style: muted),
        ],
      ),
    );
  }
}
