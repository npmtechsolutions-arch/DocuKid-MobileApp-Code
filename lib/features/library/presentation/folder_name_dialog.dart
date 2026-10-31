import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../data/library/library_repository.dart';

/// New folder / Rename folder (FR-LIB-06): [submit] runs the repository call;
/// its rule errors show inline and keep the dialog open. The result, or null.
Future<T?> showFolderNameDialog<T>(
  BuildContext context, {
  required String title,
  required String action,
  required Future<T> Function(String name) submit,
  String initial = '',
}) =>
    showAdaptiveDialog<T>(
      context: context,
      builder: (_) => _FolderNameDialog<T>(title: title, action: action, submit: submit, initial: initial),
    );

class _FolderNameDialog<T> extends StatefulWidget {
  const _FolderNameDialog({required this.title, required this.action, required this.submit, required this.initial});
  final String title, action, initial;
  final Future<T> Function(String name) submit;

  @override
  State<_FolderNameDialog<T>> createState() => _FolderNameDialogState<T>();
}

class _FolderNameDialogState<T> extends State<_FolderNameDialog<T>> {
  late final _c = TextEditingController(text: widget.initial);
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final r = await widget.submit(_c.text);
      if (mounted) Navigator.pop(context, r);
    } on LibraryException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          LibraryErrorCode.folderNameTaken => l.libFolderNameTaken,
          LibraryErrorCode.folderTooDeep => l.libFolderDepth,
          _ => l.libFolderNameInvalid,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog.adaptive(
      title: Text(widget.title),
      content: Material(
        type: MaterialType.transparency,
        child: TextField(
          key: const ValueKey('folder-name'),
          controller: _c,
          autofocus: true,
          maxLength: maxFolderNameChars,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.libFolderName, errorText: _error, errorMaxLines: 2),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _busy ? null : _go(),
        ),
      ),
      actions: [
        adaptiveAction(context, label: l.actionCancel, onPressed: () => Navigator.pop(context)),
        adaptiveAction(context, label: widget.action, primary: true, onPressed: _busy ? () {} : _go),
      ],
    );
  }
}
