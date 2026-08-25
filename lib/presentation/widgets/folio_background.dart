import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Subtle premium background — airy paper in light, nocturnal black in dark.
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
            Color.alphaBlend(
              (dark ? Colors.white : soft).withValues(alpha: dark ? 0.028 : 0.18),
              canvas,
            ),
            canvas,
            canvas,
          ],
          stops: const <double>[0, 0.22, 1],
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
                    radius: dark ? 0.88 : 0.92,
                    colors: <Color>[
                      accent.withValues(alpha: dark ? 0.045 : 0.085),
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
