import 'package:flutter/material.dart';

import 'folio_motion.dart';

/// Peer-route transition: incoming fades in over canvas while the outgoing
/// screen fades away before it can be read underneath.
class FolioPageTransitionsBuilder extends PageTransitionsBuilder {
  const FolioPageTransitionsBuilder();

  static const Curve _curve = FolioMotion.through;
  static const double _slide = 0.055;

  static final Animatable<Offset> _enterSlide = Tween<Offset>(
    begin: const Offset(_slide, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: _curve));

  static final Animatable<Offset> _popSlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(_slide, 0),
  ).chain(CurveTween(curve: _curve));

  static final Animatable<Offset> _exitSlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-_slide, 0),
  ).chain(CurveTween(curve: _curve));

  static final Animatable<double> _fadeIn = Tween<double>(begin: 0, end: 1).chain(
    CurveTween(curve: const Interval(0.18, 1, curve: FolioMotion.enter)),
  );

  static final Animatable<double> _fadeOut = Tween<double>(begin: 1, end: 0).chain(
    CurveTween(curve: const Interval(0, 0.34, curve: FolioMotion.exit)),
  );

  @override
  Duration get transitionDuration => FolioMotion.page;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        bool allowSnapshotting,
        Widget? child,
      ) => _coverOutgoing(context, secondaryAnimation, child);

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context != null && FolioMotion.reduce(context)) {
      return child;
    }
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
        return FadeTransition(
          opacity: _fadeIn.animate(animation),
          child: SlideTransition(position: _enterSlide.animate(animation), child: child),
        );
      },
      reverseBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
        return FadeTransition(
          opacity: _fadeOut.animate(animation),
          child: SlideTransition(position: _popSlide.animate(animation), child: child),
        );
      },
      child: _coverOutgoing(context, secondaryAnimation, child),
    );
  }

  static Widget _coverOutgoing(
    BuildContext? context,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    final Color fill = context == null
        ? const Color(0xFFF4F3EE)
        : Theme.of(context).scaffoldBackgroundColor;

    final Widget moving = DualTransitionBuilder(
      animation: ReverseAnimation(secondaryAnimation),
      forwardBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
        return FadeTransition(
          opacity: _fadeIn.animate(animation),
          child: SlideTransition(position: _enterSlide.animate(animation), child: child),
        );
      },
      reverseBuilder: (BuildContext context, Animation<double> animation, Widget? child) {
        return FadeTransition(
          opacity: _fadeOut.animate(animation),
          child: SlideTransition(position: _exitSlide.animate(animation), child: child),
        );
      },
      child: child,
    );

    return ColoredBox(
      color: secondaryAnimation.isAnimating ? fill : Colors.transparent,
      child: moving,
    );
  }
}
