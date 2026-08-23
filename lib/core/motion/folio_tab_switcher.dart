import 'package:flutter/material.dart';

import 'folio_motion.dart';

/// Cross-fades sibling tab navigators through the canvas so the outgoing
/// screen never sits readable underneath the incoming one.
class FolioTabSwitcher extends StatefulWidget {
  const FolioTabSwitcher({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FolioTabSwitcher> createState() => _FolioTabSwitcherState();
}

class _FolioTabSwitcherState extends State<FolioTabSwitcher> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _incoming;
  int? _outgoing;

  static const Interval _outInterval = Interval(0.0, 0.38, curve: FolioMotion.exit);
  static const Interval _inInterval = Interval(0.32, 1.0, curve: FolioMotion.enter);

  @override
  void initState() {
    super.initState();
    _incoming = widget.currentIndex;
    _controller = AnimationController(vsync: this, duration: FolioMotion.tab)..value = 1;
  }

  @override
  void didUpdateWidget(covariant FolioTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex == _incoming) return;
    _outgoing = _incoming;
    _incoming = widget.currentIndex;
    if (FolioMotion.reduce(context)) {
      _controller.value = 1;
      _outgoing = null;
    } else {
      _controller.forward(from: 0).whenComplete(() {
        if (!mounted || _controller.isAnimating) return;
        setState(() => _outgoing = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                for (int index = 0; index < widget.children.length; index++) _layer(index),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _layer(int index) {
    final bool isIncoming = index == _incoming;
    final bool isOutgoing = index == _outgoing && _outgoing != _incoming;
    final bool keepAlive = isIncoming || isOutgoing;
    final double progress = _controller.value;

    double opacity = 0;
    Offset slide = Offset.zero;

    if (isIncoming) {
      final double t = _inInterval.transform(progress);
      opacity = t;
      final double direction = (_outgoing != null && _incoming > _outgoing!) ? 1 : -1;
      slide = Offset(0.028 * direction * (1 - t), 0.01 * (1 - t));
    } else if (isOutgoing) {
      final double t = _outInterval.transform(progress);
      opacity = 1 - t;
      final double direction = _incoming > _outgoing! ? -1 : 1;
      slide = Offset(0.018 * direction * t, 0.006 * t);
    }

    return IgnorePointer(
      ignoring: !isIncoming || progress < 0.55,
      child: TickerMode(
        enabled: keepAlive,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: FractionalTranslation(
            translation: slide,
            child: SizedBox.expand(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: widget.children[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
