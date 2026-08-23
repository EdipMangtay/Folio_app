import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'money_pulse.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Finansal görünüm hazırlanıyor'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MoneyPulse(score: 72, size: 96, showLabel: false),
            const SizedBox(height: 22),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
