import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A refined surface with tonal separation — paper in light, anthracite in dark.
class PremiumSurface extends StatelessWidget {
  const PremiumSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppSpacing.radiusLg,
    this.onTap,
    this.tint,
    this.outlined = false,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;
  final bool outlined;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color base = elevated ? AppColors.elevated(theme.brightness) : AppColors.surface(theme.brightness);
    final Color fill = tint == null ? base : Color.alphaBlend(tint!, base);

    final BoxDecoration decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: theme.dividerColor.withValues(alpha: outlined ? 0.95 : (dark ? 0.78 : 0.88)),
        width: 0.85,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          fill,
          Color.alphaBlend(
            (dark ? Colors.white : AppColors.soft(theme.brightness)).withValues(alpha: dark ? 0.035 : 0.16),
            fill,
          ),
        ],
      ),
      boxShadow: elevated
          ? <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.42 : 0.045),
                blurRadius: dark ? 28 : 22,
                offset: const Offset(0, 10),
              ),
              if (!dark)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.85),
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
            ]
          : null,
    );

    final Widget content = Container(padding: padding, decoration: decoration, child: child);
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
