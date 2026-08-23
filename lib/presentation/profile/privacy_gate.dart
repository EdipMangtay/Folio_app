import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_wordmark.dart';
import '../widgets/money_pulse.dart';

/// Optional device-local privacy shield for financial data.
class PrivacyGate extends StatefulWidget {
  const PrivacyGate({required this.enabled, required this.child, required this.onDisable, super.key});

  final bool enabled;
  final Widget child;
  final VoidCallback onDisable;

  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _unlocked = false;
  bool _authenticating = false;
  bool _wasBackgrounded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlocked = !widget.enabled;
    if (widget.enabled) WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void didUpdateWidget(covariant PrivacyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _unlocked = true;
      _error = null;
    } else if (!oldWidget.enabled && widget.enabled) {
      _unlocked = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
      if (mounted) setState(() => _unlocked = false);
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      Future<void>.delayed(const Duration(milliseconds: 180), _authenticate);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!widget.enabled || _unlocked || _authenticating || !mounted) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final bool supported = await _auth.isDeviceSupported();
      if (!supported) {
        if (mounted) setState(() => _error = 'Bu cihazda ekran kilidiyle doğrulama kullanılamıyor.');
        return;
      }
      final bool result = await _auth.authenticate(
        localizedReason: 'Finansal görünümünü açmak için kimliğini doğrula.',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (mounted) {
        setState(() {
          _unlocked = result;
          if (!result) _error = 'Folio kilitli.';
        });
      }
    } on LocalAuthException {
      if (mounted) setState(() => _error = 'Doğrulama tamamlanamadı. Tekrar deneyebilirsin.');
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _unlocked) return widget.child;
    final ThemeData theme = Theme.of(context);
    return FolioBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const FolioWordmark(),
              const Spacer(),
              Center(child: MoneyPulse(score: 82, size: 150, showLabel: false)),
              const SizedBox(height: 18),
              Center(child: Text('Folio kilitli', style: theme.textTheme.headlineMedium)),
              const SizedBox(height: 9),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Text(
                    _error ?? 'Finansal görünümün bu cihazın güvenliğiyle korunuyor.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted(theme.brightness)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _authenticating ? null : _authenticate,
                  icon: _authenticating
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.scaffoldBackgroundColor))
                      : const Icon(Icons.fingerprint_rounded),
                  label: Text(_authenticating ? 'Doğrulanıyor' : 'Kilidi aç'),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 9),
                Center(child: TextButton(onPressed: widget.onDisable, child: const Text('Cihaz kilidini Folio için kapat'))),
              ],
              const Spacer(),
              Center(
                child: Text(
                  'Biyometrik veri Folio tarafından okunmaz veya saklanmaz.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
