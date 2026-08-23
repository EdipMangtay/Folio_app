import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.trailing,
    this.subtitle,
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (eyebrow != null) ...<Widget>[
                Text(eyebrow!.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
