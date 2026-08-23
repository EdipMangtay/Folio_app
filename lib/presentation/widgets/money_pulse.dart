import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Folio's signature ambient balance visual.
///
/// It deliberately avoids a fitness-ring look. The visual is a quiet field of
/// translucent contours whose movement is subtle enough for daily use.
class MoneyPulse extends StatefulWidget {
  const MoneyPulse({
    required this.score,
    super.key,
    this.size = 168,
    this.showLabel = true,
  });

  final int score;
  final double size;
  final bool showLabel;

  @override
  State<MoneyPulse> createState() => _MoneyPulseState();
}

class _MoneyPulseState extends State<MoneyPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 9000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Color tone = AppColors.pulseForScore(widget.score);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _PulsePainter(
              progress: reduceMotion ? 0.18 : _controller.value,
              score: widget.score,
              dark: Theme.of(context).brightness == Brightness.dark,
              tone: tone,
            ),
            child: child,
          );
        },
        child: widget.showLabel
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${widget.score}',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: widget.size * 0.23,
                            letterSpacing: -1.6,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text('Denge', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter({
    required this.progress,
    required this.score,
    required this.dark,
    required this.tone,
  });

  final double progress;
  final int score;
  final bool dark;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double baseRadius = size.shortestSide * 0.31;
    final double quality = (score.clamp(40, 100) - 40) / 60;
    final double breathing = 1 + math.sin(progress * math.pi * 2) * 0.018;

    // Ambient halo.
    canvas.drawCircle(
      center,
      baseRadius * 1.48,
      Paint()
        ..color = tone.withValues(alpha: dark ? 0.08 : 0.055)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.shortestSide * 0.085),
    );

    for (int layer = 0; layer < 4; layer++) {
      final Path path = Path();
      const int points = 140;
      final double layerRadius = baseRadius * (0.82 + layer * 0.115) * breathing;
      final double phase = progress * math.pi * 2 * (layer.isEven ? 1 : -0.75) + layer * 0.8;

      for (int i = 0; i <= points; i++) {
        final double angle = (i / points) * math.pi * 2;
        final double wobble =
            math.sin(angle * 3 + phase) * (0.018 + layer * 0.003) +
            math.sin(angle * 5 - phase * 0.65) * 0.010 +
            math.cos(angle * 2.2 + phase * 0.35) * 0.008;
        final double r = layerRadius * (1 + wobble * (0.8 + quality * 0.25));
        final Offset point = Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();

      final double alpha = dark ? (0.12 + layer * 0.035) : (0.10 + layer * 0.028);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer == 3 ? 1.2 : 0.8
          ..color = Color.lerp(tone, AppColors.accent(dark ? Brightness.dark : Brightness.light), layer / 5)!
              .withValues(alpha: alpha),
      );
    }

    final Rect field = Rect.fromCircle(center: center, radius: baseRadius * 1.12);
    canvas.drawCircle(
      center,
      baseRadius * 0.92,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            tone.withValues(alpha: dark ? 0.12 : 0.075),
            AppColors.accent(dark ? Brightness.dark : Brightness.light).withValues(alpha: dark ? 0.055 : 0.035),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(field),
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.score != score ||
        oldDelegate.dark != dark ||
        oldDelegate.tone != tone;
  }
}
