import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/tour/tour_step.dart';
import '../widgets/income_entry_card.dart';
import '../widgets/premium_surface.dart';

/// Draws one stop of the tour: the screen dimmed, the target cut out of the
/// dimming, and a bubble saying what that control is for.
///
/// It is told where the target is rather than measuring it, because only the
/// shell knows when a tab change has settled enough to measure.
class TourOverlay extends StatelessWidget {
  const TourOverlay({
    required this.step,
    required this.highlight,
    required this.isLast,
    required this.position,
    required this.total,
    required this.onNext,
    required this.onSkip,
    required this.onIncome,
    super.key,
  });

  final TourStep step;

  /// Global rect of the control being described, or null when it could not be
  /// measured — the bubble then appears without a cut-out.
  final Rect? highlight;

  final bool isLast;

  /// Which stop this is, counting from one, and how many there are. Shown so
  /// the tour reads as a finite thing rather than an open-ended interruption.
  final int position;
  final int total;

  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Future<void> Function(double amount, String source) onIncome;

  static const double _pad = 8;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TourStep current = step;
    final Rect? cut = highlight?.inflate(_pad);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      // The overlay is mounted as a sibling of the Scaffold, so it carries its
      // own Material: text fields, ink and buttons all require one above them.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            // Blocks everything underneath: the tour drives, so a stray tap must
            // not take the user somewhere the tour has not reached.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(
                  painter: _ScrimPainter(
                    cutout: cut,
                    color: Colors.black.withValues(alpha: 0.62),
                    ring: AppColors.accent(theme.brightness),
                  ),
                ),
              ),
            ),
            if (current is TourFormStep)
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  // Skipping the income step means "no figure, carry on", not
                  // "end the tour" — that is what Geç on a spotlight does.
                  child: _FormBubble(
                    step: current,
                    onIncome: onIncome,
                    onSkip: onNext,
                  ),
                ),
              )
            else
              _SpotlightBubble(
                step: current as TourSpotlightStep,
                cutout: cut,
                isLast: isLast,
                position: position,
                total: total,
                onNext: onNext,
                onSkip: onSkip,
              ),
          ],
        ),
      ),
    );
  }
}

/// Dims everything except the cut-out, and rings the cut-out so the highlight
/// is a shape and not only a difference in brightness.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({
    required this.cutout,
    required this.color,
    required this.ring,
  });

  final Rect? cutout;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    final Paint scrim = Paint()..color = color;
    final Rect? hole = cutout;

    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }

    final RRect rounded = RRect.fromRectAndRadius(
      hole,
      const Radius.circular(AppSpacing.radiusMd),
    );
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, scrim);
    canvas.drawRRect(rounded, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      oldDelegate.cutout != cutout ||
      oldDelegate.color != color ||
      oldDelegate.ring != ring;
}

class _SpotlightBubble extends StatelessWidget {
  const _SpotlightBubble({
    required this.step,
    required this.cutout,
    required this.isLast,
    required this.position,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final TourSpotlightStep step;
  final Rect? cutout;
  final bool isLast;
  final int position;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final Rect? hole = cutout;
    // Sit on whichever side of the target has room; default to the lower half
    // of the screen when there is nothing to sit beside.
    final bool above = hole != null && hole.center.dy > screen.height / 2;

    return Positioned(
      left: 20,
      right: 20,
      top: above ? null : (hole?.bottom ?? screen.height * 0.35) + 16,
      bottom: above ? screen.height - hole.top + 16 : null,
      child: _Bubble(
        badge: step.badge,
        title: step.title,
        body: step.body,
        progress: '$position/$total',
        primaryLabel: isLast ? 'Bitir' : 'İleri',
        onPrimary: onNext,
        onSkip: onSkip,
      ),
    );
  }
}

class _FormBubble extends StatelessWidget {
  const _FormBubble({required this.step, required this.onIncome, required this.onSkip});

  final TourFormStep step;
  final Future<void> Function(double amount, String source) onIncome;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return IncomeEntryCard(
      title: step.title,
      body: step.body,
      onSubmit: onIncome,
      onSkip: onSkip,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.title,
    required this.body,
    required this.progress,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkip,
    this.badge,
  });

  final String title;
  final String body;
  final String progress;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (badge != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppColors.accent(theme.brightness).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accent(theme.brightness),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.soft(theme.brightness),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  progress,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted(theme.brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: AppColors.ink(theme.brightness).withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 44),
                  foregroundColor: AppColors.muted(theme.brightness),
                ),
                child: const Text('Geç'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(92, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(primaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
