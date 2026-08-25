import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import 'premium_surface.dart';

/// Asks for one income figure.
///
/// A refusal appears under the field it is about. A snackbar sits at the bottom
/// of the screen, which is where the skip control lives — it hid the button it
/// was telling the user to press.
class IncomeEntryCard extends StatefulWidget {
  const IncomeEntryCard({
    required this.onSubmit,
    required this.onSkip,
    this.title,
    this.body,
    super.key,
  });

  /// Rendered inside the card when given. Headings placed outside it end up
  /// floating over whatever the app is showing behind, which reads as two
  /// pieces of text on top of each other.
  final String? title;
  final String? body;

  /// Called with a positive amount and the source the user typed, which may be
  /// empty. The card stays busy until this completes.
  final Future<void> Function(double amount, String source) onSubmit;

  final VoidCallback onSkip;

  @override
  State<IncomeEntryCard> createState() => _IncomeEntryCardState();
}

class _IncomeEntryCardState extends State<IncomeEntryCard> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final bool blank = _amountController.text.trim().isEmpty;
    final double? amount = Formatters.parseMoneyInput(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = blank ? 'Bir tutar gir.' : 'Geçerli bir tutar gir.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    await widget.onSubmit(amount, _sourceController.text.trim());
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: PremiumSurface(
        elevated: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.title != null) ...<Widget>[
              Text(widget.title!, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
            ],
            if (widget.body != null) ...<Widget>[
              Text(widget.body!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
            ],
            Text('Aylık gelirin', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              style: theme.textTheme.headlineSmall,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '₺',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            Text('Kaynak', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _sourceController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Maaş'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Kaydet ve devam et'),
            ),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: _busy ? null : widget.onSkip,
                child: const Text('Şimdilik geç'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
