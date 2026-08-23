import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/profile/privacy_gate.dart';
import 'state/settings_controller.dart';

class FolioApp extends ConsumerStatefulWidget {
  const FolioApp({required this.onboardingSeen, super.key});

  final bool onboardingSeen;

  @override
  ConsumerState<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends ConsumerState<FolioApp> {
  late final GoRouter _router = buildAppRouter(onboardingSeen: widget.onboardingSeen);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsState settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: _router,
      themeAnimationDuration: const Duration(milliseconds: 260),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35),
          ),
          child: PrivacyGate(
            enabled: settings.privacyLockEnabled,
            onDisable: () => ref.read(settingsProvider.notifier).setPrivacyLockEnabled(false),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
