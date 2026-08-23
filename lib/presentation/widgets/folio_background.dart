import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Subtle premium background — airy in light mode, warm in dark mode.
class FolioBackground extends StatelessWidget {
  const FolioBackground({required this.child, super.key, this.accentAlignment = const Alignment(0.84, -0.92)});

  final Widget child;
  final Alignment accentAlignment;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    final Color canvas = AppColors.canvas(brightness);
    final Color accent = AppColors.accent(brightness);
    final Color soft = AppColors.soft(brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: canvas,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(soft.withValues(alpha: dark ? 0.14 : 0.18), canvas),
            canvas,
            canvas,
          ],
          stops: const <double>[0, 0.18, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: accentAlignment,
                    radius: dark ? 1.0 : 0.92,
                    colors: <Color>[
                      accent.withValues(alpha: dark ? 0.08 : 0.085),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
