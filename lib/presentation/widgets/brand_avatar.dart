import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BrandAvatar extends StatelessWidget {
  const BrandAvatar({
    required this.name,
    required this.category,
    super.key,
    this.size = 44,
  });

  final String name;
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = AppColors.category(category);
    final String letter = name.trim().isEmpty ? '•' : name.trim().substring(0, 1).toUpperCase();
    final bool dark = theme.brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(color: color.withValues(alpha: dark ? 0.12 : 0.08), width: 0.7),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: theme.textTheme.titleMedium?.copyWith(
          color: dark ? color.withValues(alpha: 0.98) : _deepen(color),
          fontWeight: FontWeight.w600,
          fontSize: size * 0.34,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Color _deepen(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.18, 0.40)).toColor();
  }
}
