import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/models/insight.dart';
import 'premium_surface.dart';
import 'section_header.dart';

class InsightBlock extends StatelessWidget {
  const InsightBlock({required this.insight, super.key});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = switch (insight.tone) {
      InsightTone.positive => AppColors.sage,
      InsightTone.warning => AppColors.coral,
      InsightTone.neutral => AppColors.accent(theme.brightness),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          eyebrow: 'öne çıkan',
          title: 'Bu ayın sinyali',
          subtitle: 'Harcama akışındaki en net değişim.',
        ),
        const SizedBox(height: 18),
        PremiumSurface(
          elevated: true,
          tint: tone.withValues(alpha: theme.brightness == Brightness.dark ? 0.10 : 0.055),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: tone, size: 18),
                  ),
                  const Spacer(),
                  Text(
                    insight.metric,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: tone,
                      letterSpacing: -0.45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                insight.title,
                style: theme.textTheme.headlineSmall?.copyWith(height: 1.22),
              ),
              const SizedBox(height: 10),
              Text(
                insight.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted(theme.brightness),
                  height: 1.52,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
