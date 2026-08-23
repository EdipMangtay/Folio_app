import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FolioSuccess extends StatelessWidget {
  const FolioSuccess({
    required this.title,
    required this.body,
    super.key,
    this.height,
  });

  final String title;
  final String body;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.82, end: 1),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.scale(scale: 0.94 + (value * 0.06), child: child),
              );
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 32, color: AppColors.sage),
            ),
          ),
          const SizedBox(height: 26),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
