import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class FolioPage extends StatelessWidget {
  const FolioPage({
    required this.child,
    super.key,
    this.padding = AppSpacing.pageInsets,
    this.physics,
  });

  final Widget child;
  final EdgeInsets padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class FolioScroll extends StatelessWidget {
  const FolioScroll({
    required this.slivers,
    super.key,
    this.onRefresh,
  });

  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final CustomScrollView view = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: slivers,
    );
    if (onRefresh == null) return view;
    return RefreshIndicator(onRefresh: onRefresh!, color: Theme.of(context).colorScheme.onSurface, child: view);
  }
}
