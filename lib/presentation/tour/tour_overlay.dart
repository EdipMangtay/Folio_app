import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/folio_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/tour/tour_step.dart';
import '../widgets/income_entry_card.dart';
import '../widgets/premium_surface.dart';

/// Draws one stop of the tour: the screen dimmed with backdrop softening,
/// the target cut out of the dimming with an ultra-smoothly animating spotlight,
/// pulsating outer glow halo, continuous top-interpolating card positioning,
/// directional pointer indicators, and rich interactive controls.
class TourOverlay extends StatefulWidget {
  const TourOverlay({
    required this.step,
    required this.highlight,
    required this.isLast,
    required this.position,
    required this.total,
    required this.onNext,
    required this.onSkip,
    required this.onIncome,
    this.onPrevious,
    super.key,
  });

  final TourStep step;

  /// Global rect of the control being described, or null when it could not be
  /// measured — the bubble then appears without a cut-out.
  final Rect? highlight;

  final bool isLast;

  /// Which stop this is, counting from one, and how many there are.
  final int position;
  final int total;

  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onPrevious;
  final Future<void> Function(double amount, String source) onIncome;

  static const double pad = 8.0;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> with TickerProviderStateMixin {
  late final AnimationController _morphController;
  late final Animation<double> _morphCurved;
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;

  RectTween? _rectTween;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _morphCurved = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutCubicEmphasized,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: FolioMotion.standard,
    )..forward();

    if (widget.highlight != null) {
      _rectTween = RectTween(begin: widget.highlight, end: widget.highlight);
      _morphController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      final Rect? current = _rectTween?.evaluate(_morphCurved) ?? oldWidget.highlight ?? widget.highlight;
      _rectTween = RectTween(begin: current, end: widget.highlight);
      _morphController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TourStep current = widget.step;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: _fadeController,
          child: Stack(
            children: <Widget>[
              // Animated scrim with morphing cutout and pulsing glow halo.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) {
                    final Rect? animatedRect = _rectTween?.evaluate(_morphCurved) ?? widget.highlight;
                    final Rect? cut = animatedRect?.inflate(TourOverlay.pad);
                    // Tapping directly inside the highlighted spotlight target advances the tour!
                    if (cut != null && cut.contains(details.localPosition)) {
                      HapticFeedback.lightImpact();
                      widget.onNext();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge(<Listenable>[_morphController, _pulseController]),
                    builder: (BuildContext context, Widget? child) {
                      final Rect? animatedRect = _rectTween?.evaluate(_morphCurved) ?? widget.highlight;
                      final Rect? cut = animatedRect?.inflate(TourOverlay.pad);

                      return CustomPaint(
                        painter: _ScrimPainter(
                          cutout: cut,
                          color: Colors.black.withValues(alpha: 0.65),
                          ring: AppColors.accent(theme.brightness),
                          pulse: _pulseController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Step content: Income entry form or animated spotlight bubble.
              if (current is TourFormStep)
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _FormBubble(
                      step: current,
                      onIncome: (double a, String s) async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await widget.onIncome(a, s);
                      },
                      onSkip: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        widget.onNext();
                      },
                    ),
                  ),
                )
              else
                AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_morphController, _pulseController]),
                  builder: (BuildContext context, Widget? child) {
                    final Rect? animatedRect = _rectTween?.evaluate(_morphCurved) ?? widget.highlight;
                    final Rect? cut = animatedRect?.inflate(TourOverlay.pad);

                    return _SpotlightBubble(
                      step: current as TourSpotlightStep,
                      cutout: cut,
                      isLast: widget.isLast,
                      position: widget.position,
                      total: widget.total,
                      pulse: _pulseController.value,
                      onNext: widget.onNext,
                      onSkip: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        widget.onSkip();
                      },
                      onPrevious: widget.onPrevious,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims everything except the cut-out, with a dynamic rounded aperture and a
/// pulsing outer glow halo that organically draws attention to the control.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({
    required this.cutout,
    required this.color,
    required this.ring,
    required this.pulse,
  });

  final Rect? cutout;
  final Color color;
  final Color ring;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    final Paint scrim = Paint()..color = color;
    final Rect? hole = cutout;

    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }

    final double radius = hole.height < 48
        ? hole.height / 2
        : (hole.width < 64 ? hole.width / 2 : AppSpacing.radiusMd + 2);
    final RRect rounded = RRect.fromRectAndRadius(
      hole,
      Radius.circular(radius),
    );

    // Punch the hole through the dimmed layer.
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, scrim);
    canvas.drawRRect(rounded, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Outer soft glow halo with pulsing radius.
    final double glowSpread = 3.0 + 3.5 * pulse;
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + glowSpread
      ..color = ring.withValues(alpha: 0.18 + 0.14 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSpread);
    canvas.drawRRect(rounded, glowPaint);

    // Crisp inner contour line.
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = ring.withValues(alpha: 0.88 + 0.12 * pulse);
    canvas.drawRRect(rounded, strokePaint);
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      oldDelegate.cutout != cutout ||
      oldDelegate.color != color ||
      oldDelegate.ring != ring ||
      oldDelegate.pulse != pulse;
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
    this.pulse = 0.5,
    this.onPrevious,
  });

  final TourSpotlightStep step;
  final Rect? cutout;
  final bool isLast;
  final int position;
  final int total;
  final double pulse;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onPrevious;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final Rect? hole = cutout;

    // Sit on whichever side of the target has more room.
    final bool above = hole != null && hole.center.dy > (screen.height * 0.48);

    // Compute an explicit, non-null top position so AnimatedPositioned glides smoothly without jumping.
    final double targetTop;
    if (hole == null) {
      targetTop = (screen.height * 0.32).clamp(padding.top + 16, screen.height - 260);
    } else if (above) {
      // Place above target
      const double estimatedCardHeight = 228.0;
      final double calculated = hole.top - 14 - estimatedCardHeight;
      targetTop = calculated.clamp(padding.top + 12, screen.height - estimatedCardHeight - padding.bottom - 12);
    } else {
      // Place below target
      final double calculated = hole.bottom + 14;
      targetTop = calculated.clamp(padding.top + 12, screen.height - 240 - padding.bottom);
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubicEmphasized,
      left: 18,
      right: 18,
      top: targetTop,
      child: GestureDetector(
        // Swipe gestures: Swipe left to advance, swipe right to go back.
        onHorizontalDragEnd: (DragEndDetails details) {
          final double vx = details.primaryVelocity ?? 0;
          if (vx < -220) {
            HapticFeedback.lightImpact();
            onNext();
          } else if (vx > 220 && position > 1 && onPrevious != null) {
            HapticFeedback.selectionClick();
            onPrevious!();
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(position),
            child: _Bubble(
              badge: step.badge,
              title: step.title,
              body: step.body,
              progress: '$position/$total',
              position: position,
              total: total,
              above: above,
              hasTarget: hole != null,
              pulse: pulse,
              primaryLabel: isLast ? 'Bitir' : 'İleri',
              onPrimary: onNext,
              onSkip: onSkip,
              onPrevious: position > 1 ? onPrevious : null,
            ),
          ),
        ),
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
    required this.position,
    required this.total,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkip,
    this.badge,
    this.onPrevious,
    this.above = false,
    this.hasTarget = true,
    this.pulse = 0.5,
  });

  final String title;
  final String body;
  final String progress;
  final int position;
  final int total;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;
  final VoidCallback? onPrevious;
  final String? badge;
  final bool above;
  final bool hasTarget;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accentColor = AppColors.accent(theme.brightness);

    return PremiumSurface(
      elevated: true,
      radius: AppSpacing.radiusXl,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Category badge & Step progress indicator
          Row(
            children: <Widget>[
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: isDark ? 0.32 : 0.22),
                      width: 0.75,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              // Step Counter pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.soft(theme.brightness),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  progress,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.ink(theme.brightness).withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Visual Step Progress Dots Strip
          Row(
            children: List<Widget>.generate(total, (int index) {
              final bool isActive = index + 1 == position;
              final bool isPassed = index + 1 < position;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(right: index < total - 1 ? 4 : 0),
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor
                        : isPassed
                            ? accentColor.withValues(alpha: 0.45)
                            : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 8),

          // Body text
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.46,
              color: AppColors.ink(theme.brightness).withValues(alpha: 0.86),
            ),
          ),

          const SizedBox(height: 20),

          // Navigation buttons
          Row(
            children: <Widget>[
              // Skip button
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onSkip();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(54, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppColors.muted(theme.brightness),
                ),
                child: const Text('Geç'),
              ),

              // Back button (if available)
              if (onPrevious != null) ...<Widget>[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Önceki',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onPrevious!();
                  },
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 44),
                    foregroundColor: AppColors.muted(theme.brightness),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              ],

              const Spacer(),

              // Primary Next / Finish button
              FilledButton.icon(
                onPressed: () {
                  if (primaryLabel == 'Bitir') {
                    HapticFeedback.mediumImpact();
                  } else {
                    HapticFeedback.lightImpact();
                  }
                  onPrimary();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(100, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(
                  primaryLabel == 'Bitir' ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 18,
                ),
                label: Text(
                  primaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
