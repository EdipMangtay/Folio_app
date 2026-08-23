import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FolioWordmark extends StatelessWidget {
  const FolioWordmark({super.key, this.compact = false, this.inverse = false});

  final bool compact;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final Color ink = inverse ? AppColors.inkDark : Theme.of(context).colorScheme.onSurface;
    final Color accent = AppColors.accent(Theme.of(context).brightness);
    final double markSize = compact ? 28 : 30;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: markSize,
          height: markSize,
          child: CustomPaint(painter: _MarkPainter(ink: ink, gem: accent)),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(width: 9),
          Text(
            'folio',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ink,
                  fontSize: 18,
                  letterSpacing: -0.75,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.ink, required this.gem});

  final Color ink;
  final Color gem;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint fill = Paint()..color = ink;
    final Paint gemPaint = Paint()..color = gem;

    final RRect vertical = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.32, h * 0.76),
      Radius.circular(w * 0.14),
    );
    final RRect top = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.66, h * 0.28),
      Radius.circular(w * 0.14),
    );
    final RRect middle = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.42, w * 0.50, h * 0.24),
      Radius.circular(w * 0.12),
    );

    canvas.drawRRect(vertical, fill);
    canvas.drawRRect(top, fill);
    canvas.drawRRect(middle, fill);
    canvas.drawCircle(Offset(w * 0.76, h * 0.72), w * 0.09, gemPaint);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => oldDelegate.ink != ink || oldDelegate.gem != gem;
}

class FolioIconButton extends StatelessWidget {
  const FolioIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.label,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = theme.colorScheme.onSurface;
    final Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.elevated(theme.brightness) : ink.withValues(alpha: theme.brightness == Brightness.dark ? 0.07 : 0.04),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.72), width: 0.7),
          ),
          child: Icon(icon, size: 18, color: ink),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: label ?? tooltip,
      child: tooltip == null ? button : Tooltip(message: tooltip!, child: button),
    );
  }
}
