import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

Future<String?> showFolioTextPrompt(
  BuildContext context, {
  required String title,
  required String initial,
  String hint = '',
  String confirmLabel = 'Kaydet',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _FolioTextPrompt(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      keyboardType: TextInputType.text,
      onSubmit: (String text) => text,
    ),
  );
}

Future<double?> showFolioMoneyPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String confirmLabel = 'Kaydet',
}) {
  return showDialog<double>(
    context: context,
    builder: (BuildContext context) => _FolioTextPrompt<double>(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      suffixText: '₺',
      onSubmit: Formatters.parseMoneyInput,
    ),
  );
}

class _FolioTextPrompt<T> extends StatefulWidget {
  const _FolioTextPrompt({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.keyboardType,
    required this.onSubmit,
    this.suffixText,
  });

  final String title;
  final String initial;
  final String hint;
  final String confirmLabel;
  final TextInputType keyboardType;
  final String? suffixText;
  final T? Function(String text) onSubmit;

  @override
  State<_FolioTextPrompt<T>> createState() => _FolioTextPromptState<T>();
}

class _FolioTextPromptState<T> extends State<_FolioTextPrompt<T>> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(hintText: widget.hint.isEmpty ? null : widget.hint, suffixText: widget.suffixText),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final T? value = widget.onSubmit(_controller.text);
            if (value != null) Navigator.pop(context, value);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
