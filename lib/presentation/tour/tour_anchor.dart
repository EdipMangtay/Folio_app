import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tour/tour_step.dart';

/// Where the tour finds the thing it is pointing at.
///
/// Widgets announce themselves by name, so the phone dock and the tablet rail
/// can both offer `analyticsTab` and the tour never learns which shell is on
/// screen. Only one of them is mounted at a time.
class TourTargetRegistry {
  final Map<TourTarget, GlobalKey> _keys = <TourTarget, GlobalKey>{};

  void register(TourTarget target, GlobalKey key) => _keys[target] = key;

  /// Only clears the entry if this key is still the one registered, so a
  /// rebuild that registers the replacement first is not undone by the old
  /// widget's dispose.
  void unregister(TourTarget target, GlobalKey key) {
    if (identical(_keys[target], key)) _keys.remove(target);
  }

  /// The target's position in global coordinates, or null when it is not on
  /// screen or has not been laid out yet.
  Rect? rectOf(TourTarget target) {
    final BuildContext? context = _keys[target]?.currentContext;
    if (context == null) return null;
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) return null;
    return object.localToGlobal(Offset.zero) & object.size;
  }
}

final Provider<TourTargetRegistry> tourTargetRegistryProvider =
    Provider<TourTargetRegistry>((Ref ref) => TourTargetRegistry());

/// Marks its child as the thing the tour means by [target].
class TourAnchor extends ConsumerStatefulWidget {
  const TourAnchor({required this.target, required this.child, super.key});

  final TourTarget target;
  final Widget child;

  @override
  ConsumerState<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends ConsumerState<TourAnchor> {
  final GlobalKey _key = GlobalKey();

  /// Held rather than read on the way out: `ref` leans on BuildContext, which
  /// is already unsafe by the time dispose runs.
  late final TourTargetRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = ref.read(tourTargetRegistryProvider);
    _registry.register(widget.target, _key);
  }

  @override
  void dispose() {
    _registry.unregister(widget.target, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}
